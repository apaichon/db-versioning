# Lab 5: CI/CD GitOps with Database Migrations

## Objective
Set up a CI/CD pipeline where database migrations are version-controlled in Git and deployed across **test → uat → prod** environments via pull requests.

## Two Approaches

### Approach A: GitHub Actions + psql (FREE)
Uses GitHub Actions with `psql` to run migrations directly. No Bytebase API needed.

### Approach B: GitHub Actions + Bytebase API (ENTERPRISE)
Uses Bytebase API for SQL review and issue creation. Requires Enterprise license.

**This lab covers Approach A (free version).**

## Prerequisites
- Completed Labs 1-4
- GitHub account
- PostgreSQL accessible from GitHub Actions (or self-hosted runner)

## Step-by-Step Instructions

### Step 1: Prepare Databases

```bash
make setup
make create-envs

make migrate ENV=test MAX_VERSION=003
make seed ENV=test TABLES="users products orders order_items"

make migrate ENV=uat
make seed ENV=uat TABLES="users products orders order_items"

make migrate ENV=prod
make seed ENV=prod TABLES="users products orders order_items"
```

### Step 2: Set Up GitHub Secrets

Go to GitHub repo > **Settings** > **Secrets and variables** > **Actions**

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `DB_HOST` | Your PostgreSQL host | Database server address |
| `DB_PORT` | `5432` | Database port |
| `DB_USER` | `tutorial` | Database username |
| `DB_PASSWORD` | `tutorial_secret` | Database password |

### Step 3: Set Up GitHub Environments

1. Go to GitHub repo > **Settings** > **Environments**
2. Click **New environment** → name: `uat`
   - **Required reviewers**: add team members
3. Click **New environment** → name: `prod`
   - **Required reviewers**: add team lead + DBA
   - **Branch protection**: only `main`

These create manual approval gates before UAT and Prod deployments.

### Step 4: Create GitHub Actions Workflow

Create `.github/workflows/db-migration.yml` (already provided in repo):

```yaml
name: Database Migration CI/CD

on:
  pull_request:
    paths:
      - 'migrations/**'
  push:
    branches:
      - main
    paths:
      - 'migrations/**'

jobs:
  # Job 1: Validate migrations on PR
  validate:
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Find changed migration files
        id: changed
        run: |
          files=$(git diff --name-only origin/main HEAD -- migrations/V*.sql)
          echo "files=$files" >> $GITHUB_OUTPUT

      - name: Validate SQL (block dangerous operations)
        run: |
          for file in ${{ steps.changed.outputs.files }}; do
            if grep -qi "DROP TABLE" "$file"; then
              echo "::error::DROP TABLE found in $file"
              exit 1
            fi
            echo "✅ $file passed"
          done

  # Job 2: Deploy to Test (auto on merge)
  deploy-test:
    if: github.event_name == 'push'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run migrations on Test
        env:
          PGPASSWORD: ${{ secrets.DB_PASSWORD }}
        run: |
          for file in $(find migrations/ -name "V*.sql" | sort); do
            psql -h ${{ secrets.DB_HOST }} -U ${{ secrets.DB_USER }} \
              -d app_test -v ON_ERROR_STOP=1 -f "$file"
          done

  # Job 3: Deploy to UAT (manual approval)
  deploy-uat:
    needs: deploy-test
    runs-on: ubuntu-latest
    environment: uat
    steps:
      - uses: actions/checkout@v4
      - name: Run migrations on UAT
        env:
          PGPASSWORD: ${{ secrets.DB_PASSWORD }}
        run: |
          for file in $(find migrations/ -name "V*.sql" | sort); do
            psql -h ${{ secrets.DB_HOST }} -U ${{ secrets.DB_USER }} \
              -d app_uat -v ON_ERROR_STOP=1 -f "$file"
          done

  # Job 4: Deploy to Prod (manual approval)
  deploy-prod:
    needs: deploy-uat
    runs-on: ubuntu-latest
    environment: prod
    steps:
      - uses: actions/checkout@v4
      - name: Run migrations on Prod
        env:
          PGPASSWORD: ${{ secrets.DB_PASSWORD }}
        run: |
          for file in $(find migrations/ -name "V*.sql" | sort); do
            psql -h ${{ secrets.DB_HOST }} -U ${{ secrets.DB_USER }} \
              -d app_prod -v ON_ERROR_STOP=1 -f "$file"
          done
```

**Key point:** No Bytebase API needed. GitHub Actions runs `psql` directly.

### Step 5: Create a New Migration (Pull Request)

```bash
git checkout -b feature/add-feedback-table
make new-migration V=020 DESC=add_feedback_table
```

Edit `migrations/V020__add_feedback_table.sql`:

```sql
BEGIN;

CREATE TABLE feedback (
    id          BIGSERIAL PRIMARY KEY,
    user_id     BIGINT NOT NULL REFERENCES users(id),
    rating      INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment     TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_feedback_user_id ON feedback(user_id);

COMMIT;
```

```bash
git add migrations/V020__add_feedback_table.sql
git commit -m "feat: add feedback table migration"
git push origin feature/add-feedback-table
gh pr create --title "Add feedback table" --body "New migration V020"
```

### Step 6: PR Validation (Automatic)

