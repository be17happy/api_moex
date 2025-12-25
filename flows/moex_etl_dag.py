"""
AirFlow DAG для ETL процесса данных Московской биржи
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.postgres.operators.postgres import PostgresOperator
from airflow.providers.postgres.hooks.postgres import PostgresHook
import pandas as pd
from moex_api_client import MoexAPIClient
from loguru import logger
import sys
import os

# Добавляем путь к конфигурации
sys.path.insert(0, '/opt/airflow/config')

# Импортируем конфигурацию (с fallback на дефолтные значения)
try:
    from data_config import MAX_SECURITIES, HISTORY_DAYS, BOARD
except ImportError:
    MAX_SECURITIES = 20
    HISTORY_DAYS = 30
    BOARD = 'TQBR'

# Конфигурация по умолчанию
default_args = {
    'owner': 'moex_analytics',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 3,
    'retry_delay': timedelta(minutes=5),
}


def extract_stock_list(**context):
    """Извлечение списка акций"""
    logger.info("Starting stock list extraction")

    client = MoexAPIClient()
    try:
        # Получаем список акций
        df = client.get_stock_list(board='TQBR')

        # Сохраняем в PostgreSQL
        hook = PostgresHook(postgres_conn_id='postgres_raw')
        engine = hook.get_sqlalchemy_engine()

        # Подготовка данных - используем только доступные колонки
        df_to_insert = pd.DataFrame({
            'secid': df['SECID'],
            'shortname': df.get('SHORTNAME', None),
            'lotsize': df.get('LOTSIZE', None),
            'boardid': df.get('BOARDID', 'TQBR'),  # По умолчанию TQBR
            'prevprice': df.get('PREVPRICE', None),
            'facevalue': df.get('FACEVALUE', None),
            'status': df.get('STATUS', 'A'),  # По умолчанию Active
            'boardname': df.get('BOARDNAME', 'Т+ Акции и ДР'),
            'decimals': df.get('DECIMALS', 2),
            'sectypename': df.get('SECTYPENAME', 'Акции'),
            'remarks': df.get('REMARKS', None)
        })

        # Вставка в БД
        df_to_insert.to_sql(
            'stocks',
            engine,
            schema='raw_data',
            if_exists='replace',
            index=False,
            method='multi',
            chunksize=1000
        )

        logger.info(f"Inserted {len(df_to_insert)} stocks into database")

        # Сохраняем список бумаг для следующих задач (используем конфиг)
        top_securities = df['SECID'].head(MAX_SECURITIES).tolist()
        logger.info(f"Selected {len(top_securities)} securities for processing")
        context['ti'].xcom_push(key='top_securities', value=top_securities)

        return len(df_to_insert)

    except Exception as e:
        logger.error(f"Error in stock list extraction: {e}")
        raise
    finally:
        client.close()


def extract_trade_history(**context):
    """Извлечение исторических данных торгов"""
    logger.info("Starting trade history extraction")

    # Получаем список бумаг из предыдущей задачи
    ti = context['ti']
    securities = ti.xcom_pull(key='top_securities', task_ids='extract_stock_list')

    if not securities:
        logger.warning("No securities found, using default list")
        securities = ['SBER', 'GAZP', 'LKOH', 'YNDX', 'GMKN']

    client = MoexAPIClient()
    hook = PostgresHook(postgres_conn_id='postgres_raw')
    engine = hook.get_sqlalchemy_engine()

    try:
        # Получаем данные за указанный период (из конфига)
        end_date = datetime.now().strftime('%Y-%m-%d')
        start_date = (datetime.now() - timedelta(days=HISTORY_DAYS)).strftime('%Y-%m-%d')

        logger.info(f"Loading history from {start_date} to {end_date} ({HISTORY_DAYS} days)")

        all_data = []

        for security in securities:  # Используем все акции из конфига
            try:
                logger.info(f"Fetching history for {security}")
                df = client.get_history(security, start_date, end_date)

                if not df.empty:
                    # Подготовка данных
                    df_prepared = pd.DataFrame({
                        'secid': df['SECID'],
                        'tradedate': pd.to_datetime(df['TRADEDATE']),
                        'open': df.get('OPEN'),
                        'low': df.get('LOW'),
                        'high': df.get('HIGH'),
                        'close': df.get('CLOSE'),
                        'volume': df.get('VOLUME'),
                        'value': df.get('VALUE')
                    })

                    all_data.append(df_prepared)

            except Exception as e:
                logger.error(f"Error fetching data for {security}: {e}")
                continue

        if all_data:
            # Объединяем все данные
            final_df = pd.concat(all_data, ignore_index=True)

            # Вставка в БД с обновлением дубликатов
            final_df.to_sql(
                'trade_history',
                engine,
                schema='raw_data',
                if_exists='append',
                index=False,
                method='multi',
                chunksize=1000
            )

            logger.info(f"Inserted {len(final_df)} trade history records")
            return len(final_df)
        else:
            logger.warning("No trade history data retrieved")
            return 0

    except Exception as e:
        logger.error(f"Error in trade history extraction: {e}")
        raise
    finally:
        client.close()


def extract_market_data(**context):
    """Извлечение текущих рыночных данных"""
    logger.info("Starting market data extraction")

    ti = context['ti']
    securities = ti.xcom_pull(key='top_securities', task_ids='extract_stock_list')

    if not securities:
        securities = ['SBER', 'GAZP', 'LKOH', 'YNDX', 'GMKN']

    client = MoexAPIClient()
    hook = PostgresHook(postgres_conn_id='postgres_raw')
    engine = hook.get_sqlalchemy_engine()

    try:
        all_data = []

        for security in securities[:20]:
            try:
                df = client.get_market_data(security)
                if not df.empty:
                    all_data.append(df)
            except Exception as e:
                logger.error(f"Error fetching market data for {security}: {e}")
                continue

        if all_data:
            final_df = pd.concat(all_data, ignore_index=True)

            # Вставка в БД
            final_df.to_sql(
                'market_data',
                engine,
                schema='raw_data',
                if_exists='append',
                index=False,
                method='multi',
                chunksize=1000
            )

            logger.info(f"Inserted {len(final_df)} market data records")
            return len(final_df)
        else:
            logger.warning("No market data retrieved")
            return 0

    except Exception as e:
        logger.error(f"Error in market data extraction: {e}")
        raise
    finally:
        client.close()


def log_etl_job(**context):
    """Логирование выполнения ETL задачи"""
    ti = context['ti']
    task_id = context['task'].task_id

    hook = PostgresHook(postgres_conn_id='postgres_raw')
    conn = hook.get_conn()
    cursor = conn.cursor()

    try:
        # Используем data_interval_start вместо deprecated execution_date
        start_time = context.get('data_interval_start')
        if start_time and hasattr(start_time, 'naive'):
            start_time = start_time.naive()
        else:
            start_time = datetime.now()

        cursor.execute("""
            INSERT INTO raw_data.etl_logs (job_name, status, start_time, end_time, records_processed)
            VALUES (%s, %s, %s, %s, %s)
        """, (
            task_id,
            'SUCCESS',
            start_time,
            datetime.now(),
            0
        ))
        conn.commit()
    finally:
        cursor.close()
        conn.close()


# Создание DAG
with DAG(
    'moex_etl_pipeline',
    default_args=default_args,
    description='ETL pipeline for Moscow Exchange data',
    schedule_interval='0 */6 * * *',  # Каждые 6 часов
    catchup=False,
    tags=['moex', 'etl', 'trading'],
) as dag:

    # Задача 1: Извлечение списка акций
    task_extract_stocks = PythonOperator(
        task_id='extract_stock_list',
        python_callable=extract_stock_list,
        provide_context=True,
    )

    # Задача 2: Извлечение исторических данных
    task_extract_history = PythonOperator(
        task_id='extract_trade_history',
        python_callable=extract_trade_history,
        provide_context=True,
    )

    # Задача 3: Извлечение рыночных данных
    task_extract_market = PythonOperator(
        task_id='extract_market_data',
        python_callable=extract_market_data,
        provide_context=True,
    )

    # Задача 4: Логирование
    task_log = PythonOperator(
        task_id='log_etl_completion',
        python_callable=log_etl_job,
        provide_context=True,
    )

    # Задача 5: Запуск Dask обработки (будет реализован позже)
    task_trigger_dask = PythonOperator(
        task_id='trigger_dask_processing',
        python_callable=lambda: logger.info("Triggering Dask processing..."),
    )

    # Определение зависимостей
    task_extract_stocks >> [task_extract_history, task_extract_market]
    [task_extract_history, task_extract_market] >> task_log >> task_trigger_dask
