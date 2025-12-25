#!/usr/bin/env python3
"""
Генерация демо-данных для визуализации
"""

import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from sqlalchemy import create_engine
import random

# Подключение к БД
raw_engine = create_engine('postgresql://moex_user:moex_password@localhost:5432/moex_raw')

print("Загрузка списка акций...")
stocks_df = pd.read_sql("SELECT secid, shortname FROM raw_data.stocks LIMIT 20", raw_engine)
print(f"Выбрано {len(stocks_df)} акций для генерации данных")

# Генерация данных за последние 30 дней
end_date = datetime.now()
start_date = end_date - timedelta(days=30)
dates = pd.date_range(start=start_date, end=end_date, freq='D')

print(f"\nГенерация данных за период {start_date.date()} - {end_date.date()}")

all_history = []

for idx, stock in stocks_df.iterrows():
    secid = stock['secid']

    # Базовая цена для каждой акции
    base_price = random.uniform(50, 500)

    for date in dates:
        # Пропускаем выходные
        if date.weekday() >= 5:
            continue

        # Генерируем цены с небольшой волатильностью
        volatility = random.uniform(0.02, 0.05)
        open_price = base_price * (1 + random.uniform(-volatility, volatility))
        close_price = open_price * (1 + random.uniform(-volatility, volatility))
        high_price = max(open_price, close_price) * (1 + random.uniform(0, volatility))
        low_price = min(open_price, close_price) * (1 - random.uniform(0, volatility))

        # Генерируем объем
        volume = random.randint(100000, 10000000)
        value = volume * close_price

        all_history.append({
            'secid': secid,
            'tradedate': date.date(),
            'open': round(open_price, 2),
            'low': round(low_price, 2),
            'high': round(high_price, 2),
            'close': round(close_price, 2),
            'volume': volume,
            'value': round(value, 2)
        })

        # Обновляем базовую цену для следующего дня
        base_price = close_price

history_df = pd.DataFrame(all_history)

print(f"\nСгенерировано {len(history_df)} записей истории торгов")
print("\nПример данных:")
print(history_df.head())

print("\nЗагрузка данных в БД...")
history_df.to_sql(
    'trade_history',
    raw_engine,
    schema='raw_data',
    if_exists='append',
    index=False,
    method='multi',
    chunksize=1000
)

print(f"\n✅ Успешно загружено {len(history_df)} записей!")

# Проверка
count = pd.read_sql("SELECT COUNT(*) as cnt FROM raw_data.trade_history", raw_engine).iloc[0, 0]
print(f"Проверка: в БД {count} записей")

print("\n📊 Статистика по акциям:")
stats = pd.read_sql("""
    SELECT secid, COUNT(*) as days,
           MIN(tradedate) as from_date,
           MAX(tradedate) as to_date
    FROM raw_data.trade_history
    GROUP BY secid
    ORDER BY days DESC
    LIMIT 5
""", raw_engine)
print(stats)

raw_engine.dispose()
print("\n✅ Готово! Теперь можно запустить Dask обработку.")
