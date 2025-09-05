select * from dim_date

SELECT STR_TO_DATE(date_2, '%d-%b-%y') AS dt
FROM electric_vehicle_sales_by_makers ;

UPDATE electric_vehicle_sales_by_makers
SET date_2 = STR_TO_DATE(date_2, '%d-%b-%y')


select * from electric_vehicle_sales_by_makers

select * from electric_vehicle_sales_by_state
----------------------------------------------------------------------------------------------

-- List the top 3 and bottom 3 makers for the fiscal years 2023 and 2024 in terms of the number of 2-wheelers sold.

with mkr_wise_ev as
(
select mkr.maker,
       dt.fiscal_year,
       sum(mkr.electric_vehicles_sold) as ev_sold,
       rank() over(partition by dt.fiscal_year order by sum(mkr.electric_vehicles_sold) desc) as rnk_desc,
       rank() over(partition by dt.fiscal_year order by sum(mkr.electric_vehicles_sold)) as rnk_asc
from electric_vehicle_sales_by_makers mkr
inner join dim_date dt
on mkr.date_2 = dt.date_1
where mkr.vehicle_category = '2-wheelers' and fiscal_year in ('2023','2024')
group by mkr.maker,dt.fiscal_year
)
select *
from mkr_wise_ev
where rnk_desc <= 3 or rnk_asc <=3
------------------------------------------------------------------------------------------------------------------------
-- Identify the top 5 states with the highest penetration rate in 2-wheeler and 4-wheeler EV sales in FY 2024.

with pnr_rt as
(
select st.state, 
	   st.vehicle_category,
       sum(electric_vehicles_sold) as ev_sold,
       sum(total_vehicles_sold) as tv_sold,
       Round(sum(electric_vehicles_sold)*100/sum(total_vehicles_sold),2) as penetration_rt
from electric_vehicle_sales_by_state st
join dim_date dt
on st.date_3 = dt.date_1
where fiscal_year = '2024'
group by st.state, st.vehicle_category
),
ranked_pnr_rt as
(
select *,
       rank() over(partition by vehicle_category order by penetration_rt desc) as rnk_pnr
from pnr_rt
)
select *
from ranked_pnr_rt
where rnk_pnr <= 5
---------------------------------------OR---------------------------------------
with pnr_rt as
(
select st.state, 
	   st.vehicle_category,
       sum(electric_vehicles_sold) as ev_sold,
       sum(total_vehicles_sold) as tv_sold,
       Round(sum(electric_vehicles_sold)*100/sum(total_vehicles_sold),2) as penetration_rt
from electric_vehicle_sales_by_state st
join dim_date dt
on st.date_3 = dt.date_1
where fiscal_year = '2024'
group by st.state, st.vehicle_category
)
(
select *
from pnr_rt 
where vehicle_category = '2-wheelers'
order by penetration_rt desc
limit 5
) 
union 
(
select *
from pnr_rt 
where vehicle_category = '4-wheelers'
order by penetration_rt desc
limit 5
)

--------------------------------------------------------------------------------------------------------------
-- List the states with negative penetration (decline) in EV sales from 2022 to 2024?

with pnr_rt as
(
select st.state, 
	   st.vehicle_category,
       dt.fiscal_year,
       sum(electric_vehicles_sold) as ev_sold,
       sum(total_vehicles_sold) as tv_sold,
       Round(sum(electric_vehicles_sold)*100/sum(total_vehicles_sold),2) as penetration_rt
from electric_vehicle_sales_by_state st
join dim_date dt
on st.date_3 = dt.date_1
group by st.state, st.vehicle_category,dt.fiscal_year
order by state
),
diff_pnr_rt as
(
select state,
       vehicle_category,
       fiscal_year,
       penetration_rt,
       lag(penetration_rt,1)over(partition by state,vehicle_category order by fiscal_year) as prev_pr_rt,
       (penetration_rt -  lag(penetration_rt,1)over(partition by state,vehicle_category order by fiscal_year)) as penetration_trend
from pnr_rt
)
select * 
from diff_pnr_rt
where penetration_trend < 0
order by vehicle_category

------------------------------------------------------------------------------------------------------------------------------------------------------

-- What are the quarterly trends based on sales volume for the top 5 EV makers (4-wheelers) from 2022 to 2024?

