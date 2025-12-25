# Аналитика торговых данных Московской биржи

Проект по курсу "Технологии обработки больших данных"

## Быстрый старт

```bash
# 1. Полный перезапуск проекта
./restart.sh

# 2. Запуск пайплайна (ETL + обработка)
./run_full_pipeline.sh

# 3. Откройте Grafana
open http://localhost:3000  # admin/admin
```

Время выполнения: ~30 минут | Требования: Docker (4GB RAM)

---

## Конфигурация (BIG DATA режим)

Проект настроен на BIG DATA режим в `config/data_config.py`:

```python
MAX_SECURITIES = 250     # 250 акций
HISTORY_DAYS = 730       # 2 года истории
DASK_CHUNK_SIZE = 50000  # Chunk processing
```

Характеристики:
- ~182,500 записей торговых данных
- Данные НЕ помещаются в RAM
- Dask chunked processing
- Время: ~30 минут

Конфигурация автоматически используется AirFlow DAG и скриптами обработки.

Для изменения: отредактируйте `config/data_config.py` и запустите `./restart.sh`

---

## Визуализация

См. подробно: [START_VISUALIZATION.md](START_VISUALIZATION.md)

1. Откройте http://localhost:3000 (admin/admin)
2. Add Data Source -> PostgreSQL:
   - Host: `postgres_dwh:5432`, DB: `moex_dwh`
   - User/Pass: `moex_user`/`moex_password`
3. Создайте дашборд с SQL из START_VISUALIZATION.md

---

## Web интерфейсы

| Сервис | URL | Доступ |
|--------|-----|--------|
| Grafana | http://localhost:3000 | admin/admin |
| AirFlow | http://localhost:8080 | admin/admin |
| Dask | http://localhost:8787 | - |

---

## Структура проекта

```
config/data_config.py  - Настройки данных
flows/moex_etl_dag.py  - ETL пайплайн
dask_jobs/             - Обработка данных
sql/                   - Схемы БД
restart.sh             - Перезапуск
run_full_pipeline.sh   - Автозапуск
```

---

## Проверка работоспособности

```bash
./scripts/quick_check.sh
```

---

## Остановка

```bash
docker-compose down -v  # Полная очистка
```

---

## Технологии

AirFlow • PostgreSQL • Dask • Grafana • Docker • Python • MOEX API

---

Полная документация: docs/