```
┌─────────────────────────────────────────┐
│  Pull Request: feature/add-feedback    │
├─────────────────────────────────────────┤
│  1. Validate SQL                        │
│     ✓ Check for DROP TABLE (blocked)    │
│     ✓ Check for TRUNCATE (blocked)      │
│  2. Comment on PR: "✅ passed"          │
│  3. Human code review                   │
│  4. Merge to main                       │
└─────────────────────────────────────────┘
```

### Step 7: Merge Triggers Deployment Pipeline

```
┌─────────────────────────────────────────────────┐
│  Deployment Pipeline                             │
├─────────────────────────────────────────────────┤
│                                                  │
│  Job 1: Deploy to Test (automatic)              │
│  ┌────────────────────────────────────────────┐ │
│  │ psql -d app_test -f V020__add_feedback.sql │ │
│  │ Status: ✅ Completed                       │ │
│  └────────────────────────────────────────────┘ │
│                      ↓                           │
│  Job 2: Deploy to UAT (GitHub approval gate)    │
│  ┌────────────────────────────────────────────┐ │
│  │ ⏸ Waiting for reviewer approval...         │ │
│  │ Reviewer clicks "Approve" in GitHub        │ │
│  │ psql -d app_uat -f V020__add_feedback.sql  │ │
│  │ Status: ✅ Completed                       │ │
│  └────────────────────────────────────────────┘ │
│                      ↓                           │
│  Job 3: Deploy to Prod (GitHub approval gate)   │
│  ┌────────────────────────────────────────────┐ │
│  │ ⏸ Waiting for reviewer approval...         │ │
│  │ Reviewer clicks "Approve" in GitHub        │ │
│  │ psql -d app_prod -f V020__add_feedback.sql │ │
│  │ Status: ✅ Completed                       │ │
│  └────────────────────────────────────────────┘ │
│                                                  │
└─────────────────────────────────────────────────┘
```

### Step 8: Verify Databases

```bash
make status ENV=test
make status ENV=uat
make status ENV=prod

PGPASSWORD=tutorial_secret psql -h localhost -U tutorial -d app_test -c "\d feedback"
PGPASSWORD=tutorial_secret psql -h localhost -U tutorial -d app_uat -c "\d feedback"
PGPASSWORD=tutorial_secret psql -h localhost -U tutorial -d app_prod -c "\d feedback"
```

### Step 9: Test Validation Failure

```bash
git checkout -b feature/dangerous
make new-migration V=021 DESC=drop_table
```

Edit `migrations/V021__drop_table.sql`:

```sql
DROP TABLE feedback;
```

```bash
git add migrations/V021__drop_table.sql
git commit -m "feat: dangerous migration"
git push origin feature/dangerous
gh pr create --title "Dangerous migration" --body "Testing validation"
```

**Result:**
- ❌ ERROR: `DROP TABLE found in V021__drop_table.sql`
- PR is blocked

### Step 10: Use Bytebase GUI for Change History (Free)

```bash
make bytebase
```

1. Open `http://localhost:8088`
2. Go to project > **Databases** > `app_prod`
3. Click **Change History**
4. See all migrations applied via GitHub Actions

### Step 11: Clean Up

```bash
make down
```

## Approach B: Bytebase API (ENTERPRISE)

If you have Bytebase Enterprise, replace `psql` calls with Bytebase API:

1. Generate token: **Settings** > **Access Tokens** > **Create Token**
2. Add secrets: `BYTEBASE_URL`, `BYTEBASE_TOKEN`, `BYTEBASE_PROJECT`
3. Replace `psql` with Bytebase API calls for SQL review + issue creation

See [Bytebase GitOps Docs](https://docs.bytebase.com/gitops/overview)

## Pipeline Summary

```
PR Created          Merge to main         Manual Approve        Manual Approve
    │                    │                     │                     │
    ▼                    ▼                     ▼                     ▼
Validate SQL       Deploy Test          Deploy UAT           Deploy Prod
(psql check)       (auto)               (GitHub env)          (GitHub env)
    │                    │                     │                     │
    ▼                    ▼                     ▼                     ▼
✅ or ❌            app_test ✅          app_uat ✅            app_prod ✅
```

## Free vs Enterprise

| Feature | Free (psql) | Enterprise (Bytebase API) |
|---------|-------------|---------------------------|
| Migration deployment | ✓ psql | ✓ Bytebase API |
| SQL validation | ✓ Basic grep | ✓ 50+ rules |
| Approval gates | ✓ GitHub envs | ✓ Bytebase custom flows |
| Change history | ✓ Git + Bytebase GUI | ✓ Bytebase API |
| Risk assessment | ✗ | ✓ Automatic |
| SQL review | ✗ | ✓ 50+ rules |
| Audit trail | ✓ Git log | ✓ Bytebase audit log |

## Commands Reference

| Command | Description |
|---------|-------------|
| `make create-envs` | Create test, uat, prod databases |
| `make migrate ENV=test` | Migrate specific environment |
| `make compare-envs` | Compare schemas |
| `make bytebase` | Open Bytebase GUI |
| `make new-migration V=020 DESC=add_feedback` | Create migration |

## Next Steps

- [Bytebase GitOps Docs](https://docs.bytebase.com/gitops/overview)
- [Bytebase API Reference](https://api.bytebase.com)
- [GitHub Actions Environments](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)
