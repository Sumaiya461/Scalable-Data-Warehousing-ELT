/*
================================================================================================
Products Report
================================================================================================
Purpose :
	- This report consolidates key product metrics and behaviors.

Hilights :
	1. Gather essential fields such as product name, category, subcategory and cost.
	2. Segments products by revenue to identify High-Perfromers, Mid-Range and Low-Performers.
	3. Aggregates product level metrics:
		- total orders
		- total sales
		- total quantity sold
		- total customers (unique)
		- lifespan (in months)
	4. Calculate valuable KPIs:
		- recency (months since last sale)
		- average order revenue (AOR)
		- average monthly revenue
================================================================================================
*/

USE DataWarehouse;

IF OBJECT_ID('gold.products_report', 'V') IS NOT NULL
	DROP VIEW gold.products_report

GO

CREATE VIEW gold.products_report AS
	WITH basic_required_features AS (
		/*
		================================================================================================
		Step_1 : Selecting basic reqired features
		================================================================================================
		*/
		SELECT
			p.product_id,
			p.product_key,
			p.product_name,
			p.category,
			p.subcategory,
			f.order_number,
			f.order_date,
			f.customer_key,
			f.sales_amount,
			f.quantity,
			f.price
		FROM gold.fact_sales AS f
		LEFT JOIN gold.dim_products AS p
		ON p.product_key = f.product_key
		WHERE f.order_date	IS NOT NULL
	),
	required_aggregations AS(
		/*
		================================================================================================
		Step_2 : Performing required aggregations
		================================================================================================
		*/
		SELECT
			product_id,
			product_name,
			category,
			subcategory,
			price,
			MAX(order_date) AS last_order_date,
			COUNT(order_number) AS total_orders,
			SUM(sales_amount) AS total_sales,
			SUM(quantity) AS total_quantity_sold,
			COUNT(DISTINCT customer_key) AS total_customers_unique,
			DATEDIFF(MONTH, MIN(order_date), MAX(order_date) ) AS life_span
		FROM basic_required_features
		GROUP BY
			product_id,
			product_name,
			category,
			subcategory,
			price
	)
	/*
	================================================================================================
	Step_3 : Calculating required KPIs and generating report
	================================================================================================
	*/
	SELECT
		product_id,
		product_name,
		category,
		subcategory,
		price,
		last_order_date,
		total_orders,
		total_sales,
		-- Segmenting products based on total_sales
		CASE
			WHEN total_sales > 50000 THEN 'High-Performers'
			WHEN total_sales >= 10000 THEN 'Mid-Range'
			ELSE 'Low-Performers'
		END AS products_segment,
		total_quantity_sold,
		total_customers_unique,
		life_span,
		DATEDIFF(MONTH, last_order_date, GETDATE()) AS recency_in_months,
		-- Average Order Revenue (AOR)
		CASE 
			WHEN total_orders = 0 THEN 0
			ELSE total_sales / total_orders
		END AS average_order_revenue,
		-- Average monthly revenu
		CASE
			WHEN life_span = 0 THEN 0
			ELSE total_sales / life_span
		END AS average_monthly_revenue

	FROM required_aggregations ;

GO

SELECT * FROM gold.products_report