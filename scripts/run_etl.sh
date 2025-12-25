#!/bin/bash

echo "================================"
echo "Running MOEX ETL Pipeline"
echo "================================"
echo ""

# Check if AirFlow is running
if ! docker ps | grep -q moex_airflow_webserver; then
    echo "Error: AirFlow is not running. Please start services first:"
    echo "  docker-compose up -d"
    exit 1
fi

echo "1. Configuring AirFlow connections..."
docker exec moex_airflow_webserver airflow connections delete postgres_raw 2>/dev/null
docker exec moex_airflow_webserver airflow connections delete postgres_dwh 2>/dev/null

docker exec moex_airflow_webserver airflow connections add 'postgres_raw' \
    --conn-type 'postgres' \
    --conn-host 'postgres_raw' \
    --conn-schema 'moex_raw' \
    --conn-login 'moex_user' \
    --conn-password 'moex_password' \
    --conn-port '5432'

docker exec moex_airflow_webserver airflow connections add 'postgres_dwh' \
    --conn-type 'postgres' \
    --conn-host 'postgres_dwh' \
    --conn-schema 'moex_dwh' \
    --conn-login 'moex_user' \
    --conn-password 'moex_password' \
    --conn-port '5432'

echo ""
echo "2. Unpausing DAG..."
docker exec moex_airflow_webserver airflow dags unpause moex_etl_pipeline

echo ""
echo "3. Triggering DAG run..."
docker exec moex_airflow_webserver airflow dags trigger moex_etl_pipeline

echo ""
echo "================================"
echo "ETL Pipeline Started!"
echo "================================"
echo ""
echo "Monitor progress at: http://localhost:8080"
echo "DAG: moex_etl_pipeline"
echo ""
echo "Expected tasks:"
echo "  1. extract_stock_list       (~2-3 min)"
echo "  2. extract_trade_history    (~5-10 min)"
echo "  3. extract_market_data      (~3-5 min)"
echo "  4. log_etl_completion"
echo "  5. trigger_dask_processing"
echo ""
echo "Total time: ~15-20 minutes"
echo ""
echo "Check status with:"
echo "  docker exec moex_airflow_webserver airflow dags state moex_etl_pipeline"
echo ""