with top5_ev_mkr as 
(
select mkr.maker,
       sum(mkr.electric_vehicles_sold) as ev_sold
from electric_vehicle_sales_by_makers mkr
join dim_date dt
on mkr.date_2 = dt.date_1
where mkr.vehicle_category = '4-wheelers'
group by mkr.maker
order by ev_sold desc
limit 5
),
mkrs_with_qtr as
(
select mkr.maker,
       dt.fiscal_year,
       dt.quarter as qtr,
       sum(mkr.electric_vehicles_sold) as ev_sold
from electric_vehicle_sales_by_makers mkr
join dim_date dt
on mkr.date_2 = dt.date_1
where mkr.vehicle_category = '4-wheelers'
group by mkr.maker,dt.fiscal_year,dt.quarter
order by ev_sold desc
)
select maker,
       fiscal_year,
	   sum(case when qtr = 'Q1' then mq.ev_sold end) as q1_sales,
	   sum(case when qtr = 'Q2' then mq.ev_sold end) as q2_sales,
	   sum(case when qtr = 'Q3' then mq.ev_sold end) as q3_sales,
	   sum(case when qtr = 'Q3' then mq.ev_sold end) as q4_sales
from top5_ev_mkr t5
join mkrs_with_qtr mq
using(maker)
group by maker,fiscal_year
order by maker,fiscal_year

--------------------------------------------------------------------------------------------------------------------------------

-- How do the EV sales and penetration rates in Delhi compare to Karnataka for 2024?

select state,
       sum(st.electric_vehicles_sold) as ev_sold,
       sum(st.total_vehicles_sold) as t_v_sold,
       round(sum(st.electric_vehicles_sold)*100/sum(st.total_vehicles_sold),2) as penetration_rt
from electric_vehicle_sales_by_state st
join dim_date dt
on st.date_3 = dt.date_1
where st.state in ('Delhi','Karnataka') 
	  and
      dt.fiscal_year = '2024'
group by state

-----------------------------------------------------------------------------------------------------------------------------------

-- List down the compounded annual growth rate (CAGR) in 4-wheeler units for the top 5 makers from 2022 to 2024.

with e_v_sales as 
(
select mkr.maker,
       dt.fiscal_year,
       sum(mkr.electric_vehicles_sold) as ev_sold
from electric_vehicle_sales_by_makers mkr
join dim_date dt
on mkr.date_2 = dt.date_1
where mkr.vehicle_category = '4-wheelers' and fiscal_year in ('2022','2024')
group by mkr.maker,dt.fiscal_year
order by mkr.maker
),
pivoted_sales as
(
select maker,
       sum(case when fiscal_year = '2022' then ev_sold end) as ev_sales_2022,
       sum(case when fiscal_year = '2024' then ev_sold end) as ev_sales_2024
from e_v_sales 
group by maker
)
select *,
       round((power(ev_sales_2024/ev_sales_2022,0.5))-1,2) as cagr
from pivoted_sales
order by cagr desc
limit 5
------------------------------------------------------------------------------------------------------------------------------------

-- List down the top 10 states that had the highest compounded annual growth rate (CAGR) from 2022 to 2024 in total vehicles sold.
-- CAGR = [(Ending Value / Beginning Value) ** 1/n] -1

with total_v_sales as 
(
select st.state,
       dt.fiscal_year,
       sum(st.total_vehicles_sold) as tv_sold
from electric_vehicle_sales_by_state st
join dim_date dt
on st.date_3 = dt.date_1
where fiscal_year in ('2022','2024')
group by st.state,dt.fiscal_year
order by st.state
),
pivoted_sales as
(
select state,
       sum(case when fiscal_year = '2022' then tv_sold end) as tv_sales_2022,
       sum(case when fiscal_year = '2024' then tv_sold end) as tv_sales_2024
from total_v_sales 
group by state
)
select *,
       round(((power(tv_sales_2024/tv_sales_2022,0.5))-1)*100,2) as cagr
from pivoted_sales
order by cagr desc
limit 10

-----------------------------------------------------------------------------------------------------------------------------------

