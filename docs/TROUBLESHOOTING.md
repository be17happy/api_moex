# Решение проблем

## Проблема: DAG не найден в AirFlow

### Симптомы:
```
Dag id moex_etl_pipeline not found in DagModel
```

### Причина:
AirFlow контейнер не имеет установленных зависимостей Python, которые используются в DAG файле (например, `apimoex`, `pandas`).

### Решение:

#### 1. Создать Dockerfile для AirFlow с зависимостями

Создан файл `Dockerfile.airflow`:
```dockerfile
FROM apache/airflow:2.7.3-python3.11

USER root
RUN apt-get update && apt-get install -y build-essential && apt-get clean

COPY requirements_airflow.txt /tmp/requirements.txt
RUN chown airflow:root /tmp/requirements.txt

USER airflow
RUN pip install --no-cache-dir --user -r /tmp/requirements.txt
```

#### 2. Обновить docker-compose.yml

Изменить оба AirFlow сервиса:
```yaml
airflow-webserver:
  build:
    context: .
    dockerfile: Dockerfile.airflow
  image: moex_airflow:latest

airflow-scheduler:
  build:
    context: .
    dockerfile: Dockerfile.airflow
  image: moex_airflow:latest
```

#### 3. Пересобрать контейнеры

```bash
docker-compose build airflow-webserver airflow-scheduler
docker-compose up -d airflow-webserver airflow-scheduler
```

#### 4. Подождать инициализации

AirFlow требует 1-2 минуты для полной инициализации и сканирования DAG файлов.

#### 5. Проверить что DAG появился

```bash
docker exec moex_airflow_webserver airflow dags list | grep moex
```

Должен появиться `moex_etl_pipeline`.

##Проблема: Ошибка импорта модулей в DAG

###Симптомы:
```
ModuleNotFoundError: No module named 'apimoex'
```

### Решение:

Проверить что зависимости установлены в контейнере:
```bash
docker exec moex_airflow_webserver pip list | grep apimoex
```

Если нет, пересобрать образ:
```bash
docker-compose build --no-cache airflow-webserver
docker-compose up -d airflow-webserver
```

## Проблема: Долгая загрузка при проверке

### Симптомы:
Скрипт `check_health.sh` висит долго на этапе проверки баз данных.

### Решение:

Используйте быструю версию:
```bash
./scripts/quick_check.sh
```

## Проблема: Контейнеры не запускаются

### Диагностика:

```bash
# Проверить статус
docker-compose ps

# Просмотреть логи
docker-compose logs postgres_raw
docker-compose logs airflow-webserver
```

### Частые причины:

1. **Порты заняты** - проверьте `lsof -i :8080` (AirFlow) или `lsof -i :5432` (PostgreSQL)
2. **Недостаточно памяти** - увеличьте в Docker Desktop Settings → Resources
3. **База данных не инициализировалась** - удалите volumes и пересоздайте:
   ```bash
   docker-compose down -v
   docker-compose up -d
   ```

## Проблема: Нет данных в таблицах

### Проверка:

```bash
docker exec moex_postgres_raw psql -U moex_user -d moex_raw -c "SELECT COUNT(*) FROM raw_data.stocks;"
```

### Решение:

Запустите ETL процесс:
```bash
./scripts/run_etl.sh
```

## Проблема: Ошибка подключения к API МОЕХ

### Симптомы:
```
Connection Error / Timeout
```

### Решение:

1. Проверьте интернет-соединение:
   ```bash
   docker exec moex_airflow_webserver curl -I https://iss.moex.com
   ```

2. Если API недоступен, повторите позже или используйте VPN

## Проблема: Dask обработка не запускается

### Диагностика:

```bash
# Проверить Dask scheduler
docker-compose logs dask-scheduler

# Проверить Dask worker
docker-compose logs dask-worker
```

### Решение:

1. Убедитесь что есть данные в raw таблицах
2. Перезапустите Dask сервисы:
   ```bash
   docker-compose restart dask-scheduler dask-worker
   ```

## Проблема: Grafana не показывает данные

### Чеклист:

1. **Проверить datasource**:
   - Открыть Configuration → Data Sources
   - Проверить подключение к `postgres_dwh:5432`

2. **Проверить данные в DWH**:
   ```bash
   docker exec moex_postgres_dwh psql -U moex_user -d moex_dwh -c "SELECT COUNT(*) FROM analytics.fact_daily_trading;"
   ```

3. **Переимпортировать дашборд**:
   - Dashboards → Import
   - Загрузить `dashboards/moex_dashboard.json`

## Полезные команды для отладки

```bash
# Полный перезапуск
docker-compose down
docker-compose up -d

# Перезапуск с пересборкой
docker-compose down
docker-compose build
docker-compose up -d

# Очистка и начало с нуля
docker-compose down -v
docker system prune -f
docker-compose up -d

# Просмотр всех логов
docker-compose logs -f

# Bash в контейнере
docker exec -it moex_airflow_webserver bash

# Проверка сети между контейнерами
docker exec moex_airflow_webserver ping postgres_raw
docker exec moex_airflow_webserver ping dask-scheduler
```

## Получение поддержки

Если проблема не решена:

1. Соберите информацию:
   ```bash
   docker-compose ps > status.txt
   docker-compose logs > logs.txt
   ./scripts/quick_check.sh > check.txt
   ```

2. Опишите:
   - Что вы пытались сделать
   - Что произошло
   - Сообщения об ошибках
   - Версия Docker

3. Приложите файлы status.txt, logs.txt, check.txt
