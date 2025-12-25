# Итоговая информация по проекту

## Что готово

### 1. Архитектура Big Data системы
- API (MOEX) -> AirFlow (ETL) -> PostgreSQL (Raw) -> Dask -> PostgreSQL (DWH) -> Grafana
- Все компоненты контейнеризированы в Docker
- Автоматизированные скрипты для запуска

### 2. Конфигурация для Big Data
- **250 акций** из Московской биржи
- **730 дней** истории (2 года)
- **~182,500 записей** торговых данных
- **Chunked processing** через Dask (по 50k записей)
- Данные НЕ помещаются в RAM при обычной обработке

### 3. Обработка данных
- ETL через Apache AirFlow
- Распределенная обработка через Dask
- Star Schema в Data Warehouse
- Агрегации и вычисления метрик

### 4. Визуализация
- Grafana дашборды
- Временные ряды
- Аналитические панели

## Как запустить

```bash
cd /Users/artemvorobev/Documents/vs_code/API_project/bigdata_project

# Шаг 1: Полный перезапуск (очистка + сборка + запуск)
./restart.sh

# Шаг 2: Запуск пайплайна (~30 минут)
./run_full_pipeline.sh

# Шаг 3: Открыть Grafana
open http://localhost:3000
# Логин: admin, Пароль: admin
```

## Конфигурация данных

Все настройки в файле `config/data_config.py`:

```python
MAX_SECURITIES = 250    # Количество акций
HISTORY_DAYS = 730      # Период истории (2 года)
DASK_CHUNK_SIZE = 50000 # Размер chunk для Dask
```

Эти параметры автоматически используются:
- AirFlow DAG импортирует их для ETL
- Генератор демо-данных использует для создания данных
- Dask обработчик применяет для chunked processing

## Обоснование Big Data

См. подробно: `BIG_DATA_EXPLANATION.md`

Ключевые моменты:
1. **Volume**: 182,500+ записей, не помещаются в RAM
2. **Technology**: Dask chunked processing, AirFlow orchestration
3. **Processing**: Out-of-core computation, batch loading
4. **Architecture**: Lambda-style (batch + speed layers)

## Web интерфейсы

| Сервис | URL | Доступ |
|--------|-----|--------|
| Grafana | http://localhost:3000 | admin/admin |
| AirFlow | http://localhost:8080 | admin/admin |
| Dask | http://localhost:8787 | - |

## Базы данных

```bash
# Raw Database (исходные данные)
docker exec -it moex_postgres_raw psql -U moex_user -d moex_raw

# Data Warehouse (обработанные данные)
docker exec -it moex_postgres_dwh psql -U moex_user -d moex_dwh
```

## Проверка работоспособности

```bash
# Быстрая проверка
./scripts/quick_check.sh

# Проверка данных в DWH
docker exec moex_postgres_dwh psql -U moex_user -d moex_dwh -c "
SELECT
    'dim_security' as table_name, COUNT(*) as records FROM analytics.dim_security
UNION ALL SELECT 'dim_date', COUNT(*) FROM analytics.dim_date
UNION ALL SELECT 'fact_daily_trading', COUNT(*) FROM analytics.fact_daily_trading
UNION ALL SELECT 'market_summary', COUNT(*) FROM analytics.market_summary;"
```

Ожидаемые результаты:
- dim_security: 250 записей
- dim_date: 730 записей
- fact_daily_trading: ~182,500 записей
- market_summary: 730 записей

## Создание визуализации в Grafana

См. подробно: `START_VISUALIZATION.md`

Краткая инструкция:
1. Открыть http://localhost:3000 (admin/admin)
2. Add Data Source -> PostgreSQL
   - Host: `postgres_dwh:5432`
   - Database: `moex_dwh`
   - User: `moex_user`, Password: `moex_password`
3. Создать Dashboard с SQL запросами из `START_VISUALIZATION.md`

## Структура проекта

```
config/
  data_config.py        - Конфигурация объема данных
  airflow_connections.sh - Настройка подключений AirFlow

flows/
  moex_etl_dag.py       - AirFlow DAG для ETL
  moex_api_client.py    - Клиент для API MOEX

dask_jobs/
  dask_processor.py     - Обработчик данных через Dask

sql/
  init_raw.sql          - Схема Raw Database
  init_dwh.sql          - Схема Data Warehouse (Star Schema)

scripts/
  quick_check.sh        - Быстрая проверка
  run_etl.sh            - Запуск ETL
  run_dask.sh           - Запуск Dask обработки

restart.sh              - Полный перезапуск проекта
run_full_pipeline.sh    - Автоматический запуск всего пайплайна
docker-compose.yml      - Конфигурация Docker контейнеров
```

## Технологии

- **Apache AirFlow 2.7.3** - ETL orchestration
- **PostgreSQL 15** - Raw DB + Data Warehouse
- **Dask 2024.1.0** - Distributed data processing
- **Grafana 10.2** - Data visualization
- **Docker & Docker Compose** - Containerization
- **Python 3.11** - Programming language
- **apimoex** - Moscow Exchange API client

## Документация

- `README.md` - Быстрый старт
- `CONFIGURATION.md` - Настройка конфигурации
- `BIG_DATA_EXPLANATION.md` - Обоснование Big Data подхода
- `START_VISUALIZATION.md` - Создание визуализации
- `COMMANDS.md` - Полный список команд
- `docs/` - Дополнительная документация

## Остановка и очистка

```bash
# Остановка (данные сохраняются)
docker-compose stop

# Запуск после остановки
docker-compose start

# Полная очистка (удаление всех данных)
docker-compose down -v
```

## Для отчета/презентации

### Скриншоты
1. `docker-compose ps` - статус контейнеров
2. http://localhost:8080 - AirFlow DAG
3. http://localhost:3000 - Grafana дашборды с графиками
4. Вывод `run_full_pipeline.sh` - процесс обработки

### Ключевые метрики
- Объем данных: 250 акций × 730 дней = ~182,500 записей
- Время обработки: ~30 минут
- Chunk size: 50,000 записей
- Примерный размер в памяти: ~1.7-2 GB (raw)
- Технологии: 7 контейнеров Docker

### Демонстрация Big Data подхода
1. Показать конфигурацию в `config/data_config.py`
2. Запустить `./run_full_pipeline.sh` и показать chunked processing в выводе
3. Показать использование памяти: `docker stats`
4. Показать размер данных в PostgreSQL
5. Показать Grafana дашборды

---

**Проект готов к демонстрации и сдаче!**
