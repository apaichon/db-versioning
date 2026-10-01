.PHONY: help setup down migrate status rollback new-migration seed drop-tables large-data backfill create-envs compare-envs bytebase slides lab1 lab2 lab3 lab4 clean reset api-install api-start api-test

help:
	@echo "Database Version Control Tutorial - Available Commands"
	@echo ""
	@echo "SETUP & INFRASTRUCTURE:"
	@echo "  make setup           - Start PostgreSQL and Bytebase containers"
	@echo "  make down            - Stop all containers"
	@echo "  make clean           - Remove containers and volumes (destructive)"
	@echo "  make reset           - Reset database to initial state"
	@echo ""
	@echo "ENVIRONMENT MANAGEMENT:"
	@echo "  make create-envs     - Create test, uat, prod databases"
	@echo "  make compare-envs    - Compare schemas across environments"
	@echo "  make migrate ENV=test MAX_VERSION=003  - Migrate specific env"
	@echo "  make seed ENV=uat TABLES='users'       - Seed specific env"
	@echo "  make status ENV=prod                   - Status for specific env"
	@echo ""
	@echo "MIGRATION OPERATIONS:"
	@echo "  make migrate                 - Apply all pending migrations"
	@echo "  make migrate MAX_VERSION=003 - Apply only migrations up to V003"
	@echo "  make status                  - Show migration status"
	@echo "  make seed                    - Insert sample data (all tables)"
	@echo "  make seed TABLES='users products' - Insert data for specific tables"
	@echo "  make drop-tables             - Drop all tables (destructive!)"
	@echo "  make rollback V=004          - Rollback to specific version"
	@echo "  make new-migration V=007 DESC=add_payment_methods"
	@echo ""
	@echo "LAB EXERCISES:"
	@echo "  make lab1            - Lab 1: Basic migration workflow"
	@echo "  make lab2            - Lab 2: Safe schema changes"
	@echo "  make lab3            - Lab 3: Risky changes & rollback"
	@echo "  make lab4            - Lab 4: Bytebase risk management"
	@echo ""
	@echo "TOOLS:"
	@echo "  make bytebase        - Open Bytebase UI (http://localhost:8088)"
	@echo "  make slides          - Start Slidev presentation"
	@echo "  make psql            - Open PostgreSQL shell"
	@echo ""
	@echo "API COMMANDS (Lab 1):"
	@echo "  make api-install     - Install API dependencies"
	@echo "  make api-start       - Start API server (http://localhost:3000)"
	@echo "  make api-test        - Test API endpoints"
	@echo ""
	@echo "LARGE DATA (Lab 3):"
	@echo "  make large-data COUNT=10000000 - Generate large dataset"
	@echo "  make backfill BATCH=10000      - Backfill column in batches"
	@echo ""

setup:
	@echo "Starting PostgreSQL and Bytebase..."
	docker compose up -d
	@echo ""
	@echo "Waiting for PostgreSQL to be ready..."
	@sleep 3
	@docker compose exec postgres pg_isready -U tutorial -d app_db
	@echo ""
	@echo "PostgreSQL: localhost:5432 (user: tutorial, password: tutorial_secret, db: app_db)"
	@echo "Bytebase:   http://localhost:8088 (metadata stored in bytebase_db)"
	@echo ""
	@echo "Run 'make migrate' to apply migrations"

down:
	@echo "Stopping containers..."
	docker compose down

clean:
	@echo "Removing containers and volumes..."
	docker compose down -v
	@echo "Cleaned. Run 'make setup' to start fresh."

reset: down clean setup
	@echo "Database reset complete."

create-envs:
	@echo "Creating environment databases (test, uat, prod)..."
	./scripts/create-env-databases.sh

compare-envs:
	@echo "Comparing environments..."
	./scripts/compare-envs.sh

