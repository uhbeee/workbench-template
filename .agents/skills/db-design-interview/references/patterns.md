# Common Relational Design Patterns

## Table of Contents
1. State Machines
2. Audit Trails & Temporal Data
3. Soft Deletes
4. Polymorphic Associations
5. Multi-Tenancy
6. Entity-Attribute-Value (EAV)
7. Tree / Hierarchical Data
8. Optimistic Locking

---

## 1. State Machines

When an entity passes through defined states (draft → published → archived), model the
states explicitly and guard transitions.

```sql
-- Use an ENUM or CHECK constraint for valid states
CREATE TABLE orders (
  id BIGINT PRIMARY KEY,
  status VARCHAR(20) NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'confirmed', 'shipped', 'delivered', 'cancelled', 'refunded')),
  -- ...
);

-- Track state transitions for auditing
CREATE TABLE order_status_history (
  id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  order_id BIGINT NOT NULL REFERENCES orders(id),
  from_status VARCHAR(20),
  to_status VARCHAR(20) NOT NULL,
  changed_by BIGINT REFERENCES users(id),
  changed_at TIMESTAMP NOT NULL DEFAULT now(),
  reason TEXT
);

CREATE INDEX idx_order_status_history_order ON order_status_history(order_id, changed_at);
```

**When to use:** Any entity with a lifecycle. Orders, applications, support tickets, content
with publish workflows.

**Key consideration:** Enforce valid transitions in application code (or triggers), but store
the full history in the database. The history table is invaluable for debugging and compliance.

---

## 2. Audit Trails & Temporal Data

### Approach A: History table per entity
Best when you need to query historical states of a specific entity type.

```sql
CREATE TABLE products (
  id BIGINT PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  price DECIMAL(10,2) NOT NULL,
  updated_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE products_history (
  history_id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  product_id BIGINT NOT NULL,
  name VARCHAR(255) NOT NULL,
  price DECIMAL(10,2) NOT NULL,
  valid_from TIMESTAMP NOT NULL,
  valid_to TIMESTAMP NOT NULL DEFAULT now(),
  changed_by BIGINT
);

CREATE INDEX idx_products_hist_lookup ON products_history(product_id, valid_from);
```

### Approach B: Generic audit log
Best when you need a system-wide audit trail but don't query historical values often.

```sql
CREATE TABLE audit_log (
  id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  table_name VARCHAR(100) NOT NULL,
  record_id BIGINT NOT NULL,
  action VARCHAR(10) NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
  old_values JSONB,
  new_values JSONB,
  changed_by BIGINT,
  changed_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_audit_table_record ON audit_log(table_name, record_id, changed_at);
```

### Approach C: Point-in-time snapshots
When you need to know what a value was at order time (e.g., the price when purchased).

```sql
CREATE TABLE order_items (
  id BIGINT PRIMARY KEY,
  order_id BIGINT NOT NULL REFERENCES orders(id),
  product_id BIGINT NOT NULL REFERENCES products(id),
  quantity INT NOT NULL,
  unit_price DECIMAL(10,2) NOT NULL,  -- Snapshot of price at time of order
  product_name VARCHAR(255) NOT NULL  -- Snapshot of name at time of order
);
```

**This is critical.** Never just store a FK to products and join to get the price — the
price will change, and then historical orders show the wrong amount.

---

## 3. Soft Deletes

### Option A: deleted_at timestamp (recommended)
```sql
ALTER TABLE users ADD COLUMN deleted_at TIMESTAMP;

-- Partial index for performance: queries on active records skip deleted ones
CREATE INDEX idx_users_active_email ON users(email) WHERE deleted_at IS NULL;

-- Application must add WHERE deleted_at IS NULL to all queries
-- Or use a view:
CREATE VIEW active_users AS SELECT * FROM users WHERE deleted_at IS NULL;
```

### Option B: is_deleted boolean
Simpler but loses the "when was it deleted?" information.

### Option C: Separate archive table
Move deleted records to a parallel table. Keeps the main table clean but complicates
restoration and breaks FK references.

**Recommendation:** Use `deleted_at TIMESTAMP` with partial indexes. It gives you the
deletion timestamp for compliance, keeps queries fast via partial indexes, and doesn't
break FK relationships.

**Warning:** Soft deletes add complexity to every query. If you use an ORM, configure a
default scope. If writing raw SQL, use views or be disciplined about WHERE clauses.

---

## 4. Polymorphic Associations

When multiple entity types share a relationship (e.g., comments on both posts and photos).

### Option A: Separate FK columns (stronger integrity)
```sql
CREATE TABLE comments (
  id BIGINT PRIMARY KEY,
  content TEXT NOT NULL,
  post_id BIGINT REFERENCES posts(id),
  photo_id BIGINT REFERENCES photos(id),
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  CHECK (
    (post_id IS NOT NULL AND photo_id IS NULL) OR
    (post_id IS NULL AND photo_id IS NOT NULL)
  )
);
```
**Pros:** Real FK constraints, database-enforced integrity.
**Cons:** Schema change needed for each new commentable type. Columns grow with types.

### Option B: Type + ID columns (flexible, weaker integrity)
```sql
CREATE TABLE comments (
  id BIGINT PRIMARY KEY,
  content TEXT NOT NULL,
  commentable_type VARCHAR(50) NOT NULL,
  commentable_id BIGINT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_comments_target ON comments(commentable_type, commentable_id);
```
**Pros:** No schema changes when adding new commentable types.
**Cons:** No FK constraint — orphaned references possible. Queries need the type column.

