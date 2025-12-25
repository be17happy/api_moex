#!/bin/bash

echo "================================"
echo "Running MOEX Dask Processing"
echo "================================"
echo ""

# Check if containers are running
if ! docker ps | grep -q moex_dask_scheduler; then
    echo "Error: Dask scheduler is not running. Please start services first:"
    echo "  docker-compose up -d"
    exit 1
fi

if ! docker ps | grep -q moex_postgres_raw; then
    echo "Error: PostgreSQL is not running. Please start services first:"
    echo "  docker-compose up -d"
    exit 1
fi

echo "Copying processing script to container..."
docker cp scripts/run_dask.py moex_airflow_webserver:/tmp/run_dask.py

echo ""
echo "Starting Dask processing pipeline..."
echo "This may take 5-10 minutes..."
echo ""

docker exec moex_airflow_webserver python /tmp/run_dask.py

echo ""
echo "================================"
echo "Dask Processing Complete!"
echo "================================"
echo ""
echo "Check Dask Dashboard: http://localhost:8787"
echo "View results in Grafana: http://localhost:3000"
echo ""