migrate:
ifdef ENV
ifdef MAX_VERSION
	@echo "Applying migrations up to V$(MAX_VERSION) to app_$(ENV)..."
	DB_NAME=app_$(ENV) ./scripts/migrate.sh migrate $(MAX_VERSION)
else
	@echo "Applying all migrations to app_$(ENV)..."
	DB_NAME=app_$(ENV) ./scripts/migrate.sh migrate
endif
else
ifdef MAX_VERSION
	@echo "Applying migrations up to V$(MAX_VERSION)..."
	./scripts/migrate.sh migrate $(MAX_VERSION)
else
	@echo "Applying all migrations..."
	./scripts/migrate.sh migrate
endif
endif

status:
ifdef ENV
	@echo "Migration status for app_$(ENV):"
	DB_NAME=app_$(ENV) ./scripts/migrate.sh status
else
	@echo "Migration status:"
	./scripts/migrate.sh status
endif

seed:
ifdef ENV
ifdef TABLES
	@echo "Seeding app_$(ENV) with: $(TABLES)..."
	DB_NAME=app_$(ENV) ./scripts/seed-data.sh $(TABLES)
else
	@echo "Seeding app_$(ENV) with all data..."
	DB_NAME=app_$(ENV) ./scripts/seed-data.sh
endif
else
ifdef TABLES
	@echo "Seeding database with sample data for tables: $(TABLES)..."
	./scripts/seed-data.sh $(TABLES)
else
	@echo "Seeding database with all sample data..."
	./scripts/seed-data.sh
endif
endif

drop-tables:
	@echo "WARNING: This will drop ALL tables in the database!"
	@read -p "Are you sure? [y/N] " confirm && [ "$$confirm" = "y" ] || exit 1
	./scripts/drop-tables.sh

rollback:
	@if [ -z "$(V)" ]; then \
		echo "Usage: make rollback V=<version>"; \
		echo "Example: make rollback V=004"; \
		exit 1; \
	fi
	./scripts/migrate.sh rollback $(V)

new-migration:
	@if [ -z "$(V)" ] || [ -z "$(DESC)" ]; then \
		echo "Usage: make new-migration V=<version> DESC=<description>"; \
		echo "Example: make new-migration V=007 DESC=add_payment_methods"; \
		exit 1; \
	fi
	./scripts/new-migration.sh $(V) $(DESC)

psql:
	@echo "Connecting to PostgreSQL..."
	PGPASSWORD=tutorial_secret psql -h localhost -U tutorial -d app_db

bytebase:
	@echo "Checking Bytebase..."
	@if ! docker ps --format '{{.Names}}' | grep -q 'db-versioning-bytebase'; then \
		echo "Bytebase not running. Starting..."; \
		docker compose up -d bytebase; \
		echo "Waiting for Bytebase to be ready..."; \
		sleep 5; \
	fi
	@echo "Bytebase UI: http://localhost:8088"
	@open http://localhost:8088 2>/dev/null || echo "Open http://localhost:8088 in your browser"!

slides:
	@echo "Starting Slidev presentation..."
	npm run dev

api-install:
	@echo "Installing API dependencies..."
	cd api && npm install --cache /tmp/npm-cache
	@echo "API dependencies installed."

api-start:
	@echo "Starting API server..."
	@echo "API will be available at http://localhost:3000"
	@echo "Press Ctrl+C to stop"
	cd api && node server.js

api-test:
	@echo "Testing API endpoints..."
	@echo ""
	@echo "GET /api/v1/users/1"
	@curl -s http://localhost:3000/api/v1/users/1 | jq .
	@echo ""
	@echo "GET /api/v1/users"
	@curl -s http://localhost:3000/api/v1/users | jq .

large-data:
	@echo "Generating large dataset..."
	./scripts/generate-large-data.sh $(or $(COUNT),1000000) 50000

backfill:
	@echo "Backfilling category column in batches..."
	./scripts/backfill-category.sh $(or $(BATCH),10000)

