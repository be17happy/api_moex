#!/bin/bash

echo "================================================"
echo "MOEX Analytics - Полный пайплайн"
echo "================================================"
echo ""

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Шаг 1: Настройка подключений AirFlow
echo "Шаг 1/4: Настройка AirFlow..."
./config/airflow_connections.sh
echo ""

# Шаг 2: Запуск ETL
echo "Шаг 2/4: Запуск ETL процесса..."
echo "Это займет 5-15 минут в зависимости от настроек..."
docker exec moex_airflow_webserver airflow dags unpause moex_etl_pipeline
docker exec moex_airflow_webserver airflow dags trigger moex_etl_pipeline

echo ""
echo "Ожидание завершения ETL (5 минут)..."
sleep 300

# Проверка данных
stocks=$(docker exec moex_postgres_raw psql -U moex_user -d moex_raw -t -c "SELECT COUNT(*) FROM raw_data.stocks;" 2>/dev/null | tr -d '[:space:]')
history=$(docker exec moex_postgres_raw psql -U moex_user -d moex_raw -t -c "SELECT COUNT(*) FROM raw_data.trade_history;" 2>/dev/null | tr -d '[:space:]')

echo ""
echo "Загружено данных:"
echo "  - Акции: $stocks"
echo "  - История торгов: $history"
echo ""

if [ "$history" == "0" ]; then
    echo -e "${YELLOW}⚠${NC} История торгов не загружена. Генерируем демо-данные..."

    docker exec moex_airflow_webserver bash -c "cat > /tmp/gen_demo.py << 'EOF'
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from sqlalchemy import create_engine
import random

raw_engine = create_engine('postgresql://moex_user:moex_password@postgres_raw:5432/moex_raw')

# Читаем конфигурацию
try:
    import sys
    sys.path.insert(0, '/opt/airflow/config')
    from data_config import MAX_SECURITIES, HISTORY_DAYS
except:
    MAX_SECURITIES = 250
    HISTORY_DAYS = 73

stocks_df = pd.read_sql(f'SELECT secid FROM raw_data.stocks LIMIT {MAX_SECURITIES}', raw_engine)
end_date = datetime.now()
start_date = end_date - timedelta(days=HISTORY_DAYS)
dates = pd.date_range(start=start_date, end=end_date, freq='D')

print(f'Generating {HISTORY_DAYS} days of data for {len(stocks_df)} securities...')

all_history = []
for idx, stock in stocks_df.iterrows():
    secid = stock['secid']
    base_price = random.uniform(50, 500)

    for date in dates:
        if date.weekday() >= 5:
            continue

        vol = random.uniform(0.02, 0.05)
        open_p = base_price * (1 + random.uniform(-vol, vol))
        close_p = open_p * (1 + random.uniform(-vol, vol))
        high_p = max(open_p, close_p) * (1 + random.uniform(0, vol))
        low_p = min(open_p, close_p) * (1 - random.uniform(0, vol))
        volume = random.randint(100000, 10000000)

        all_history.append({
            'secid': secid,
            'tradedate': date.date(),
            'open': round(open_p, 2),
            'low': round(low_p, 2),
            'high': round(high_p, 2),
            'close': round(close_p, 2),
            'volume': volume,
            'value': round(volume * close_p, 2)
        })
        base_price = close_p

history_df = pd.DataFrame(all_history)
history_df.to_sql('trade_history', raw_engine, schema='raw_data', if_exists='append', index=False, method='multi', chunksize=1000)

count = pd.read_sql('SELECT COUNT(*) as cnt FROM raw_data.trade_history', raw_engine).iloc[0, 0]
print(f'Generated {count} records')
EOF
python /tmp/gen_demo.py"
fi

echo ""
echo "Шаг 3/4: Запуск Dask обработки..."

docker exec moex_airflow_webserver bash -c "cat > /tmp/process_data.py << 'EOFPY'
import pandas as pd
import dask.dataframe as dd
from sqlalchemy import create_engine
from datetime import datetime
import gc

raw_engine = create_engine('postgresql://moex_user:moex_password@postgres_raw:5432/moex_raw')
dwh_engine = create_engine('postgresql://moex_user:moex_password@postgres_dwh:5432/moex_dwh')

# Загружаем конфигурацию
CHUNK_SIZE = 50000  # Обработка по 50k записей за раз

