/*
=======================================================================================================
Script Purpose:
    This script checks whether the data is loaded into the tables correclty or not and explores it
=======================================================================================================
*/

USE DataWarehouse;
-- bronze.crm_cust_info

-- check for NULLS or DUPLICATES on PRIMARY KEY
-- Expectations: No Results

SELECT
	cst_id,
	COUNT(*)
FROM bronze.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL ;

-- check for Unwanted spaces in text columns
-- Expectations: No Results

SELECT
	cst_key
FROM bronze.crm_cust_info
WHERE cst_key != TRIM(cst_key); -- clear

SELECT
	cst_firstname
FROM bronze.crm_cust_info
WHERE cst_firstname != TRIM(cst_firstname); -- need transformation

SELECT
	cst_lastname
FROM bronze.crm_cust_info
WHERE cst_lastname != TRIM(cst_lastname); -- need transformation

SELECT
	cst_marital_status
FROM bronze.crm_cust_info
WHERE cst_marital_status != TRIM(cst_marital_status); -- clear

SELECT
	cst_gndr
FROM bronze.crm_cust_info
WHERE cst_gndr != TRIM(cst_gndr); -- clear

-- Data Stabdardization & consistency
SELECT DISTINCT(cst_gndr)
FROM bronze.crm_cust_info; -- F, M and NULL

SELECT DISTINCT(cst_marital_status)
FROM bronze.crm_cust_info; -- S, M and NULL

-- bronze.crm_prd_info

-- check for NULLS or DUPLICATES on PRIMARY KEY
-- Expectations: No Results

SELECT
	prd_id,
	COUNT(*)
FROM bronze.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1 OR prd_id IS NULL ; -- clear

-- check for Unwanted spaces in text columns
-- Expectations: No Results

SELECT
	prd_key
FROM bronze.crm_prd_info
WHERE prd_key != TRIM(prd_key); -- clear

SELECT
	prd_nm
FROM bronze.crm_prd_info
WHERE prd_nm != TRIM(prd_nm); -- clear

SELECT
	prd_line
FROM bronze.crm_prd_info
WHERE prd_line != TRIM(prd_line); -- clear

-- checking whethre the cost in null or negative
SELECT
	prd_cost
FROM bronze.crm_prd_info
WHERE prd_cost < 0 OR prd_cost IS NULL;

-- Data Stabdardization & consistency
SELECT DISTINCT(prd_line)
FROM bronze.crm_prd_info; -- M, R, S, T and NULL

-- check for invalid date orders

SELECT *
FROM bronze.crm_prd_info
WHERE prd_end_dt < prd_start_dt; -- need transformation


-- bronze crm_sales_details
SELECT * FROM bronze.crm_sales_details;

-- Checking for empty spaces
SELECT * FROM bronze.crm_sales_details
WHERE TRIM(sls_ord_num) != sls_ord_num;

-- Checking whether sls_prd_key can be used for data modelling 
SELECT * FROM bronze.crm_sales_details
WHERE sls_prd_key NOT IN (SELECT prd_key FROM silver.crm_prd_info);

-- Checking whether sls_cust_id can be used for data modelling 
SELECT * FROM bronze.crm_sales_details
WHERE sls_cust_id NOT IN (SELECT cst_id FROM silver.crm_cust_info);

-- Checking for invalid dates

SELECT
	NULLIF(sls_order_dt,0) AS sls_order_dt
FROM bronze.crm_sales_details
WHERE sls_order_dt < 0
OR LEN(sls_order_dt) != 8
OR sls_order_dt > 20500101
OR sls_order_dt < 19000101;

-- Check for orderdt is greater than shipping or due date
SELECT * FROM bronze.crm_sales_details
WHERE sls_order_dt > sls_ship_dt OR sls_order_dt > sls_due_dt;

-- Checking Sales, quantity and price are as per rules or not
SELECT
	sls_sales,
	sls_quantity,
	sls_price
FROM bronze.crm_sales_details
WHERE sls_sales != sls_price * sls_quantity
OR sls_sales IS NULL OR sls_price IS NULL OR sls_quantity IS NULL
OR sls_sales <= 0 OR sls_price <= 0 OR sls_quantity <= 0;

SELECT
	sls_sales,
	sls_quantity,
	sls_price
FROM bronze.crm_sales_details
ORDER BY sls_quantity DESC;


-- bronze.erp_cust_az12

SELECT * FROM bronze.erp_cust_az12;

-- Checking whether cid is fit to connect with silver.crm_cust_info

SELECT * FROM silver.crm_cust_info;

SELECT
	CASE
		WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
		ELSE cid
	END AS cid
FROM bronze.erp_cust_az12
WHERE cid NOT IN (SELECT DISTINCT(cid) FROM silver.crm_cust_info) -- clears that cid needs transformation and can connect


SELECT
	DISTINCT bdate
FROM bronze.erp_cust_az12
WHERE bdate > GETDATE();

SELECT 
	DISTINCT gen
FROM bronze.erp_cust_az12;


-- bronze.erp_loc_a101

SELECT * FROM bronze.erp_loc_a101;

-- checking cid is suitable for data connection

SELECT cid FROM bronze.erp_loc_a101; -- need tranformation AW00011000 to AW-00011000

SELECT cst_key FROM silver.crm_cust_info;

SELECT 
	REPLACE(cid, '-', '') AS cid
FROM bronze.erp_loc_a101
WHERE REPLACE(cid, '-', '') NOT IN (SELECT cst_key FROM silver.crm_cust_info)

-- Data Standardization & Consistency
SELECT
	DISTINCT cntry
FROM bronze.erp_loc_a101;


-- bronze.erp_px_cat_g1v2
SELECT * FROM bronze.erp_px_cat_g1v2;

-- Check for unwanted spaces
SELECT * FROM bronze.erp_px_cat_g1v2
WHERE id != TRIM(id) OR cat != TRIM(cat) OR subcat != TRIM(subcat) OR maintenance != TRIM(maintenance);

-- Checking whether id is used for connection or not

SELECT id FROM bronze.erp_px_cat_g1v2;

SELECT prd_cat_id FROM silver.crm_prd_info;

-- Normalization and Standardization
SELECT DISTINCT cat FROM bronze.erp_px_cat_g1v2;

SELECT DISTINCT subcat FROM bronze.erp_px_cat_g1v2;

SELECT DISTINCT maintenance FROM bronze.erp_px_cat_g1v2;