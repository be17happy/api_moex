# Решение проблемы с запуском DAG

## Проблема
```
Dag id moex_etl_pipeline not found in DagModel
```

## Причина
AirFlow контейнер не имел установленных Python зависимостей, необходимых для DAG файла (apimoex, pandas, loguru и др.).

## Решение

### 1. Создан минимальный requirements для AirFlow

Файл `requirements_airflow.txt`:
```
psycopg2-binary==2.9.9
SQLAlchemy==1.4.51
apimoex==1.3.0
pandas==2.1.4
numpy==1.26.2
requests==2.31.0
loguru==0.7.2
python-dateutil==2.8.2
```

### 2. Создан Dockerfile для AirFlow

Файл `Dockerfile.airflow`:
```dockerfile
FROM apache/airflow:2.7.3-python3.11

USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY requirements_airflow.txt /tmp/requirements.txt
RUN chown airflow:root /tmp/requirements.txt

USER airflow
RUN pip install --no-cache-dir --user -r /tmp/requirements.txt
```

### 3. Обновлен docker-compose.yml

Изменены оба AirFlow сервиса:
```yaml
airflow-webserver:
  build:
    context: .
    dockerfile: Dockerfile.airflow
  image: moex_airflow:latest
  # ... остальные настройки

airflow-scheduler:
  build:
    context: .
    dockerfile: Dockerfile.airflow
  image: moex_airflow:latest
  # ... остальные настройки
```

### 4. Пересобраны и перезапущены сервисы

```bash
docker-compose build airflow-webserver airflow-scheduler
docker-compose up -d airflow-webserver airflow-scheduler
```

### 5. Проверка и запуск

```bash
# Проверка что DAG появился
docker exec moex_airflow_webserver airflow dags list | grep moex
# Output: moex_etl_pipeline | moex_etl_dag.py | moex_analytics | True

# Запуск ETL
./scripts/run_etl.sh
```

## Результат

 DAG успешно найден
 ETL процесс запущен
 Задачи в статусе "queued"

## Текущий статус

```
DAG: moex_etl_pipeline
Status: running
Expected duration: ~15-20 минут

Tasks:
  1. extract_stock_list       (~2-3 min)
  2. extract_trade_history    (~5-10 min)
  3. extract_market_data      (~3-5 min)
  4. log_etl_completion
  5. trigger_dask_processing
```

## Мониторинг

- **AirFlow UI**: http://localhost:8080
- **Логи**: `docker-compose logs -f airflow-scheduler`
- **Статус**: `docker exec moex_airflow_webserver airflow dags state moex_etl_pipeline`

## Следующие шаги

1. Дождаться завершения ETL (~15-20 минут)
2. Проверить данные в БД:
   ```bash
   docker exec moex_postgres_raw psql -U moex_user -d moex_raw -c "SELECT COUNT(*) FROM raw_data.stocks;"
   ```
3. Запустить Dask обработку:
   ```bash
   ./scripts/run_dask.sh
   ```
4. Открыть Grafana и импортировать дашборды:
   ```bash
   open http://localhost:3000
   ```

## Дополнительная информация

- Все созданные файлы:
  - `Dockerfile.airflow` - кастомный образ AirFlow
  - `requirements_airflow.txt` - минимальные зависимости
  - `TROUBLESHOOTING.md` - документ по решению проблем
  - `scripts/rebuild_airflow.sh` - скрипт пересборки

- Полезные команды в: `CHEATSHEET.md`
- Пошаговая инструкция: `QUICKSTART.md`
- Следующие шаги: `NEXT_STEPS.md`