print('BIG DATA обработка с использованием Dask...')
print(f'Chunk size: {CHUNK_SIZE:,} records')

# 1. dim_security (малая таблица, обрабатываем обычным pandas)
print('\\n1/4: Обработка dim_security...')
securities = pd.read_sql('SELECT DISTINCT secid FROM raw_data.trade_history', raw_engine)
stocks = pd.read_sql('SELECT * FROM raw_data.stocks', raw_engine)
securities = securities.merge(stocks, on='secid', how='left')

dim_security = pd.DataFrame({
    'secid': securities['secid'],
    'shortname': securities.get('shortname'),
    'sectypename': securities.get('sectypename', 'Акции'),
    'boardname': securities.get('boardname', 'Т+'),
    'lotsize': securities.get('lotsize'),
    'facevalue': securities.get('facevalue'),
    'valid_from': datetime.now(),
    'valid_to': pd.Timestamp('9999-12-31'),
    'is_current': True
})
dim_security.to_sql('dim_security', dwh_engine, schema='analytics', if_exists='append', index=False)
print(f'Загружено {len(dim_security)} securities')

# 2. dim_date (малая таблица)
print('\\n2/4: Обработка dim_date...')
dates_df = pd.read_sql('SELECT DISTINCT tradedate FROM raw_data.trade_history', raw_engine)
dates_df['tradedate'] = pd.to_datetime(dates_df['tradedate'])

dim_dates = pd.DataFrame({
    'date': dates_df['tradedate'],
    'date_key': dates_df['tradedate'].dt.strftime('%Y%m%d').astype(int),
    'year': dates_df['tradedate'].dt.year,
    'quarter': dates_df['tradedate'].dt.quarter,
    'month': dates_df['tradedate'].dt.month,
    'week': dates_df['tradedate'].dt.isocalendar().week,
    'day': dates_df['tradedate'].dt.day,
    'day_of_week': dates_df['tradedate'].dt.dayofweek,
    'day_name': dates_df['tradedate'].dt.day_name(),
    'month_name': dates_df['tradedate'].dt.month_name(),
    'is_weekend': dates_df['tradedate'].dt.dayofweek >= 5
})
dim_dates.to_sql('dim_date', dwh_engine, schema='analytics', if_exists='append', index=False)
print(f'Загружено {len(dim_dates)} dates')

# 3. fact_daily_trading (БОЛЬШАЯ таблица - используем chunked processing)
print('\\n3/4: Обработка fact_daily_trading (BIG DATA)...')

# Получаем измерения для джоина
dim_sec = pd.read_sql('SELECT security_key, secid FROM analytics.dim_security WHERE is_current = true', dwh_engine)
dim_dt = pd.read_sql('SELECT date_key, date FROM analytics.dim_date', dwh_engine)
dim_dt['date'] = pd.to_datetime(dim_dt['date'])

# Считаем общее количество записей
total_count = pd.read_sql('SELECT COUNT(*) as cnt FROM raw_data.trade_history', raw_engine).iloc[0, 0]
print(f'Всего записей для обработки: {total_count:,}')
print(f'Примерный размер в памяти: ~{(total_count * 100 / 1024 / 1024):.1f} MB')

# Обрабатываем данные по частям (chunks)
chunks_processed = 0
total_facts_loaded = 0

for chunk_num, chunk in enumerate(pd.read_sql('SELECT * FROM raw_data.trade_history', raw_engine, chunksize=CHUNK_SIZE)):
    chunk['tradedate'] = pd.to_datetime(chunk['tradedate'])

    # Джоины с измерениями
    chunk = chunk.merge(dim_sec, on='secid', how='left')
    chunk = chunk.merge(dim_dt, left_on='tradedate', right_on='date', how='left')

    # Вычисления
    chunk['price_change'] = chunk['close'] - chunk['open']
    chunk['price_change_pct'] = ((chunk['close'] - chunk['open']) / chunk['open'] * 100).round(4)
    chunk['volatility'] = ((chunk['high'] - chunk['low']) / chunk['open'] * 100).round(4)

    # Подготовка фактов
    fact_chunk = chunk[['date_key', 'security_key', 'open', 'close', 'high', 'low', 'volume', 'value', 'price_change', 'price_change_pct', 'volatility']].copy()
    fact_chunk.columns = ['date_key', 'security_key', 'open_price', 'close_price', 'high_price', 'low_price', 'volume', 'value', 'price_change', 'price_change_pct', 'volatility']
    fact_chunk = fact_chunk.drop_duplicates(subset=['date_key', 'security_key'])

    # Загрузка в DWH
    fact_chunk.to_sql('fact_daily_trading', dwh_engine, schema='analytics', if_exists='append', index=False, method='multi', chunksize=1000)

    chunks_processed += 1
    total_facts_loaded += len(fact_chunk)

    # Освобождаем память
    del chunk, fact_chunk
    gc.collect()

    if chunks_processed % 5 == 0:
        print(f'  Обработано chunks: {chunks_processed}, записей: {total_facts_loaded:,} / {total_count:,} ({100*total_facts_loaded/total_count:.1f}%)')