lab1:
	@echo "=========================================="
	@echo "Lab 1: Migration-Driven API Evolution"
	@echo "=========================================="
	@echo ""
	@echo "Full instructions: labs/lab1-basic-migrations.md"
	@echo ""
	@echo "Quick Start:"
	@echo "  1. make setup                    # Start PostgreSQL"
	@echo "  2. make migrate MAX_VERSION=003  # Apply V001-V003 only"
	@echo "  3. make seed TABLES='users products orders order_items'"
	@echo "  4. make api-install              # Install API dependencies"
	@echo "  5. make api-start                # Start API server"
	@echo "  6. make api-test                 # Test API (in another terminal)"
	@echo ""
	@echo "Run 'cat labs/lab1-basic-migrations.md' for full instructions"
	@echo ""

lab2:
	@echo "=========================================="
	@echo "Lab 2: Safe Schema Changes (Expand & Contract)"
	@echo "=========================================="
	@echo ""
	@echo "Full instructions: labs/lab2-safe-changes.md"
	@echo ""
	@echo "Quick Start:"
	@echo "  1. make setup                    # Start PostgreSQL"
	@echo "  2. make migrate MAX_VERSION=003  # Apply V001-V003 only"
	@echo "  3. make seed TABLES='users products orders order_items'"
	@echo "  4. make api-install && make api-start  # Start API"
	@echo "  5. make new-migration V=008 DESC=add_email_address_column"
	@echo "  6. Edit migration to ADD COLUMN email_address + copy data"
	@echo "  7. make migrate                  # Apply safe migration"
	@echo "  8. curl localhost:3000/api/v1/users/1  # v1 still works!"
	@echo "  9. curl localhost:3000/api/v2/users/1  # v2 also works!"
	@echo ""
	@echo "Run 'cat labs/lab2-safe-changes.md' for full instructions"
	@echo ""

lab3:
	@echo "=========================================="
	@echo "Lab 3: Safe DDL on Large Tables (10M+)"
	@echo "=========================================="
	@echo ""
	@echo "Full instructions: labs/lab3-risky-changes.md"
	@echo ""
	@echo "Quick Start:"
	@echo "  1. make setup                    # Start PostgreSQL"
	@echo "  2. make migrate MAX_VERSION=003  # Apply V001-V003"
	@echo "  3. make large-data COUNT=1000000 # Generate 1M rows"
	@echo "  4. make new-migration V=010 DESC=add_category_to_transactions_safe"
	@echo "  5. Edit migration: ADD COLUMN category (nullable)"
	@echo "  6. make migrate                  # Instant, no lock"
	@echo "  7. make backfill BATCH=10000     # Backfill in batches"
	@echo "  8. Add NOT NULL + CREATE INDEX CONCURRENTLY"
	@echo ""
	@echo "Run 'cat labs/lab3-risky-changes.md' for full instructions"
	@echo ""

lab4:
	@echo "=========================================="
	@echo "Lab 4: Bytebase Multi-Environment (Free)"
	@echo "=========================================="
	@echo ""
	@echo "Full instructions: labs/lab4-bytebase-risk.md"
	@echo ""
	@echo "Quick Start:"
	@echo "  1. make setup                    # Start PostgreSQL + Bytebase"
	@echo "  2. make create-envs              # Create test, uat, prod"
	@echo "  3. make migrate ENV=test MAX_VERSION=003"
	@echo "  4. make migrate ENV=uat"
	@echo "  5. make migrate ENV=prod"
	@echo "  6. make seed ENV=test TABLES='users products orders order_items'"
	@echo "  7. make seed ENV=uat  TABLES='users products orders order_items'"
	@echo "  8. make seed ENV=prod TABLES='users products orders order_items'"
	@echo "  9. make compare-envs             # See schema differences"
	@echo " 10. make bytebase                 # Open Bytebase (free version)"
	@echo ""
	@echo "Run 'cat labs/lab4-bytebase-risk.md' for full instructions"
	@echo ""
