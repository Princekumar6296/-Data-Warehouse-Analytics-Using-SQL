/*
=============================================================
Create Database and Schemas
=============================================================
Script Purpose:
    This script creates a new database named 'DataWarehouseAnalytics' after checking if it already exists. 
    If the database exists, it is dropped and recreated. Additionally, this script creates a schema called gold
	
WARNING:
    Running this script will drop the entire 'DataWarehouseAnalytics' database if it exists. 
    All data in the database will be permanently deleted. Proceed with caution 
    and ensure you have proper backups before running this script.
*/
-- Drop and recreate the 'DataWarehouseAnalytics' database

DROP DATABASE IF EXISTS "DataWarehouseAnalytics";
CREATE DATABASE "DataWarehouseAnalytics";



-- Create Schema
CREATE SCHEMA gold;

-- Create Tables

CREATE TABLE gold.dim_customers (
    customer_key INT,
    customer_id INT,
    customer_number VARCHAR(50),
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    country VARCHAR(50),
    marital_status VARCHAR(50),
    gender VARCHAR(50),
    birthdate DATE,
    create_date DATE
);

select * from gold.dim_customers


CREATE TABLE gold.dim_products (
    product_key INT,
    product_id INT,
    product_number VARCHAR(50),
    product_name VARCHAR(50),
    category_id VARCHAR(50),
    category VARCHAR(50),
    subcategory VARCHAR(50),
    maintenance VARCHAR(50),
    cost INT,
    product_line VARCHAR(50),
    start_date DATE
);

select * from gold.dim_products

CREATE TABLE gold.fact_sales (
    order_number VARCHAR(50),
    product_key INT,
    customer_key INT,
    order_date DATE,
    shipping_date DATE,
    due_date DATE,
    sales_amount INT,
    quantity SMALLINT,  -- tinyint in SQL Server is 0-255, closest is SMALLINT in PostgreSQL
    price INT
);

select * from gold.fact_sales;


-- Calculating the total sales per month and running total of sales over time.


SELECT
    TO_CHAR(order_date, 'DD-MM-YY') AS order_year,
    total_sales,
    SUM(total_sales) OVER (ORDER BY order_date) AS running_total_sales,
    ROUND(AVG(avg_price) OVER (ORDER BY order_date)) AS moving_avg_price
FROM (
    SELECT
        DATE_TRUNC('MONTH', order_date) AS order_date,
        SUM(sales_amount) AS total_sales,
        AVG(price) AS avg_price
    FROM GOLD.FACT_SALES
    WHERE order_date IS NOT NULL
    GROUP BY DATE_TRUNC('MONTH', order_date)
) AS yearly_data
ORDER BY order_date;




-- Analyze the yearly performance of products by comparing their sales to both the average sales 
-- performance of  the product and the previous year's sales.

WITH yearly_product_sales AS (
    SELECT
        EXTRACT(YEAR FROM f.order_date) AS order_year,
        p.product_name,
        SUM(f.sales_amount) AS current_sales
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p 
        ON p.product_key = f.product_key
    WHERE f.order_date IS NOT NULL
    GROUP BY EXTRACT(YEAR FROM f.order_date), p.product_name
)
SELECT 
    order_year, 
    product_name,
    current_sales,
    ROUND(AVG(current_sales) OVER (PARTITION BY product_name)) AS avg_sales,
    ROUND(current_sales - AVG(current_sales) OVER (PARTITION BY product_name)) AS diff_avg,
    CASE 
        WHEN (current_sales - AVG(current_sales) OVER (PARTITION BY product_name)) > 0 THEN 'Above Avg'
        WHEN (current_sales - AVG(current_sales) OVER (PARTITION BY product_name)) < 0 THEN 'Below Avg'
        ELSE 'Avg'
    END AS avg_change
FROM yearly_product_sales
ORDER BY product_name, order_year;



-- Which categories contribute the most to overall sales ? 

WITH category_sales AS (
    SELECT 
        p.category, 
        SUM(f.sales_amount) AS total_sales
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p 
        ON p.product_key = f.product_key
    GROUP BY p.category
)

SELECT
    category,
    total_sales,
    SUM(total_sales) OVER () AS overall_sales,
    CONCAT(ROUND((total_sales::float / SUM(total_sales) OVER())::numeric * 100, 2), '%') AS percent_of_total
FROM category_sales
ORDER BY total_sales DESC;



-- segments products intoo cost ranges and count how many product fall into each segment


with product_segments as(
select 
product_key,
product_name,
cost,
CASE WHEN cost < 100 then 'Below 100'
     WHEN cost between 100 and 500 then '100 - 500'
	 WHEN cost between 500 and 1000 then '500 - 1000'
	 ELSE 'Above 1000'
end cost_range
from gold.dim_products)

select
cost_range,
count(product_key) AS total_products
from product_segments
group by cost_range 
order by total_products DESC
