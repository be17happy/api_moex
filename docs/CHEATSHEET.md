# Шпаргалка по командам проекта

## 🚀 Быстрый старт

```bash
# 1. Запустить все сервисы
docker-compose up -d

# 2. Проверить статус (быстро)
./scripts/quick_check.sh

# 3. Запустить ETL
./scripts/run_etl.sh

# 4. Дождаться завершения ETL (~15-20 мин), затем запустить Dask
./scripts/run_dask.sh

# 5. Открыть Grafana
open http://localhost:3000
```

## 📊 Проверка состояния

```bash
# Быстрая проверка
./scripts/quick_check.sh

# Подробная проверка (медленная)
./scripts/check_health.sh

# Статус контейнеров
docker-compose ps

# Логи всех сервисов
docker-compose logs -f

# Логи конкретного сервиса
docker-compose logs -f airflow-scheduler
```

## 🗄️ Работа с базами данных

### Подключение к БД

```bash
# Raw Database
docker exec moex_postgres_raw psql -U moex_user -d moex_raw

# DWH Database
docker exec moex_postgres_dwh psql -U moex_user -d moex_dwh

# Из скрипта (один запрос)
docker exec moex_postgres_raw psql -U moex_user -d moex_raw -c "SELECT COUNT(*) FROM raw_data.stocks;"
```

### Полезные SQL команды

```sql
-- Показать все таблицы
\dt raw_data.*
\dt analytics.*

-- Показать индексы
\di raw_data.*
\di analytics.*

-- Показать схемы
\dn

-- Описание таблицы
\d raw_data.stocks
\d analytics.fact_daily_trading

-- Количество записей
SELECT COUNT(*) FROM raw_data.stocks;
SELECT COUNT(*) FROM raw_data.trade_history;
SELECT COUNT(*) FROM analytics.fact_daily_trading;

-- Топ 10 акций
SELECT secid, COUNT(*)
FROM raw_data.trade_history
GROUP BY secid
ORDER BY COUNT(*) DESC
LIMIT 10;

-- Последние загруженные данные
SELECT * FROM raw_data.trade_history
ORDER BY created_at DESC
LIMIT 10;
```

## 🔄 AirFlow

### Управление DAG

```bash
# Показать список DAG
docker exec moex_airflow_webserver airflow dags list

# Включить DAG
docker exec moex_airflow_webserver airflow dags unpause moex_etl_pipeline

# Запустить DAG вручную
docker exec moex_airflow_webserver airflow dags trigger moex_etl_pipeline

# Проверить статус DAG
docker exec moex_airflow_webserver airflow dags state moex_etl_pipeline

# Список задач
docker exec moex_airflow_webserver airflow tasks list moex_etl_pipeline
```

### Управление подключениями

```bash
# Список подключений
docker exec moex_airflow_webserver airflow connections list

# Добавить подключение
docker exec moex_airflow_webserver airflow connections add 'postgres_raw' \
    --conn-type 'postgres' \
    --conn-host 'postgres_raw' \
    --conn-schema 'moex_raw' \
    --conn-login 'moex_user' \
    --conn-password 'moex_password' \
    --conn-port '5432'

# Удалить подключение
docker exec moex_airflow_webserver airflow connections delete postgres_raw
```

## 🧮 Dask

```bash
# Открыть Dask Dashboard
open http://localhost:8787

# Запустить обработку
./scripts/run_dask.sh

# Проверить логи Dask
docker-compose logs -f dask-scheduler
docker-compose logs -f dask-worker
```

## 📈 Grafana

```bash
# Открыть Grafana
open http://localhost:3000

# Логины
# admin / admin

# Перезапустить Grafana
docker-compose restart grafana

# Логи Grafana
docker-compose logs -f grafana
```

## 🔧 Управление сервисами

### Запуск/остановка

```bash
# Запустить все
docker-compose up -d

# Остановить все
docker-compose stop

# Перезапустить все
docker-compose restart

# Перезапустить один сервис
docker-compose restart postgres_raw

# Остановить и удалить контейнеры (данные сохраняются)
docker-compose down

# Удалить все (включая данные)
docker-compose down -v
```

