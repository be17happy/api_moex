# Быстрый старт и проверка работоспособности

## Шаг 1: Запуск всех сервисов

```bash
cd bigdata_project
docker-compose up -d
```

## Шаг 2: Проверка статуса контейнеров

```bash
docker-compose ps
```

**Ожидаемый результат**: Все сервисы должны быть в статусе "Up"

```
NAME                        STATUS
moex_airflow_scheduler      Up
moex_airflow_webserver      Up
moex_dask_scheduler         Up
moex_dask_worker            Up
moex_grafana                Up
moex_postgres_dwh           Up (healthy)
moex_postgres_raw           Up (healthy)
```

## Шаг 3: Проверка логов (если есть проблемы)

```bash
# Все логи
docker-compose logs

# Только AirFlow
docker-compose logs airflow-webserver airflow-scheduler

# Только базы данных
docker-compose logs postgres_raw postgres_dwh
```

## Шаг 4: Настройка AirFlow подключений

Подождите 30-60 секунд после запуска, чтобы AirFlow инициализировался, затем:

```bash
chmod +x config/airflow_connections.sh
./config/airflow_connections.sh
```

**Альтернатива (если скрипт не работает)** - настройте подключения вручную через Web UI:
1. Откройте http://localhost:8080
2. Логин: `admin`, пароль: `admin`
3. Admin → Connections → Add Connection
4. Создайте два подключения:
   - **postgres_raw**: host=`postgres_raw`, port=`5432`, schema=`moex_raw`
   - **postgres_dwh**: host=`postgres_dwh`, port=`5432`, schema=`moex_dwh`

## Шаг 5: Проверка баз данных

### Проверка Raw Database
```bash
docker exec -it moex_postgres_raw psql -U moex_user -d moex_raw -c "\dt raw_data.*"
```

**Ожидаемый результат**: Список таблиц (stocks, trade_history, market_data, etl_logs)

### Проверка DWH Database
```bash
docker exec -it moex_postgres_dwh psql -U moex_user -d moex_dwh -c "\dt analytics.*"
```

**Ожидаемый результат**: Список таблиц аналитики

## Шаг 6: Запуск первого ETL процесса

### Вариант A: Через Web UI (рекомендуется)

1. Откройте AirFlow UI: http://localhost:8080
2. Найдите DAG `moex_etl_pipeline`
3. Включите DAG (переключатель слева)
4. Нажмите кнопку "Trigger DAG" (▶️ справа)
5. Наблюдайте за выполнением задач

### Вариант B: Через командную строку

```bash
docker exec moex_airflow_webserver airflow dags unpause moex_etl_pipeline
docker exec moex_airflow_webserver airflow dags trigger moex_etl_pipeline
```

## Шаг 7: Мониторинг выполнения DAG

В AirFlow UI вы увидите выполнение следующих задач:

1. ✅ **extract_stock_list** - загружает список акций (~2-3 минуты)
2. ✅ **extract_trade_history** - загружает историю торгов (~5-10 минут)
3. ✅ **extract_market_data** - загружает текущие данные (~3-5 минут)
4. ✅ **log_etl_completion** - логирует завершение
5. ✅ **trigger_dask_processing** - запускает Dask

**Примерное время выполнения**: 10-20 минут

## Шаг 8: Проверка загруженных данных

### Проверка количества загруженных акций
```bash
docker exec -it moex_postgres_raw psql -U moex_user -d moex_raw -c "SELECT COUNT(*) FROM raw_data.stocks;"
```

### Проверка истории торгов
```bash
docker exec -it moex_postgres_raw psql -U moex_user -d moex_raw -c "SELECT secid, COUNT(*) as records FROM raw_data.trade_history GROUP BY secid LIMIT 10;"
```

### Проверка последних данных
```bash
docker exec -it moex_postgres_raw psql -U moex_user -d moex_raw -c "SELECT secid, tradedate, close FROM raw_data.trade_history ORDER BY tradedate DESC LIMIT 10;"
```

## Шаг 9: Запуск Dask обработки

### Создайте скрипт для запуска Dask

Создайте файл `run_dask.py` в корне проекта:

```python
import sys
sys.path.append('/opt/airflow/dags')

from dask_jobs.dask_processor import DaskMoexProcessor

processor = DaskMoexProcessor(
    dask_scheduler='dask-scheduler:8786',
    raw_db_url='postgresql://moex_user:moex_password@postgres_raw:5432/moex_raw',
    dwh_db_url='postgresql://moex_user:moex_password@postgres_dwh:5432/moex_dwh'
)

try:
    print("Starting Dask processing pipeline...")
    processor.run_full_pipeline()
    print("Pipeline completed successfully!")
except Exception as e:
    print(f"Error: {e}")
finally:
    processor.close()
```

