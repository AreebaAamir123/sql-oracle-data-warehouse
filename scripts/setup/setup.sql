/* =====================================================================
    1: SETUP DATABASE USERS  The Medallion Architecture (Bronze → Silver → Gold).
   =====================================================================
   WHAT THIS DOES :
   - Creates three separate "layers" in the database, one for each
     stage of the data pipeline: bronze, silver, and gold.
   - Each layer is a database user with its own password.
   - Grants each user the basic permissions to log in and create tables.
   ===================================================================== */

-- Switch to the pluggable database (required in Oracle XE 21c+)
ALTER SESSION SET CONTAINER = XEPDB1;

-- ---------------------------------------------------------------------
-- BRONZE LAYER: raw data, exactly as it came from source systems
-- ---------------------------------------------------------------------
CREATE USER bronze IDENTIFIED BY your_password;
GRANT CONNECT, RESOURCE, UNLIMITED TABLESPACE TO bronze;

-- ---------------------------------------------------------------------
-- SILVER LAYER: cleaned, deduplicated, standardized data
-- ---------------------------------------------------------------------
CREATE USER silver IDENTIFIED BY your_password;
GRANT CONNECT, RESOURCE, UNLIMITED TABLESPACE TO silver;

-- ---------------------------------------------------------------------
-- GOLD LAYER: business-ready star schema for reporting
-- ---------------------------------------------------------------------
CREATE USER gold IDENTIFIED BY your_password;
GRANT CONNECT, RESOURCE, UNLIMITED TABLESPACE TO gold;

-- ---------------------------------------------------------------------

