  -- Imported the data as imi_2020_all via import and export wizard
  /*checking the imported table*/
SELECT TOP (1000) [YEAR]
      ,[COUNTY]
      ,[HOSPITAL]
      ,[OSHPDID]
      ,[Procedure/Condition]
      ,[Risk Adjuested Mortality Rate]
      ,[# of Deaths]
      ,[# of Cases]
      ,[Hospital Ratings]
      ,[LONGITUDE]
      ,[LATITUDE]
  FROM [imi].[dbo].[imi_2020_all]


  -- STEP A: DATA CLEANING

  -- 1) creting a new temp table "imi_2020" to omit the rows containing the statewide results, thereby only having the results at county level

  --if OBJECT_ID ('imi_2020', 'U') is NUll
  
  drop table if exists imi_2020
  create table imi..imi_2020
  (
  [year] INT NOT NULL,
    county nvarchar (40) NOT NULL,
    hospital nvarchar(100),
    osphdid INT,
    [procedure/condition] nvarchar(255),
    risk_adjusted_mortality_rate float ,
    number_of_deaths INT,
    number_of_diagnosed_cases INT,
    hospital_ratings varchar(40),
    longitude DECIMAL( 9,6 ),
    latitude DECIMAL( 8,6));

	Insert into imi.dbo.imi_2020
	select * from imi..imi_2020_all
	where HOSPITAL != 'STATEWIDE' ;

	 /*checking the newly created table*/
	SELECT TOP (1000)* from imi.dbo.imi_2020
	order by 1,2;

  
  --2) Filling out nulls
  /*hospital rating=none,
  number_of_deaths= 0,
  number_of_diagnosed_cases= 0,
  risk_adjusted_mortality_rate = 0
   */
   update imi..imi_2020
 set hospital_ratings = isnull(hospital_ratings, 'none'),
 number_of_deaths = isnull(number_of_deaths, 0),
  number_of_diagnosed_cases = isnull(number_of_diagnosed_cases, 0);

   -- using a different method to update NULLS

   update imi..imi_2020
   set
  risk_adjusted_mortality_rate =  0
  where risk_adjusted_mortality_rate is NULL ;

/* checking up the changes in the table*/

  SELECT TOP (1000)* from imi.dbo.imi_2020
	order by 1,2;

  --3) Creating two separate columns to house the name of the hospital, and the the campus location, if present
  /* among the 318 California-licensed hospitals, a few of them have been named using a different convention. 
  I will filter these out from the first query and work on them in the subsequent one. The hsopitals are:

  -all "Adventist Health" hospitals where the campus location has not been seperated out with a hyphen (-).
  -"Emanate Health Inter - Community Hospital" where we have a hyphen to distinguish the "intercommunity" instead of any campus location.
  -"Riverside University Health System – Medical Center" where we have a hyphen to distinguish the "medical center" instead of any campus location.*/

/* method 1 - using charindex and substring functions*/
-- encountered issue with "long dash(em dash)" and "short dash(en dash)" used variably in different hospital names
-- did not use coalesce as Case statement can work for 3 scenarios simultaneously i.e. small -, large - , and no – while coalesce cannot

 select *,
 case
 -- with "long dash(em dash)" 
 when CHARINDEX ( '–', hospital)!=0
 then SUBSTRING (hospital, 1,CHARINDEX ( '–', hospital)-1)
 -- with "em dash(en dash)"
 when CHARINDEX ( '-', hospital)!=0
 then SUBSTRING (hospital, 1,CHARINDEX ( '-', hospital)-1)
 -- else case for conditions when no "-" is present
 else hospital
 end as hospital_name
 from imi.dbo.imi_2020
 where hospital not like 'Adventist Health%'
AND hospital not like 'Emanate Health%'
AND hospital not like 'Riverside University Health%'
order by 1,2;

-- creating column for campus_name
 select * , 

 case
 when CHARINDEX ( '–', hospital)!=0
 then SUBSTRING(hospital, (charindex('–', hospital)+1), LEN(hospital) )
 when CHARINDEX ( '-', hospital)!=0
 then substring(hospital, (CHARINDEX ( '-', hospital)+1), LEN(hospital))
 else 'none'
 end as campus_name
 from imi.dbo.imi_2020
 where hospital not like 'Adventist Health%'
AND hospital not like 'Emanate Health%'
AND hospital not like 'Riverside University Health%'
order by 1,2;

 /* adding two columns in the imi_2020 table for storing the induvidual values of hospital name and the campus*/
 ALTER table imi.dbo.imi_2020
 add hospital_name nvarchar(200) ,
  campus_name nvarchar(200)  ;

   --making column as "not null"
