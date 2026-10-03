/* =====================================================================
   SCRIPT 7: GOLD LAYER — STAR SCHEMA VALIDATION
   ===================================================================== */

-- ---------------------------------------------------------------------
-- REFERENTIAL INTEGRITY — fact keys must resolve to dimensions
-- ---------------------------------------------------------------------

-- Check 1: every fact row has a matching customer
SELECT COUNT(*) AS orphan_customers
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c ON c.customer_key = f.customer_key
WHERE c.customer_key IS NULL;

-- Check 2: every fact row has a matching product
SELECT COUNT(*) AS orphan_products
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p ON p.product_key = f.product_key
WHERE p.product_key IS NULL;

-- ---------------------------------------------------------------------
-- SURROGATE KEY INTEGRITY — keys must be unique and non-null
-- ---------------------------------------------------------------------

-- Check 3: customer_key is unique
SELECT customer_key, COUNT(*) AS cnt
FROM gold.dim_customers
GROUP BY customer_key
HAVING COUNT(*) > 1;

-- Check 4: product_key is unique
SELECT product_key, COUNT(*) AS cnt
FROM gold.dim_products
GROUP BY product_key
HAVING COUNT(*) > 1;

-- Check 5: no NULLs in dimension keys
SELECT COUNT(*) AS null_customer_keys
FROM gold.dim_customers
WHERE customer_key IS NULL;

SELECT COUNT(*) AS null_product_keys
FROM gold.dim_products
WHERE product_key IS NULL;

-- ---------------------------------------------------------------------
-- BUSINESS LOGIC — gold should reflect silver
-- ---------------------------------------------------------------------

-- Check 6: fact_sales row count should equal silver.crm_sales_details
SELECT
    (SELECT COUNT(*) FROM silver.crm_sales_details) AS silver_sales,
    (SELECT COUNT(*) FROM gold.fact_sales)          AS gold_sales;
-- Should match

-- Check 7: dim_products count should equal silver's current products
SELECT
    (SELECT COUNT(*) FROM silver.crm_prd_info WHERE prd_end_dt IS NULL) AS silver_current,
    (SELECT COUNT(*) FROM gold.dim_products)                             AS gold_products;
-- Should match
