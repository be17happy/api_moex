"""
Moscow Exchange API Client
Модуль для работы с API Московской биржи
"""

import apimoex
import requests
import pandas as pd
from datetime import datetime, timedelta
from typing import List, Dict, Optional
from loguru import logger


class MoexAPIClient:
    """Клиент для работы с API Московской биржи"""

    def __init__(self):
        self.session = requests.Session()
        logger.info("MOEX API Client initialized")

    def get_stock_list(self, board: str = 'TQBR') -> pd.DataFrame:
        """
        Получить список акций с указанной площадки

        Args:
            board: Код площадки (по умолчанию TQBR - основной режим торгов)

        Returns:
            DataFrame с информацией об акциях
        """
        try:
            logger.info(f"Fetching stock list for board: {board}")
            data = apimoex.get_board_securities(self.session, board=board)
            df = pd.DataFrame(data)
            logger.info(f"Retrieved {len(df)} securities")
            return df
        except Exception as e:
            logger.error(f"Error fetching stock list: {e}")
            raise

    def get_market_data(self, security: str = 'SBER') -> pd.DataFrame:
        """
        Получить текущие рыночные данные по бумаге

        Args:
            security: Тикер ценной бумаги

        Returns:
            DataFrame с рыночными данными
        """
        try:
            logger.info(f"Fetching market data for: {security}")
            data = apimoex.get_market_data(self.session, security=security)
            df = pd.DataFrame(data)
            df['timestamp'] = datetime.now()
            df['secid'] = security
            logger.info(f"Retrieved market data for {security}")
            return df
        except Exception as e:
            logger.error(f"Error fetching market data for {security}: {e}")
            raise

    def get_history(
        self,
        security: str,
        start_date: Optional[str] = None,
        end_date: Optional[str] = None,
        board: str = 'TQBR'
    ) -> pd.DataFrame:
        """
        Получить исторические данные торгов

        Args:
            security: Тикер ценной бумаги
            start_date: Дата начала в формате 'YYYY-MM-DD'
            end_date: Дата окончания в формате 'YYYY-MM-DD'
            board: Код площадки

        Returns:
            DataFrame с историческими данными
        """
        try:
            # Установить даты по умолчанию, если не указаны
            if end_date is None:
                end_date = datetime.now().strftime('%Y-%m-%d')
            if start_date is None:
                start_date = (datetime.now() - timedelta(days=365)).strftime('%Y-%m-%d')

            logger.info(f"Fetching history for {security} from {start_date} to {end_date}")

            data = apimoex.get_board_history(
                self.session,
                security=security,
                start=start_date,
                end=end_date,
                board=board
            )

            df = pd.DataFrame(data)

            if not df.empty:
                df['TRADEDATE'] = pd.to_datetime(df['TRADEDATE'])
                df['secid'] = security
                logger.info(f"Retrieved {len(df)} records for {security}")
            else:
                logger.warning(f"No data found for {security}")

            return df
        except Exception as e:
            logger.error(f"Error fetching history for {security}: {e}")
            raise

    def get_multiple_securities_history(
        self,
        securities: List[str],
        start_date: Optional[str] = None,
        end_date: Optional[str] = None,
        board: str = 'TQBR'
    ) -> pd.DataFrame:
        """
        Получить исторические данные для нескольких бумаг

        Args:
            securities: Список тикеров
            start_date: Дата начала
            end_date: Дата окончания
            board: Код площадки

        Returns:
            DataFrame с объединенными данными
        """
        all_data = []

        for security in securities:
            try:
                df = self.get_history(security, start_date, end_date, board)
                if not df.empty:
                    all_data.append(df)
            except Exception as e:
                logger.error(f"Failed to get data for {security}: {e}")
                continue

        if all_data:
            result = pd.concat(all_data, ignore_index=True)
            logger.info(f"Total records retrieved: {len(result)}")
            return result
        else:
            logger.warning("No data retrieved for any security")
            return pd.DataFrame()

    def get_top_securities(self, limit: int = 50) -> List[str]:
        """
        Получить список топовых ценных бумаг по объему торгов

        Args:
            limit: Количество бумаг

        Returns:
            Список тикеров
        """
        try:
            logger.info(f"Fetching top {limit} securities")
            df = self.get_stock_list()

            # Фильтруем активные бумаги
            if 'PREVPRICE' in df.columns:
                df = df[df['PREVPRICE'].notna()]
                df = df.sort_values('PREVPRICE', ascending=False)

            securities = df['SECID'].head(limit).tolist()
            logger.info(f"Retrieved {len(securities)} top securities")
            return securities
        except Exception as e:
            logger.error(f"Error fetching top securities: {e}")
            raise

    def close(self):
        """Закрыть сессию"""
        self.session.close()
        logger.info("MOEX API Client session closed")


# Пример использования
if __name__ == "__main__":
    client = MoexAPIClient()

    # Получить список акций
    stocks = client.get_stock_list()
    print(f"Total stocks: {len(stocks)}")
    print(stocks.head())

    # Получить исторические данные
    history = client.get_history('SBER', start_date='2024-01-01')
    print(f"\nHistory records: {len(history)}")
    print(history.head())

    # Получить текущие рыночные данные
    market_data = client.get_market_data('SBER')
    print(f"\nMarket data:")
    print(market_data.head())

    client.close()
