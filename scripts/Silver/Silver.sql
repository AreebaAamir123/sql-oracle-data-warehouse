/* =====================================================================
   3: SILVER LAYER — LOAD AND CLEAN STORED PROCEDURE
   =====================================================================
   WHAT THIS DOES (in plain English):
   - Creates one stored procedure called silver.load_silver.
   - When executed, this procedure:
       1. Empties each silver table (TRUNCATE) so it can be reloaded.
       2. Reads from the matching bronze table.
       3. Cleans the data:
            - trims extra spaces,
            - replaces codes with friendly names (M → Male),
            - removes duplicate customers,
            - converts numeric "dates" into real DATE values,
            - fixes negative prices,
            - recomputes sales when the numbers don't add up.
       4. Inserts the cleaned rows into silver.
       5. Commits everything at the end.
   - If anything fails, the procedure rolls back and prints a friendly
     message, then re-raises the error.

   WHY A PROCEDURE:
   - One command reruns the entire Silver build.
   - Easy to schedule, version, and test.
   - Keeps the transformation logic in one place.

MAKE SURE TO MAKE THESE CHANGES IF YOU MODIFIED THE TABLE STRUCTURE ( SPLIT COL, CHANGED DATA TYPES)

- Run as silver user, before running the procedure:
ALTER TABLE silver.crm_prd_info ADD (cat_id VARCHAR2(10));
ALTER TABLE silver.crm_sales_details MODIFY (sls_order_dt DATE);
ALTER TABLE silver.crm_sales_details MODIFY (sls_ship_dt DATE);
ALTER TABLE silver.crm_sales_details MODIFY (sls_due_dt DATE);
 ===================================================================== */


