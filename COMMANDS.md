# Команды для запуска проекта

##  Полный перезапуск и запуск

```bash
cd /Users/artemvorobev/Documents/vs_code/API_project/bigdata_project

# 1. Полный перезапуск (очистка + сборка + запуск)
./restart.sh

# 2. Запуск пайплайна (ETL + Dask + проверка)
./run_full_pipeline.sh

# 3. Откройте браузер
open http://localhost:3000  # Grafana (admin/admin)
```

**Общее время: ~20-30 минут**

---

##  Настройка объема данных

### Быстро (5 акций, 7 дней) - для тестирования

```bash
# Отредактируйте config/data_config.py
MAX_SECURITIES = 5
HISTORY_DAYS = 7
```

### Средне (20 акций, 30 дней) - для демонстрации [РЕКОМЕНДУЕТСЯ]

```bash
MAX_SECURITIES = 20
HISTORY_DAYS = 30
```

### Полно (50 акций, 90 дней) - для анализа

```bash
MAX_SECURITIES = 50
HISTORY_DAYS = 90
```

---

##  Проверка работоспособности

```bash
# Быстрая проверка
./scripts/quick_check.sh

# Проверка данных в DWH
docker exec moex_postgres_dwh psql -U moex_user -d moex_dwh -c "
SELECT
    'Securities' as table_name, COUNT(*) as records FROM analytics.dim_security
UNION ALL SELECT 'Daily Facts', COUNT(*) FROM analytics.fact_daily_trading
UNION ALL SELECT 'Market Summary', COUNT(*) FROM analytics.market_summary;"

# Статус контейнеров
docker-compose ps
```

---

##  Создание дашбордов в Grafana

### Шаг 1: Подключение Data Source

1. http://localhost:3000 → Settings → Data Sources
2. Add data source → PostgreSQL
3. Заполните:
   - Name: `MOEX Analytics DWH`
   - Host: `postgres_dwh:5432`
   - Database: `moex_dwh`
   - User: `moex_user`
   - Password: `moex_password`
   - SSL Mode: `disable`
4. Save & Test

### Шаг 2: Создание графиков

```sql
-- График 1: Объем торгов
SELECT summary_date as time, total_volume as value
FROM analytics.market_summary
ORDER BY summary_date

-- График 2: Топ акций
SELECT s.secid, AVG(f.price_change_pct) as "Изменение %"
FROM analytics.fact_daily_trading f
JOIN analytics.dim_security s ON f.security_key = s.security_key
GROUP BY s.secid
ORDER BY AVG(f.price_change_pct) DESC
LIMIT 10

-- График 3: Gainers vs Losers
SELECT summary_date as time,
       gainers_count as "Растут",
       losers_count as "Падают"
FROM analytics.market_summary
ORDER BY summary_date
```

---

##  Ручной запуск компонентов

### ETL Process

```bash
# Настройка подключений
./config/airflow_connections.sh

# Запуск DAG
docker exec moex_airflow_webserver airflow dags trigger moex_etl_pipeline

# Проверка статуса
docker exec moex_airflow_webserver airflow dags list-runs -d moex_etl_pipeline
```

### Dask Processing

```bash
# Используется автоматически в run_full_pipeline.sh
# Или вручную через команды в скрипте
```

---

##  Подключение к базам данных

```bash
# Raw Database (порт 5432)
docker exec -it moex_postgres_raw psql -U moex_user -d moex_raw

# Data Warehouse (порт 5433)
docker exec -it moex_postgres_dwh psql -U moex_user -d moex_dwh
```

Или через SQL клиент:
- **Raw**: localhost:5432 / moex_raw / moex_user / moex_password
- **DWH**: localhost:5433 / moex_dwh / moex_user / moex_password

---

##  Остановка и очистка

```bash
# Остановка (данные сохраняются)
docker-compose stop

# Запуск после остановки
docker-compose start

# Полная очистка (удаление всех данных)
docker-compose down -v

# Очистка + удаление образов
docker-compose down -v --rmi all
```

---

##  Полезные команды

```bash
# Логи
docker-compose logs -f                    # Все
docker-compose logs -f airflow-scheduler  # Только AirFlow
docker-compose logs -f grafana            # Только Grafana

# Перезапуск одного сервиса
docker-compose restart airflow-scheduler
docker-compose restart grafana

# Просмотр использования ресурсов
docker stats
```

---

##  Типичный сценарий использования

```bash
# 1. Первый запуск
./restart.sh                # Полная установка (1 раз)
./run_full_pipeline.sh      # Загрузка данных

# 2. Работа с графиками
open http://localhost:3000  # Создайте дашборды

# 3. Изменение настроек
nano config/data_config.py  # Измените MAX_SECURITIES или HISTORY_DAYS

# 4. Перезапуск с новыми настройками
./restart.sh
./run_full_pipeline.sh

# 5. Остановка после работы
docker-compose stop
```

---

##  Для отчета

```bash
# Сделайте скриншоты:
# 1. docker-compose ps (статус контейнеров)
# 2. http://localhost:8080 (AirFlow DAG)
# 3. http://localhost:3000 (Grafana дашборды)

# Экспорт данных для отчета
docker exec moex_postgres_dwh psql -U moex_user -d moex_dwh -c "\d+ analytics.*" > schema_dump.txt
```

---

**Все готово!** 🎉
