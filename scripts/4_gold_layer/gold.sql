/*
===============================================================================
DDL Script: Create Gold Views
===============================================================================
Script Purpose:
    This script creates views for the Gold layer in the data warehouse. 
    The Gold layer represents the final dimension and fact tables (Star Schema)

    Each view performs transformations and combines data from the Silver layer 
    to produce a clean, enriched, and business-ready dataset.

Usage:
    - These views can be queried directly for analytics and reporting.
===============================================================================
*/

use DataWarehouse;

-- =============================================================================
-- Create Dimension: gold.dim_customers
-- =============================================================================

IF OBJECT_ID('gold.dim_customers', 'V') IS NOT NULL
	DROP VIEW gold.dim_customers;

GO 

CREATE VIEW gold.dim_customers AS
	SELECT
		ROW_NUMBER() OVER(ORDER BY cc.cst_id) AS customer_key, -- Surrogate key
		cc.cst_id AS customer_id,
		cc.cst_firstname AS first_name,
		cc.cst_lastname AS last_name,
		lo.cntry AS country,
		cc.cst_marital_status AS marital_status,
		CASE
			WHEN cc.cst_gndr != 'n/a' THEN cc.cst_gndr -- CRM is the master for Gender Info.
			ELSE COALESCE(az.gen, 'n/a')
		END AS gender,
		az.bdate AS birth_date,
		cc.cst_create_date AS create_date
	FROM silver.crm_cust_info AS cc
	LEFT JOIN silver.erp_cust_az12 AS az
	ON az.cid = cc.cst_key
	LEFT JOIN silver.erp_loc_a101 AS lo
	ON lo.cid = cc.cst_key
;

GO

-- =============================================================================
-- Create Dimension: gold.dim_products
-- =============================================================================

IF OBJECT_ID('gold.dim_products','V') IS NOT NULL
	DROP VIEW gold.dim_products;
GO

CREATE VIEW gold.dim_products AS
	SELECT
		ROW_NUMBER() OVER(ORDER BY pf.prd_start_dt, pf.prd_id) AS product_key, -- Surrogate key
		pf.prd_id AS product_id,
		pf.prd_key AS product_number,
		pf.prd_nm AS product_name,
		pf.prd_cat_id AS category_id,

		CASE
			WHEN px.cat IS NOT NULL THEN px.cat
			ELSE 'n/a'
		END AS category,

		CASE
			WHEN px.subcat IS NOT NULL THEN px.subcat
			ELSE 'n/a'
		END AS subcategory,

		CASE 
			WHEN px.maintenance IS NOT NULL THEN px.maintenance
			ELSE 'n/a'
		END AS maintenance,

		pf.prd_cost AS cost,
		pf.prd_line AS product_line,
		pf.prd_start_dt AS start_date
	FROM silver.crm_prd_info AS pf
	LEFT JOIN silver.erp_px_cat_g1v2 AS px
	ON px.id = pf.prd_cat_id
	WHERE pf.prd_end_dt IS NULL -- Filter out all historical data
; 

GO

-- =============================================================================
-- Create Fact Table: gold.fact_sales
-- =============================================================================

IF OBJECT_ID('gold.fact_sales', 'V') IS NOT NULL
	DROP VIEW gold.fact_sales;

GO

CREATE VIEW gold.fact_sales AS
	SELECT
		sa.sls_ord_num AS order_number,
		pr.product_key,
		cu.customer_key,
		sa.sls_order_dt AS order_date,
		sa.sls_ship_dt AS shipping_date,
		sa.sls_due_dt AS due_date,
		sa.sls_sales AS sales_amount,
		sa.sls_quantity AS quantity,
		sa.sls_price AS price
	FROM silver.crm_sales_details AS sa
	LEFT JOIN gold.dim_products AS pr
	ON sa.sls_prd_key = pr.product_number
	LEFT JOIN gold.dim_customers AS cu
	ON sa.sls_cust_id = cu.customer_id
;

GO

SELECT * FROM gold.dim_customers;
SELECT * FROM gold.dim_products;
SELECT * FROM gold.fact_sales;

