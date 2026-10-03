/* =====================================================================
   2: BRONZE LAYER — TABLE CREATION AND RAW DATA LOAD
   =====================================================================
   WHAT THIS DOES :
   - Creates the six raw tables in the bronze schema.
   - Truncates each table first, so this script can be re-run
     safely without producing duplicate rows.
   - Data is loaded MANUALLY using SQL Developer's "Import Data"
     wizard .
   ===================================================================== */

-- ---------------------------------------------------------------------
-- crm_cust_info  ← source: source_crm/cust_info.csv
-- Customer master data from the CRM system.
-- ---------------------------------------------------------------------
TRUNCATE TABLE bronze.crm_cust_info;

CREATE TABLE bronze.crm_cust_info (
    cst_id              NUMBER,
    cst_key             VARCHAR2(50),
    cst_firstname       VARCHAR2(50),
    cst_lastname        VARCHAR2(50),
    cst_marital_status  VARCHAR2(50),    
    cst_gndr            VARCHAR2(50),
    cst_create_date     DATE DEFAULT SYSDATE
);

-- ---------------------------------------------------------------------
-- crm_prd_info  ← source: source_crm/prd_info.csv
-- Product master data. prd_key encodes a category prefix.
-- ---------------------------------------------------------------------
TRUNCATE TABLE bronze.crm_prd_info;

CREATE TABLE bronze.crm_prd_info (
    prd_id        NUMBER,
    prd_key       VARCHAR2(50),
    prd_nm        VARCHAR2(100),
    prd_cost      NUMBER,
    prd_line      VARCHAR2(50),
    prd_start_dt  DATE,
    prd_end_dt    DATE
);

-- ---------------------------------------------------------------------
-- crm_sales_details  ← source: source_crm/sales_details.csv
-- Sales transactions. Date columns arrive as 8-digit numbers
-- (e.g. 20101229). They'll be converted to real dates in Silver.
-- ---------------------------------------------------------------------
TRUNCATE TABLE bronze.crm_sales_details;

CREATE TABLE bronze.crm_sales_details (
    sls_ord_num   VARCHAR2(50),
    sls_prd_key   VARCHAR2(50),
    sls_cust_id   NUMBER,
    sls_order_dt  NUMBER,
    sls_ship_dt   NUMBER,
    sls_due_dt    NUMBER,
    sls_sales     NUMBER,
    sls_quantity  NUMBER,
    sls_price     NUMBER
);

-- ---------------------------------------------------------------------
-- erp_loc_a101  ← source: source_erp/LOC_A101.csv
-- Customer country/location lookup from the ERP system.
-- ---------------------------------------------------------------------
TRUNCATE TABLE bronze.erp_loc_a101;

CREATE TABLE bronze.erp_loc_a101 (
    cid    VARCHAR2(50),
    cntry  VARCHAR2(50)
);

-- ---------------------------------------------------------------------
-- erp_cust_az12  ← source: source_erp/CUST_AZ12.csv
-- Additional customer info (birthdate, gender) from ERP.
-- ---------------------------------------------------------------------
TRUNCATE TABLE bronze.erp_cust_az12;

CREATE TABLE bronze.erp_cust_az12 (
    cid    VARCHAR2(50),
    bdate  DATE,
    gen    VARCHAR2(50)
);

-- ---------------------------------------------------------------------
-- erp_px_cat_g1v2  ← source: source_erp/PX_CAT_G1V2.csv
-- Product category hierarchy (category → subcategory → maintenance).
-- ---------------------------------------------------------------------
TRUNCATE TABLE bronze.erp_px_cat_g1v2;

CREATE TABLE bronze.erp_px_cat_g1v2 (
    id           VARCHAR2(50),
    cat          VARCHAR2(50),
    subcat       VARCHAR2(50),
    maintenance  VARCHAR2(50)
);

COMMIT;

/
