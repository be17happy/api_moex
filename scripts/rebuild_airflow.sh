#!/bin/bash

echo "================================"
echo "Rebuilding AirFlow with dependencies"
echo "================================"
echo ""

echo "1. Stopping AirFlow services..."
docker-compose stop airflow-webserver airflow-scheduler

echo ""
echo "2. Building new AirFlow image with dependencies..."
echo "This may take 5-10 minutes..."
docker-compose build airflow-webserver airflow-scheduler

echo ""
echo "3. Starting AirFlow services..."
docker-compose up -d airflow-webserver airflow-scheduler

echo ""
echo "4. Waiting for AirFlow to initialize (30 seconds)..."
sleep 30

echo ""
echo "5. Checking AirFlow status..."
docker-compose ps airflow-webserver airflow-scheduler

echo ""
echo "================================"
echo "AirFlow Rebuild Complete!"
echo "================================"
echo ""
echo "Verify at: http://localhost:8080"
echo ""
echo "Next steps:"
echo "  1. Wait 1-2 minutes for AirFlow to fully start"
echo "  2. Run: ./scripts/run_etl.sh"
echo ""