-- What are the peak and low season months for EV sales based on the data from 2022 to 2024?
with monthly_sales as
(
select month(dt.date_1) as mnth,
	   monthname(dt.date_1) as mnth_name,
       dt.fiscal_year,
       sum(st.electric_vehicles_sold) as ev_sold
from electric_vehicle_sales_by_state st
join dim_date dt
on st.date_3 = dt.date_1
where fiscal_year in ('2022','2024')
group by mnth,dt.fiscal_year,mnth_name
),
yearly_sales_dist as
(
select mnth,
       mnth_name,
	   sum(case when fiscal_year = '2022' then ev_sold end) as ev_sales_2022,
       sum(case when fiscal_year = '2024' then ev_sold end) as ev_sales_2024
from monthly_sales
group by mnth,mnth_name
)
select mnth,
       mnth_name,
       ev_sales_2022,
	   rank()over(order by ev_sales_2022) rnked_mnths_22,
       ev_sales_2024,
       rank()over(order by ev_sales_2024) rnked_mnths_24
from yearly_sales_dist
order by mnth

-------------------------------------------------------------------------------------------------------------------------------------------------
-- What is the projected number of EV sales (including 2-wheelers and 4-wheelers) for the top 10 states by penetration rate in 2030, 
-- based on the compounded annual growth rate (CAGR) from previous years?
-- Projected Sales=Last Year Sales×(1+CAGR) **Years Ahead
with top10_st_by_pnr_rt as
(
select st.state,
       dt.fiscal_year,
	   sum(st.electric_vehicles_sold) as ev_sold,
       sum(st.total_vehicles_sold) as total_v_sold,
       round(sum(st.electric_vehicles_sold)*100/sum(st.total_vehicles_sold),2) as penetration_rt
from electric_vehicle_sales_by_state st
join dim_date dt 
on st.date_3 = dt.date_1
where dt.fiscal_year = '2024'
group by st.state,dt.fiscal_year
order by penetration_rt desc
limit 10
),
cagr_calculation as
(
select st.state,
       dt.fiscal_year,
       sum(st.electric_vehicles_sold) as ev_sold
from electric_vehicle_sales_by_state st
join dim_date dt
on st.date_3 = dt.date_1
where fiscal_year in ('2022','2024')
group by st.state,dt.fiscal_year
order by st.state
),
pivoted_sales as
(
select state,
       sum(case when fiscal_year = '2022' then ev_sold end) as ev_sales_2022,
       sum(case when fiscal_year = '2024' then ev_sold end) as ev_sales_2024
from  cagr_calculation
group by state
),
calculated_cagr as
(
select *,
       round(power(ev_sales_2024/ev_sales_2022,0.5)-1,2) as cagr
from pivoted_sales
order by cagr desc
)
select top10.state,
       round((ccg.ev_sales_2024 * power(1+ccg.cagr,6)),0) as projected_sales_2030,
	   round(round((ccg.ev_sales_2024 * power(1+ccg.cagr,6)),0)/1000000,2) as projected_sales_2030_in_mn
from top10_st_by_pnr_rt top10
join calculated_cagr ccg
on top10.state = ccg.state
order by projected_sales_2030 desc

---------------------------------------------------------------------------------------------------------------------------------------------

-- Estimate the revenue growth rate of 4-wheeler and 2-wheelers EVs in India for 2022 vs 2024 and 2023 vs 2024, assuming an average unit price.
-- 2-wheeler ---> 85000     4-wheeler---> 1500000
with total_electric_vehicles_sold as
(
select dt.fiscal_year,
	   mkr.vehicle_category,
       sum(mkr.electric_vehicles_sold) as ev_sold
from electric_vehicle_sales_by_makers mkr
join dim_date dt
on mkr.date_2 = dt.date_1
group by dt.fiscal_year,mkr.vehicle_category
order by mkr.vehicle_category
),
pivoted_sales as
(
select vehicle_category,
       sum(case when fiscal_year = '2022' then ev_sold end) as ev_sales_2022,
       sum(case when fiscal_year = '2023' then ev_sold end) as ev_sales_2023,
       sum(case when fiscal_year = '2024' then ev_sold end) as ev_sales_2024
from total_electric_vehicles_sold 
group by vehicle_category
)
select vehicle_category,
	   ev_sales_2022,
       ev_sales_2023,
       ev_sales_2024,
       round((ev_sales_2024 - ev_sales_2022)*100/ev_sales_2022,2) as rev_22_vs_24,
	   round((ev_sales_2024 - ev_sales_2023)*100/ev_sales_2023,2) as rev_23_vs_24
from pivoted_sales
group by vehicle_category

--------------------------------------------------------------------------------------------------------------------------------



