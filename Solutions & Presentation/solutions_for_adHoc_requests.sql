/*
1. 
Provide the list of markets in which customer "Atliq Exclusive" operates its
business in the APAC region.
*/

select 
	distinct(market) as market
from dim_customer
where 
	customer = 'Atliq Exclusive' and 
    region = 'APAC';
    
/*
2. 
What is the percentage of unique product increase in 2021 vs. 2020? 
The final output contains these fields,
	unique_products_2020
	unique_products_2021
	percentage_chg
*/

with 
	cte1 as    
		(select 
			 count(distinct(product_code)) as 'unique_products_2020'
		from fact_sales_monthly
		where fiscal_year = 2020),
	cte2 as
		(select 
			 count(distinct(product_code)) as 'unique_products_2021'
		from fact_sales_monthly
		where fiscal_year = 2021)
select
	*, 
    round((unique_products_2021 - unique_products_2020)*100/unique_products_2020, 2) as 'percentage_chg'
from cte1
cross join cte2;

/*
3. 
Provide a report with all the unique product counts for each segment and
sort them in descending order of product counts. The final output contains
2 fields,
	segment
	product_count
*/

select 
	segment, count(distinct(product_code)) as 'product_count'
from dim_product
group by segment
order by product_count desc;

/*
4.
Follow-up: Which segment had the most increase in unique products in
2021 vs 2020? The final output contains these fields,
	segment
	product_count_2020
	product_count_2021
	difference
*/
with
	cte1 as
		(select 
			p.segment, s.fiscal_year, 
			count(distinct(s.product_code)) as 'product_count_2020'
		from fact_sales_monthly s
		join dim_product p
		on s.product_code = p.product_code
		where fiscal_year = 2020
		group by segment, fiscal_year),
	cte2 as
		(select 
			p.segment, s.fiscal_year, 
			count(distinct(s.product_code)) as 'product_count_2021'
		from fact_sales_monthly s
		join dim_product p
		on s.product_code = p.product_code
		where fiscal_year = 2021
		group by segment, fiscal_year)
select
	segment,
	product_count_2020, product_count_2021,
    (product_count_2021-product_count_2020) as 'difference'
from cte1 c1
join cte2 c2
using (segment);


/*
5.
Get the products that have the highest and lowest manufacturing costs.
The final output should contain these fields,
	product_code
	product
	manufacturing_cost
*/

select 
	m.product_code,
    p.product,
    max(m.manufacturing_cost) as manufacturing_cost
from fact_manufacturing_cost m
join dim_product p
on m.product_code = p.product_code
UNION 
select 
	m.product_code,
    p.product,
    min(m.manufacturing_cost) as manufacturing_cost
from fact_manufacturing_cost m
join dim_product p
on m.product_code = p.product_code;

/*
6.
Generate a report which contains the top 5 customers who received an
average high pre_invoice_discount_pct for the fiscal year 2021 and in the
Indian market. The final output contains these fields,
	customer_code
	customer
	average_discount_percentage
*/

select 
	d.customer_code,
    c.customer,
    d.pre_invoice_discount_pct
from fact_pre_invoice_deductions d
join dim_customer c
on d.customer_code = c.customer_code
where 
	fiscal_year = 2021 and
    market = 'India' and
    d.pre_invoice_discount_pct > (select 
									avg(pre_invoice_discount_pct) 
								 from fact_pre_invoice_deductions
								 where fiscal_year = 2021)
order by d.pre_invoice_discount_pct desc
limit 5;


/*
7.
Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” 
for each month. This analysis helps to get an idea of low and high-performing months 
and take strategic decisions.The final report contains these columns:
	Month
	Year
	Gross sales Amount
*/

with 
	cte as
		(select 
			MONTHNAME(s.date) as 'Month',
			YEAR(s.date) as 'Year',
			s.sold_quantity, g.gross_price,
			ROUND(s.sold_quantity*g.gross_price, 2) as 'Gross_sales_Amount'
		from dim_customer c
		join fact_sales_monthly s 
		on c.customer_code = s.customer_code
		join fact_gross_price g
		on s.product_code = g.product_code and s.fiscal_year = g.fiscal_year
		where c.customer = 'Atliq Exclusive')
select 
	Month, Year,
    ROUND(sum(Gross_sales_Amount)/1000000, 2) as 'Gross_Sales_Amount_mln'
from cte
group by Month, Year;


/*
8.
In which quarter of 2020, got the maximum total_sold_quantity? The final
output contains these fields sorted by the total_sold_quantity,
	Quarter
	total_sold_quantity
*/

WITH 
	cte AS
		(SELECT 
			*,
			CASE
				WHEN MONTH(date) BETWEEN 9 AND 11 THEN 'Q1'
				WHEN MONTH(date) IN (12,1,2) THEN 'Q2'
				WHEN MONTH(date) BETWEEN 3 AND 5 THEN 'Q3'
				ELSE 'Q4'
			END AS quater
		FROM fact_sales_monthly
		WHERE fiscal_year = 2020)
SELECT
	quater,
    sum(sold_quantity) as 'total_sold_quantity'
FROM cte
GROUP BY quater
ORDER BY total_sold_quantity desc;


/*
9.
Which channel helped to bring more gross sales in the fiscal year 2021
and the percentage of contribution? The final output contains these fields,
	channel
	gross_sales_mln
	percentage
*/


with cte as
	(select 
		s.customer_code, c.channel, s.product_code,g.gross_price,
		ROUND(sum(s.sold_quantity*g.gross_price)/1000000, 2) as gross_sales_mln
	from dim_customer c
	join fact_sales_monthly s 
	on c.customer_code = s.customer_code
	join fact_gross_price g
	on s.product_code = g.product_code and s.fiscal_year = g.fiscal_year
	where s.fiscal_year = 2021
    group by channel)

select
	channel, gross_sales_mln,
    gross_sales_mln*100/sum(gross_sales_mln) over() as percentage
from cte
order by percentage desc;


/*
10.
Get the Top 3 products in each division that have a high total_sold_quantity
in the fiscal_year 2021? The final output contains these fields
	division
	product_code
*/


with cte1 as
		(select 
			s.product_code,
            p.product,
			p.division,
			sum(s.sold_quantity) as total_sold_quantity
		from fact_sales_monthly s
		join dim_product p
		on s.product_code = p.product_code
		where s.fiscal_year = 2021
		group by p.product_code),
    cte2 as 
		(select 
			*,
			dense_rank() over(partition by division order by total_sold_quantity desc) as rank_order
		from cte1)
select
	division,
    product_code,
    product,
	total_sold_quantity,
	rank_order
from cte2
where rank_order <= 3;