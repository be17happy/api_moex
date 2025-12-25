#!/bin/bash

echo "================================================"
echo "MOEX Analytics - Полный перезапуск проекта"
echo "================================================"
echo ""

# Цвета для вывода
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Шаг 1: Остановка и очистка
echo "Шаг 1/5: Остановка контейнеров..."
docker-compose down -v
echo -e "${GREEN}✓${NC} Контейнеры остановлены, данные удалены"
echo ""

# Шаг 2: Сборка образов
echo "Шаг 2/5: Сборка образов..."
echo "Это может занять несколько минут..."
docker-compose build --no-cache
if [ $? -ne 0 ]; then
    echo -e "${RED}✗${NC} Ошибка при сборке образов"
    exit 1
fi
echo -e "${GREEN}✓${NC} Образы собраны"
echo ""

# Шаг 3: Запуск контейнеров
echo "Шаг 3/5: Запуск контейнеров..."
docker-compose up -d
if [ $? -ne 0 ]; then
    echo -e "${RED}✗${NC} Ошибка при запуске контейнеров"
    exit 1
fi
echo -e "${GREEN}✓${NC} Контейнеры запущены"
echo ""

# Шаг 4: Ожидание инициализации
echo "Шаг 4/5: Ожидание инициализации..."
echo "Подождите пока все сервисы запустятся (60 секунд)..."
sleep 60
echo -e "${GREEN}✓${NC} Сервисы должны быть готовы"
echo ""

# Шаг 5: Проверка статуса
echo "Шаг 5/5: Проверка статуса..."
echo ""

# Проверка контейнеров
echo "Контейнеры:"
docker-compose ps --format "  {{.Name}}: {{.Status}}"
echo ""

# Проверка баз данных
echo "Проверка баз данных..."
sleep 5

raw_tables=$(docker exec moex_postgres_raw psql -U moex_user -d moex_raw -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='raw_data';" 2>/dev/null | tr -d '[:space:]')
dwh_tables=$(docker exec moex_postgres_dwh psql -U moex_user -d moex_dwh -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='analytics';" 2>/dev/null | tr -d '[:space:]')

if [ "$raw_tables" == "4" ]; then
    echo -e "  ${GREEN}✓${NC} Raw Database: 4 таблицы созданы"
else
    echo -e "  ${YELLOW}⚠${NC} Raw Database: $raw_tables таблиц (ожидалось 4)"
fi

if [ "$dwh_tables" == "7" ]; then
    echo -e "  ${GREEN}✓${NC} DWH Database: 7 таблиц созданы"
else
    echo -e "  ${YELLOW}⚠${NC} DWH Database: $dwh_tables таблиц (ожидалось 7)"
fi

echo ""
echo "================================================"
echo "Проект перезапущен!"
echo "================================================"
echo ""
echo " Настройка объема данных:"
echo "   Отредактируйте: config/data_config.py"
echo "   - MAX_SECURITIES: количество акций (сейчас: 20)"
echo "   - HISTORY_DAYS: период истории (сейчас: 30 дней)"
echo ""
echo " Следующие шаги:"
echo ""
echo "1. Настройте AirFlow подключения:"
echo "   ./config/airflow_connections.sh"
echo ""
echo "2. Запустите ETL процесс:"
echo "   docker exec moex_airflow_webserver airflow dags trigger moex_etl_pipeline"
echo ""
echo "3. После ETL запустите Dask обработку:"
echo "   docker exec moex_airflow_webserver bash -c 'python /tmp/run_process.py'"
echo ""
echo "4. Откройте Grafana для визуализации:"
echo "   http://localhost:3000 (admin/admin)"
echo ""
echo " Web интерфейсы:"
echo "   - AirFlow:  http://localhost:8080 (admin/admin)"
echo "   - Grafana:  http://localhost:3000 (admin/admin)"
echo "   - Dask:     http://localhost:8787"
echo ""
echo " Документация:"
echo "   - README.md - основная документация"
echo "   - START_VISUALIZATION.md - руководство по визуализации"
echo ""
