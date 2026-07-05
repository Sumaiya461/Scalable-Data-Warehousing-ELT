/*
===============================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
===============================================================================
Script Purpose:
    This stored procedure performs the ETL (Extract, Transform, Load) process to 
    populate the 'silver' schema tables from the 'bronze' schema.
	Actions Performed:
		- Truncates Silver tables.
		- Inserts transformed and cleansed data from Bronze into Silver tables.
		
Parameters:
    None. 
	  This stored procedure does not accept any parameters or return any values.

Usage Example:
    EXEC Silver.load_silver;
===============================================================================
*/
CREATE OR ALTER PROCEDURE silver.silver_load AS
BEGIN
	DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME
	BEGIN TRY
		SET @batch_start_time = GETDATE()
		PRINT('=======================================================================');
		PRINT('Loading data into silver layer');
		PRINT('=======================================================================');

		SET @start_time = GETDATE();

		-- Transforming and Loading data into silver.crm_cust_info

		PRINT '>> Truncating silver.crm_cust_info'
		TRUNCATE TABLE silver.crm_cust_info;
		PRINT '>> Writing Data into silver.crm_cust_info'
		INSERT INTO silver.crm_cust_info (
			cst_id,
			cst_key,
			cst_firstname,
			cst_lastname,
			cst_marital_status,
			cst_gndr,
			cst_create_date
		)
		SELECT
			cst_id,
			cst_key,
			TRIM(cst_firstname) AS cst_firstname, -- Removing unwanted spaces
			TRIM(cst_lastname) AS cst_lastname, -- Removing unwanted spaces
			CASE WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
				WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
				ELSE 'n/a'
			END cst_marital_status, -- Normalize maritial status values to readable format
			CASE WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
				WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
				ELSE 'n/a'
			END cst_gndr, -- Normalize gender values to readable format
			cst_create_date
		FROM(
			SELECT
				*,
				ROW_NUMBER() OVER(PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last
			FROM bronze.crm_cust_info
			WHERE cst_id IS NOT NULL
			)t
		WHERE flag_last = 1 ; -- selecting the most recent record per customer (Removing duplicates)
		SET @end_time = GETDATE();
		PRINT('>>> Load durantion: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds')
		PRINT('--------------')

		SET @start_time = GETDATE();

		-- Transforming and Loading data into silver.crm_prd_info

		PRINT '>> Truncating silver.crm_prd_info'
		TRUNCATE TABLE silver.crm_prd_info;
		PRINT '>> Writing Data into silver.crm_prd_info'
		INSERT INTO silver.crm_prd_info (
			prd_id,
			prd_cat_id,
			prd_key,
			prd_nm,
			prd_cost,
			prd_line,
			prd_start_dt,
			prd_end_dt
		)
		SELECT
			prd_id,
			REPLACE(SUBSTRING(prd_key, 1, 5),'-', '_') AS cat_id, -- Selecting substring and replacing - with _ (CO-RF-FR-R92B-58 --> CO_RF)
			SUBSTRING(prd_key, 7, LEN(prd_key)) AS prd_key, -- -- Selecting substring (CO-RF-FR-R92B-58 --> FR-R92B-58)
			prd_nm,
			ISNULL(prd_cost, 0) AS prd_cost, -- Replacing NULL with 0

			CASE UPPER(TRIM(prd_line)) -- Normalization & Standardization
				WHEN 'M' THEN 'Mountain'
				WHEN 'R' THEN 'Road'
				WHEN 'T' THEN 'Touring'
				WHEN 'S' THEN 'Other Sales'
				ELSE 'n/a'
			END AS ped_line, 

			CAST(prd_start_dt AS DATE) AS prd_start_dt, -- Changing data type to Date
			CAST(DATEADD(DAY, -1, LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt)) AS DATE) AS prd_end_dt -- Adding end_date as star_date + 1
		FROM bronze.crm_prd_info;
		SET @end_time = GETDATE();
		PRINT('>>> Load durantion: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds')
		PRINT('--------------')

		SET @start_time = GETDATE();

		-- Transforming and Loading data into silver.crm_sales_details

		PRINT '>> Truncating silver.crm_sales_details'
		TRUNCATE TABLE silver.crm_sales_details;
		PRINT '>> Writing Data into silver.crm_sales_details'
		INSERT INTO silver.crm_sales_details (
			sls_ord_num,
			sls_prd_key,
			sls_cust_id,
			sls_order_dt,
			sls_ship_dt,
			sls_due_dt,
			sls_sales,
			sls_price,
			sls_quantity
			)

		SELECT
			sls_ord_num,
			sls_prd_key,
			sls_cust_id,

			CASE -- Replacing invalid dates with NULL
				WHEN sls_order_dt = 0 OR LEN(sls_order_dt) != 8 THEN NULL
				ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
			END AS sls_order_dt,

			CASE -- Replacing invalid dates with NULL 
				WHEN sls_ship_dt = 0 OR LEN(sls_ship_dt) != 8 THEN NULL
				ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
			END AS sls_ship_dt,

			CASE -- Replacing invalid dates with NULL
				WHEN sls_due_dt = 0 OR LEN(sls_due_dt) != 8 THEN NULL
				ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
			END AS sls_due_dt,

			CASE -- Finding invalid sales and adjusting them
				WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price)
					THEN sls_quantity * ABS(sls_price)
				ELSE sls_sales
			END AS sls_sales,

			CASE -- Finding zero or negative price and adjusting them
				WHEN sls_price IS NULL OR sls_price <= 0 
					THEN sls_sales / NULLIF(sls_quantity,0)
				ELSE sls_price
			END AS sls_price,
	
			sls_quantity
		FROM bronze.crm_sales_details;
		SET @end_time = GETDATE();
		PRINT('>>> Load durantion: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds')
		PRINT('--------------')

		SET @start_time = GETDATE();


		-- Transforming and Loading data into silver.crm_cust_info

		PRINT '>> Truncating silver.erp_cust_az12'
		TRUNCATE TABLE silver.erp_cust_az12;
		PRINT '>> Writing Data into silver.erp_cust_az12'
		INSERT INTO silver.erp_cust_az12 (
			cid,
			bdate,
			gen
		)
		SELECT

			CASE -- Extracting cid (NASAW00011000 --> AW00011000)
				WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
				ELSE cid
			END AS cid,

			CASE -- Filling bdate which are greater than today (in future dates)
				WHEN bdate > GETDATE() THEN NULL
				ELSE bdate
			END AS bdate,

			CASE -- Normalization & Standardization
				WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
				WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
				ELSE 'n/a'
			END AS gen

		FROM bronze.erp_cust_az12;
		SET @end_time = GETDATE();
		PRINT('>>> Load durantion: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds')
		PRINT('--------------')

		SET @start_time = GETDATE();


		-- Transforming and Loading data into silver.crm_cust_info

		PRINT '>> Truncating silver.erp_loc_a101'
		TRUNCATE TABLE silver.erp_loc_a101;
		PRINT '>> Writing Data into silver.erp_loc_a101'
		INSERT INTO silver.erp_loc_a101(
			cid,
			cntry
		)
		SELECT
			REPLACE(cid, '-', '') AS cid, -- Replacting '-' with empty string (AW-00011000 --> AW00011000)
	
			CASE -- Normalization & Standardization
				WHEN TRIM(cntry) = 'DE' THEN 'Germany'
				WHEN TRIM(cntry) IN ('US', 'USA') THEN 'United States'
				WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'n/a'
				ELSE TRIM(cntry)
			END AS cntry

		FROM bronze.erp_loc_a101;
		SET @end_time = GETDATE();
		PRINT('>>> Load durantion: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds')
		PRINT('--------------')

		SET @start_time = GETDATE();


		-- Transforming and Loading data into silver.crm_cust_info

		PRINT '>> Truncating silver.erp_px_cat_g1v2'
		TRUNCATE TABLE silver.erp_px_cat_g1v2;
		PRINT '>> Writing Data into silver.erp_px_cat_g1v2'
		INSERT INTO silver.erp_px_cat_g1v2(
			id,
			cat,
			subcat,
			maintenance
		)
		SELECT
			id,
			cat,
			subcat,
			maintenance
		FROM bronze.erp_px_cat_g1v2;
		SET @end_time = GETDATE();
		PRINT('>>> Load durantion: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds')
		PRINT('--------------')
		SET @batch_end_time = GETDATE();
		PRINT('=======================================================================');
		PRINT('Loading Bronze Layer is completed');
		PRINT('	- Total load durantion: ' + CAST(DATEDIFF(second, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds')
		PRINT('=======================================================================');
	END TRY

	BEGIN CATCH
		PRINT('=======================================================================');
		PRINT('ERROR OCCURED WHILE LOADING BRONZE LAYER');
		PRINT('Error message:' + ERROR_MESSAGE());
		PRINT('Error number:' + CAST(ERROR_NUMBER() AS NVARCHAR));
		PRINT('Error state:' + CAST(ERROR_STATE() AS NVARCHAR));
		PRINT('=======================================================================');
	END CATCH
END

EXEC silver.silver_load;