### Запустите обработку
```bash
docker cp run_dask.py moex_airflow_webserver:/opt/airflow/
docker exec moex_airflow_webserver python /opt/airflow/run_dask.py
```

## Шаг 10: Проверка данных в DWH

### Проверка dimension таблиц
```bash
# Количество ценных бумаг
docker exec -it moex_postgres_dwh psql -U moex_user -d moex_dwh -c "SELECT COUNT(*) FROM analytics.dim_security;"

# Количество дат
docker exec -it moex_postgres_dwh psql -U moex_user -d moex_dwh -c "SELECT COUNT(*) FROM analytics.dim_date;"
```

### Проверка fact таблицы
```bash
docker exec -it moex_postgres_dwh psql -U moex_user -d moex_dwh -c "SELECT COUNT(*) FROM analytics.fact_daily_trading;"
```

### Проверка агрегатов
```bash
# Недельные агрегаты
docker exec -it moex_postgres_dwh psql -U moex_user -d moex_dwh -c "SELECT COUNT(*) FROM analytics.agg_weekly_trading;"

# Топ бумаг
docker exec -it moex_postgres_dwh psql -U moex_user -d moex_dwh -c "SELECT s.secid, t.price_change_pct FROM analytics.top_performers t JOIN analytics.dim_security s ON t.security_key = s.security_key LIMIT 10;"
```

## Шаг 11: Настройка Grafana

1. Откройте Grafana: http://localhost:3000
2. Логин: `admin`, пароль: `admin`
3. Проверьте подключение к базам данных:
   - Configuration (⚙️) → Data Sources
   - Должны быть подключены "MOEX Analytics DWH" и "MOEX Raw Data"

4. Импортируйте дашборд:
   - Dashboards → Import
   - Upload JSON file: `dashboards/moex_dashboard.json`
   - Выберите datasource: "MOEX Analytics DWH"
   - Нажмите Import

## Шаг 12: Просмотр визуализаций

После импорта дашборда вы увидите:

- 📊 **Market Summary** - дневной объем и стоимость
- 🔝 **Top Gainers/Losers** - лучшие и худшие бумаги
- 📈 **Price Trends** - графики изменения цен
- 🥧 **Market Sentiment** - соотношение растущих/падающих
- 📉 **Volatility & Metrics** - волатильность и ключевые метрики

## Контрольный список проверки ✅

- [ ] Все контейнеры запущены (`docker-compose ps`)
- [ ] AirFlow доступен на http://localhost:8080
- [ ] Grafana доступна на http://localhost:3000
- [ ] Dask Dashboard доступен на http://localhost:8787
- [ ] Базы данных созданы и доступны
- [ ] AirFlow подключения настроены
- [ ] DAG `moex_etl_pipeline` успешно выполнен
- [ ] Данные загружены в raw_data схему
- [ ] Dask обработка выполнена
- [ ] Данные появились в analytics схеме
- [ ] Дашборд импортирован в Grafana
- [ ] Визуализации отображают данные

## Troubleshooting - Частые проблемы

### 1. Контейнер постоянно перезапускается

```bash
docker-compose logs [service_name]
```

### 2. AirFlow не запускается

Увеличьте время ожидания и проверьте, что PostgreSQL готов:
```bash
docker-compose restart airflow-webserver airflow-scheduler
```

### 3. Нет данных в Grafana

Проверьте, что:
- Dask обработка завершена
- Данные есть в analytics таблицах
- Datasource правильно настроен

### 4. Ошибка подключения к API МОЕХ

Проверьте интернет-соединение:
```bash
docker exec moex_airflow_webserver curl -I https://iss.moex.com
```

### 5. "Out of memory" ошибки

Увеличьте память для Docker:
- Docker Desktop → Settings → Resources → Memory (минимум 4GB)

## Следующие шаги

После успешной проверки переходите к:

1. **Настройке расписания** - изменение частоты обновления
2. **Добавлению новых метрик** - расширение аналитики
3. **Оптимизации запросов** - улучшение производительности
4. **Созданию алертов** - уведомления в Grafana
5. **Написанию отчета** - документирование результатов

---

**Время на полную проверку**: ~30-45 минут
