/*OLIST is an e-commerce platform handling orders, products, sellers, customers, payments, and deliveries.
The business team needed clear visibility into revenue, growth, customer behavior, delivery performance,
and product contribution to make better decisions.*/

USE OLIST

SELECT * FROM orders                                                   ---1
SELECT * FROM products                                                 ---2 
SELECT * FROM seller                                                   ---3
SELECT * FROM product_category  -- USED FIRST ROW AS HEADER            ---4
SELECT * FROM customer                                                 ---5
SELECT * FROM geolocation                                              ---6
SELECT * FROM order_items                                              ---7
SELECT * FROM payments                                                 ---8
SELECT * FROM reviews                                                  ---9

---------------------------------------------------------------------------
SELECT * FROM product_category  -- USED FIRST ROW AS HEADER            ---4

CREATE TABLE product_category1
     (
    product_category_name varchar(100),
	product_category_name_english varchar(100)
	);
         
INSERT INTO product_category1
 SELECT 
     [column1],
     [column2]
FROM 
     product_category
WHERE 
     [column1] <> 'product_category_name';


SELECT * FROM product_category1;

DROP TABLE product_category;

-----------------------------------------------------------
/*KPI*/

--gross_revenue--
SELECT 
     cast(
	    round(
		      ((SUM(price)) + (SUM(freight_value)))/1000000 ,2) as varchar(20) ) 
			                         + ' m' as gross_revenue                      ----Converted values into millions
FROM order_items

--net_revenue--------------------------------
SELECT 
      CAST(
	       ROUND(
		        ((SUM(price)) + (SUM(freight_value)))/1000000, 2) AS VARCHAR(20))
				       + ' m' AS net_revenue
FROM order_items
JOIN orders
ON 
     orders.order_id = order_items.order_id
WHERE
     order_status = 'delivered';

--REVENUE TRENDS-------------------------------------------------------
SELECT 
      C.year,
	  C.month_name,
	  ROUND(SUM(OI.price + OI.freight_value)/1000, 2) AS REVENUE_M
FROM 
      order_items AS OI
JOIN 
      orders AS O
ON
     O.order_id = OI.order_id
JOIN 
     CALENDER AS C
ON 
     C.Date = CAST(O.order_purchase_timestamp AS DATE)
WHERE 
     O.order_status = 'delivered'
GROUP BY
     C.year,
	 C.month_name,
	 C.month_number
ORDER BY
     1 ASC, 
	 C.month_number ASC;


/*Which States Generate the Most Revenue?*/
SELECT 
      customer_state,
	  ROUND(SUM(OI.price + OI.freight_value)/1000000, 2) AS REVENUE_M
FROM 
      [order_items] AS OI
JOIN  orders AS O
      ON 
	    O.order_id = O.order_id
JOIN
      [customer] as C
	  ON
	     C.customer_id = O.customer_id
GROUP BY
      customer_state
ORDER BY
      2 DESC;

/*What is the Order Status Distribution?*/
SELECT 
      order_status,
	  count(order_id) as total_order
FROM orders
GROUP BY 
       order_status
ORDER BY
       2 DESC;

/*Are Orders Delivered Late?*/
SELECT
     COUNT(order_id) AS LATE_DELIVERY
FROM 
     orders
WHERE
    [order_delivered_customer_date] >[order_estimated_delivery_date]
/*LATE DELIVERY RATE % */
SELECT 
      CAST(LATE_DELIVERED_PCT AS VARCHAR(5) ) + ' %' AS LATE_DELIVERED_PCT
FROM(
SELECT(
       ROUND(
	         SUM(CASE
			         WHEN [order_delivered_customer_date] > [order_estimated_delivery_date]
					 THEN 1 
					 ELSE 0
				 END
				 ) * 100/COUNT(*), 2)) AS LATE_DELIVERED_PCT
FROM orders
WHERE 
     [order_status] = 'delivered'
)  AS T;



/*Which Payment Types are Most Used?*/
SELECT 
     payment_type,
     COUNT(order_id) AS TOTAL_PAYMENT
FROM [payments]
GROUP BY 
     payment_type
ORDER BY
     2 DESC

