# Lab 5: CI/CD GitOps with Bytebase

## Objective
Set up a GitOps workflow where database migrations are version-controlled in Git and automatically deployed through Bytebase across **test → uat → prod** environments via pull requests.

## How GitOps Works with Bytebase

```
Developer creates PR with migration SQL
         ↓
GitHub Actions runs SQL Review (Bytebase API)
         ↓
PR merged → Bytebase creates Issue
         ↓
Test (auto) → UAT (manual rollout) → Prod (manual rollout)
```

## Prerequisites
- Completed Labs 1-4
- GitHub account
- Bytebase running (`make bytebase`)
- Bytebase API token (generated in Step 3)

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

### Step 2: Configure Bytebase for GitOps

1. Open `http://localhost:8088`
2. Register admin (if not done already)
3. Add PostgreSQL instance (host: `postgres`, port: `5432`, user: `tutorial`, password: `tutorial_secret`)
4. Create project `db-versioning-tutorial`
5. Add `app_test` → Test, `app_uat` → UAT, `app_prod` → Prod

### Step 3: Generate Bytebase API Token

**Note:** This is a Bytebase API token, NOT a GitHub access token.

1. Open Bytebase at `http://localhost:8088`
2. Click **Settings** > **Access Tokens**
3. Click **Create Token**
4. Name: `github-actions`
5. Copy the token value (e.g., `bb-token-xxxxx`)
6. Save it for GitHub Secrets (Step 4)

| Token | Source | Used For |
|-------|--------|----------|
| `BYTEBASE_TOKEN` | Bytebase > Settings > Access Tokens | Authenticate API calls to Bytebase |
| `GITHUB_TOKEN` | GitHub (auto-provided in Actions) | GitHub Actions operations |

### Step 4: Set Up GitHub Repository

```bash
# Fork or use your existing repo
git remote -v
# origin  https://github.com/apaichon/db-versioning.git
```

Add GitHub repository secrets:

1. Go to your GitHub repo > **Settings** > **Secrets and variables** > **Actions**
2. Click **New repository secret**
3. Add:
   - Name: `BYTEBASE_URL`
   - Value: `http://localhost:8088`
4. Add:
   - Name: `BYTEBASE_TOKEN`
   - Value: (paste token from Step 3)
5. Add:
   - Name: `BYTEBASE_PROJECT`
   - Value: `db-versioning-tutorial`

### Step 5: Create GitHub Actions Workflow