### Option C: Junction tables per type
```sql
CREATE TABLE post_comments (
  comment_id BIGINT PRIMARY KEY REFERENCES comments(id),
  post_id BIGINT NOT NULL REFERENCES posts(id)
);

CREATE TABLE photo_comments (
  comment_id BIGINT PRIMARY KEY REFERENCES comments(id),
  photo_id BIGINT NOT NULL REFERENCES photos(id)
);
```
**Pros:** Full FK integrity, clean separation.
**Cons:** More tables, more JOINs.

**Recommendation:** For < 4 types that rarely change, use Option A. For extensible systems,
use Option B with application-level integrity checks. Option C when data integrity is critical
and you can tolerate the extra joins.

---

## 5. Multi-Tenancy

### Option A: Shared table with tenant_id
```sql
CREATE TABLE projects (
  id BIGINT PRIMARY KEY,
  tenant_id BIGINT NOT NULL REFERENCES tenants(id),
  name VARCHAR(255) NOT NULL
);

-- EVERY index must include tenant_id for query isolation
CREATE INDEX idx_projects_tenant ON projects(tenant_id, name);

-- Row-level security (PostgreSQL)
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON projects
  USING (tenant_id = current_setting('app.current_tenant')::bigint);
```
**Pros:** Simple, single schema, easy migrations.
**Cons:** Risk of data leakage if tenant_id filter is forgotten. Noisy neighbor problems.

### Option B: Schema-per-tenant (PostgreSQL)
```sql
CREATE SCHEMA tenant_123;
CREATE TABLE tenant_123.projects (...);
-- SET search_path = tenant_123, public;
```
**Pros:** Strong isolation, per-tenant backup/restore, simpler queries (no tenant_id).
**Cons:** Schema migrations must run per-tenant. Connection management is more complex.

### Option C: Database-per-tenant
**Pros:** Complete isolation, independent scaling, per-tenant encryption keys.
**Cons:** Operational overhead at scale. Cross-tenant queries are impossible.

**Recommendation:** Start with Option A + Row Level Security for most SaaS products. Move
to Option B when you have regulatory requirements or large tenants that need isolation.
Option C for enterprise customers with strict compliance needs.

---

## 6. Entity-Attribute-Value (EAV)

When different records need different sets of attributes (e.g., product catalog where shoes
have "size" but laptops have "RAM").

```sql
CREATE TABLE product_attributes (
  id BIGINT PRIMARY KEY,
  product_id BIGINT NOT NULL REFERENCES products(id),
  attribute_name VARCHAR(100) NOT NULL,
  attribute_value TEXT,
  UNIQUE (product_id, attribute_name)
);
```

**Almost always avoid this.** EAV is a trap that looks flexible but makes queries painful,
prevents type checking, and defeats indexing.

**Better alternatives:**
- **JSONB column** (PostgreSQL): `attributes JSONB` with GIN index. Same flexibility, better
  query support, and you can add JSON Schema validation.
- **Table-per-type** (class table inheritance): Shared base table with type-specific child
  tables for additional columns.
- **Single table with nullable columns:** If there are < 10 type-specific columns, just add
  them all as nullable. Simpler than it sounds.

---

## 7. Tree / Hierarchical Data

### Option A: Adjacency List (simple)
```sql
CREATE TABLE categories (
  id BIGINT PRIMARY KEY,
  parent_id BIGINT REFERENCES categories(id),
  name VARCHAR(255) NOT NULL
);
```
Easy writes, hard to query full subtree (requires recursive CTE).

### Option B: Materialized Path
```sql
CREATE TABLE categories (
  id BIGINT PRIMARY KEY,
  path VARCHAR(500) NOT NULL,  -- e.g., '/1/5/12/'
  name VARCHAR(255) NOT NULL
);

CREATE INDEX idx_categories_path ON categories(path);
-- Subtree: WHERE path LIKE '/1/5/%'
```
Easy subtree queries, but path updates on moves are expensive.

### Option C: Closure Table
```sql
CREATE TABLE category_tree (
  ancestor_id BIGINT NOT NULL REFERENCES categories(id),
  descendant_id BIGINT NOT NULL REFERENCES categories(id),
  depth INT NOT NULL,
  PRIMARY KEY (ancestor_id, descendant_id)
);
```
Best query performance for all tree operations, but more storage and writes.

**Recommendation:** Adjacency list + recursive CTE for shallow trees (< 10 levels) with
infrequent subtree queries. Closure table for deep trees or heavy subtree operations.

---

## 8. Optimistic Locking

Prevent lost updates when two users edit the same record.

```sql
CREATE TABLE documents (
  id BIGINT PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  content TEXT,
  version INT NOT NULL DEFAULT 1,  -- Optimistic lock column
  updated_at TIMESTAMP NOT NULL DEFAULT now()
);

-- Update only succeeds if version matches
UPDATE documents
SET title = 'New Title', version = version + 1, updated_at = now()
WHERE id = 123 AND version = 5;

-- If 0 rows affected → someone else updated it → handle conflict
```

**When to use:** Any entity that multiple users might edit concurrently. Documents, settings,
inventory counts. Much simpler than pessimistic locking (SELECT FOR UPDATE) and works well
with web applications where the "lock" would need to span an HTTP request cycle.