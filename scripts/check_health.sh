#!/bin/bash

echo "================================"
echo "MOEX Analytics - Health Check"
echo "================================"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_container() {
    local container=$1
    local name=$2

    if docker ps | grep -q $container; then
        echo -e "${GREEN}✓${NC} $name is running"
        return 0
    else
        echo -e "${RED}✗${NC} $name is NOT running"
        return 1
    fi
}

check_url() {
    local url=$1
    local name=$2

    if curl -s -o /dev/null -w "%{http_code}" $url | grep -q "200\|302"; then
        echo -e "${GREEN}✓${NC} $name is accessible at $url"
        return 0
    else
        echo -e "${RED}✗${NC} $name is NOT accessible at $url"
        return 1
    fi
}

check_database() {
    local container=$1
    local db=$2
    local schema=$3

    local count=$(docker exec -it $container psql -U moex_user -d $db -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$schema';" 2>/dev/null | tr -d '[:space:]')

    if [ ! -z "$count" ] && [ "$count" -gt 0 ]; then
        echo -e "${GREEN}✓${NC} Database $db.$schema has $count tables"
        return 0
    else
        echo -e "${RED}✗${NC} Database $db.$schema has issues"
        return 1
    fi
}

echo "1. Checking Docker Containers..."
echo "--------------------------------"
check_container "moex_postgres_raw" "PostgreSQL Raw"
check_container "moex_postgres_dwh" "PostgreSQL DWH"
check_container "moex_airflow_webserver" "AirFlow Webserver"
check_container "moex_airflow_scheduler" "AirFlow Scheduler"
check_container "moex_dask_scheduler" "Dask Scheduler"
check_container "moex_dask_worker" "Dask Worker"
check_container "moex_grafana" "Grafana"
echo ""

echo "2. Checking Web Interfaces..."
echo "--------------------------------"
check_url "http://localhost:8080" "AirFlow UI"
check_url "http://localhost:3000" "Grafana"
check_url "http://localhost:8787" "Dask Dashboard"
echo ""

echo "3. Checking Databases..."
echo "--------------------------------"
sleep 2  # Wait for DB to be ready
check_database "moex_postgres_raw" "moex_raw" "raw_data"
check_database "moex_postgres_dwh" "moex_dwh" "analytics"
echo ""

echo "4. Checking Data..."
echo "--------------------------------"

# Check stocks data
stocks_count=$(docker exec -it moex_postgres_raw psql -U moex_user -d moex_raw -t -c "SELECT COUNT(*) FROM raw_data.stocks;" 2>/dev/null | tr -d '[:space:]')
if [ ! -z "$stocks_count" ] && [ "$stocks_count" -gt 0 ]; then
    echo -e "${GREEN}✓${NC} raw_data.stocks has $stocks_count records"
else
    echo -e "${YELLOW}⚠${NC} raw_data.stocks is empty (run ETL pipeline)"
fi

# Check trade history
history_count=$(docker exec -it moex_postgres_raw psql -U moex_user -d moex_raw -t -c "SELECT COUNT(*) FROM raw_data.trade_history;" 2>/dev/null | tr -d '[:space:]')
if [ ! -z "$history_count" ] && [ "$history_count" -gt 0 ]; then
    echo -e "${GREEN}✓${NC} raw_data.trade_history has $history_count records"
else
    echo -e "${YELLOW}⚠${NC} raw_data.trade_history is empty (run ETL pipeline)"
fi

# Check DWH data
fact_count=$(docker exec -it moex_postgres_dwh psql -U moex_user -d moex_dwh -t -c "SELECT COUNT(*) FROM analytics.fact_daily_trading;" 2>/dev/null | tr -d '[:space:]')
if [ ! -z "$fact_count" ] && [ "$fact_count" -gt 0 ]; then
    echo -e "${GREEN}✓${NC} analytics.fact_daily_trading has $fact_count records"
else
    echo -e "${YELLOW}⚠${NC} analytics.fact_daily_trading is empty (run Dask processing)"
fi

echo ""
echo "================================"
echo "Health Check Complete!"
echo "================================"
echo ""
echo "Next steps:"
echo "1. If containers are not running: docker-compose up -d"
echo "2. If data is empty, run ETL: ./scripts/run_etl.sh"
echo "3. Access AirFlow: http://localhost:8080 (admin/admin)"
echo "4. Access Grafana: http://localhost:3000 (admin/admin)"
echo ""