--  alter table imi.dbo.imi_2020
--  alter column hospital_name nvarchar(200) not null
--  alter table imi..imi_2020
--alter column campus_name nvarchar(200) not null;
 
 exec sp_columns imi_2020 ;

 

 --Updating the campus_name column in the imi_2020 column

 update imi.dbo.imi_2020
set campus_name= subquery.camp
from (
 select  
 osphdid,
 case
 when hospital = 'Emanate Health Inter - Community Hospital'
 then 'none'
 when hospital ='Riverside University Health System – Medical Center'
 then 'none'
 when CHARINDEX ( '–', hospital)!=0
 then SUBSTRING(hospital, (charindex('–', hospital)+1), LEN(hospital) )
 when CHARINDEX ( '-', hospital)!=0
 then substring(hospital, (CHARINDEX ( '-', hospital)+1), LEN(hospital))
 else 'none'
 end as camp
 from imi.dbo.imi_2020
 where hospital not like 'Adventist Health%'
AND hospital NOT LIKE 'Southern California Hospital at%' 
 AND hospital NOT  LIKE 'Mercy Medical Center Mt. Shasta') as subquery
where imi_2020.osphdid = subquery.osphdid;

/* checking up the changes in the table*/
  SELECT TOP (1000)* from imi.dbo.imi_2020
	order by 1,2

-- updating the hospital_name in the same way
	UPDATE imi.dbo.imi_2020	
	set hospital_name= subquery2.hosp
	from
	(select 
	osphdid, 
 case
when hospital like 'Emanate Health%'
then hospital
when hospital like 'Riverside University Health%'
then hospital
 when CHARINDEX ( '–', hospital)!=0
 then SUBSTRING (hospital, 1,CHARINDEX ( '–', hospital)-1)
 when CHARINDEX ( '-', hospital)!=0
 then SUBSTRING (hospital, 1,CHARINDEX ( '-', hospital)-1)
 else hospital
 end as hosp
 from imi.dbo.imi_2020
 where hospital not like 'Adventist Health%'
 AND hospital NOT LIKE 'Southern California Hospital at%' 
 AND hospital NOT  LIKE 'Mercy Medical Center Mt. Shasta'
) as subquery2
where imi_2020.osphdid = subquery2.osphdid

/* checking up the changes in the table*/
  SELECT TOP (1000)* from imi.dbo.imi_2020
	order by 1,2;

-- lastly, dealing with the exceptions listed out, with either the RIGHT and the RTRIM function, that works on the same logic as substring function

	select RIGHT(hospital, len(hospital)-17)
	from imi.dbo.imi_2020
	where hospital LIKE  'Adventist Health%' 
	

	select RIGHT(hospital, len(hospital)-29)
	from imi.dbo.imi_2020
	where hospital LIKE  'Southern California Hospital at%'

select RIGHT(hospital, len(hospital)-21)
	from imi.dbo.imi_2020
	where hospital LIKE  'Mercy Medical Center Mt. Shasta'
	-- updating the campus name for"Adventist Health%", "Southern California Hospital%" and "Mercy Medical Center Mt. Shasta" where the campus name are not prefixed by a hyphen (-)
	update imi.dbo.imi_2020
	set campus_name = subquery3.camp
	from
	(select  osphdid,
	case
	when hospital LIKE  'Adventist Health%'
	then RIGHT(hospital, len(hospital)-17)
	when hospital LIKE  'Southern California Hospital at%'
	then RIGHT(hospital, len(hospital)-32)
	when hospital LIKE  'Mercy Medical Center Mt. Shasta'
	then RIGHT(hospital, len(hospital)-21)
	end as camp
	from imi.dbo.imi_2020
	WHERE hospital like 'Adventist Health%'
OR hospital  like 'Southern California Hospital at%'
OR hospital like 'Mercy Medical Center Mt. Shasta') subquery3
where  imi_2020.osphdid = subquery3.osphdid


	--updating the hospital name for"Adventist Health%", "Southern California Hospital%" and "Mercy Medical Center Mt. Shasta" where the campus name are not prefixed by a hyphen (-)

update imi.dbo.imi_2020

	set hospital_name = subquery4.hosp
	from
	(select  osphdid,
	case
	when hospital LIKE  'Adventist Health%'
	then LEFT(hospital, 18)
	when hospital LIKE  'Southern California Hospital at%'
	then LEFT(hospital, 30)
	when hospital LIKE  'Mercy Medical Center Mt. Shasta'
	then LEFT (hospital, 22)
	end as hosp
	from imi.dbo.imi_2020
	where hospital like 'Adventist Health%'
 OR hospital  like 'Southern California Hospital at%'
OR hospital like 'Mercy Medical Center Mt. Shasta')as subquery4
	where imi_2020.osphdid = subquery4.osphdid
	
	-- renaming column hospital for ease of use

	use imi
	exec sp_rename 'dbo.imi_2020.hospital', 'hospital_full_name' ;