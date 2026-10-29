CREATE SCHEMA dannys_diner;

Use dannys_diner;

CREATE TABLE sales (
  customer_id VARCHAR(1),
  order_date DATE,
  product_id INTEGER
);

INSERT INTO sales
  (customer_id, order_date, product_id)
VALUES
  ('A', '2021-01-01', '1'),
  ('A', '2021-01-01', '2'),
  ('A', '2021-01-07', '2'),
  ('A', '2021-01-10', '3'),
  ('A', '2021-01-11', '3'),
  ('A', '2021-01-11', '3'),
  ('B', '2021-01-01', '2'),
  ('B', '2021-01-02', '2'),
  ('B', '2021-01-04', '1'),
  ('B', '2021-01-11', '1'),
  ('B', '2021-01-16', '3'),
  ('B', '2021-02-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-07', '3');
 

CREATE TABLE menu (
  product_id INTEGER,
  product_name VARCHAR(5),
  price INTEGER);

INSERT INTO menu
  (product_id, product_name, price)
VALUES
  ('1', 'sushi', '10'),
  ('2', 'curry', '15'),
  ('3', 'ramen', '12');
  

CREATE TABLE members (
  customer_id VARCHAR(1),
  join_date DATE);

INSERT INTO members
  (customer_id, join_date)
VALUES
  ('A', '2021-01-07'),
  ('B', '2021-01-09');
  
  
  
  
  -- 1. What is the total amount each customer spent at the restaurant?
  
  select s.customer_id, sum(m.price) as total_spendings
  from sales as s join menu as m
  on s.product_id = m.product_id
  group by s.customer_id;
  
  
-- 2. How many days has each customer visited the restaurant?

select s.customer_id, count(distinct s.order_date) as visit_days
from sales as s join menu as m
on s.product_id = m.product_id
group by s.customer_id;


-- 3. What was the first item from the menu purchased by each customer?

select distinct s.customer_id,  first_value(m.product_name) over (partition by s.customer_id ) as First_order
from sales as s join menu as m
on s.product_id = m.product_id;


-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?

select m.product_name, count(s.product_id) as most_purchased_count
from sales as s join menu as m
on s.product_id = m.product_id
group by m.product_name
order by most_purchased_count desc
limit 1;


-- 5. Which item was the most popular for each customer?

with orders as 
( select s.customer_id, m.product_name, count(s.product_id) as order_count,
 dense_rank() over (partition by s.customer_id order by count(s.product_id) desc) as rnk
from sales as s join menu as m
on s.product_id = m.product_id
group by s.customer_id, m.product_name)

select customer_id, product_name, order_count
from orders
where rnk = 1;


-- 6. Which item was purchased first by the customer after they became a member?

with ranked_member_sales as 
(select
s.customer_id, m.product_name, s.order_date, row_number() over (partition by s.customer_id order by s.order_date) as pur_rank
from menu as m join sales as s 
on m.product_id = s.product_id
join members as mem
on s.customer_id = mem.customer_id
where s.order_date >= mem.join_date)
select customer_id, product_name, order_date
from ranked_member_sales
where pur_rank = 1;


-- 7. Which item was purchased just before the customer became a member?

with ranked_member_sales as 
(select
s.customer_id, m.product_name, s.order_date, row_number() over (partition by s.customer_id order by s.order_date desc) as pur_rank
from menu as m join sales as s 
on m.product_id = s.product_id
join members as mem
on s.customer_id = mem.customer_id
where s.order_date <= mem.join_date)
select customer_id, product_name, order_date
from ranked_member_sales
where pur_rank = 1;

-- 8. What is the total items and amount spent for each member before they became a member?

select
s.customer_id, count(s.product_id) as order_cnt, sum(m.price) as sum_orders
from menu as m join sales as s 
on m.product_id = s.product_id
join members as mem
on s.customer_id = mem.customer_id
where s.order_date < mem.join_date
group by s.customer_id;

-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

select s.customer_id,
sum(case when m.product_id = 1 then 200
when m.product_id = 2 then 150
when m.product_id = 3 then 120 end) as points
from sales s join menu m
on s.product_id = m.product_id
group by s.customer_id;


-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi 
-- how many points do customer A and B have at the end of January?



WITH program_dates AS
(SELECT customer_id, join_date,
DATE_ADD(join_date, INTERVAL 6 DAY) AS promo_end_date,   -- First week includes the join date, so add 6 days
LAST_DAY('2021-01-01') AS max_date                       -- Filter constraint up to the end of January 2021
  FROM members)
  
SELECT s.customer_id,
SUM(CASE WHEN m.product_name = 'sushi' THEN m.price * 20                                -- 1. Sushi always gets 2x points ($1 = 20 points)
         WHEN s.order_date BETWEEN p.join_date AND p.promo_end_date THEN m.price * 20   -- 2. First week promo gives 2x points on EVERYTHING ($1 = 20 points)
         ELSE m.price * 10 END) AS total_points                                         -- 3. All other regular items get normal points ($1 = 10 points)
FROM sales s JOIN program_dates p ON s.customer_id = p.customer_id
JOIN menu m ON s.product_id = m.product_id
WHERE s.order_date <= p.max_date
GROUP BY s.customer_id
ORDER BY s.customer_id;


-- creating basic data tables that Danny and his team can use to quickly derive insights without needing to join the underlying tables using SQL.

select s.customer_id, s.order_date,	 m.product_name	, m.price,
case when s.order_date < mem.join_date or mem.customer_id is null then 'N'
     when s.order_date >= mem.join_date then 'Y' end as Member
from menu as m join sales as s 
on m.product_id = s.product_id
left join members as mem
on s.customer_id = mem.customer_id;


/*Danny also requires further information about the ranking of customer products, 
but he purposely does not need the ranking for non-member purchases
 so he expects null ranking values for the records when customers are not yet part of the loyalty program.*/

with members_data as
(select s.customer_id, s.order_date, m.product_name	, m.price,
case when s.order_date < mem.join_date or mem.customer_id is null then 'N'
     when s.order_date >= mem.join_date then 'Y' end as Member
from menu as m join sales as s 
on m.product_id = s.product_id
left join members as mem
on s.customer_id = mem.customer_id)


select customer_id, order_date, product_name, price, member,
case when member = 'Y' then row_number() over (partition by s.customer_id, member order by order_date) else null end as ranking
from members_data
order by customer_id, order_date;

