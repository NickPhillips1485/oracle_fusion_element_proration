# oracle_fusion_element_proration
As I'll soon be starting a new role as an Oracle Fusion Payroll Consultant, I wanted to practice some of the required skills. In this mini project
I'll be creating a new version of the GLB_EARN_PRORATION Fast Formula and then using the configuration options to associate it with a regular earnings element.
The out-of-the-box proration functionality uses a calendar days pro-ration method, so for this exercise I'll be amending this to use the working days method. 

## Scenario
Note: The employee data used in this project is entirely fictional and sourced from a development environment. It does not represent any real individuals or
sensitive information. This data is strictly for testing and development purposes only.

The employee (person number 91842) is being paid an element entry called housing allowance uk. The payment for one full calendar month is £3,100.00
The element uses the seeded proration:
Proration Group: Entry Changes for Proration
Proration Formula: GLB_EARN_PRORATION

I ended the element effective 15-Mar-2026, which meant for that month 15 days were payable according to the calendar days method: £3100 / 31 x 15 = £1500
A quick pay was run to validate this result. 

The scenario I'm using for this exercise is that the client wants to change the pro-ration method to working days, which in this case would equate to:
£3100 / 22 x 10 = £1409.09

## Steps
The first step was to take a copy of the GLB_EARN_PRORATION proration formula and create a new version, of formula type 'Payroll Run Proration'. Ensure the
formula has a 01-01-0001 effective date and do not associate it with an LDG. I named the new formula GLB_EARN_PRORATION_HOUSING2.

I identified this section of the formula as that which controlled the proration calculation in a standard scenario such as a mid-month end date:

```
 l_total_days = days_between(PAY_EARN_PERIOD_END, PAY_EARN_PERIOD_START ) + 1
 l_days = days_between(prorate_end , prorate_start) + 1
 l_value = (l_value / l_total_days) * l_days
 ```

Clearly the days_between function is counting all calendar days when determining l_total_days (31) and l_days (15).
I found a function called GET_WORKING_DAYS

I hoped that it would be simple as switching out the days_between function for the get_working_days function, i.e. 

 l_total_days = get_working_days(PAY_EARN_PERIOD_END, PAY_EARN_PERIOD_START ) + 1
 l_days = days_between(prorate_end , prorate_start) + 1
 l_value = (l_value / l_total_days) * l_days

The formula compiled successfully but the quick pay went into error:

Formula GLB_EARN_PRORATION_HOUSING2, line 230, a number was divided by zero while running the formula.

This suggests it was extracting a zero value for l_total days. I couldn't see a way around this and nearly gave up but in the end decided on a solution which
hard-coded those dates. Admittedly this wouldn't be acceptable for a production solution as those dates would need to be called dynamically, but it was the best I could do.  

/* Debugging: Assign specific dates for March */
```l_first_day_of_month = to_date('2026-03-01', 'YYYY-MM-DD')
   l_last_day_of_month = to_date('2026-03-31', 'YYYY-MM-DD')```

```
l_total_working_days = GET_WORKING_DAYS(l_first_day_of_month, l_last_day_of_month)
         l_days = get_working_days(prorate_start, prorate_end)
		 l_value = (l_value / l_total_working_days) * l_days```


The revised formula was added to the element setup:
Proration Group: Entry Changes for Proration
Proration Formula: GLB_EARN_PRORATION_HOUSING2

When I re-ran the quick pay, this code produced the correct value pro-rated on working days, £3100 / 22 x 10 = £1409.09

## Challenges
Aside from the issues described above, other problems I encountered were: 
- The first time I tried to associate the new formula with the element setup, it was not available to select in the dropdown. To resolve this I had to re-create the formula ensuring it was not linked to an LDG, and that formula creation effective date was 01-01-0001.
- When I initially ran the final code, it did not error anymore (indicating the hardcoding had worked) but it produced a £0.00 outcome on the SOE, suggesting the l_days variable had a zero value. I noticed the arguments appeared to be the wrong way around l_days = get_working_days(prorate_end, prorate_start), so I changed them to l_days = get_working_days(prorate_start, prorate_end), which worked. But this is confusing because the original seeded version of the formula had them the wrong way around, and that worked. Does the days_between function require last date then first date whereas get_working_days needs first_date then last_date?
- The various issues would have been alot easier to overcome if I could have relied on some logging, but I could not extract the log files from this environment, which needs investigating. 

## Summary
- Overall I'm pleased to have arrived at a solution, and I should be able to leverage this knowledge when starting my new role; but it is not a perfect solution as the period start and end dates were hardcoded rather than called dynamically. I need to get to the bottom of why the get_working_days function could not determine the number of days in the period. 

The code files and output screenshots are saved in the repo. 