.PHONY: help setup down migrate status rollback new-migration bytebase slides lab1 lab2 lab3 lab4 clean reset

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
	@echo "Lab 1: Basic Migration Workflow"
	@echo "=========================================="
	@echo ""
	@echo "Step 1: Start services"
	@echo "  make setup"
	@echo ""
	@echo "Step 2: Check migration status"
	@echo "  make status"
	@echo ""
	@echo "Step 3: Apply all migrations"
	@echo "  make migrate"
	@echo ""
	@echo "Step 4: Verify status"
	@echo "  make status"
	@echo ""
	@echo "Step 5: Connect to database and explore"
	@echo "  make psql"
	@echo "  \\dt                    -- list tables"
	@echo "  SELECT * FROM _schema_migrations;"
	@echo "  \\q                    -- quit"
	@echo ""
	@echo "Step 6: Clean up"
	@echo "  make down"
	@echo ""

lab2:
	@echo "=========================================="
	@echo "Lab 2: Safe Schema Changes"
	@echo "=========================================="
	@echo ""
	@echo "This lab demonstrates backward-compatible changes."
	@echo ""
	@echo "Step 1: Start services and apply migrations"
	@echo "  make setup && make migrate"
	@echo ""
	@echo "Step 2: Create a new safe migration"
	@echo "  make new-migration V=007 DESC=add_user_preferences"
	@echo ""
	@echo "Step 3: Edit migrations/V007__add_user_preferences.sql"
	@echo "  Add this SQL:"
	@echo ""
	@echo "  -- Migration: V007 - add_user_preferences"
	@echo "  -- Risk level: LOW"
	@echo "  -- Backward compatible: YES"
	@echo ""
	@echo "  CREATE TABLE user_preferences ("
	@echo "      id          BIGSERIAL PRIMARY KEY,"
	@echo "      user_id     BIGINT NOT NULL REFERENCES users(id),"
	@echo "      theme       VARCHAR(50) DEFAULT 'light',"
	@echo "      language    VARCHAR(10) DEFAULT 'en',"
	@echo "      created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()"
	@echo "  );"
	@echo ""
	@echo "Step 4: Apply the new migration"
	@echo "  make migrate"
	@echo ""
	@echo "Step 5: Verify in database"
	@echo "  make psql"
	@echo "  \\d user_preferences"
	@echo ""

lab3:
	@echo "=========================================="
	@echo "Lab 3: Risky Changes & Rollback"
	@echo "=========================================="
	@echo ""
	@echo "This lab demonstrates risky changes and rollback strategy."
	@echo ""
	@echo "Step 1: Start services and apply migrations"
	@echo "  make setup && make migrate"
	@echo ""
	@echo "Step 2: Check current status"
	@echo "  make status"
	@echo ""
	@echo "Step 3: Simulate rollback to version 004"
	@echo "  make rollback V=004"
	@echo ""
	@echo "Step 4: Check status after rollback"
	@echo "  make status"
	@echo ""
	@echo "Step 5: Re-apply all migrations"
	@echo "  make migrate"
	@echo ""
	@echo "WARNING: In production, you would need actual rollback SQL"
	@echo "to reverse schema changes. This lab only resets tracking."
	@echo ""

lab4:
	@echo "=========================================="
	@echo "Lab 4: Bytebase Risk Management"
	@echo "=========================================="
	@echo ""
	@echo "This lab demonstrates Bytebase risk assessment and approvals."
	@echo ""
	@echo "Step 1: Start services"
	@echo "  make setup"
	@echo ""
	@echo "Step 2: Open Bytebase UI"
	@echo "  make bytebase"
	@echo ""
	@echo "Step 3: Register admin account (first time)"
	@echo "  - Open http://localhost:8080"
	@echo "  - Click 'Sign Up' and register"
	@echo ""
	@echo "Step 4: Add PostgreSQL instance"
	@echo "  - Settings > Instances > Create Instance"
	@echo "  - Select PostgreSQL"
	@echo "  - Host: postgres, Port: 5432"
	@echo "  - Username: tutorial, Password: tutorial_secret"
	@echo ""
	@echo "Step 5: Create a project"
	@echo "  - Projects > Create Project"
	@echo "  - Name: db-versioning-tutorial"
	@echo ""
	@echo "Step 6: Submit a schema change"
	@echo "  - Project > Databases > Edit Schema"
	@echo "  - Paste SQL:"
	@echo "    CREATE TABLE test_table (id BIGSERIAL PRIMARY KEY, name TEXT);"
	@echo "  - Click Create"
	@echo ""
	@echo "Step 7: Configure risk rules"
	@echo "  - Settings > Risk Center"
	@echo "  - Add rules for environment, sql_type, table_rows"
	@echo ""
	@echo "Step 8: Configure approval flow"
	@echo "  - CI/CD > Custom Approval"
	@echo "  - Add rules based on risk level"
	@echo ""
