# Lab 4: Bytebase Risk Management & Approval Workflows

## Objective
Learn how to use Bytebase for automated risk assessment, SQL review, and configurable approval workflows for database changes.

## Prerequisites
- Completed Labs 1-3
- Docker and Docker Compose installed
- Web browser

## Step-by-Step Instructions

### Step 1: Start Environment

```bash
make setup
make migrate
make seed
```

### Step 2: Access Bytebase UI

```bash
make bytebase
```

Or open `http://localhost:8080` in your browser.

### Step 3: Register Admin Account

1. Click **Sign Up** (first time only)
2. Fill in:
   - Email: `admin@example.com`
   - Password: `admin123`
   - Confirm Password: `admin123`
3. Click **Sign Up**

You are now logged in as **Workspace Admin**.

### Step 4: Add PostgreSQL Instance

1. Click **Instances** in the left sidebar
2. Click **Create Instance**
3. Select **PostgreSQL**
4. Fill in connection details:
   - **Instance Name**: `tutorial-postgres`
   - **Host**: `postgres`
   - **Port**: `5432`
   - **Username**: `tutorial`
   - **Password**: `tutorial_secret`
5. Click **Create**

You should see the instance with databases: `app_db`, `postgres`

### Step 5: Create a Project

1. Click **Projects** in the left sidebar
2. Click **Create Project**
3. Fill in:
   - **Name**: `db-versioning-tutorial`
   - **Key**: `DBVER`
4. Click **Create**

### Step 6: Add Database to Project

1. Click on the project `db-versioning-tutorial`
2. Click **Databases** in the left sidebar
3. Click **Add Database**
4. Select the instance `tutorial-postgres`
5. Select database `app_db`
6. Click **Add**

### Step 7: Submit a Schema Change (CREATE TABLE)

1. Click on the database `app_db`
2. Click **Edit Schema** (top right)
3. In the SQL editor, paste:

```sql
-- New table for customer feedback
CREATE TABLE customer_feedback (
    id          BIGSERIAL PRIMARY KEY,
    user_id     BIGINT REFERENCES users(id),
    rating      INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment     TEXT,
    product_id  BIGINT REFERENCES products(id),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_feedback_user_id ON customer_feedback(user_id);
CREATE INDEX idx_feedback_product_id ON customer_feedback(product_id);
CREATE INDEX idx_feedback_rating ON customer_feedback(rating);
```

4. Click **Create** to submit the change

### Step 8: Review the Change

1. You'll see the issue created
2. Note the **Risk Level** (should be LOW for CREATE TABLE)
3. Click **Review** tab
4. Note any SQL review findings

### Step 9: Configure Risk Rules

1. Click **Settings** > **Risk Center** in the left sidebar
2. Click **Create Risk Rule**

**Rule 1: Production DDL**

- **Name**: `Production DDL Changes`
- **Statement Types**: Select `DDL`
- **Condition**:
  ```
  environment_id == "prod"
  ```
- **Risk Level**: `HIGH`
- Click **Create**

**Rule 2: Large Table Operations**

- Click **Create Risk Rule**
- **Name**: `Large Table DDL`
- **Statement Types**: Select `DDL`
- **Condition**:
  ```
  table_rows > 1000000
  ```
- **Risk Level**: `HIGH`
- Click **Create**

**Rule 3: Production DML**

- Click **Create Risk Rule**
- **Name**: `Production Data Changes`
- **Statement Types**: Select `DML`
- **Condition**:
  ```
  environment_id == "prod"
  ```
- **Risk Level**: `HIGH`
- Click **Create**

**Rule 4: DELETE Operations**

- Click **Create Risk Rule**
- **Name**: `All DELETE Operations`
- **Statement Types**: Select `DELETE`
- **Risk Level**: `HIGH`
- Click **Create`

### Step 10: Configure Approval Flow

1. Click **CI/CD** > **Custom Approval** in the left sidebar
2. Under **Change Database**, click **Add Rule`

**Rule 1: CREATE TABLE in Production**

- **Name**: `CREATE TABLE in Prod`
- **Condition**:
  ```
  statement.sql_type == "CREATE_TABLE" && resource.environment_id == "prod"
  ```
- **Approval Flow**:
  - Click **Add Node**
  - Select **DBA**
- **Risk Level**: `MEDIUM`
- Click **Create**

**Rule 2: ALTER TABLE in Production**

- Click **Add Rule**
- **Name**: `ALTER TABLE in Prod`
- **Condition**:
  ```
  statement.sql_type == "ALTER_TABLE" && resource.environment_id == "prod"
  ```