### Масштабирование

```bash
# Добавить Dask workers
docker-compose up -d --scale dask-worker=3

# Проверить количество
docker-compose ps | grep dask-worker
```

## 🐛 Отладка

### Просмотр логов

```bash
# Все логи
docker-compose logs

# Последние 100 строк
docker-compose logs --tail=100

# Следить за логами в реальном времени
docker-compose logs -f

# Логи конкретного сервиса
docker-compose logs airflow-scheduler
docker-compose logs postgres_raw
```

### Подключение к контейнеру

```bash
# Bash в AirFlow
docker exec -it moex_airflow_webserver bash

# Bash в Dask Worker
docker exec -it moex_dask_worker bash

# Python в контейнере
docker exec -it moex_airflow_webserver python
```

### Проверка сети

```bash
# Проверить, что порты доступны
nc -z localhost 8080  # AirFlow
nc -z localhost 3000  # Grafana
nc -z localhost 5432  # PostgreSQL Raw
nc -z localhost 5433  # PostgreSQL DWH

# Или через curl
curl -I http://localhost:8080
curl -I http://localhost:3000
```

## 📁 Файловая система

### Копирование файлов

```bash
# Из контейнера на хост
docker cp moex_airflow_webserver:/opt/airflow/logs ./local_logs

# С хоста в контейнер
docker cp ./my_script.py moex_airflow_webserver:/tmp/

# Просмотр файлов в контейнере
docker exec moex_airflow_webserver ls -la /opt/airflow/dags
```

## 🧹 Очистка

```bash
# Удалить все данные и начать заново
docker-compose down -v
docker system prune -f
docker-compose up -d

# Очистить только логи
rm -rf logs/*

# Очистить данные из БД (но оставить структуру)
docker exec moex_postgres_raw psql -U moex_user -d moex_raw -c "TRUNCATE TABLE raw_data.stocks CASCADE;"
```

## 📊 Мониторинг производительности

```bash
# Использование ресурсов
docker stats

# Размер контейнеров
docker ps --size

# Использование дискового пространства
docker system df

# Подробная информация
docker system df -v
```

## 🔐 Учетные данные

```
PostgreSQL:
  User: moex_user
  Password: moex_password
  Raw DB Port: 5432
  DWH DB Port: 5433

AirFlow:
  URL: http://localhost:8080
  User: admin
  Password: admin

Grafana:
  URL: http://localhost:3000
  User: admin
  Password: admin

Dask Dashboard:
  URL: http://localhost:8787
  No auth required
```

## 🎓 Полезные команды для отчета

```bash
# Сделать дамп структуры БД
docker exec moex_postgres_dwh pg_dump -U moex_user -d moex_dwh --schema-only > dwh_schema.sql

# Экспорт данных в CSV
docker exec moex_postgres_raw psql -U moex_user -d moex_raw -c "COPY (SELECT * FROM raw_data.stocks) TO STDOUT WITH CSV HEADER" > stocks.csv

# Статистика по таблицам
docker exec moex_postgres_dwh psql -U moex_user -d moex_dwh -c "
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size,
    n_live_tup as rows
FROM pg_stat_user_tables
WHERE schemaname = 'analytics'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;"
```

## 🚨 Частые проблемы

### Порт уже занят

```bash
# Найти процесс на порту
lsof -i :8080
lsof -i :5432

# Убить процесс
kill -9 <PID>

# Или изменить порт в docker-compose.yml
```

### Контейнер не запускается

```bash
# Проверить логи
docker-compose logs postgres_raw

# Пересоздать контейнер
docker-compose up -d --force-recreate postgres_raw
```

### Нет памяти

```bash
# Проверить использование памяти
docker stats

# Увеличить память для Docker Desktop
# Settings → Resources → Memory (минимум 4GB)
```

### База данных не инициализировалась

```bash
# Удалить volume и пересоздать
docker-compose down -v
docker-compose up -d
```
