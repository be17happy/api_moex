#!/usr/bin/env python3
"""
Скрипт для запуска Dask обработки данных МОЕХ
"""

import sys
import os

# Добавляем путь к модулям
sys.path.insert(0, '/opt/airflow/dags')
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dask_jobs.dask_processor import DaskMoexProcessor
from loguru import logger

def main():
    logger.info("=" * 50)
    logger.info("MOEX Dask Processing Pipeline")
    logger.info("=" * 50)

    # Создаем процессор
    processor = DaskMoexProcessor(
        dask_scheduler='dask-scheduler:8786',
        raw_db_url='postgresql://moex_user:moex_password@postgres_raw:5432/moex_raw',
        dwh_db_url='postgresql://moex_user:moex_password@postgres_dwh:5432/moex_dwh'
    )

    try:
        logger.info("Starting full processing pipeline...")

        # Запускаем полный пайплайн
        processor.run_full_pipeline()

        logger.info("=" * 50)
        logger.info("Pipeline completed successfully! ✓")
        logger.info("=" * 50)

        # Выводим статистику
        logger.info("\nStatistics:")

        import pandas as pd
        from sqlalchemy import create_engine

        dwh_engine = create_engine('postgresql://moex_user:moex_password@postgres_dwh:5432/moex_dwh')

        # Считаем записи
        stats = {
            'Securities': pd.read_sql("SELECT COUNT(*) FROM analytics.dim_security", dwh_engine).iloc[0, 0],
            'Dates': pd.read_sql("SELECT COUNT(*) FROM analytics.dim_date", dwh_engine).iloc[0, 0],
            'Daily Facts': pd.read_sql("SELECT COUNT(*) FROM analytics.fact_daily_trading", dwh_engine).iloc[0, 0],
            'Weekly Aggregates': pd.read_sql("SELECT COUNT(*) FROM analytics.agg_weekly_trading", dwh_engine).iloc[0, 0],
            'Monthly Aggregates': pd.read_sql("SELECT COUNT(*) FROM analytics.agg_monthly_trading", dwh_engine).iloc[0, 0],
            'Top Performers': pd.read_sql("SELECT COUNT(*) FROM analytics.top_performers", dwh_engine).iloc[0, 0],
            'Market Summary': pd.read_sql("SELECT COUNT(*) FROM analytics.market_summary", dwh_engine).iloc[0, 0],
        }

        for key, value in stats.items():
            logger.info(f"  {key}: {value}")

        dwh_engine.dispose()

    except Exception as e:
        logger.error(f"Error in pipeline execution: {e}")
        import traceback
        logger.error(traceback.format_exc())
        sys.exit(1)

    finally:
        processor.close()
        logger.info("\nDask processor closed")

if __name__ == "__main__":
    main()