- **Approval Flow**:
  - Click **Add Node**
  - Select **Project Owner**
  - Click **Add Node**
  - Select **DBA**
- **Risk Level**: `HIGH`
- Click **Create**

**Rule 3: DELETE in Production**

- Click **Add Rule**
- **Name**: `DELETE in Prod`
- **Condition**:
  ```
  statement.sql_type == "DELETE" && resource.environment_id == "prod"
  ```
- **Approval Flow**:
  - Click **Add Node**
  - Select **Project Owner**
  - Click **Add Node**
  - Select **DBA**
  - Click **Add Node**
  - Select **Security` (custom role)
- **Risk Level**: `HIGH`
- Click **Create**

### Step 11: Add Users and Roles

1. Click **IAM & Admin** > **Users** in the left sidebar
2. Click **Create User**

**Add DBA User:**
- **Email**: `dba@example.com`
- **Password**: `dba123`
- **Role**: `Workspace DBA`
- Click **Create**

**Add Developer User:**
- Click **Create User**
- **Email**: `dev@example.com`
- **Password**: `dev123`
- **Role**: `Project Developer`
- Click **Create**

### Step 12: Test Approval Workflow

1. Log out (click avatar > Sign out)
2. Log in as `dev@example.com` / `dev123`
3. Go to project `db-versioning-tutorial`
4. Click **Databases** > `app_db` > **Edit Schema**
5. Paste this SQL:

```sql
-- Add a new column to users
ALTER TABLE users ADD COLUMN last_login_at TIMESTAMPTZ;
```

6. Click **Create**

You should see:
- The issue is created
- **Risk Level**: HIGH (ALTER TABLE in prod)
- **Approval Flow**: Project Owner → DBA
- Status: **Waiting for approval**

### Step 13: Approve as DBA

1. Log out
2. Log in as `dba@example.com` / `dba123`
3. Go to **Issues** in the left sidebar
4. Click on the pending issue
5. Review the SQL change
6. Click **Approve**

### Step 14: Configure SQL Review Policy

1. Log in as admin (`admin@example.com`)
2. Click **Settings** > **SQL Review`
3. Click **Create Policy**

**Enable Key Rules:**

- ✅ `schema.rule.pk-required` - Require primary keys
- ✅ `schema.rule.no-select-all` - Prevent SELECT *
- ✅ `naming.table` - Table naming convention
- ✅ `schema.rule.column-no-null` - Require NOT NULL

Click **Create**

### Step 15: Test SQL Review

1. Go to project > Databases > Edit Schema
2. Paste this SQL (violates rules):

```sql
-- Bad: No primary key, uses SELECT *
CREATE TABLE bad_table (
    name VARCHAR(100),
    value TEXT
);
```

3. Click **Create**

You should see SQL review warnings:
- ⚠️ Table must have a primary key
- ⚠️ Column should have NOT NULL constraint

### Step 16: View Audit Log

1. Click **Audit Log** in the left sidebar
2. Review all changes made:
   - Who made the change
   - When it was made
   - What SQL was executed
   - Approval chain

## Key Takeaways

1. **Risk Rules** automatically assess change risk based on conditions
2. **Approval Flows** enforce review process based on risk level
3. **SQL Review** catches common mistakes before they reach production
4. **Audit Log** provides complete change history for compliance
5. **Role-Based Access** ensures proper separation of duties

## Bytebase Features Summary

| Feature | Benefit |
|---------|---------|
| Risk Assessment | Automatic risk scoring |
| Custom Approval | Configurable workflows |
| SQL Review | 50+ automated checks |
| Audit Log | Complete change history |
| Data Masking | PII protection |
| Just-in-Time Access | Secure temporary access |
| GitOps | CI/CD integration |

## Production Checklist

- [ ] Configure environments (dev/test/prod)
- [ ] Set up risk rules for each environment
- [ ] Configure approval flows based on risk
- [ ] Enable SQL review policies
- [ ] Add team members with appropriate roles
- [ ] Test approval workflow with sample changes
- [ ] Review audit log regularly
- [ ] Set up webhooks for notifications

## Next Steps

- Explore [Bytebase Documentation](https://docs.bytebase.com)
- Learn about [Data Masking](https://docs.bytebase.com/security/data-masking/overview)
- Set up [GitOps Workflow](https://docs.bytebase.com/gitops/overview)
- Configure [Just-in-Time Access](https://docs.bytebase.com/security/database-permission/just-in-time)

## Clean Up

```bash
make down
```
