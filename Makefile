.PHONY: help setup down migrate status rollback new-migration seed bytebase slides lab1 lab2 lab3 lab4 clean reset

help:
	@echo "Database Version Control Tutorial - Available Commands"
	@echo ""
	@echo "SETUP & INFRASTRUCTURE:"
	@echo "  make setup           - Start PostgreSQL and Bytebase containers"
	@echo "  make down            - Stop all containers"
	@echo "  make clean           - Remove containers and volumes (destructive)"
	@echo "  make reset           - Reset database to initial state"
	@echo ""
	@echo "MIGRATION OPERATIONS:"
	@echo "  make migrate         - Apply all pending migrations"
	@echo "  make status          - Show migration status"
	@echo "  make seed            - Insert sample data (users, products, orders)"
	@echo "  make rollback V=004  - Rollback to specific version"
	@echo "  make new-migration V=007 DESC=add_payment_methods"
	@echo ""
	@echo "LAB EXERCISES:"
	@echo "  make lab1            - Lab 1: Basic migration workflow"
	@echo "  make lab2            - Lab 2: Safe schema changes"
	@echo "  make lab3            - Lab 3: Risky changes & rollback"
	@echo "  make lab4            - Lab 4: Bytebase risk management"
	@echo ""
	@echo "TOOLS:"
	@echo "  make bytebase        - Open Bytebase UI (http://localhost:8080)"
	@echo "  make slides          - Start Slidev presentation"
	@echo "  make psql            - Open PostgreSQL shell"
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
	@echo "Bytebase:   http://localhost:8080"
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

migrate:
	@echo "Applying migrations..."
	./scripts/migrate.sh migrate

status:
	@echo "Migration status:"
	./scripts/migrate.sh status

seed:
	@echo "Seeding database with sample data..."
	./scripts/seed-data.sh

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
	@echo "Opening Bytebase UI..."
	@open http://localhost:8080 2>/dev/null || echo "Open http://localhost:8080 in your browser"

slides:
	@echo "Starting Slidev presentation..."
	npm run dev

lab1:
	@echo "=========================================="
	@echo "Lab 1: Basic Migration Workflow (V001-V003)"
	@echo "=========================================="
	@echo ""
	@echo "Full instructions: labs/lab1-basic-migrations.md"
	@echo ""
	@echo "Quick Start:"
	@echo "  1. make setup          # Start PostgreSQL and Bytebase"
	@echo "  2. make status         # Check migration status"
	@echo "  3. make migrate        # Apply all migrations"
	@echo "  4. make seed           # Insert sample data"
	@echo "  5. make psql           # Connect to database"
	@echo "     \\dt                 # List tables"
	@echo "     SELECT * FROM users LIMIT 5;"
	@echo "     \\q                  # Quit"
	@echo "  6. make down           # Stop containers"
	@echo ""
	@echo "Run 'cat labs/lab1-basic-migrations.md' for full instructions"
	@echo ""

lab2:
	@echo "=========================================="
	@echo "Lab 2: Safe Schema Changes"
	@echo "=========================================="
	@echo ""
	@echo "Full instructions: labs/lab2-safe-changes.md"
	@echo ""
	@echo "Quick Start:"
	@echo "  1. make setup && make migrate && make seed"
	@echo "  2. make new-migration V=007 DESC=add_user_preferences"
	@echo "  3. Edit migrations/V007__add_user_preferences.sql"
	@echo "  4. make migrate"
	@echo "  5. make psql"
	@echo "     \\d user_preferences"
	@echo ""
	@echo "Run 'cat labs/lab2-safe-changes.md' for full instructions"
	@echo ""

lab3:
	@echo "=========================================="
	@echo "Lab 3: Risky Changes & Rollback"
	@echo "=========================================="
	@echo ""
	@echo "Full instructions: labs/lab3-risky-changes.md"
	@echo ""
	@echo "Quick Start:"
	@echo "  1. make setup && make migrate && make seed"
	@echo "  2. make status"
	@echo "  3. make rollback V=004"
	@echo "  4. make status"
	@echo "  5. make migrate"
	@echo ""
	@echo "Run 'cat labs/lab3-risky-changes.md' for full instructions"
	@echo ""

lab4:
	@echo "=========================================="
	@echo "Lab 4: Bytebase Risk Management"
	@echo "=========================================="
	@echo ""
	@echo "Full instructions: labs/lab4-bytebase-risk.md"
	@echo ""
	@echo "Quick Start:"
	@echo "  1. make setup"
	@echo "  2. make bytebase       # Open http://localhost:8080"
	@echo "  3. Register admin account"
	@echo "  4. Add PostgreSQL instance"
	@echo "  5. Configure risk rules"
	@echo "  6. Submit schema change"
	@echo ""
	@echo "Run 'cat labs/lab4-bytebase-risk.md' for full instructions"
	@echo ""
