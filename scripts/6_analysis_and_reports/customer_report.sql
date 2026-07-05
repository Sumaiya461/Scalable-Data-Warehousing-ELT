/*
===================================================================================================
Customer Report
===================================================================================================
Purpose :
	- This report consolidates key customer metrics and behaviours

Hilights :
	1. Gather essentail fields such as names, ages and transcation details.
	2. Segments customers into categoreis (VIP, Regular, New) and age groups.
	3. Aggregates customer level metrics
		- total orders
		- total sales
		- total quantity purchased
		- total products
		- lifespan (in months)
	4. Calculates valuable KPIs :
		- recency (months since last order)
		- average order value
		- average monthly spend
===================================================================================================
*/

USE DataWarehouse;

IF OBJECT_ID('gold.customer_reports', 'V') IS NOT NULL
	DROP VIEW gold.customer_reports;

GO

CREATE VIEW gold.customer_reports AS 
	WITH basic_details AS (
	/*
	===================================================================================================
	Step_1 : Selecting basic details
	===================================================================================================
	*/
		SELECT
			c.customer_key,
			c.customer_id,
			CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
			DATEDIFF(YEAR, c.birth_date, GETDATE()) AS age,
			s.order_number,
			s.product_key,
			s.order_date,
			s.sales_amount,
			s.quantity
		FROM gold.fact_sales AS s
		LEFT JOIN gold.dim_customers AS c
		ON c.customer_key = s.customer_key
		WHERE s.order_date IS NOT NULL
	),
	customer_aggregations AS (
	/*
	===================================================================================================
	Step_2 : Performing required aggregations
	===================================================================================================
	*/
		SELECT
				customer_id,
				customer_name,
				age,
				COUNT(DISTINCT order_number) AS total_orders,
				SUM(quantity) AS total_quantity,
				SUM(sales_amount) AS total_amount,
				COUNT(DISTINCT product_key) AS total_products,
				MAX(order_date) AS last_order_date,
				DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS life_span
		FROM basic_details
		GROUP BY 
				customer_id,
				customer_name,
				age
	)
	/*
	===================================================================================================
	Step_3 : Generating final report
	===================================================================================================
	*/
	SELECT
		customer_id,
		customer_name,
		age,
		-- Segmenting customers based on age
		CASE
			WHEN age < 20 THEN 'Below 20'
			WHEN age BETWEEN 20 AND 29 THEN '20-29'
			WHEN age BETWEEN 30 AND 39 THEN '30-39'
			WHEN age BETWEEN 40 AND 49 THEN '40-49'
			ELSE '50 or more'
		END AS age_group,
		total_orders,
		total_quantity,
		total_amount,
		total_products,
		last_order_date,
		life_span,
		-- Segmenting customers based on life_span and total_amount
		CASE
			WHEN life_span >= 12 AND total_amount > 5000 THEN 'VIP'
			WHEN life_span >=12 AND total_amount <= 5000 THEN 'Regular'
			ELSE 'New'
		END AS customer_segment,
		DATEDIFF(MONTH, last_order_date, GETDATE()) AS recency,
		-- Average Order Value (AOR)
		CASE
			WHEN total_orders = 0 THEN 0
			ELSE (total_amount / total_orders)
		END AS average_order_value,
		-- Average monthly revenue
		CASE
			WHEN life_span = 0 THEN 0
			ELSE (total_amount / life_span)
		END AS average_monthly_spends
	FROM customer_aggregations;

GO

SELECT * FROM gold.customer_reports;



