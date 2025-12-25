#!/bin/bash

# Script to configure AirFlow connections
# Run this after AirFlow is started

echo "Configuring AirFlow connections..."

# PostgreSQL Raw Database Connection
docker exec moex_airflow_webserver airflow connections add 'postgres_raw' \
    --conn-type 'postgres' \
    --conn-host 'postgres_raw' \
    --conn-schema 'moex_raw' \
    --conn-login 'moex_user' \
    --conn-password 'moex_password' \
    --conn-port '5432'

# PostgreSQL DWH Connection
docker exec moex_airflow_webserver airflow connections add 'postgres_dwh' \
    --conn-type 'postgres' \
    --conn-host 'postgres_dwh' \
    --conn-schema 'moex_dwh' \
    --conn-login 'moex_user' \
    --conn-password 'moex_password' \
    --conn-port '5432'

echo "Connections configured successfully!"
echo "You can verify them at http://localhost:8080/connection/list/"
