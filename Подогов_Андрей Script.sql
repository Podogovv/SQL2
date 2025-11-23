create table customer (
    customer_id int not null primary key,
    first_name text,
    last_name text,
    gender text,
    dob date,
    job_title text,
    job_industry_category text,
    wealth_segment text,
    deceased_indicator char(1),
    owns_car bool,
    address text,
    postcode int,
    state text,
    country text,
    property_valuation int
);

create table product (
    product_id int not null primary key,
    brand text,
    product_line text,
    product_class text,
    product_size text,
    list_price int,
    standard_cost int
);

CREATE TABLE orders (
    order_id int primary key,
    customer_id int not null,
    order_date date not null,
    online_order bool,
    order_status bool not null
);

create table order_items (
    order_item_id int primary key,
    order_id int not null,
    product_id int not null,
    quantity int not null,
    item_list_price_at_sale float4 not null,
    item_standard_cost_at_sale float4
);

select distinct p.brand
from product p
join order_items oi on oi.product_id = p.product_id
where p.standard_cost > 1500
group by p.brand
having sum (oi.quantity) >= 1000;

select
    d::date as day,
    count(o.order_id) as confirmed_online_orders,
    count(distinct o.customer_id) as unique_customers
from generate_series('2017-04-01'::date, '2017-04-09'::date, interval '1 day') d
left join orders o
    on o.order_date::date = d::date
   and o.order_status = 'approved'
   and o.online_order = true
group by d
order by d;


select 
    first_name,
    last_name,
    job_title,
    job_industry_category,
    dob,
    extract(year from age(current_date, dob)) as age
from customer
where job_industry_category = 'IT' 
    and job_title like 'Senior%'
    and extract(year from age(current_date, dob)) > 35

union all

select 
    first_name,
    last_name,
    job_title,
    job_industry_category,
    dob,
    extract(year from age(current_date, dob)) as age
from customer
where job_industry_category = 'Financial Services' 
    and job_title like 'Lead%'
    and extract(year from age(current_date, dob)) > 35;

select distinct p.brand
from orders o
join customer c on o.customer_id = c.customer_id
join order_items oi on o.order_id = oi.order_id
join product p on oi.product_id = p.product_id
where c.job_industry_category = 'Financial Services'
  and p.brand not in (
    select distinct p2.brand
    from orders o2
    join customer c2 on o2.customer_id = c2.customer_id
    join order_items oi2 on o2.order_id = oi2.order_id
    join product p2 on oi2.product_id = p2.product_id
    where c2.job_industry_category = 'IT'
  )
order by p.brand;


with state_avg_property as (
    select
        state,
        AVG(property_valuation) as avg_property_valuation
    from customer
    where deceased_indicator = 'N'
    group by state
),
customer_orders_count as (
    select 
        c.customer_id,
        c.first_name,
        c.last_name,
        c.state,
        c.property_valuation,
        count (distinct o.order_id) as online_orders_count
    from customer c
    join orders o on c.customer_id = o.customer_id
    join order_items oi on o.order_id = oi.order_id
    join product p on oi.product_id = p.product_id
    where o.online_order = true
      AND p.brand IN ('Giant Bicycles', 'Norco Bicycles', 'Trek Bicycles')
      and c.deceased_indicator = 'N'
    group by c.customer_id, c.first_name, c.last_name, c.state, c.property_valuation
)
select 
    coc.customer_id,
    coc.first_name,
    coc.last_name,
    coc.online_orders_count,
    coc.state,
    coc.property_valuation
from customer_orders_count coc
join state_avg_property sap on coc.state = sap.state
where coc.property_valuation > sap.avg_property_valuation
order by coc.online_orders_count desc
limit 10;

select 
    c.customer_id,
    c.first_name,
    c.last_name,
    c.owns_car,
    c.wealth_segment
from customer c
where c.deceased_indicator = 'N'
  and c.owns_car = 'Yes'        
  and c.wealth_segment != 'Mass Customer'
  and not exists (
    select 1
    from orders o
    where o.customer_id = c.customer_id
      and o.online_order = true         
      and o.order_status = 'approved'     
      and o.order_date >= current_date - interval '1 year' 
  )
order by c.customer_id;

with top_road_products as (
    select product_id
    from product
    where product_line = 'Road'
    order by list_price desc
    limit 5
)
select 
    c.customer_id,
    c.first_name,
    c.last_name,
    count(distinct p.product_id) as purchased_top_products_count
from customer c
join orders o on c.customer_id = o.customer_id
join order_items oi on o.order_id = oi.order_id
join product p on oi.product_id = p.product_id
where c.job_industry_category = 'IT'
  and p.product_id in (select product_id from top_road_products)
group by c.customer_id, c.first_name, c.last_name
having count(distinct p.product_id) >= 2
order by purchased_top_products_count desc, c.customer_id;

select 
    c.customer_id,
    c.first_name,
    c.last_name,
    c.job_industry_category,
    count(distinct o.order_id) as order_count,
    sum(oi.quantity * oi.item_list_price_at_sale) as total_revenue
from customer c
join orders o on c.customer_id = o.customer_id
join order_items oi on o.order_id = oi.order_id
where c.job_industry_category = 'IT'
  and o.order_status = 'Approved'
  and o.order_date between '2017-01-01' and '2017-03-01'
group by c.customer_id, c.first_name, c.last_name, c.job_industry_category
having count(distinct o.order_id) >= 3
   and sum(oi.quantity * oi.item_list_price_at_sale) > 10000
UNION
select 
    c.customer_id,
    c.first_name,
    c.last_name,
    c.job_industry_category,
    count(distinct o.order_id) as order_count,
    sum(oi.quantity * oi.item_list_price_at_sale) as total_revenue
from customer c
join orders o on c.customer_id = o.customer_id
join order_items oi on o.order_id = oi.order_id
where c.job_industry_category = 'Health'
  and o.order_status = 'Approved'
  and o.order_date between '2017-01-01' and '2017-03-01'
group by c.customer_id, c.first_name, c.last_name, c.job_industry_category
having count(distinct o.order_id) >= 3
   and sum(oi.quantity * oi.item_list_price_at_sale) > 10000
order by job_industry_category, total_revenue desc;



