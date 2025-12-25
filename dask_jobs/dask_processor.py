"""
Dask processor for aggregating and transforming MOEX data
Обработка данных с использованием Dask для распределенных вычислений
"""

import dask.dataframe as dd
import pandas as pd
from dask.distributed import Client
from sqlalchemy import create_engine
from datetime import datetime, timedelta
from loguru import logger
from typing import Optional


class DaskMoexProcessor:
    """Процессор для обработки данных МОЕХ с использованием Dask"""

    def __init__(
        self,
        dask_scheduler: str = 'dask-scheduler:8786',
        raw_db_url: str = 'postgresql://moex_user:moex_password@postgres_raw:5432/moex_raw',
        dwh_db_url: str = 'postgresql://moex_user:moex_password@postgres_dwh:5432/moex_dwh'
    ):
        """
        Инициализация процессора

        Args:
            dask_scheduler: Адрес Dask scheduler
            raw_db_url: URL базы сырых данных
            dwh_db_url: URL хранилища данных
        """
        self.client = Client(dask_scheduler)
        self.raw_engine = create_engine(raw_db_url)
        self.dwh_engine = create_engine(dwh_db_url)
        logger.info(f"Dask client connected to {dask_scheduler}")

    def load_raw_data(self, table_name: str, schema: str = 'raw_data') -> dd.DataFrame:
        """
        Загрузка сырых данных из PostgreSQL в Dask DataFrame

        Args:
            table_name: Имя таблицы
            schema: Схема базы данных

        Returns:
            Dask DataFrame
        """
        logger.info(f"Loading data from {schema}.{table_name}")

        # Читаем данные с помощью pandas, затем конвертируем в dask
        query = f"SELECT * FROM {schema}.{table_name}"
        df_pandas = pd.read_sql(query, self.raw_engine)
        ddf = dd.from_pandas(df_pandas, npartitions=4)

        logger.info(f"Loaded {len(df_pandas)} rows")
        return ddf

    def process_daily_aggregates(self, start_date: Optional[str] = None):
        """
        Агрегация данных по дням

        Args:
            start_date: Дата начала обработки (по умолчанию последние 30 дней)
        """
        logger.info("Processing daily aggregates")

        if start_date is None:
            start_date = (datetime.now() - timedelta(days=30)).strftime('%Y-%m-%d')

        # Загружаем данные
        ddf_history = self.load_raw_data('trade_history')

        # Конвертируем в pandas для обработки
        df = ddf_history.compute()

        if df.empty:
            logger.warning("No data to process")
            return

        # Фильтруем по дате
        df['tradedate'] = pd.to_datetime(df['tradedate'])
        df = df[df['tradedate'] >= start_date]

        # Сначала заполняем dim_security
        self._populate_dim_security(df)

        # Затем заполняем dim_date
        self._populate_dim_date(df)

        # Получаем ключи для измерений
        dim_security = pd.read_sql("SELECT security_key, secid FROM analytics.dim_security WHERE is_current = true", self.dwh_engine)
        dim_date = pd.read_sql("SELECT date_key, date FROM analytics.dim_date", self.dwh_engine)

        # Преобразуем даты для join
        dim_date['date'] = pd.to_datetime(dim_date['date'])

        # Объединяем с измерениями
        df = df.merge(dim_security, on='secid', how='left')
        df = df.merge(dim_date, left_on='tradedate', right_on='date', how='left')

        # Вычисляем метрики
        df['price_change'] = df['close'] - df['open']
        df['price_change_pct'] = ((df['close'] - df['open']) / df['open'] * 100).round(4)
        df['volatility'] = ((df['high'] - df['low']) / df['open'] * 100).round(4)

        # Подготавливаем данные для fact таблицы
        fact_data = df[[
            'date_key', 'security_key', 'open', 'close', 'high', 'low',
            'volume', 'value', 'price_change', 'price_change_pct', 'volatility'
        ]].copy()

        fact_data.columns = [
            'date_key', 'security_key', 'open_price', 'close_price',
            'high_price', 'low_price', 'volume', 'value',
            'price_change', 'price_change_pct', 'volatility'
        ]

        # Удаляем дубликаты
        fact_data = fact_data.drop_duplicates(subset=['date_key', 'security_key'])

        # Загружаем в DWH
        fact_data.to_sql(
            'fact_daily_trading',
            self.dwh_engine,
            schema='analytics',
            if_exists='append',
            index=False,
            method='multi',
            chunksize=1000
        )

        logger.info(f"Processed {len(fact_data)} daily aggregate records")

    def process_weekly_aggregates(self):
        """Агрегация данных по неделям"""
        logger.info("Processing weekly aggregates")

        # Загружаем дневные данные
        query = """
        SELECT
            f.date_key,
            f.security_key,
            d.date,
            d.year,
            d.week,
            f.open_price,
            f.close_price,
            f.high_price,
            f.low_price,
            f.volume,
            f.value,
            f.price_change_pct,
            f.volatility
        FROM analytics.fact_daily_trading f
        JOIN analytics.dim_date d ON f.date_key = d.date_key
        ORDER BY f.security_key, d.date
        """

        df = pd.read_sql(query, self.dwh_engine)

        if df.empty:
            logger.warning("No data to aggregate")
            return

        # Группируем по неделям
        weekly = df.groupby(['security_key', 'year', 'week']).agg({
            'date': ['min', 'max'],
            'open_price': 'first',
            'close_price': 'last',
            'high_price': 'max',
            'low_price': 'min',
            'volume': 'sum',
            'value': 'sum',
            'price_change_pct': lambda x: ((x.iloc[-1] - x.iloc[0]) / x.iloc[0] * 100) if len(x) > 0 and x.iloc[0] != 0 else 0,
            'volatility': 'mean'
        }).reset_index()

        # Переименовываем колонки
        weekly.columns = [
            'security_key', 'year', 'week_num', 'week_start_date', 'week_end_date',
            'open_price', 'close_price', 'high_price', 'low_price',
            'total_volume', 'total_value', 'price_change_pct', 'avg_volatility'
        ]

        # Создаем week_key
        weekly['week_key'] = weekly['year'] * 100 + weekly['week_num']

        # Вычисляем среднюю цену и изменение
        weekly['avg_price'] = (weekly['open_price'] + weekly['close_price']) / 2
        weekly['price_change'] = weekly['close_price'] - weekly['open_price']
        weekly['total_trades'] = 0  # Можно добавить подсчет если есть данные

        # Загружаем в DWH
        weekly.to_sql(
            'agg_weekly_trading',
            self.dwh_engine,
            schema='analytics',
            if_exists='replace',
            index=False,
            method='multi',
            chunksize=1000
        )

        logger.info(f"Processed {len(weekly)} weekly aggregate records")

    def process_monthly_aggregates(self):
        """Агрегация данных по месяцам"""
        logger.info("Processing monthly aggregates")

        query = """
        SELECT
            f.date_key,
            f.security_key,
            d.date,
            d.year,
            d.month,
            f.open_price,
            f.close_price,
            f.high_price,
            f.low_price,
            f.volume,
            f.value,
            f.price_change_pct,
            f.volatility
        FROM analytics.fact_daily_trading f
        JOIN analytics.dim_date d ON f.date_key = d.date_key
        ORDER BY f.security_key, d.date
        """

        df = pd.read_sql(query, self.dwh_engine)

        if df.empty:
            logger.warning("No data to aggregate")
            return

        # Группируем по месяцам
        monthly = df.groupby(['security_key', 'year', 'month']).agg({
            'date': ['min', 'max'],
            'open_price': 'first',
            'close_price': 'last',
            'high_price': 'max',
            'low_price': 'min',
            'volume': 'sum',
            'value': 'sum',
            'price_change_pct': lambda x: ((x.iloc[-1] - x.iloc[0]) / x.iloc[0] * 100) if len(x) > 0 and x.iloc[0] != 0 else 0,
            'volatility': 'mean'
        }).reset_index()

        monthly.columns = [
            'security_key', 'year', 'month', 'month_start_date', 'month_end_date',
            'open_price', 'close_price', 'high_price', 'low_price',
            'total_volume', 'total_value', 'price_change_pct', 'avg_volatility'
        ]

        monthly['month_key'] = monthly['year'] * 100 + monthly['month']
        monthly['avg_price'] = (monthly['open_price'] + monthly['close_price']) / 2
        monthly['price_change'] = monthly['close_price'] - monthly['open_price']
        monthly['total_trades'] = 0

        # Загружаем в DWH
        monthly.to_sql(
            'agg_monthly_trading',
            self.dwh_engine,
            schema='analytics',
            if_exists='replace',
            index=False,
            method='multi',
            chunksize=1000
        )

        logger.info(f"Processed {len(monthly)} monthly aggregate records")

    def calculate_top_performers(self, period: str = 'daily', limit: int = 20):
        """
        Вычисление топовых бумаг по изменению цены

        Args:
            period: Период ('daily', 'weekly', 'monthly')
            limit: Количество топовых бумаг
        """
        logger.info(f"Calculating top {limit} performers for {period} period")

        if period == 'daily':
            query = """
            SELECT
                d.date as analysis_date,
                f.security_key,
                f.price_change_pct,
                f.volume,
                f.value,
                ROW_NUMBER() OVER (PARTITION BY d.date ORDER BY f.price_change_pct DESC) as rank
            FROM analytics.fact_daily_trading f
            JOIN analytics.dim_date d ON f.date_key = d.date_key
            WHERE d.date >= CURRENT_DATE - INTERVAL '30 days'
            """
        else:
            # Можно добавить для weekly и monthly
            logger.warning(f"Period {period} not implemented yet")
            return

        df = pd.read_sql(query, self.dwh_engine)

        if df.empty:
            logger.warning("No data for top performers")
            return

        # Фильтруем только топ N
        top_df = df[df['rank'] <= limit].copy()
        top_df['period'] = period

        # Загружаем в DWH
        top_df.to_sql(
            'top_performers',
            self.dwh_engine,
            schema='analytics',
            if_exists='append',
            index=False,
            method='multi',
            chunksize=1000
        )

        logger.info(f"Calculated {len(top_df)} top performer records")

    def calculate_market_summary(self):
        """Вычисление общей рыночной статистики"""
        logger.info("Calculating market summary")

        query = """
        SELECT
            d.date as summary_date,
            COUNT(DISTINCT f.security_key) as total_securities,
            SUM(f.volume) as total_volume,
            SUM(f.value) as total_value,
            AVG(f.price_change_pct) as avg_price_change_pct,
            SUM(CASE WHEN f.price_change_pct > 0 THEN 1 ELSE 0 END) as gainers_count,
            SUM(CASE WHEN f.price_change_pct < 0 THEN 1 ELSE 0 END) as losers_count,
            SUM(CASE WHEN f.price_change_pct = 0 THEN 1 ELSE 0 END) as unchanged_count,
            AVG(f.volatility) as market_volatility
        FROM analytics.fact_daily_trading f
        JOIN analytics.dim_date d ON f.date_key = d.date_key
        WHERE d.date >= CURRENT_DATE - INTERVAL '30 days'
        GROUP BY d.date
        ORDER BY d.date
        """

        df = pd.read_sql(query, self.dwh_engine)

        if df.empty:
            logger.warning("No data for market summary")
            return

        # Загружаем в DWH
        df.to_sql(
            'market_summary',
            self.dwh_engine,
            schema='analytics',
            if_exists='replace',
            index=False,
            method='multi',
            chunksize=1000
        )

        logger.info(f"Calculated {len(df)} market summary records")

    def _populate_dim_security(self, df: pd.DataFrame):
        """Заполнение таблицы измерения ценных бумаг"""
        logger.info("Populating dim_security")

        # Получаем уникальные secid из сырых данных
        securities = df[['secid']].drop_duplicates()

        # Получаем дополнительные данные из stocks
        stocks_df = pd.read_sql("SELECT * FROM raw_data.stocks", self.raw_engine)

        # Объединяем
        securities = securities.merge(stocks_df, on='secid', how='left')

        # Подготавливаем данные
        dim_data = pd.DataFrame({
            'secid': securities['secid'],
            'shortname': securities.get('shortname'),
            'sectypename': securities.get('sectypename'),
            'boardname': securities.get('boardname'),
            'lotsize': securities.get('lotsize'),
            'facevalue': securities.get('facevalue'),
            'valid_from': datetime.now(),
            'valid_to': pd.Timestamp('9999-12-31'),
            'is_current': True
        })

        # Вставляем только новые бумаги
        existing = pd.read_sql("SELECT secid FROM analytics.dim_security WHERE is_current = true", self.dwh_engine)
        new_securities = dim_data[~dim_data['secid'].isin(existing['secid'])]

        if not new_securities.empty:
            new_securities.to_sql(
                'dim_security',
                self.dwh_engine,
                schema='analytics',
                if_exists='append',
                index=False
            )
            logger.info(f"Added {len(new_securities)} new securities to dim_security")

    def _populate_dim_date(self, df: pd.DataFrame):
        """Заполнение таблицы измерения дат"""
        logger.info("Populating dim_date")

        # Получаем уникальные даты
        dates = pd.DataFrame({'date': pd.to_datetime(df['tradedate'].unique())})
        dates = dates.sort_values('date')

        # Создаем измерение дат
        dim_dates = pd.DataFrame({
            'date': dates['date'],
            'date_key': dates['date'].dt.strftime('%Y%m%d').astype(int),
            'year': dates['date'].dt.year,
            'quarter': dates['date'].dt.quarter,
            'month': dates['date'].dt.month,
            'week': dates['date'].dt.isocalendar().week,
            'day': dates['date'].dt.day,
            'day_of_week': dates['date'].dt.dayofweek,
            'day_name': dates['date'].dt.day_name(),
            'month_name': dates['date'].dt.month_name(),
            'is_weekend': dates['date'].dt.dayofweek >= 5
        })

        # Вставляем только новые даты
        existing = pd.read_sql("SELECT date_key FROM analytics.dim_date", self.dwh_engine)
        new_dates = dim_dates[~dim_dates['date_key'].isin(existing['date_key'])]

        if not new_dates.empty:
            new_dates.to_sql(
                'dim_date',
                self.dwh_engine,
                schema='analytics',
                if_exists='append',
                index=False
            )
            logger.info(f"Added {len(new_dates)} new dates to dim_date")

    def run_full_pipeline(self):
        """Запуск полного пайплайна обработки"""
        logger.info("Starting full Dask processing pipeline")

        try:
            # 1. Обработка дневных агрегатов
            self.process_daily_aggregates()

            # 2. Обработка недельных агрегатов
            self.process_weekly_aggregates()

            # 3. Обработка месячных агрегатов
            self.process_monthly_aggregates()

            # 4. Вычисление топовых бумаг
            self.calculate_top_performers('daily', limit=20)

            # 5. Вычисление рыночной статистики
            self.calculate_market_summary()

            logger.info("Full pipeline completed successfully")

        except Exception as e:
            logger.error(f"Error in pipeline execution: {e}")
            raise

    def close(self):
        """Закрытие соединений"""
        self.client.close()
        self.raw_engine.dispose()
        self.dwh_engine.dispose()
        logger.info("Dask processor closed")


if __name__ == "__main__":
    # Пример использования
    processor = DaskMoexProcessor(
        dask_scheduler='localhost:8786',
        raw_db_url='postgresql://moex_user:moex_password@localhost:5432/moex_raw',
        dwh_db_url='postgresql://moex_user:moex_password@localhost:5433/moex_dwh'
    )

    try:
        processor.run_full_pipeline()
    finally:
        processor.close()
