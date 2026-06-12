# Normalization Reference

## Table of Contents
1. Normal Forms (1NF → BCNF)
2. When to Denormalize
3. Denormalization Strategies

---

## Normal Forms

### First Normal Form (1NF)
**Rule:** Atomic values only. No repeating groups, no comma-separated lists, no arrays-as-strings.

**Violation:**
```sql
-- BAD: Multiple values crammed into one column
CREATE TABLE orders (
  id INT PRIMARY KEY,
  product_ids VARCHAR(255)  -- '101,102,103' — can't query, can't FK, can't index
);
```

**Fix:**
```sql
CREATE TABLE orders (
  id INT PRIMARY KEY,
  customer_id INT NOT NULL
);

CREATE TABLE order_items (
  id INT PRIMARY KEY,
  order_id INT NOT NULL REFERENCES orders(id),
  product_id INT NOT NULL REFERENCES products(id),
  quantity INT NOT NULL DEFAULT 1
);
```

**Exception (PostgreSQL):** Native array or JSONB columns can hold multi-valued data when
the values are truly self-contained (e.g., tags, labels) and you don't need to JOIN on them.
But if you find yourself writing `WHERE 'electronics' = ANY(tags)` frequently, consider a
junction table instead — arrays don't support foreign key constraints.

### Second Normal Form (2NF)
**Rule:** 1NF + every non-key column depends on the *entire* primary key, not just part of it.
Only relevant for composite primary keys.

**Violation:**
```sql
-- BAD: customer_name depends only on customer_id, not on (order_id, product_id)
CREATE TABLE order_items (
  order_id INT,
  product_id INT,
  customer_name VARCHAR(100),  -- Partial dependency!
  quantity INT,
  PRIMARY KEY (order_id, product_id)
);
```

**Fix:** Move customer_name to the customers table where it belongs.

### Third Normal Form (3NF)
**Rule:** 2NF + no transitive dependencies. Every non-key column depends on the key, the
whole key, and nothing but the key.

**Violation:**
```sql
-- BAD: country is determined by postal_code, not directly by the customer
CREATE TABLE customers (
  id INT PRIMARY KEY,
  postal_code VARCHAR(10),
  country VARCHAR(50)  -- Transitive: id → postal_code → country
);
```

**Fix:**
```sql
CREATE TABLE postal_codes (
  code VARCHAR(10) PRIMARY KEY,
  country VARCHAR(50) NOT NULL
);

CREATE TABLE customers (
  id INT PRIMARY KEY,
  postal_code VARCHAR(10) REFERENCES postal_codes(code)
);
```

**Pragmatic note:** Enforcing 3NF for postal codes is often overkill. The real question is:
does this transitive dependency cause *update anomalies* at your scale? If you have 500
customers and postal codes never change, a denormalized country column is fine. If you have
50M rows and countries get reassigned, normalize.

### Boyce-Codd Normal Form (BCNF)
**Rule:** Every determinant is a candidate key. Stricter than 3NF — relevant when you have
overlapping candidate keys.

In practice, most real-world schemas only need to think about BCNF when they have tables with
multiple overlapping unique constraints. If you're not sure, 3NF is sufficient.

---

## When to Denormalize

Normalization optimizes for *write correctness* (no update anomalies). Denormalization
optimizes for *read performance* (fewer JOINs, simpler queries).

**Denormalize when:**
- A read query is on a critical hot path and JOINs are measurably slow
- The denormalized data rarely changes (e.g., caching a user's display_name on a comment)
- You need real-time aggregations that can't wait for materialized view refreshes
- The source of truth is still normalized — denormalized copies are treated as caches

**Don't denormalize when:**
- You haven't measured that the JOIN is actually slow (premature optimization)
- The denormalized data changes frequently (update anomalies will bite you)
- You can solve it with an index or a materialized view instead

---

## Denormalization Strategies

### Pre-computed Aggregates
```sql
-- Add item_count and total directly on orders
ALTER TABLE orders ADD COLUMN item_count INT NOT NULL DEFAULT 0;
ALTER TABLE orders ADD COLUMN total DECIMAL(10,2) NOT NULL DEFAULT 0;

-- Maintain via trigger or application code
-- Source of truth: SUM from order_items
```

### Cached Derived Columns
```sql
-- Store seller's average rating directly on the seller row
ALTER TABLE sellers ADD COLUMN avg_rating DECIMAL(3,2);
ALTER TABLE sellers ADD COLUMN review_count INT DEFAULT 0;

-- Update when reviews change
-- Source of truth: AVG from reviews table
```

### Materialized Views (PostgreSQL)
```sql
CREATE MATERIALIZED VIEW mv_daily_sales AS
SELECT
  date_trunc('day', created_at) AS sale_date,
  COUNT(*) AS order_count,
  SUM(total) AS revenue
FROM orders
WHERE status = 'completed'
GROUP BY 1;

CREATE UNIQUE INDEX idx_mv_daily_sales_date ON mv_daily_sales(sale_date);

-- Refresh on schedule
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_daily_sales;
```