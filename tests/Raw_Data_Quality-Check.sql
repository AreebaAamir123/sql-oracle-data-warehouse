/* =====================================================================
   Data Quality Checks For Addind Data To Silver
   =====================================================================
*/


/* ---------------------------------------------------------------------
   TABLE 1: crm_cust_info
   --------------------------------------------------------------------- */

-- CHECK 1.1 — Duplicate customer IDs

SELECT cst_id, COUNT(*) AS duplicate_count
FROM bronze.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

-- CHECK 1.2 — NULL primary keys

SELECT COUNT(*) AS null_ids
FROM bronze.crm_cust_info
WHERE cst_id IS NULL;

-- CHECK 1.3 — Unwanted leading/trailing spaces in name fields

SELECT cst_id, cst_firstname, cst_lastname
FROM bronze.crm_cust_info
WHERE cst_firstname != TRIM(cst_firstname)
   OR cst_lastname  != TRIM(cst_lastname)
FETCH FIRST 20 ROWS ONLY;

-- CHECK 1.4 — Distinct values in cst_marital_status and cst_gndr

SELECT 'marital_status' AS column_name, cst_marital_status AS value, COUNT(*) AS cnt
FROM bronze.crm_cust_info
GROUP BY cst_marital_status
UNION ALL
SELECT 'gender', cst_gndr, COUNT(*)
FROM bronze.crm_cust_info
GROUP BY cst_gndr
ORDER BY 1, 2;


/* ---------------------------------------------------------------------
   TABLE 2: crm_prd_info
   --------------------------------------------------------------------- */

-- CHECK 2.1 — NULL or negative product cost

SELECT prd_id, prd_cost
FROM bronze.crm_prd_info
WHERE prd_cost IS NULL OR prd_cost < 0;

-- CHECK 2.2 — Products where end date is BEFORE start date

SELECT prd_id, prd_start_dt, prd_end_dt
FROM bronze.crm_prd_info
WHERE prd_end_dt IS NOT NULL
  AND prd_end_dt < prd_start_dt;

-- CHECK 2.3 — Overlapping date ranges for the same product

SELECT prd_id, prd_key, prd_start_dt, prd_end_dt,
       LEAD(prd_start_dt) OVER (
           PARTITION BY prd_key
           ORDER BY prd_start_dt
       ) AS next_start_dt
FROM bronze.crm_prd_info
WHERE prd_end_dt IS NOT NULL
  AND prd_end_dt > LEAD(prd_start_dt) OVER (
           PARTITION BY prd_key
           ORDER BY prd_start_dt
       ) - 1;

-- CHECK 2.4 — Unwanted spaces in product name

SELECT prd_id, prd_nm
FROM bronze.crm_prd_info
WHERE prd_nm != TRIM(prd_nm);

-- CHECK 2.5 — Distinct values in prd_line

SELECT prd_line, COUNT(*) AS cnt
FROM bronze.crm_prd_info
GROUP BY prd_line
ORDER BY prd_line;


/* ---------------------------------------------------------------------
   TABLE 3: crm_sales_details
   --------------------------------------------------------------------- */

-- CHECK 3.1 — Invalid order/ship/due dates

SELECT COUNT(*) AS invalid_order_dt
FROM bronze.crm_sales_details
WHERE sls_order_dt = 0
   OR LENGTH(TO_CHAR(sls_order_dt)) != 8;

SELECT COUNT(*) AS invalid_ship_dt
FROM bronze.crm_sales_details
WHERE sls_ship_dt = 0
   OR LENGTH(TO_CHAR(sls_ship_dt)) != 8;

SELECT COUNT(*) AS invalid_due_dt
FROM bronze.crm_sales_details
WHERE sls_due_dt = 0
   OR LENGTH(TO_CHAR(sls_due_dt)) != 8;

-- CHECK 3.2 — Sales, quantity, or price that are NULL, zero, or negative .These break the "sales = quantity × price" rule.
SELECT COUNT(*) AS bad_sales
FROM bronze.crm_sales_details
WHERE sls_sales IS NULL OR sls_sales <= 0;

SELECT COUNT(*) AS bad_quantity
FROM bronze.crm_sales_details
WHERE sls_quantity IS NULL OR sls_quantity <= 0;

SELECT COUNT(*) AS bad_price
FROM bronze.crm_sales_details
WHERE sls_price IS NULL OR sls_price <= 0;

-- CHECK 3.3 — Rows where sales ≠ quantity × |price|

SELECT sls_ord_num, sls_sales, sls_quantity, sls_price
FROM bronze.crm_sales_details
WHERE sls_sales != sls_quantity * ABS(sls_price)
FETCH FIRST 20 ROWS ONLY;

-- CHECK 3.4 — Ship date before order date (impossible)

SELECT sls_ord_num, sls_order_dt, sls_ship_dt
FROM bronze.crm_sales_details
WHERE TO_DATE(TO_CHAR(sls_order_dt), 'YYYYMMDD')
    > TO_DATE(TO_CHAR(sls_ship_dt),  'YYYYMMDD');


/* ---------------------------------------------------------------------
   TABLE 4: erp_cust_az12
   --------------------------------------------------------------------- */

-- CHECK 4.1 — CID values that don't start with the expected prefix

SELECT COUNT(*) AS non_nas_cids
FROM bronze.erp_cust_az12
WHERE CID NOT LIKE 'NAS%';

-- CHECK 4.2 — Birthdates in the future (impossible) or before 1920

SELECT cid, bdate
FROM bronze.erp_cust_az12
WHERE bdate > SYSDATE
   OR bdate < DATE '1920-01-01';

-- CHECK 4.3 — Distinct values in GEN (gender code)

SELECT gen, COUNT(*) AS cnt
FROM bronze.erp_cust_az12
GROUP BY gen
ORDER BY gen;


/* ---------------------------------------------------------------------
   TABLE 5: erp_loc_a101
   --------------------------------------------------------------------- */

-- CHECK 5.1 — CIDs containing dashes (need to be stripped in Silver)

SELECT COUNT(*) AS cids_with_dashes
FROM bronze.erp_loc_a101
WHERE CID LIKE '%-%';

-- CHECK 5.2 — Distinct country values

SELECT cntry, COUNT(*) AS cnt
FROM bronze.erp_loc_a101
GROUP BY cntry
ORDER BY cnt DESC;

-- CHECK 5.3 — NULL or empty country codes

SELECT COUNT(*) AS null_or_empty_country
FROM bronze.erp_loc_a101
WHERE cntry IS NULL OR TRIM(cntry) = '';


/* ---------------------------------------------------------------------
   TABLE 6: erp_px_cat_g1v2
   --------------------------------------------------------------------- */

-- CHECK 6.1 — NULLs in any of the four columns

SELECT
    SUM(CASE WHEN ID          IS NULL THEN 1 ELSE 0 END) AS null_id,
    SUM(CASE WHEN CAT         IS NULL THEN 1 ELSE 0 END) AS null_cat,
    SUM(CASE WHEN SUBCAT      IS NULL THEN 1 ELSE 0 END) AS null_subcat,
    SUM(CASE WHEN MAINTENANCE IS NULL THEN 1 ELSE 0 END) AS null_maintenance
FROM bronze.erp_px_cat_g1v2;

-- CHECK 6.2 — Distinct maintenance values

SELECT maintenance, COUNT(*) AS cnt
FROM bronze.erp_px_cat_g1v2
GROUP BY maintenance
ORDER BY maintenance;


/
