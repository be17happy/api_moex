.PHONY: help build up down restart logs clean install test

help:
	@echo "Available commands:"
	@echo "  make build     - Build all Docker containers"
	@echo "  make up        - Start all services"
	@echo "  make down      - Stop all services"
	@echo "  make restart   - Restart all services"
	@echo "  make logs      - View logs from all services"
	@echo "  make clean     - Remove all containers and volumes"
	@echo "  make install   - Install Python dependencies locally"
	@echo "  make test      - Run tests"
	@echo "  make status    - Show status of all services"

build:
	docker-compose build

up:
	docker-compose up -d
	@echo "Services started. Access points:"
	@echo "  - AirFlow: http://localhost:8080 (admin/admin)"
	@echo "  - Grafana: http://localhost:3000 (admin/admin)"
	@echo "  - Dask Dashboard: http://localhost:8787"

down:
	docker-compose down

restart:
	docker-compose restart

logs:
	docker-compose logs -f

logs-airflow:
	docker-compose logs -f airflow-webserver airflow-scheduler

logs-dask:
	docker-compose logs -f dask-scheduler dask-worker

logs-postgres:
	docker-compose logs -f postgres_raw postgres_dwh

status:
	docker-compose ps

clean:
	docker-compose down -v
	docker system prune -f

install:
	pip install -r requirements.txt

test:
	pytest tests/ -v

shell-airflow:
	docker exec -it moex_airflow_webserver bash

shell-dask:
	docker exec -it moex_dask_worker bash

psql-raw:
	docker exec -it moex_postgres_raw psql -U moex_user -d moex_raw

psql-dwh:
	docker exec -it moex_postgres_dwh psql -U moex_user -d moex_dwh
