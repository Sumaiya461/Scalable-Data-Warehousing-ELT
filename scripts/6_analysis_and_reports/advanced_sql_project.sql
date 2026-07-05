/*
=================================================================================================
Advanced Analytics
	- Performing required all advanced analytical techniques to generate final reports
=================================================================================================
*/

use DataWarehouse;

/*
=================================================================================================
Change Over Time (Trends)
=================================================================================================
*/
-- Task_1 : Analyze sales over time 
SELECT
	DATETRUNC(month, order_date) AS order_month,
	SUM(sales_amount) AS sales_amount,
	COUNT(DISTINCT(customer_key)) AS no_of_customers,
	SUM(quantity) AS quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(month, order_date) 
ORDER BY DATETRUNC(month, order_date), SUM(sales_amount)

/*
=================================================================================================
Cummulative Analysis
=================================================================================================
*/
-- Task_2 : calculate total sales per month and running total of sales over time
SELECT
	order_month,
	total_sales,
	SUM(total_sales) OVER(PARTITION BY order_month ORDER BY order_month) AS running_total,
	AVG(average_price) OVER(PARTITION BY order_month ORDER BY order_month) AS moving_average
FROM(
	SELECT
		DATETRUNC(month, order_date) AS order_month,
		SUM(sales_amount) AS total_sales,
		AVG(price) AS average_price
	FROM gold.fact_sales
	WHERE order_date IS NOT NULL
	GROUP BY DATETRUNC(month, order_date)
	)t;

/*
=================================================================================================
Performance Analysis
=================================================================================================
*/
-- Task_3 : Analyze the yearly performance of products by comparing each product's sales to both it's average sales performance
-- and the previous year's sales

WITH yearly_product_analysis AS (
	SELECT
		YEAR(s.order_date) AS order_year,
		p.product_name AS product_name,
		SUM(s.sales_amount) AS current_sales
	FROM gold.fact_sales AS s
	LEFT JOIN gold.dim_products AS p
	ON s.product_key = p.product_key
	WHERE order_date IS NOT NULL
	GROUP BY 
		YEAR(s.order_date) ,
		p.product_name
)

SELECT
	order_year,
	product_name,
	current_sales,
	AVG(current_sales) OVER(PARTITION BY product_name) AS avg_sales,
	CASE
		WHEN current_sales - AVG(current_sales) OVER(PARTITION BY product_name) > 0
			THEN 'Above avg_sales'
		WHEN current_sales - AVG(current_sales) OVER(PARTITION BY product_name) < 0
			THEN 'Below avg_sales'
		ELSE 'No change'
	END AS comapre_with_avg_sales,
	CASE
		WHEN current_sales - LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) < 0
			THEN 'Below previous year sales'
		WHEN current_sales - LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) > 0
			THEN  'ABove previous year sales'
		ELSE 'No change'
	END AS compare_with_prev_year_sales
FROM yearly_product_analysis;

/*
=================================================================================================
Part to whole Analysis (proportional)
=================================================================================================
*/
-- Task_4 : Which category contributes the most overall sales
WITH category_contribution AS (
	SELECT
		p.category AS category,
		SUM(s.sales_amount) AS total_sales
	FROM gold.fact_sales AS s
	LEFT JOIN gold.dim_products AS p
	ON s.product_key = p.product_key
	GROUP BY p.category
)
SELECT
	category,
	total_sales,
	SUM(total_sales) OVER() AS overall_sales,
	CONCAT(ROUND((CAST(total_sales AS FLOAT)/ SUM(total_sales) OVER())*100,2), '%') AS percentage_of_total
FROM category_contribution;

/*
=================================================================================================
Data Segmentation
=================================================================================================
*/
-- Task_5 : Segment products into cost ranges and count how many products fall into each segment
WITH cost_ranges AS (
	SELECT
		product_name,
		cost,
		CASE 
			WHEN cost < 100 THEN 'Below 100'
			WHEN cost BETWEEN 100 AND 500 THEN '100-500'
			WHEN cost BETWEEN 500 AND 1000 THEN '500-1000'
			ELSE 'Above 100'
		END AS cost_range
	FROM gold.dim_products
)

SELECT
	cost_range,
	COUNT(product_name) AS no_of_products
FROM cost_ranges
GROUP BY cost_range
ORDER BY no_of_products DESC;

/* 
Group customers into three groups based in their spenfing behaviour:
	- VIP : Customers with atleast 12 months (between first order and last order)
			of history and spending more then $5,000/-
	- Regular : Customers with atleast 12 months (between first order and last order)
			of history and spending $5,000/- or less
	- New : Customers with life span less than 12 months (between first order and last order)
And find the total number of customer by each group
*/
WITH customer_history AS (
	SELECT
		c.customer_id,
		MIN(s.order_date) AS first_order_date,
		MAX(s.order_date) AS last_order_date,
		DATEDIFF(MONTH, MIN(s.order_date), MAX(s.order_date)) AS history, 
		SUM(sales_amount) AS total_spends
	FROM gold.fact_sales AS s
	LEFT JOIN gold.dim_customers AS c
	ON s.customer_key = c.customer_key
	GROUP BY c.customer_id
), 
customer_segmentation AS (
	SELECT
		customer_id,
		history,
		total_spends,
		CASE 
			WHEN history >= 12 AND total_spends > 5000 THEN 'VIP'
			WHEN history >=12 AND total_spends <= 5000 THEN 'Regular'
			ELSE 'New'
		END AS customer_segment

	FROM customer_history
)

SELECT
	customer_segment,
	COUNT(customer_id) AS total_customers
FROM customer_segmentation
GROUP BY customer_segment
ORDER BY COUNT(customer_id) DESC;