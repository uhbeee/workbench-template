# Indexing Strategy Reference

## Table of Contents
1. Index Types
2. Composite Index Ordering
3. Specialized Indexes
4. Anti-Patterns
5. Query Analysis with EXPLAIN

---

## Index Types

### B-Tree (Default)
The workhorse. Supports equality (=), range (<, >, BETWEEN), ORDER BY, and prefix matching.

```sql
-- Single column: speeds up WHERE user_id = ?
CREATE INDEX idx_orders_user ON orders(user_id);

-- Range queries: speeds up WHERE created_at > ? AND created_at < ?
CREATE INDEX idx_orders_created ON orders(created_at);
```

**Use for:** Most queries. Equality, ranges, sorting, IS NULL.

### Hash
Equality-only lookups. Smaller and slightly faster than B-tree for pure equality, but
can't do ranges or sorting. PostgreSQL supports hash indexes; MySQL uses them internally
for MEMORY tables.

```sql
CREATE INDEX idx_users_email_hash ON users USING hash (email);
```

**Use for:** Exact match lookups only, when you're certain you'll never range-scan.
In practice, B-tree is almost always the better choice — the difference is marginal.

### GIN (Generalized Inverted Index) — PostgreSQL
For multi-valued data: arrays, JSONB, full-text search vectors.

```sql
-- JSONB containment queries
CREATE INDEX idx_products_attrs ON products USING gin (attributes);
-- Supports: WHERE attributes @> '{"color": "red"}'

-- Full-text search
CREATE INDEX idx_products_search ON products USING gin (to_tsvector('english', name || ' ' || description));
```

**Use for:** JSONB queries, array containment, full-text search.

### GiST (Generalized Search Tree) — PostgreSQL
For geometric, range, and proximity queries.

```sql
-- Range types (e.g., booking date ranges)
CREATE INDEX idx_bookings_dates ON bookings USING gist (date_range);
-- Supports: WHERE date_range && '[2024-01-01, 2024-01-31]'

-- PostGIS geospatial
CREATE INDEX idx_locations_geo ON locations USING gist (coordinates);
```

**Use for:** Overlapping ranges, nearest-neighbor, geospatial.

### Full-Text Indexes

**PostgreSQL:**
```sql
-- Add a tsvector column (or use a generated column)
ALTER TABLE products ADD COLUMN search_vector tsvector
  GENERATED ALWAYS AS (to_tsvector('english', coalesce(name,'') || ' ' || coalesce(description,''))) STORED;

CREATE INDEX idx_products_fts ON products USING gin (search_vector);

-- Query
SELECT * FROM products WHERE search_vector @@ to_tsquery('english', 'wireless & headphones');
```

**MySQL:**
```sql
ALTER TABLE products ADD FULLTEXT INDEX idx_products_ft (name, description);

-- Query
SELECT * FROM products WHERE MATCH(name, description) AGAINST('wireless headphones' IN BOOLEAN MODE);
```

---

## Composite Index Ordering

Column order in a composite index matters enormously. The index can satisfy queries that
filter on a *prefix* of the columns, in order.

```sql
CREATE INDEX idx_orders_user_status_created ON orders(user_id, status, created_at DESC);
```

**This index supports:**
```sql
WHERE user_id = 123                                    -- ✅ Uses index (prefix: user_id)
WHERE user_id = 123 AND status = 'active'              -- ✅ Uses index (prefix: user_id, status)
WHERE user_id = 123 AND status = 'active' ORDER BY created_at DESC  -- ✅ Full index
```

**This index does NOT support:**
```sql
WHERE status = 'active'                                -- ❌ status is not the first column
WHERE created_at > '2024-01-01'                        -- ❌ created_at is not the first column
WHERE user_id = 123 ORDER BY created_at DESC           -- ⚠️ Partial: uses user_id, but skips status
```

**Rules of thumb:**
1. Put equality columns first (WHERE x = ?)
2. Put range/sort columns last (WHERE y > ? ORDER BY z)
3. Put the most selective column first when all are equality
4. If a column is always in the query, put it first

---

## Specialized Indexes

### Partial Indexes (PostgreSQL)
Index only the rows that matter. Dramatically smaller, faster to maintain.

```sql
-- Only index active orders (skip the 90% that are completed/archived)
CREATE INDEX idx_orders_active ON orders(user_id, created_at)
  WHERE status IN ('pending', 'processing');

-- Only index non-deleted records
CREATE INDEX idx_users_active ON users(email)
  WHERE deleted_at IS NULL;
```

### Covering Indexes (Index-Only Scans)
Include extra columns so the query never touches the table heap.

```sql
-- PostgreSQL: INCLUDE clause
CREATE INDEX idx_orders_user_covering ON orders(user_id)
  INCLUDE (status, total, created_at);

-- Now this query can be served entirely from the index:
SELECT status, total, created_at FROM orders WHERE user_id = 123;
```

### Expression Indexes
Index a computed value.

```sql
-- Case-insensitive email lookup
CREATE INDEX idx_users_email_lower ON users(lower(email));

-- Extract from JSONB
CREATE INDEX idx_products_brand ON products((attributes->>'brand'));

-- Date part extraction
CREATE INDEX idx_orders_month ON orders(date_trunc('month', created_at));
```

---

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
|---|---|---|
| No index on foreign keys | Every JOIN does a full table scan on the child | Always index FK columns |
| Over-indexing | Slows down writes, wastes storage, confuses optimizer | Only index columns that appear in WHERE/ORDER BY/JOIN of real queries |
| Wrong composite order | Index exists but query can't use it | Match column order to query patterns |
| Indexing low-cardinality columns alone | Boolean or status columns with 3 values — index barely helps | Combine with a selective column in a composite index, or use partial index |
| Function on indexed column in WHERE | `WHERE UPPER(email) = 'FOO'` — can't use index on email | Use expression index, or normalize data on write |

---

## Query Analysis with EXPLAIN

Always verify your indexes work. Don't guess.

```sql
EXPLAIN ANALYZE SELECT * FROM orders WHERE user_id = 123 AND status = 'pending';
```

**What to look for:**

| Indicator | Good | Bad |
|---|---|---|
| Scan type | Index Scan, Index Only Scan | Seq Scan (on large table) |
| Rows estimate | Close to actual rows | Wildly off (stale statistics) |
| Execution time | Meets latency target | 10x slower than expected |
| Buffers | Shared hit (in cache) | Shared read (disk I/O) |

If `Seq Scan` on a large table: check that the index exists, that the WHERE clause matches
the index prefix, and that the planner's row estimate justifies using the index (very small
tables may legitimately seq scan).

```sql
-- Force statistics refresh if estimates are off
ANALYZE orders;
```