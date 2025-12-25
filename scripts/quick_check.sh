#!/bin/bash

# Быстрая проверка без долгих ожиданий

echo "================================"
echo "MOEX Analytics - Quick Check"
echo "================================"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "1. Docker Containers"
echo "--------------------"
if docker-compose ps | grep -q "Up"; then
    echo -e "${GREEN}✓${NC} Containers are running"
    docker-compose ps --format "table {{.Name}}\t{{.Status}}" | grep -v "^NAME"
else
    echo -e "${RED}✗${NC} Containers are not running"
    echo "Run: docker-compose up -d"
    exit 1
fi

echo ""
echo "2. Databases"
echo "--------------------"

# Check Raw DB
raw_tables=$(docker exec moex_postgres_raw psql -U moex_user -d moex_raw -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='raw_data';" 2>/dev/null | tr -d '[:space:]')
if [ "$raw_tables" == "4" ]; then
    echo -e "${GREEN}✓${NC} Raw Database: 4 tables created"
else
    echo -e "${YELLOW}⚠${NC} Raw Database: $raw_tables tables (expected 4)"
fi

# Check DWH
dwh_tables=$(docker exec moex_postgres_dwh psql -U moex_user -d moex_dwh -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='analytics';" 2>/dev/null | tr -d '[:space:]')
if [ "$dwh_tables" == "7" ]; then
    echo -e "${GREEN}✓${NC} DWH Database: 7 tables created"
else
    echo -e "${YELLOW}⚠${NC} DWH Database: $dwh_tables tables (expected 7)"
fi

# Check Airflow DB
airflow_db=$(docker exec moex_postgres_raw psql -U moex_user -l -t | grep -c "airflow")
if [ "$airflow_db" -ge "1" ]; then
    echo -e "${GREEN}✓${NC} Airflow Database: created"
else
    echo -e "${RED}✗${NC} Airflow Database: not found"
fi

echo ""
echo "3. Data Status"
echo "--------------------"

# Check stocks
stocks=$(docker exec moex_postgres_raw psql -U moex_user -d moex_raw -t -c "SELECT COUNT(*) FROM raw_data.stocks;" 2>/dev/null | tr -d '[:space:]')
if [ -z "$stocks" ] || [ "$stocks" == "0" ]; then
    echo -e "${YELLOW}⚠${NC} No stocks data yet - run ETL: ./scripts/run_etl.sh"
else
    echo -e "${GREEN}✓${NC} Stocks: $stocks records"
fi

# Check trade history
history=$(docker exec moex_postgres_raw psql -U moex_user -d moex_raw -t -c "SELECT COUNT(*) FROM raw_data.trade_history;" 2>/dev/null | tr -d '[:space:]')
if [ -z "$history" ] || [ "$history" == "0" ]; then
    echo -e "${YELLOW}⚠${NC} No trade history yet - run ETL: ./scripts/run_etl.sh"
else
    echo -e "${GREEN}✓${NC} Trade History: $history records"
fi

# Check DWH facts
facts=$(docker exec moex_postgres_dwh psql -U moex_user -d moex_dwh -t -c "SELECT COUNT(*) FROM analytics.fact_daily_trading;" 2>/dev/null | tr -d '[:space:]')
if [ -z "$facts" ] || [ "$facts" == "0" ]; then
    echo -e "${YELLOW}⚠${NC} No analytics yet - run Dask: ./scripts/run_dask.sh"
else
    echo -e "${GREEN}✓${NC} Analytics Facts: $facts records"
fi

echo ""
echo "4. Web Interfaces"
echo "--------------------"

# Quick URL checks (without waiting for full response)
if nc -z localhost 8080 2>/dev/null; then
    echo -e "${GREEN}✓${NC} AirFlow:    http://localhost:8080 (admin/admin)"
else
    echo -e "${RED}✗${NC} AirFlow:    not accessible"
fi

if nc -z localhost 3000 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Grafana:    http://localhost:3000 (admin/admin)"
else
    echo -e "${RED}✗${NC} Grafana:    not accessible"
fi

if nc -z localhost 8787 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Dask:       http://localhost:8787"
else
    echo -e "${RED}✗${NC} Dask:       not accessible"
fi

echo ""
echo "================================"
echo "Next Steps:"
echo "================================"

if [ -z "$stocks" ] || [ "$stocks" == "0" ]; then
    echo "1. Run ETL to load data:"
    echo "   ./scripts/run_etl.sh"
    echo ""
    echo "2. After ETL completes, run Dask processing:"
    echo "   ./scripts/run_dask.sh"
    echo ""
    echo "3. Open Grafana to view dashboards:"
    echo "   open http://localhost:3000"
else
    if [ -z "$facts" ] || [ "$facts" == "0" ]; then
        echo "1. Run Dask processing:"
        echo "   ./scripts/run_dask.sh"
        echo ""
        echo "2. Open Grafana to view dashboards:"
        echo "   open http://localhost:3000"
    else
        echo "✓ System is ready!"
        echo ""
        echo "View dashboards:"
        echo "  - AirFlow: http://localhost:8080"
        echo "  - Grafana: http://localhost:3000"
        echo "  - Dask:    http://localhost:8787"
    fi
fi
echo ""
