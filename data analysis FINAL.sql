
 --STEP 2: data analysis

--PART 0
--Calculate the average Risk Adjusted Rate (RAR) for each hospital with a having clause
use imi
go
drop view if exists  overall_rar
go
create view overall_rar as
(
select hospital_full_name, hospital_name, campus_name, osphdid, county, 
AVG(risk_adjusted_mortality_rate) average_rar
from imi..imi_2020
GROUP BY osphdid, hospital_full_name, hospital_name, campus_name, county)
--order by county;

 -- PART I
 --Which hospital should you avoid in California based on your procedure/condition?
  select distinct [procedure/condition], MAX(risk_adjusted_mortality_rate) over(partition by [procedure/condition])as max_rar,
  MIN(risk_adjusted_mortality_rate)over(partition by [procedure/condition]) as min_rar 
  from imi.dbo.imi_2020


select [procedure/condition], max(case when max_rar = risk_adjusted_mortality_rate then hospital_full_name end) as max_hospital_full_name,
MAX(case when max_rar = risk_Adjusted_mortality_rate then osphdid end) as osphdid, max_rar
--min(case when min_rar = risk_adjusted_mortality_rate then hospital_full_name end) as min_hospital_full_name,  min_rar
from 
(
select 
MAX(risk_adjusted_mortality_rate) over (partition by[procedure/condition]) as max_rar,
MIN(risk_adjusted_mortality_rate) over (partition by[procedure/condition]) as min_rar,*
from imi.dbo.imi_2020
) as subquery1
group by [procedure/condition], max_rar, min_rar



  -- PART II
 --What is the worst performing indicator of each hospital?

select distinct hospital_full_name, MAX(risk_adjusted_mortality_rate) over(partition by hospital_full_name )as max_rar,
  MIN(risk_adjusted_mortality_rate)over(partition by [procedure/condition]) as min_rar 
  from imi.dbo.imi_2020
  order by hospital_full_name


use imi
go
drop view  if exists view_of_hosp
go
create view view_of_hosp as
(
select  hospital_full_name, osphdid, hospital_name, campus_name, 
max(case when max_rar_of_hospital = 0 then 'NO deaths recorded for any indicator and max_rar_of_hospital=min_rar_of_hospital= 0'
when max_rar_of_hospital = risk_adjusted_mortality_rate then[procedure/condition]end) as max_rar_procedure,max_rar_of_hospital
--min(case when min_rar_of_hospital = risk_adjusted_mortality_rate then [procedure/condition]end) as min_rar_procedure,  min_rar_of_hospital
from
(
select  
MAX(risk_adjusted_mortality_rate) over (partition by hospital_full_name) as max_rar_of_hospital, 
MIN(risk_adjusted_mortality_rate) over (partition by hospital_full_name) as min_rar_of_hospital, *
from imi_2020
)as subquery2
group by  hospital_full_name,osphdid, hospital_name, campus_name, max_rar_of_hospital,min_rar_of_hospital)
--order by hospital_full_name

--III
-- Count of various types of hospital ratings for each hospital

with CTE1  as
(  select hospital_full_name, osphdid, hospital_name, campus_name,
SUM(case when hospital_ratings = 'none' then 1 else 0 end) [none],
sum (case when hospital_ratings = 'As Expected' then 1 else 0 end) as_expected,
SUM(case when hospital_ratings= 'better' then 1 else 0 end) better,
sum(case when hospital_ratings = 'worse' then 1 else 0 end) worse
from imi_2020
group by hospital_full_name, osphdid, hospital_name, campus_name)

-- finding out average rating for each hospital

select hospital_full_name, osphdid, hospital_name, campus_name,
case when none> as_expected and none>better and none>worse then 'none'
when as_expected>=none and as_expected>=better and as_expected>=worse then 'as expected'
when better>= none and better>=as_expected and better>= worse then 'better'
else 'worse'
end as average_rating
from CTE1


--IV  top worse and better performers
use imi
go
drop view  if exists count_of_better
go
create view count_of_better as
(

select
--distinct
hospital_full_name, osphdid, hospital_name, campus_name,
COUNT  (hospital_ratings) over(partition by hospital_full_name order by hospital_full_name) as count_of_better
from imi_2020
where hospital_ratings='better'
--order by count_of_better desc
)
-- count of better rated indicators for each hospital


select distinct i20. hospital_full_name, i20.osphdid, i20.hospital_name, i20.campus_name, isnull(count_of_better, 0)
from imi_2020 i20
left join count_of_better cob on i20.osphdid=cob.osphdid

use imi
go 
drop view if exists count_of_worse
go
create view count_of_worse as
(
select 
--distinct
hospital_full_name, osphdid, hospital_name, campus_name,
COUNT  (hospital_ratings) over(partition by hospital_full_name) as count_of_worse
from imi_2020
where hospital_ratings='worse'
--order by  count_of_worse desc
)


--Count of worse rated indicators for each hospital
SELECT distinct i20.county, i20.hospital_name, i20.campus_name, i20.hospital_full_name, i20.osphdid, overall_rar.average_rar, 
longitude, latitude, voh.max_rar_procedure, ISNULL( cob.count_of_better, 0) no_of_better
, ISNULL(cow.count_of_worse, 0) no_of_worse
  FROM [imi].[dbo].[imi_2020] i20
  join view_of_hosp voh on i20.osphdid = voh.osphdid 
  join overall_rar on i20.osphdid= overall_rar.osphdid
 left  join count_of_better cob on i20.osphdid= cob.osphdid
  left  join count_of_worse cow on i20.osphdid= cow.osphdid
  
  order by 1,2,3

-- V 
--get the number of better and worse performing hospitals for each indicator for Tableau

select i20.[procedure/condition],
SUM (case when hospital_ratings = 'better' then 1 else 0 end) count_of_better,
sum (case when hospital_ratings = 'worse' then 1 else 0 end) count_of_worse
from imi_2020 i20
group by [procedure/condition]