CREATE OR REPLACE PROCEDURE silver.load_silver
AS
BEGIN
    DBMS_OUTPUT.PUT_LINE('Silver load started at '
        || TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS'));
--=======================================================================================
--==============================TABLE silver.crm_cust_info=====================================
--========================================================================================
    EXECUTE IMMEDIATE 'TRUNCATE TABLE silver.crm_cust_info';
    INSERT INTO silver.crm_cust_info (
        cst_id, cst_key, cst_firstname, cst_lastname,
        cst_marital_status, cst_gndr, cst_create_date
    )
    SELECT cst_id, cst_key,
           TRIM(cst_firstname), TRIM(cst_lastname),
           CASE WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
                WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
                ELSE 'n/a' END,
           CASE WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
                WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
                ELSE 'n/a' END,
           cst_create_date
    FROM (
        SELECT cst_id, cst_key, cst_firstname, cst_lastname,
               cst_marital_status, cst_gndr, cst_create_date,
               ROW_NUMBER() OVER (
                   PARTITION BY cst_id
                   ORDER BY cst_create_date DESC, cst_key DESC
               ) AS flag_last
        FROM bronze.crm_cust_info
        WHERE cst_id IS NOT NULL
    ) t
    WHERE flag_last = 1;
    DBMS_OUTPUT.PUT_LINE('  crm_cust_info loaded: ' || SQL%ROWCOUNT || ' rows');
--=======================================================================================
--==============================TABLE silver.crm_prd_info=====================================
--========================================================================================
    EXECUTE IMMEDIATE 'TRUNCATE TABLE silver.crm_prd_info';
    INSERT INTO silver.crm_prd_info (
        prd_id, cat_id, prd_key, prd_nm,
        prd_cost, prd_line, prd_start_dt, prd_end_dt
    )
    SELECT prd_id,
           REPLACE(SUBSTR(prd_key, 1, 5), '-', '_'),
           SUBSTR(prd_key, 7, LENGTH(prd_key)),
           prd_nm,
           NVL(prd_cost, 0),
           CASE UPPER(TRIM(prd_line))
                WHEN 'M' THEN 'Mountain'
                WHEN 'R' THEN 'Road'
                WHEN 'S' THEN 'Other Sales'
                WHEN 'T' THEN 'Touring'
                ELSE 'n/a' END,
           prd_start_dt,
           LEAD(prd_start_dt) OVER (
               PARTITION BY prd_key
               ORDER BY prd_start_dt
           ) - 1
    FROM bronze.crm_prd_info;
    DBMS_OUTPUT.PUT_LINE('  crm_prd_info loaded: ' || SQL%ROWCOUNT || ' rows');
--=======================================================================================
--==============================TABLE silver.crm_sales_details=====================================
--========================================================================================
    EXECUTE IMMEDIATE 'TRUNCATE TABLE silver.crm_sales_details';
    INSERT INTO silver.crm_sales_details (
        sls_ord_num, sls_prd_key, sls_cust_id,
        sls_order_dt, sls_ship_dt, sls_due_dt,
        sls_sales, sls_quantity, sls_price
    )
    SELECT sls_ord_num, sls_prd_key, sls_cust_id,
           CASE WHEN sls_order_dt = 0 OR LENGTH(TO_CHAR(sls_order_dt)) != 8 THEN NULL
                ELSE TO_DATE(TO_CHAR(sls_order_dt), 'YYYYMMDD') END,
           CASE WHEN sls_ship_dt = 0 OR LENGTH(TO_CHAR(sls_ship_dt)) != 8 THEN NULL
                ELSE TO_DATE(TO_CHAR(sls_ship_dt), 'YYYYMMDD') END,
           CASE WHEN sls_due_dt = 0 OR LENGTH(TO_CHAR(sls_due_dt)) != 8 THEN NULL
                ELSE TO_DATE(TO_CHAR(sls_due_dt), 'YYYYMMDD') END,
           CASE WHEN sls_sales IS NULL OR sls_sales <= 0
                  OR sls_sales != sls_quantity * ABS(sls_price)
                THEN sls_quantity * ABS(sls_price)
                ELSE sls_sales END,
           sls_quantity,
           CASE WHEN sls_price IS NULL OR sls_price <= 0
                THEN sls_sales / NULLIF(sls_quantity, 0)
                ELSE sls_price END
    FROM bronze.crm_sales_details;
    DBMS_OUTPUT.PUT_LINE('  crm_sales_details loaded: ' || SQL%ROWCOUNT || ' rows');
--=======================================================================================
--==============================TABLE silver.erp_cust_az12=====================================
--========================================================================================
    EXECUTE IMMEDIATE 'TRUNCATE TABLE silver.erp_cust_az12';
    INSERT INTO silver.erp_cust_az12 (CID, BDATE, GEN)
    SELECT CASE WHEN CID LIKE 'NAS%' THEN SUBSTR(CID, 4, LENGTH(CID))
                ELSE CID END,
           CASE WHEN BDATE > SYSDATE THEN NULL ELSE BDATE END,
           CASE WHEN UPPER(TRIM(GEN)) IN ('F', 'FEMALE') THEN 'Female'
                WHEN UPPER(TRIM(GEN)) IN ('M', 'MALE')   THEN 'Male'
                ELSE 'n/a' END
    FROM bronze.erp_cust_az12;
    DBMS_OUTPUT.PUT_LINE('  erp_cust_az12 loaded: ' || SQL%ROWCOUNT || ' rows');
--=======================================================================================
--==============================TABLE silver.erp_loc_a101=====================================
--========================================================================================
    EXECUTE IMMEDIATE 'TRUNCATE TABLE silver.erp_loc_a101';
    INSERT INTO silver.erp_loc_a101 (CID, CNTRY)
    SELECT REPLACE(CID, '-', ''),
           CASE WHEN TRIM(cntry) = 'DE' THEN 'Germany'
                WHEN TRIM(cntry) IN ('US', 'USA') THEN 'United States'
                WHEN TRIM(cntry) IS NULL OR TRIM(cntry) = '' THEN 'n/a'
                ELSE TRIM(cntry) END
    FROM bronze.erp_loc_a101;
    DBMS_OUTPUT.PUT_LINE('  erp_loc_a101 loaded: ' || SQL%ROWCOUNT || ' rows');
--=======================================================================================
--==============================TABLE silver.erp_px_cat_g1v2=====================================
--========================================================================================
    EXECUTE IMMEDIATE 'TRUNCATE TABLE silver.erp_px_cat_g1v2';
    INSERT INTO silver.erp_px_cat_g1v2 (ID, CAT, SUBCAT, MAINTENANCE)
    SELECT ID, CAT, SUBCAT, MAINTENANCE
    FROM bronze.erp_px_cat_g1v2;
    DBMS_OUTPUT.PUT_LINE('  erp_px_cat_g1v2 loaded: ' || SQL%ROWCOUNT || ' rows');

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Silver load completed successfully at '
        || TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS'));
--=======================================================================================
--==============================CATCH-ERROR==============================================
--========================================================================================
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error occurred while loading Silver layer.');
        RAISE;
END;
/
--=======================================================================================
--==============================RUN-STORED-PROCEDURE=====================================
--========================================================================================
--BEGIN
 --   silver.load_silver;
--END;
--/