print(f'Загружено {total_facts_loaded:,} facts (обработано {chunks_processed} chunks)')

# 4. market_summary (агрегация)
print('\\n4/4: Обработка market_summary...')

# Читаем факты по частям и агрегируем
summary_parts = []

for chunk in pd.read_sql('SELECT * FROM analytics.fact_daily_trading', dwh_engine, chunksize=CHUNK_SIZE):
    chunk_summary = chunk.groupby('date_key').agg({
        'security_key': 'count',
        'volume': 'sum',
        'value': 'sum',
        'price_change_pct': 'mean',
        'volatility': 'mean'
    }).reset_index()

    chunk_summary['gainers_count'] = chunk[chunk['price_change_pct'] > 0].groupby('date_key').size()
    chunk_summary['losers_count'] = chunk[chunk['price_change_pct'] < 0].groupby('date_key').size()
    chunk_summary['unchanged_count'] = chunk[chunk['price_change_pct'] == 0].groupby('date_key').size()

    summary_parts.append(chunk_summary)

# Объединяем части и финальная агрегация
summary = pd.concat(summary_parts, ignore_index=True)
summary = summary.groupby('date_key').agg({
    'security_key': 'sum',
    'volume': 'sum',
    'value': 'sum',
    'price_change_pct': 'mean',
    'volatility': 'mean',
    'gainers_count': 'sum',
    'losers_count': 'sum',
    'unchanged_count': 'sum'
}).reset_index()

summary.columns = ['date_key', 'total_securities', 'total_volume', 'total_value', 'avg_price_change_pct', 'market_volatility', 'gainers_count', 'losers_count', 'unchanged_count']

dim_dt_map = dim_dt.set_index('date_key')['date'].to_dict()
summary['summary_date'] = summary['date_key'].map(dim_dt_map)

summary[['summary_date', 'total_securities', 'total_volume', 'total_value', 'avg_price_change_pct', 'gainers_count', 'losers_count', 'unchanged_count', 'market_volatility']].to_sql('market_summary', dwh_engine, schema='analytics', if_exists='append', index=False)

print(f'Загружено {len(summary)} summary records')

print('\\n' + '='*60)
print('BIG DATA обработка завершена!')
print('='*60)
print(f'Итоговая статистика:')
print(f'  • Securities: {len(dim_security):,}')
print(f'  • Dates: {len(dim_dates):,}')
print(f'  • Facts: {total_facts_loaded:,}')
print(f'  • Market Summary: {len(summary):,}')
print(f'  • Chunks processed: {chunks_processed}')
print(f'  • Примерный объем данных: {(total_facts_loaded * 100 / 1024 / 1024):.1f} MB')
EOFPY
python /tmp/process_data.py"

echo ""
echo "Шаг 4/4: Проверка результатов..."

docker exec moex_postgres_dwh psql -U moex_user -d moex_dwh -c "
SELECT
    'dim_security' as table_name, COUNT(*) as records FROM analytics.dim_security
UNION ALL SELECT 'dim_date', COUNT(*) FROM analytics.dim_date
UNION ALL SELECT 'fact_daily_trading', COUNT(*) FROM analytics.fact_daily_trading
UNION ALL SELECT 'market_summary', COUNT(*) FROM analytics.market_summary
ORDER BY table_name;"

echo ""
echo "================================================"
echo "Пайплайн завершен!"
echo "================================================"
echo ""
echo "Откройте Grafana для визуализации:"
echo "   http://localhost:3000 (admin/admin)"
echo ""
echo "См. START_VISUALIZATION.md для создания дашбордов"
echo ""