/*REVENUE CONTRIBUTION % BY CATEGORY*/
WITH TOTAL_REV AS(
       SELECT  
	        SUM(OI.price + OI.freight_value) AS TOTAL_REVENUE
	   FROM order_items OI
JOIN orders
ON 
     orders.order_id = OI.order_id
WHERE
     order_status = 'delivered'
	 )
SELECT  
       product_category_name,
	   (ROUND(SUM(OI.price + OI.freight_value)/1000,2)) AS  net_revenue_thousend,
	   (ROUND(SUM(OI.price + OI.freight_value)*100/TOTAL_REVENUE,2)) AS  net_revenue_pct
FROM   products
JOIN   order_items AS OI
ON     products.product_id = OI.product_id
JOIN   orders
ON     orders.order_id = OI.order_id
CROSS JOIN   TOTAL_REV 
WHERE 
       order_status = 'delivered'
GROUP BY 
       product_category_name,TOTAL_REVENUE
ORDER BY 
       3 DESC;

/*Running Total Revenue*/
SELECT
      C.[year],
	  C.[month_name],
	  ROUND(SUM(OI.price + OI.freight_value)/1000,2) AS  revenue,
	  ROUND(SUM(
	            SUM(OI.price + OI.freight_value))
				OVER(ORDER BY C.[year],C.[month_number])/1000,2) AS revenu_running
FROM 
     [dbo].[order_items] AS OI
JOIN [dbo].[orders] AS O
ON 
     O.order_id = OI.order_id
JOIN [dbo].[CALENDER] AS C
ON 
     CAST(O.[order_purchase_timestamp] AS DATE) = C.[Date]
WHERE 
    O.order_status ='delivered'
GROUP BY
    C.[year],
	C.[month_name],
	C.[month_number]
ORDER BY
    1,
	C.[month_number]

/*MOM GROWTH % */
WITH monthly_rev AS (
    SELECT 
        c.year,
        c.month_number,
        c.month_name,
        SUM(oi.price + oi.freight_value) AS revenue
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.order_id
    JOIN CALENDER c ON CAST(o.order_purchase_timestamp AS DATE) = c.Date
    WHERE o.order_status = 'delivered'
    GROUP BY c.year, c.month_number, c.month_name
)
SELECT 
    year,
    month_name,
    ROUND(revenue/1000000.0,2) AS revenue_m,
    ROUND(
        (revenue - LAG(revenue) OVER (ORDER BY year, month_number))
        * 100.0 / LAG(revenue) OVER (ORDER BY year, month_number)
    ,2) AS mom_growth_pct
FROM monthly_rev
ORDER BY year, month_number;


/*Top 3 Product Categories per Month*/
WITH category_rank AS(
SELECT
     C.year,
	 C.month_name,
	 C.month_number,
	 PC.[product_category_name_english],
	 SUM(oi.price + oi.freight_value) AS revenue,
	 DENSE_RANK() OVER(PARTITION BY C.year,C.month_name, C.month_number ORDER BY SUM(oi.price + oi.freight_value) DESC
	 ) AS RNK
FROM [dbo].[order_items] AS oi
JOIN
     [dbo].[orders] o
ON   
     o.order_id = oi.order_id
JOIN 
     [dbo].[CALENDER] AS C
ON   
     c.[Date] = CAST( o.order_purchase_timestamp AS DATE)
JOIN
     [dbo].[products] AS p
ON
     p.product_id =oi.product_id
JOIN
     [dbo].[product_category1] AS pc
ON
     pc.product_category_name = p.product_category_name
WHERE
     order_status = 'delivered'
GROUP BY 
     C.year,
	 C.month_number,
	 C.month_name,
	 PC.[product_category_name_english]
)
SELECT * ,
      CASE
	      WHEN RNK = 1
		  THEN '--------------------------->'
		  WHEN RNK = 2
		  THEN '------------->'
		  WHEN RNK = 3
		  THEN '--->'
		END AS VISUAL
FROM 
     category_rank
WHERE
     RNK <= 3 ;


/*I solved end-to-end business problems using SQL Server, including data cleansing, KPI creation,
time-series analysis, window functions, ranking, and percentage contribution analysis, 
and prepared the data for Power BI dashboards.*/

















