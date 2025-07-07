select * from category
select * from products
select * from sales
select * from stores
select * from warranty

alter table products
add constraint pkcategory
foreign key (category_id) references category(category_id) 


alter table sales
add constraint pkprodects
foreign key (product_id) references products(product_id)

alter table sales
add constraint pkstore
foreign key (store_id) references stores(store_id)

alter table warranty
add constraint fkorder
foreign key(sale_id) references sales(sale_id)

-- 1. Find the number of stores in each country.
select 
	country,
	count(store_id) as total_stores
from stores
group by country
order by total_stores desc

-- Q.2 Calculate the total number of units sold by each store.

select
	s.store_id,
	st.store_name,
	sum(s.quantity) as total_unit_sold
from sales as s
join
stores as st
on st.store_id = s.store_id
group by s.store_id,st.store_name
order by 3 desc

-- Q.3 Identify how many sales occurred in December 2023.

select 
	count(sale_id) as total_sales
from sales
where month(sale_date) = 12 and year(sale_date) = 2023;


-- Q.4 Determine how many stores have never had a warranty claim filed.
select count(*) from stores
where store_id not in (
						select 
							distinct store_id
						from sales as s
						right join warranty as w
						on s.sale_id = w.sale_id);

-- Q.5 Calculate the percentage of warranty claims marked as "Warranty Void".
select 
    round(
        cast(count(claim_id) as float) / 
        (select count(*) from warranty) * 100, 
        2
    ) as warranty_void_percentage
from warranty
where repair_status = 'Warranty Void';

-- Q.6 Identify which store had the highest total units sold in the last year.
select top 1
    s.store_id,
    st.store_name,
    sum(s.quantity) as total_units_sold
from sales as s
join stores as st on s.store_id = st.store_id
where sale_date >= dateadd(year, -1, getdate())
group by s.store_id, st.store_name
order by total_units_sold desc;


-- Q.7 Count the number of unique products sold in the last year.
select
    count(distinct product_id) as unique_products_sold
from sales
where sale_date >= dateadd(year, -1, getdate());


-- Q.8 Find the average price of products in each category.
select
    p.category_id,
    c.category_name,
    round(avg(p.price), 2) as avg_price
from products as p
join category as c on p.category_id = c.category_id
group by p.category_id, c.category_name
order by avg_price desc;


-- Q.9 How many warranty claims were filed in 2020?
select 
    count(*) as warranty_claims
from warranty
where year(claim_date) = 2020;

-- Q.10 For each store, identify the best-selling day based on highest quantity sold.

-- store_id, day_name, sum(qty)
--  window dense rank 
select
    store_id,
    day_name,
    total_unit_sold
from (
    select 
        store_id,
        datename(weekday, sale_date) as day_name,
        sum(quantity) as total_unit_sold,
        dense_rank() over (partition by store_id order by sum(quantity) desc) as rank
    from sales
    group by store_id, datename(weekday, sale_date)
) as t
where rank = 1;


-- Medium to Hard Questions
-- Q.11 Identify the least selling product in each country for each year based on total units sold.
with product_rank as (
    select 
        st.country,
        year(s.sale_date) as year,
        p.product_name,
        sum(s.quantity) as total_qty_sold,
        rank() over(
            partition by st.country, year(s.sale_date) 
            order by sum(s.quantity) asc
        ) as rnk
    from sales as s
    join stores as st on s.store_id = st.store_id
    join products as p on s.product_id = p.product_id
    group by st.country, year(s.sale_date), p.product_name
)
select 
    country,
    year,
    product_name,
    total_qty_sold
from product_rank
where rnk = 1;


-- Q.12 Calculate how many warranty claims were filed within 180 days of a product sale.
select 
    count(*) as total_claims_within_180_days
from warranty as w
left join sales as s on w.sale_id = s.sale_id
where 
    datediff(day, s.sale_date, w.claim_date) <= 180;


--Q.13  Determine how many warranty claims were filed for products launched in the last two years.
-- each prod 
--  no claim
--  no sale
-- each must be launcnhed in last 2 year
select p.product_name,
    count(distinct w.claim_id) as no_claims,
    count(distinct s.sale_id) as no_sales
from products as p
JOIN sales as s on p.product_id = s.product_id
LEFT JOIN warranty as w on s.sale_id = w.sale_id
WHERE p.launch_date >= dateadd(year, -2, getdate())
group by p.product_name
having count(w.claim_id) > 0;



-- Q.14 List the months in the last three years where sales exceeded 5,000 units in the USA.
select 
    format(s.sale_date, 'MM-yyyy') AS month,
    sum(s.quantity) as total_unit_sold