Create `.github/workflows/db-migration.yml`:

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
  # Job 1: SQL Review on PR
  sql-review:
    if: github.event_name == 'pull_request'
   Aruns-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Find changed migration files
        id: changed
        run: |
          files=$(git diff --name-only origin/main HEAD -- migrations/V*.sql)
          echo "files=$files" >> $GITHUB_OUTPUT
          if [ -z "$files" ]; then
            echo "has_changes=false" >> $GITHUB_OUTPUT
          else
            echo "has_changes=true" >> $GITHUB_OUTPUT
          fi

      - name: SQL Review via Bytebase API
        if: steps.changed.outputs.has_changes == 'true'
        run: |
          for file in ${{ steps.changed.outputs.files }}; do
            echo "Reviewing: $file"
            sql=$(cat "$file")

            # Call Bytebase SQL Review API
            response=$(curl -s -X POST \
              "${{ secrets.BYTEBASE_URL }}/api/v1/sql/review" \
              -H "Authorization: Bearer ${{ secrets.BYTEBASE_TOKEN }}" \
              -H "Content-Type: application/json" \
              -d "{
                \"sql\": \"$(echo "$sql" | jq -Rs .)\",
                \"engine\": \"POSTGRES\"
              }")

            echo "Review result: $response"

            # Check for errors
            has_error=$(echo "$response" | jq -r '.adviceList[]? | select(.level == "ERROR") | .title' 2>/dev/null)
            if [ -n "$has_error" ]; then
              echo "::error::SQL Review found errors in $file"
              echo "$has_error"
              exit 1
            fi
          done

      - name: Comment on PR
        if: always()
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: '✅ SQL Review passed for migration files'
            })

  # Job 2: Deploy to Test (auto on merge)
  deploy-test:
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Find new migration files
        id: migrations
        run: |
          files=$(find migrations/ -name "V*.sql" -newer migrations/.last-deploy || true)
          echo "files=$files" >> $GITHUB_OUTPUT

      - name: Deploy to Test via Bytebase API
        run: |
          for file in ${{ steps.migrations.outputs.files }}; do
            echo "Deploying $file to Test..."
            sql=$(cat "$file")

            curl -s -X POST \
              "${{ secrets.BYTEBASE_URL }}/api/v1/issues" \
              -H "Authorization: Bearer ${{ secrets.BYTEBASE_TOKEN }}" \
              -H "Content-Type: application/json" \
              -d "{
                \"project\": \"${{ secrets.BYTEBASE_PROJECT }}\",
                \"database\": \"app_test\",
                \"sql\": \"$(echo "$sql" | jq -Rs .)\",
                \"title\": \"Deploy $file to Test\"
              }"
          done

      - name: Update last deploy marker
        run: touch migrations/.last-deploy

  # Job 3: Deploy to UAT (manual trigger)
  deploy-uat:
    needs: deploy-test
    runs-on: ubuntu-latest
    environment:
      name: uat
    steps:
      - uses: actions/checkout@v4

      - name: Deploy to UAT via Bytebase API
        run: |
          for file in $(find migrations/ -name "V*.sql" -newer migrations/.last-uat || true); do
            echo "Deploying $file to UAT..."
            sql=$(cat "$file")

            curl -s -X POST \
              "${{ secrets.BYTEBASE_URL }}/api/v1/issues" \
              -H "Authorization: Bearer ${{ secrets.BYTEBASE_TOKEN }}" \
              -H "Content-Type: application/json" \
              -d "{
                \"project\": \"${{ secrets.BYTEBASE_PROJECT }}\",
                \"database\": \"app_uat\",
                \"sql\": \"$(echo "$sql" | jq -Rs .)\",
                \"title\": \"Deploy $file to UAT\"
              }"
          done
          touch migrations/.last-uat

  # Job 4: Deploy to Prod (manual trigger + approval)
  deploy-prod:
    needs: deploy-uat
    runs-on: ubuntu-latest
    environment:
      name: prod
    steps:
      - uses: actions/checkout@v4

      - name: Deploy to Prod via Bytebase API
        run: |
          for file in $(find migrations/ -name "V*.sql" -newer migrations/.last-prod || true); do
            echo "Deploying $file to Prod..."
            sql=$(cat "$file")

            curl -s -X POST \
              "${{ secrets.BYTEBASE_URL }}/api/v1/issues" \
              -H "Authorization: Bearer ${{ secrets.BYTEBASE_TOKEN }}\"
              -H "Content-Type: application/json" \
              -d "{
                \"project\": \"${{ secrets.BYTEBASE_PROJECT }}\",
                \"database\": \"app_prod\",
                \"sql\": \"$(echo "$sql" | jq -Rs .)\",
                \"title\": \"Deploy $file to Prod\"
              }"
          done
          touch migrations/.last-prod
```

### Step 6: Create a New Migration (Pull Request)

```bash
# Create a new migration
make new-migration V=020 DESC=add_feedback_table
```

Edit `migrations/V020__add_feedback_table.sql`:

```sql
-- Migration: V020 - add_feedback_table
-- Risk level: LOW
-- Backward compatible: YES

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

### Step 7: Create Pull Request

```bash
git checkout -b feature/add-feedback-table
git add migrations/V020__add_feedback_table.sql
git commit -m "feat: add feedback table migration"
git push origin feature/add-feedback-table

# Create PR on GitHub
gh pr create --title "Add feedback table" --body "New migration V020"
```

### Step 8: PR Review Pipeline

When the PR is created, GitHub Actions runs:

```
┌─────────────────────────────────────────┐
│  Pull Request: feature/add-feedback    │
├─────────────────────────────────────────┤
│                                          │
│  1. SQL Review (Bytebase API)           │
│     ✓ Check primary keys                │
│     ✓ Check naming conventions          │
│     ✓ Check NOT NULL constraints        │
│     ✓ Check foreign keys                │
│                                          │
│  2. Comment on PR: "✅ SQL Review passed"│
│                                          │
│  3. Human code review                   │
│     ✓ Reviewer approves                 │
│                                          │
│  4. Merge to main                       │
│                                          │
└─────────────────────────────────────────┘
```

### Step 9: Merge Triggers Deployment Pipeline

When the PR is merged to `main`:

