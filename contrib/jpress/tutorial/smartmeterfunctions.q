/- Functions to analyze the smartmeter data
/- we have two tables
/- meter contains the output of each meter
/- The output of each meter is the total usage to date, 
/- rather than the usage since the last update 
/- static contains associated static data

/- ---------------------
/- TOTAL USAGE analytics
/- ---------------------

/- Work out the usage of each customer in a given time frame
/- e.g. meterusage[2013.08.10;2013.08.29]
meterusage:{[startdate; enddate]
 
 /- calculate the usage at the start and the end
 start:select first usage by meterid from meter where date=startdate;
 end:select last usage by meterid from meter where date=enddate;
 
 /- subtract the two
 end-start}

/- calculate the meter usage for a given month
/- add in the month field
/- e.g. monthlyusage[2013.08m]
monthlyusage:{[month] 
 `month`meterid xkey 
  select month:month,meterid,usage 
  from meterusage[`date$month; -1+`date$month+1]}

/- calculate the difference in usage between two months for each meter
/- order by absolute difference
/- e.g. monthlychange[2013.08m; 2013.09m]
monthlychange:{[month1;month2]
 
 /- work out how many days are in each month
 month1days:(`date$month1 + 1) - `date$month1;
 month2days:(`date$month2 + 1) - `date$month2;
 
 /- join the two monthly usage stats together
 t:(select meterid,month1dailyusage:usage%month1days from monthlyusage[month1]) 
    lj 
    `meterid xkey select meterid,month2dailyusage:usage%month2days from monthlyusage[month2];
  
 /- add in the monthly change
 t:update change:month2dailyusage - month1dailyusage from t;
 
 /- add in a temporary absolute change column, 
 /- sort on it, then delete it
 delete abschange 
  from `abschange xdesc 
   update abschange:abs change from t}

/- total monthly usage by customer type
/- operate over a list of months
/- e.g. monthlyusagebycusttype[2013.08 2013.09m]
monthlyusagebycusttype:{[months] 
 select sum usage by month,custtype 
 from 
  (raze monthlyusage peach months,:()) 
  lj 
  `meterid xkey select meterid,custtype from static}

/- Generate a pivot table with the % usage of each customer type in each region
/- http://code.kx.com/wiki/Pivot
/- e.g. meterusagepivot[2013.08.01;2013.08.31;1b]
meterusagepivot:{[startdate;enddate;aspercent]
 t:meterusage[startdate;enddate];
 
 /- join on the static data
 t:t lj static;
 
 /- Calculate the total usage for each grouping
 t:select sum usage by custtype,region from t;
 
 /- Convert to % values
 if[aspercent;t:update usage:100*usage%sum usage from t];
 
 /- pivot the data to have the regions as row ids
 /- and the customer types as the column headers
 C:asc exec distinct custtype from t;
 t1:exec C#custtype!usage by region:region from t;
 
 /- fill the pivot table with 0s
 0^t1}

/- For every customer on every day within the date range, 
/- calculate the n (daycount) day moving average of usage.
/- Compare each days usage to the moving average, and flag it if it is
/- > rangecheck away from the moving average
/- e.g. meterusagejump[2013.08.01;2013.08.31;20;100]
meterusagejump:{[startdate;enddate;daycount;rangecheck]
 /- pull out the daily starting values
 t:select first usage by date,meterid from meter where date within (startdate;enddate);

 /- calculate the daily usage
 t:update usage:next deltas usage by meterid from t;

 /- add the moving average
 t:update mavgusage:daycount mavg usage by meterid from t;

 /- pull out the rows which are outside the range check
 select from t where rangecheck < abs 100*1 - usage % mavgusage}



/--------------------------
/- TIME PROFILING analytics
/--------------------------

/- Build a usage profile for a given set of meterids
/- The meterids can then be used to profile a customer type, region etc.
/- The usage profile is bucketed into discrete time buckets
/- The appropriate size will depend on the sample period of the data that was built
/- The default sampling is 15 minutes
/- e.g. groupusage[2013.08.01; 2013.08.31; 100000 100001; 15]
groupusage:{[startdate; enddate; meterids; timebucket]
 /- To get the usage of a group of ids, we can just calculate a sum 
 /- of all the usage statistics within the bucket 
 /- then compare with the previous bucket
 /- use ` as a wildcard to calculate across all customers
 t:$[meterids~`;
	select first usage 
	by date,(timebucket*0D00:01) xbar time
	from meter where date within (startdate;enddate);
	select sum usage 
	by date,(timebucket*0D00:01) xbar time 
	from meter where date within (startdate;enddate),meterid in meterids]; 

 /- The usage within each bucket is then the difference between the current
 /- bucket and the next bucket
 t:update usage:deltas usage from t;
 
 t}

/- Use groupusage to generate a daily average profile
/- i.e. over a given set of days,
/- calculate the average usage within each time period
/- e.g. dailyaverageprofile[2013.08.01; 2013.08.31; 100000 100001; 15]
dailyaverageprofile:{[startdate;enddate;meterids;timebucket]
 
 /- get the usage stats for the group
 t:groupusage[startdate;enddate;meterids;timebucket];
 
 /- For the profile we then calculate the average and peak 
 /- of the time buckets across the days
 select avgusage:avg usage
 by time:`timespan$timebucket xbar time.minute
 from t}

/- compare a profile for a set of ids
/- to a specific date for a (possibly different) set of ids
comparetoprofile:{[startdate;enddate;meterids;timebucket;comparestartdate;compareenddate;compareids]
 update difference:avgusage - compareusage 
 from 
  dailyaverageprofile[startdate;enddate;meterids;timebucket]  
  lj
  `time xkey 
   select time,compareusage:avgusage 
   from dailyaverageprofile[comparestartdate;compareenddate;compareids;timebucket]}

customertypeprofiles:{[startdate;enddate;timebucket]
 /- Calculate the total usage in each bucket
 t:select sum usage
   by date,custtype:(exec meterid!custtype from static)[meterid], (timebucket*0D00:01) xbar time
   from meter where date within (startdate;enddate);
 
 /- Calculate the usage by getting the diff with the next usage
 t:update deltas usage
   by custtype 
   from t;
 
 /- Calculate the average across the days
 /- reduce the time to a timespan 
 t:select avg usage
   by custtype, `timespan$time
   from t;

 /- Pivot the table
 C:asc exec distinct custtype from t;
 exec C#custtype!usage by time:`timestamp$2000.01.01+time from t}

/----------------------------------
/- DAILY STATISTICS
/----------------------------------

/- daily analysis for each customer
/- e.g. dailystats[2013.08.01;2013.08.10]
dailystats:{[startdate;enddate]
 /- use the inner select to only calculate the usage in each time bucket only once
 select date,meterid,usage, peakrate:max each allrates, 
        minrate:min each allrates, avgrate:avg each allrates 
 from 
  select usage:(last usage) - first usage, allrates:1 _ deltas usage 
  by date,meterid 
  from meter 
  where date within (startdate;enddate)}

/- same as dailystats but optimized for slave usage
dailystatsoptimized:{[startdate;enddate]
  select usage:(last usage) - first usage, stats:{(max;min;avg)@\:1 _ deltas x}usage
  by date,meterid
  from meter
  where date within (startdate;enddate)}

/---------
/- BILLING
/---------

/- define a pricing table
/- different customer types have different pricing schedules
pricing:([custtype:`res`com`ind] time:(00:00 08:00 11:15 12:00 17:00 18:00 22:15;
 			               00:00 09:00 17:00 20:00;
  			               00:00 08:00 17:00);
		                 price:(0.6 1.2 1.1 1.0 1.1 1.4  0.6;
			                0.6 0.9 0.8 0.6;
			                0.4 0.6 0.4));

/- Calculate the usage for every customer in every pricing period
/- e.g. usageperperiod[2013.08.01;2013.08.10]
usageperperiod:{[startdate;enddate]
  
 /- build a table containing the meter ids and the bill sample times
 /- need to sample the data 1 minute after the billing time
 samples:ungroup(select meterid,custtype from static)
 	         lj 
                 update time+1 from pricing; 

 /- get the list of dates between the start date and end date
 datelist:startdate + til 1+enddate - startdate;
 
 /- use aj (asof join) to build up a table of usage info at each price point 
 t:raze {[samples;d] 
  aj[`meterid`time;
     update time:time+d from samples;
     select time,meterid,usage from meter where date=d]}[samples] peach datelist;

 /- calculate the usage in each period
 update usage:next deltas usage by meterid from t}

/- Calculate the bill for every meter
/- e.g. bill[2013.08.01;2013.08.10]
bill:{[startdate;enddate]
 select cost:sum price*usage by meterid from usageperperiod[startdate;enddate]}
 
/- Calculate the usage and cost for each different priced unit for every meter
/- e.g. usageperprice[2013.08.01;2013.08.10] 
usageperprice:{[startdate;enddate]
 select sum usage,cost:sum price*usage 
 by meterid,price 
 from usageperperiod[startdate;enddate]}

/-----------
/- Utilities
/-----------

/- Get the meter ids for a (set of) customertypes or regions
custids:{exec meterid from static where custtype in x}
regionids:{exec meterid from static where region in x}
