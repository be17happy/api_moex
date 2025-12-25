# Конфигурация проекта

## Настройка объема данных

Все параметры загрузки данных настраиваются в файле `config/data_config.py`.

### Текущая конфигурация

```python
MAX_SECURITIES = 250  # Количество акций для загрузки
HISTORY_DAYS = 730     # Период истории (2 года)
DASK_CHUNK_SIZE = 50000  # Размер chunk для обработки
```

Эта конфигурация соответствует режиму BIG DATA:
- Данные не помещаются в оперативную память
- Используется chunked processing через Dask
- Время обработки: ~30 минут

### Как работает конфигурация

1. **AirFlow DAG** (`flows/moex_etl_dag.py`) автоматически импортирует настройки:
```python
from data_config import MAX_SECURITIES, HISTORY_DAYS, BOARD
```

2. **Генерация демо-данных** (`run_full_pipeline.sh`) использует те же параметры:
```python
sys.path.insert(0, '/opt/airflow/config')
from data_config import MAX_SECURITIES, HISTORY_DAYS
```

3. **Dask обработка** читает CHUNK_SIZE для определения размера порций данных

### Изменение конфигурации

Чтобы изменить объем данных:

1. Отредактируйте `config/data_config.py`
2. Запустите полный перезапуск: `./restart.sh`
3. Запустите пайплайн: `./run_full_pipeline.sh`

### Доступные режимы

#### Тестовый (быстро, ~5 минут)
```python
MAX_SECURITIES = 5
HISTORY_DAYS = 7
```

#### Демо (среднее, ~10 минут)
```python
MAX_SECURITIES = 20
HISTORY_DAYS = 30
```

#### BIG DATA (рекомендуется для зачета, ~30 минут)
```python
MAX_SECURITIES = 250
HISTORY_DAYS = 730
```

## Мониторинг конфигурации

Проверить, какие значения использует система:

```bash
# Посмотреть текущую конфигурацию
cat config/data_config.py

# Проверить сколько данных загружено
docker exec moex_postgres_raw psql -U moex_user -d moex_raw -c "
SELECT
  (SELECT COUNT(*) FROM raw_data.stocks) as stocks,
  (SELECT COUNT(*) FROM raw_data.trade_history) as history_records;"
```

## Важно

- Конфигурация монтируется в Docker контейнеры через volume в `docker-compose.yml`
- Изменения конфига требуют перезапуска контейнеров (`./restart.sh`)
- AirFlow DAG имеет fallback на значения по умолчанию, если конфиг недоступен