from sales as s
JOIN stores as st on s.store_id = st.store_id
where 
    st.country = 'USA'
    and s.sale_date >= dateadd(year, -3, getdate())
group by format(s.sale_date, 'MM-yyyy')
having sum(s.quantity) > 5000;



-- Q.15 Identify the product category with the most warranty claims filed in the last two years.
select top 1
    c.category_name,
    count(w.claim_id) as total_claims
from warranty as w
left join sales as s on w.sale_id = s.sale_id
join products as p on p.product_id = s.product_id
join category as c on c.category_id = p.category_id
where w.claim_date >= dateadd(YEAR, -2, getdate())
group by c.category_name
order by total_claims desc;


-- Complex Problems
-- Q.16 Determine the percentage chance of receiving warranty claims after each purchase for each country!
select 
    country,
    total_unit_sold,
    total_claim,
    coalesce(cast(total_claim as float) /nullif(cast(total_unit_sold as float), 0) * 100, 0) as risk
from (
    select 
        st.country,
        sum(s.quantity) as total_unit_sold,
        count(w.claim_id) as total_claim
    from sales as s
    join stores as st on s.store_id = st.store_id
    left join warranty as w on w.sale_id = s.sale_id
    group by st.country
) as t1
order by risk desc;


-- Q.17 Analyze the year-by-year growth ratio for each store.

-- each store and their yearly sale 
with yearly_sales as (
    select 
        s.store_id,
        st.store_name,
        year(s.sale_date) as year,
        sum(s.quantity * p.price) as total_sale
    from sales as s
    join products as p on s.product_id = p.product_id
    join stores as st on st.store_id = s.store_id
    group by s.store_id, st.store_name, year(s.sale_date)
),
growth_ratio as (
    select 
        store_name,
        year,
        lag(total_sale) over (partition by store_name order by year) as last_year_sale,
        total_sale as current_year_sale
    from yearly_sales
)
select 
    store_name,
    year,
    last_year_sale,
    current_year_sale,
    round(
        (cast(current_year_sale as float) - cast(last_year_sale as float)) 
        / nullif(cast(last_year_sale as float), 0) * 100, 3
    ) as growth_ratio
from growth_ratio
where 
    last_year_sale IS NOT NULL
    AND year <> year(getdate());

-- Q.18 Calculate the correlation between product price and warranty claims for 
-- products sold in the last five years, segmented by price range.
select 
    case
        when p.price < 500 then 'Less Expenses Product'
        when p.price BETWEEN 500 AND 1000 then 'Mid Range Product'
        else 'Expensive Product'
    end as price_segment,
    count(w.claim_id) as total_claims
from warranty as w
left join sales as s on w.sale_id = s.sale_id
join products as p on p.product_id = s.product_id
where w.claim_date >= dateadd(year, -5, getdate())
group by 
    case
        when p.price < 500 then 'Less Expenses Product'
        when p.price BETWEEN 500 AND 1000 then 'Mid Range Product'
        else 'Expensive Product'
    end;


-- Q.19 Identify the store with the highest percentage of "Paid Repaired" claims relative to total claims filed
with paid_repair as (
    select 
        s.store_id,
        count(w.claim_id) as paid_repaired
    FROM sales AS s
    RIGHT JOIN warranty as w on w.sale_id = s.sale_id
    where w.repair_status = 'Paid Repaired'
    group by s.store_id
),
total_repaired as (
    select 
        s.store_id,
        count(w.claim_id) as total_repaired
    from sales as s
    RIGHT JOIN warranty as w on w.sale_id = s.sale_id
    group by s.store_id
)

select top 1
    tr.store_id,
    st.store_name,
    pr.paid_repaired,
    tr.total_repaired,
    round(
        cast(pr.paid_repaired as float) / nullif(cast(tr.total_repaired as float), 0) * 100, 
        2
    ) as percentage_paid_repaired
from paid_repair as pr
JOIN total_repaired as tr on pr.store_id = tr.store_id
JOIN stores as st on tr.store_id = st.store_id
order by percentage_paid_repaired desc;


-- Q.20 Write a query to calculate the monthly running total of sales for each store
-- over the past four years and compare trends during this period.
with monthly_sales as (
    select 
        s.store_id,
        year(s.sale_date) as year,
        month(s.sale_date) as month,
        sum(p.price * s.quantity) as total_revenue
    from sales as s
    JOIN products as p on s.product_id = p.product_id
    where s.sale_date >= dateadd(YEAR, -4, getdate())
    group by s.store_id, year(s.sale_date), month(s.sale_date)
)
select 
    store_id,
    year,
    month,
    total_revenue,
    sum(total_revenue) over (
        partition by store_id 
        order by year, month
    ) as running_total
from monthly_sales
order by store_id, year, month;