```
┌─────────────────────────────────────────────────┐
│  Deployment Pipeline (on merge to main)          │
├─────────────────────────────────────────────────┤
│                                                   │
│  Job 1: Deploy to Test (automatic)               │
│  ┌─────────────────────────────────────────────┐ │
│  │ Bytebase creates issue for app_test         │ │
│  │ Test environment → auto-rollout             │ │
│  │ Status: ✅ Completed                        │ │
│  └─────────────────────────────────────────────┘ │
│                      ↓                            │
│  Job 2: Deploy to UAT (manual trigger)           │
│  ┌─────────────────────────────────────────────┐ │
│  │ Click "Review deployments" in GitHub        │ │
│  │ Click "Approve" for UAT environment         │ │
│  │ Bytebase creates issue for app_uat          │ │
│  │ Click "Rollout" in Bytebase                 │ │
│  │ Status: ✅ Completed                        │ │
│  └─────────────────────────────────────────────┘ │
│                      ↓                            │
│  Job 3: Deploy to Prod (manual trigger)          │
│  ┌─────────────────────────────────────────────┐ │
│  │ Click "Review deployments" in GitHub        │ │
│  │ Click "Approve" for Prod environment        │ │
│  │ Bytebase creates issue for app_prod         │ │
│  │ Click "Rollout" in Bytebase                 │ │
│  │ Status: ✅ Completed                        │ │
│  └─────────────────────────────────────────────┘ │
│                                                   │
└─────────────────────────────────────────────────┘
```

### Step 10: Verify in Bytebase

1. Open `http://localhost:8088`
2. Go to project > **Issues**
3. You should see 3 issues:
   - `Deploy V020 to Test` → Completed
   - `Deploy V020 to UAT` → Completed
   - `Deploy V020 to Prod` → Completed
4. Go to **Change History** for each database
5. Verify `feedback` table exists in all 3 databases

### Step 11: Verify Databases

```bash
make status ENV=test
make status ENV=uat
make status ENV=prod

# Check feedback table exists in all environments
PGPASSWORD=tutorial_secret psql -h localhost -U tutorial -d app_test -c "\d feedback"
PGPASSWORD=tutorial_secret psql -h localhost -U tutorial -d app_uat -c "\d feedback"
PGPASSWORD=tutorial_secret psql -h localhost -U tutorial -d app_prod -c "\d feedback"
```

### Step 12: Test SQL Review Failure

Create a PR with bad SQL to see SQL Review catch it:

```bash
git checkout -b feature/bad-migration
make new-migration V=021 DESC=bad_table
```

Edit `migrations/V021__bad_table.sql`:

```sql
-- Bad: no primary key, nullable columns
CREATE TABLE bad_table (
    name VARCHAR(100),
    value TEXT
);
```

```bash
git add migrations/V021__bad_table.sql
git commit -m "feat: bad migration (should fail SQL review)"
git push origin feature/bad-migration
gh pr create --title "Bad migration" --body "Testing SQL review"
```

**Expected result:**
- GitHub Actions runs SQL Review
- ❌ ERROR: Table must have a primary key
- PR is blocked (review fails)
- Comment on PR shows the error

Fix the SQL and push again:

```sql
CREATE TABLE bad_table (
    id   BIGSERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    value TEXT
);
```

Now SQL Review passes.

### Step 13: Clean Up

```bash
make down
```

## CI/CD Pipeline Summary

```
PR Created          Merge to main         Manual Approve        Manual Approve
    │                    │                     │                     │
    ▼                    ▼                     ▼                     ▼
SQL Review         Deploy Test          Deploy UAT           Deploy Prod
(Bytebase API)     (auto-rollout)       (manual rollout)      (manual rollout)
    │                    │                     │                     │
    ▼                    ▼                     ▼                     ▼
✅ or ❌            app_test ✅          app_uat ✅            app_prod ✅
```

## GitOps Benefits

| Without GitOps | With GitOps |
|----------------|-------------|
| Manual SQL execution | Version-controlled in Git |
| No review process | SQL Review on every PR |
| No audit trail | Full history in Git + Bytebase |
| Direct to prod | Test → UAT → Prod pipeline |
| No rollback | Git revert + Bytebase rollback |
| Hard to track changes | PR links to issues |

## Free Version GitOps Features

| Feature | Free Version |
|---------|-------------|
| SQL Review API | ✓ |
| Issue creation API | ✓ |
| Change History | ✓ |
| Environments | ✓ |
| Rollout (manual for Prod) | ✓ |
| Custom Approval (Enterprise) | ✗ |
| Risk Center (Enterprise) | ✗ |

## GitHub Environments Setup

1. Go to GitHub repo > **Settings** > **Environments**
2. Click **New environment** → name: `uat`
   - Required reviewers: add team members
3. Click **New environment** → name: `prod`
   - Required reviewers: add team lead + DBA
   - Branch protection: only `main`

This adds manual approval gates before UAT and Prod deployments.

## Commands Reference

| Command | Description |
|---------|-------------|
| `make new-migration V=020 DESC=add_feedback` | Create migration |
| `make compare-envs` | Compare schemas |
| `make bytebase` | Open Bytebase |
| `gh pr create --title "..."` | Create pull request |

## Next Steps

- [Bytebase GitOps Docs](https://docs.bytebase.com/gitops/overview)
- [Bytebase API Reference](https://api.bytebase.com)
- [GitHub Actions Environments](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)
