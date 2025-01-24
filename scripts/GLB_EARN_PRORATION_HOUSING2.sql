/********************************************************************************
*                                                                               *
* FORMULA NAME: GLB_EARN_PRORATION                                              *
*                                                                               *
* FORMULA TYPE:Payroll Run Proration                                            *
*                                                                               *
*Description : Formula to calculate pro rated amounts                           *
*                                                                               *
* A typical example                                                             *
* of proration would be when a new employee starts work in the middle of a      *
* monthly payroll period and your payroll department makes a pro-rata payment   *
* to reflect the proportion of monthly pay to which the employee is entitled.   *
*                                                                               *
*                                                                               *
*  Change History                                                               *
*  ---------------                                                              *
*                                                                               *
*  Who        Date       Description                                            *
*  ---------- ---------- --------------------------------------                 *
*  vdharmap   24-Jul-2012  Created                                              *
*  vdharmap   16-Dec-2013  Added proration options                              *
*                                                                               *
*********************************************************************************/

/* Database Item Defaults */
default for prorate_start is '0001/01/01 00:00:00' (date)
default for prorate_end is '0001/01/01 00:00:00' (date)
default for PAY_EARN_PERIOD_START is '0001/01/01 00:00:00' (date)
default for PAY_EARN_PERIOD_END is '0001/01/01 00:00:00' (date)
default for pay_value is 0.0
default for hours_worked is 0.0
default for days_worked is 0.0
default for proration_unit is 'Hourly'
default for EARNED_DATE is '0001/01/01 00:00:00' (date)

Default for ee_id  is 0
default for PAYROLL_PERIOD_TYPE is 'PRD'

inputs are  prorate_start (date),
            prorate_end (date),
            pay_value (number),
            hours_worked (number),
      days_worked(number),
      proration_unit(text)


l_calculated_rate = 0
l_multiple = 0
l_proration_method = 'X'

l_prorate_rate_formula = 'X'
l_workunit_rate_formula = 'X'
l_target_periodicity = 'X'   /* to cover for existing element formulas, that don't pass these values */
l_source_periodicity = 'X'
l_unit_type = 'X'
l_ee_units_entered = 0 /* units entered by end user in the EE, applicable only for Unit Rate element */

if (proration_unit='Hourly') then 
  (
    proration_unit='ORA_WORKHOUR'
  )
l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT)Entered the Proration Formula')
l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) pay value= '||to_char(pay_value))
l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) Initial hours : '||TO_CHAR(hours_worked))  
l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) Initial days : '||TO_CHAR(days_worked))  
l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) Initial proration unit : '|| proration_unit)  
/* Key Variable values retrival*/



l_payroll_rel_action_id  = GET_CONTEXT(PAYROLL_REL_ACTION_ID, 0)

 IF l_payroll_rel_action_id = 0 THEN
(
   l_msg      = GET_MESG('HRX','HRX_USETE_CONTEXT_NOT_SET','CONTEXT','PAYROLL_REL_ACTION_ID')
   l_dummy = PAY_LOG_ERROR(l_msg)
/*   dummy = 1 */
   /* Formula must error out at this point */
)


  ee_id = GET_CONTEXT(ELEMENT_ENTRY_ID,0)
  IF ee_id = 0 THEN
  (
    log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) - Element Entry Id context not set')
    mesg = 'Element Entry Id context is not set.'
    Return mesg
   )


    IF (WSA_EXISTS('unit_type','TEXT_NUMBER')) THEN
    (
      wsa_unit_type = WSA_GET('unit_type', EMPTY_TEXT_NUMBER)
      IF wsa_unit_type.EXISTS(ee_Id) THEN
      (  l_unit_type = wsa_unit_type[ee_Id] )
    )
  l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) unit type is : '|| l_unit_type)  
    IF (WSA_EXISTS('proration_method','TEXT_NUMBER')) THEN
    (
      wsa_proration_method = WSA_GET('proration_method', EMPTY_TEXT_NUMBER)
      IF wsa_proration_method.EXISTS(ee_Id) THEN
      (  l_proration_method = wsa_proration_method[ee_Id] )
    )

  /* for ADD REPORT WORK UNIT CHECK BEFORE REDUCE REGULAR */
    GLB_REPORT_UNIT_KEY = 'REPORT_UNIT_'||entry_level||'-'||TO_CHAR(ee_Id)||'-'|| TO_CHAR(l_payroll_rel_action_id)
    l_report_unit = WSA_GET(GLB_REPORT_UNIT_KEY, 'X')
  l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) l_report_unit is : '|| l_report_unit)


   IF (WSA_EXISTS('PRORATION_CONVERSION_RULE','TEXT_NUMBER')) THEN
    (
      was_proration_rate_formula = WSA_GET('PRORATION_CONVERSION_RULE', EMPTY_TEXT_NUMBER)
      IF was_proration_rate_formula.EXISTS(ee_Id) THEN
      (  l_prorate_rate_formula = was_proration_rate_formula[ee_Id] )
    )


  l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) proration rate conversion formula: '|| l_prorate_rate_formula)  

   IF (WSA_EXISTS('WORK_UNITS_CONVERSION_RULE','TEXT_NUMBER')) THEN
    (
      was_workunit_rate_formula = WSA_GET('WORK_UNITS_CONVERSION_RULE', EMPTY_TEXT_NUMBER)
      IF was_workunit_rate_formula.EXISTS(ee_Id) THEN
      (  l_workunit_rate_formula = was_workunit_rate_formula[ee_Id] )
    )


    l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) workunit rate conversion formula: '|| l_workunit_rate_formula)  

if (l_unit_type <> 'X' ) then  /* for Unit X Rate element, get the inputs */
  ( IF (WSA_EXISTS('multiple','NUMBER_NUMBER')) THEN
    (
      wsa_multiple = WSA_GET('multiple',EMPTY_NUMBER_NUMBER)
      IF wsa_multiple.EXISTS(ee_Id) THEN
      (  l_multiple = wsa_multiple[ee_Id] )
     )

    IF (WSA_EXISTS('calculated_rate','NUMBER_NUMBER')) THEN
    (
      wsa_calculated_rate = WSA_GET('calculated_rate',EMPTY_NUMBER_NUMBER)
      IF wsa_calculated_rate.EXISTS(ee_Id) THEN
      (  l_calculated_rate = wsa_calculated_rate[ee_Id] )
     )
  IF (WSA_EXISTS('ee_units_entered','NUMBER_NUMBER')) THEN
    (
      wsa_ee_units_entered = WSA_GET('ee_units_entered',EMPTY_NUMBER_NUMBER)
      IF wsa_ee_units_entered.EXISTS(ee_Id) THEN
      (  l_ee_units_entered = wsa_ee_units_entered[ee_Id] )
     )
    IF (WSA_EXISTS('source_periodicity','TEXT_NUMBER')) THEN
    (
      wsa_source_periodicity = WSA_GET('source_periodicity', EMPTY_TEXT_NUMBER)
      IF wsa_source_periodicity.EXISTS(ee_Id) THEN
      (  l_source_periodicity = wsa_source_periodicity[ee_Id] )
    )

    IF (WSA_EXISTS('target_periodicity','TEXT_NUMBER')) THEN
    (
      wsa_target_periodicity = WSA_GET('target_periodicity', EMPTY_TEXT_NUMBER)
      IF wsa_target_periodicity.EXISTS(ee_Id) THEN
      (  l_target_periodicity = wsa_target_periodicity[ee_Id] )
    )
 )

l_hours = 0.0   
l_days_worked=0        
l_value = pay_value

IF (prorate_start was not defaulted) then
(
  l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) Porate start  : '||to_char(prorate_start))
  l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) Porate end  : '||to_char(prorate_end))

   /* to cover for payroll transfer case */
   l_prorate_start = greatest(prorate_start, pay_earn_period_start)
   l_prorate_end = least(prorate_end, pay_earn_period_end)

  if (l_prorate_rate_formula = 'ORA_ANNUAL_STD_WORK_HOURS' or l_prorate_rate_formula = 'ORA_ANNUAL_WORK_HOURS' or l_prorate_rate_formula = 'ORA_PERIOD_WORK_SCHED_RATE' or l_prorate_rate_formula = 'ANNUALIZED RATE CONVERSION' or l_prorate_rate_formula = 'DAILY RATE CONVERSION') then
  (

        l_prorate_name='ORA_RATE_CONV_PRORATE'
  )

  else 
    ( 
    l_prorate_name=l_prorate_rate_formula||'_PRORATE'
    if (IS_EXECUTABLE(l_prorate_name)) THEN
     (
      l_prorate_name=l_prorate_rate_formula||'_PRORATE'
     )
     else 
     (

      l_prorate_name = 'ORA_RATE_CONV_PRORATE'
     )

  )

   IF(l_prorate_rate_formula <> 'X' ) then (
    /* for new created element proration calculation  */
  l_source_periodicity=PAYROLL_PERIOD_TYPE

     CALL_FORMULA(l_prorate_name,
                               prorate_start > 'PRORATE_START_DATE',
                               prorate_end > 'PRORATE_END_DATE', 
                 l_source_periodicity > 'SOURCE_PERIODICITY', 
                               l_prorate_rate_formula>'RATE_CONV_FORMULA',
                 l_workunit_rate_formula > 'WORKUNIT_CONV_FORMULA',
                hours_worked > 'HOURS_WORKED',
                days_worked > 'DAYS_WORKED',
                 pay_value > 'IN_AMOUNT', 
                proration_unit>'PRORATION_UNIT',
                l_unit_type > 'UNIT_TYPE',
                 l_value < 'PRORATE_AMOUNT' DEFAULT 0,
                 l_hours < 'PRO_HOURS' DEFAULT 0,
                 l_days_worked < 'PRO_DAYS' DEFAULT 0)


   )
   else (
    /* for existing element deal with proration calculation */
   IF (l_unit_type = 'X' ) THEN
      ( /* Flat amount and Percentage formula */    
      if (l_proration_method = 'CDAYS_VRATE' or l_proration_method = 'X' ) THEN
                 /* either it is Calendar days variable rate proration, or existing element
                          without proration method specified */
        (
		
		/* Debugging: Assign specific dates for March */
		l_first_day_of_month = to_date('2026-03-01', 'YYYY-MM-DD')
		l_last_day_of_month = to_date('2026-03-31', 'YYYY-MM-DD')
		
		
         l_total_working_days = GET_WORKING_DAYS(l_first_day_of_month, l_last_day_of_month)
         l_days = get_working_days(prorate_start, prorate_end)
		 l_value = (l_value / l_total_working_days) * l_days
         l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) Proration formula called from FLAT or PERCENTAGE')
         l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) calculated pay_value : '||TO_CHAR(l_value))
         l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) l_total_working_days : '||TO_CHAR(l_total_working_days))
         l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) calculated days : '||TO_CHAR(l_days))
         l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) calculated hours : '||TO_CHAR(l_hours))
        )
      else
      (  /* l_source_periodicity, l_target_periodicty are separate between unit_rate element
              and flat and percentage element logic */
         l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) FLAT or PERCENTAGE, proration_method = ' || l_proration_method)
         l_source_periodicity = PAYROLL_PERIOD_TYPE
         if (l_proration_method = 'CDAYS_FRATE') THEN
            (
              l_proration_units = days_between(prorate_end , prorate_start) + 1
              l_target_periodicity = 'DAILY'
            )
         else ( if (l_proration_method = 'WH_FRATE') THEN
                   (
                     l_target_periodicity = 'WORKHOUR'
                     l_prorate_unit_type = 'H'
                   )
                else if (l_proration_method = 'WD_FRATE') THEN
                   (
                    l_target_periodicity = 'WORKDAY' 
                     l_prorate_unit_type = 'D'
                   )

                  if ( entry_level = 'AP') then
                      ( l_term_assignment_id = term_hr_term_id
                       set_input('HR_ASSIGN_ID',l_term_assignment_id)
                      )
                      else if ( entry_level = 'PA') then
                      ( l_term_assignment_id = ASG_HR_ASG_ID
                        set_input('HR_ASSIGN_ID',l_term_assignment_id)
                      )
                  l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) FLAT OR PERCENTAGE calling GET_PAY_AVAILIBILITY')
                  CALL_FORMULA('GET_PAY_AVAILABILITY',
                               prorate_start > 'ACTUAL_START_DATE',
                               prorate_end > 'ACTUAL_END_DATE',
                               l_prorate_unit_type > 'UNIT_TYPE',
                               entry_level > 'ENTRY_LEVEL',
                               l_term_assignment_id > 'HR_ASSIGN_ID',
                               l_proration_units < 'L_UNITS' DEFAULT 0)
                 )
           l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) FLAT OR PERCENTAGE calling RATE_CONVERTER')
           l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) source_periodicity and target periodicity =' ||payroll_period_type || ' and  '||l_target_periodicity)
           CALL_FORMULA( 'RATE_CONVERTER',
                        pay_value > 'SOURCE_AMOUNT',
                        payroll_period_type > 'SOURCE_PERIODICITY',
                        l_target_periodicity > 'TARGET_PERIODICITY',
                       'ANNUALIZED RATE CONVERSION' > 'method',
                        l_prorate_rate < 'TARGET_AMOUNT' DEFAULT 0) 
           l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) l_prorate_rate : '||TO_CHAR(l_prorate_rate))
           l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) hours_worked : '||TO_CHAR(hours_worked))
           l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) proration_units : '||TO_CHAR(l_proration_units))

           if l_proration_method = 'WH_FRATE' then
              ( l_hours = l_proration_units ) 
           else if l_proration_method = 'WD_FRATE' then
              (
                   l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) Get hours worked for WD_FRATE')
                  CALL_FORMULA('GET_PAY_AVAILABILITY',
                               prorate_start > 'ACTUAL_START_DATE',
                               prorate_end > 'ACTUAL_END_DATE',
                               'H' > 'UNIT_TYPE',
                               entry_level > 'ENTRY_LEVEL',
                               l_term_assignment_id > 'HR_ASSIGN_ID',
                               l_hours < 'L_UNITS' DEFAULT 0)
              )
           else
               (l_hours = hours_worked * l_value /pay_value       
                l_hours = round(l_hours,3))
           l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) l_hours : '||TO_CHAR(l_hours))

           /** if proration units are not full, then prorate, otherwise pay the whole amount */
           if (l_proration_method = 'WD_FRATE' OR l_proration_method = 'WH_FRATE') then
              ( l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) hours_worked, l_hours =' || to_char(hours_worked)||' ,'||to_char(l_hours))

                 /** Percentage element hours worked had been removed, so there no need to check l_hours < hours_worked , and l_value didn't calculated by l_hours, it is save to comment below code */
           /**   if (l_hours < hours_worked ) then */
           /** l_value = l_prorate_rate * l_proration_units  */
              /**    else */
                 /**       (l_value = pay_value)  */

       if (l_hours=hours_worked ) then
                           (l_value = pay_value)
                    else 
                  l_value = l_prorate_rate * l_proration_units 

               )
            else /** CDAYS_FRATE **/
              ( l_value = l_prorate_rate * l_proration_units
               l_hours = hours_worked * l_value /pay_value       
               l_hours = round(l_hours,3))
      )
     ) 
   ELSE
   (    
  if (pay_value != 0 and pay_value was not defaulted) then 
  (   
     l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) unit type= '||l_unit_type)
     l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) multiple = '||to_char(l_multiple))
     l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) cal_rate = '||to_char(l_calculated_rate))
     l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) HR_ENTRY_LEVEL : '||ENTRY_LEVEL)

      if ( entry_level = 'AP') then
       ( l_term_assignment_id = term_hr_term_id
        set_input('HR_ASSIGN_ID',l_term_assignment_id)
       )
       else if ( entry_level = 'PA') then
       ( l_term_assignment_id = ASG_HR_ASG_ID
         set_input('HR_ASSIGN_ID',l_term_assignment_id)
       )

      if (l_calculated_rate = 0  and l_target_periodicity <> 'X') then
       (  /* Possibly Mid hire - User did not give Rate value and it was not derived in the base Unit X Rate formula */

           l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) Initialize the call for GET_PAY_SALARY_BASIS')

           CALL_FORMULA('GET_PAY_SALARY_BASIS',
                        l_term_assignment_id > 'HR_ASSIGN_ID',
                        l_term_assignment_id > 'HR_TRM_ID',
                        prorate_start > 'HR_EFFECTIVE_DATE',
                        entry_level > 'HR_ENTRY_LEVEL',
                        l_salary < 'L_SALARY' DEFAULT 0,
                        l_salary_basis_code < 'L_SALARY_BASIS_CODE' DEFAULT ' ',
                        l_full_time_salary < 'L_FULL_TIME_SALARY' DEFAULT 0)

            l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) SALARY : '||TO_CHAR(l_salary))
            l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) SALARY_BASIS_CODE : '||l_salary_basis_code)
            l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) FULL TIME SALARY : '||TO_CHAR(l_full_time_salary))


                    l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) Parameter Initialization for Rate Converter Call')
                    CALL_FORMULA( 'RATE_CONVERTER',
                                   l_full_time_salary > 'SOURCE_AMOUNT',
                                   l_source_periodicity > 'SOURCE_PERIODICITY',
                                   l_target_periodicity > 'TARGET_PERIODICITY',
                                   'ANNUALIZED RATE CONVERSION' > 'method',
                                   l_calculated_rate < 'TARGET_AMOUNT' DEFAULT 0)

                    l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) Rate Converter Executed ')


       )   /* mid hire end */
     if (l_ee_units_entered = 0 ) then
      (
       CALL_FORMULA('GET_PAY_AVAILABILITY',
                       prorate_start > 'ACTUAL_START_DATE',
                       prorate_end > 'ACTUAL_END_DATE',
                       'H' > 'UNIT_TYPE',
                       entry_level > 'ENTRY_LEVEL',
                       l_term_assignment_id > 'HR_ASSIGN_ID',
                       l_prorate_hours < 'L_UNITS' DEFAULT 0)
       l_hours = l_prorate_hours
       if l_unit_type = 'H' then
          (l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) hours for the chunk : '||TO_CHAR(l_prorate_hours))
           Calculated_Hours = l_hours
          l_value = l_hours * l_calculated_rate * l_multiple  )
       else
        ( CALL_FORMULA('GET_PAY_AVAILABILITY',
                       prorate_start > 'ACTUAL_START_DATE',
                       prorate_end > 'ACTUAL_END_DATE',
                       'D' > 'UNIT_TYPE',
                       entry_level > 'ENTRY_LEVEL',
                       l_term_assignment_id > 'HR_ASSIGN_ID',
                       l_prorate_days < 'L_UNITS' DEFAULT 0)
          l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) days for the chunk : '||TO_CHAR(l_prorate_days))
          l_value = l_prorate_days * l_calculated_rate * l_multiple
          calculated_days = l_prorate_days
     )
        )
     else  /* user entered units in the EE, those are prorated based on days in the chunk */
        (
          l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) units are entered '||TO_CHAR(l_ee_units_entered))
          l_total_days = days_between(PAY_EARN_PERIOD_END, PAY_EARN_PERIOD_START ) + 1
          l_days = days_between(prorate_end , prorate_start) + 1
          l_value = l_ee_units_entered * l_calculated_rate * l_multiple * l_days / l_total_days 
          if l_unit_type = 'H' then
           ( l_hours = l_ee_units_entered * l_days /l_total_days )
          else
           ( l_hours = 0
             calculated_days = l_ee_units_entered * l_days/ l_total_days

           )
           Calculated_Hours = l_hours
        ) 
        calculated_rate = l_calculated_rate
    )
     )
  )
)
/*Do Reduce in Proration */

 GLB_EARN_REDUCE_KEY = ENTRY_LEVEL||'-'||TO_CHAR(ee_id)||'-'|| TO_CHAR(l_payroll_rel_action_id)
 l_log =PAY_INTERNAL_LOG_WRITE('(GLBPRT) GLB_EARN_REDUCE_KEY '||GLB_EARN_REDUCE_KEY)

 GLB_EARN_REDUCE_EARNING_KEY = 'EARNING_'||GLB_EARN_REDUCE_KEY
 l_log =PAY_INTERNAL_LOG_WRITE('(GLBPRT) GLB_EARN_REDUCE_EARNING_KEY '||GLB_EARN_REDUCE_EARNING_KEY)

 GLB_EARN_REDUCE_HOURS_KEY = 'HOUR_'|| GLB_EARN_REDUCE_KEY
 l_log =PAY_INTERNAL_LOG_WRITE('(GLBPRT) GLB_EARN_REDUCE_HOURS_KEY '||GLB_EARN_REDUCE_HOURS_KEY)

 GLB_EARN_REDUCE_DAYS_KEY = 'DAY_'|| GLB_EARN_REDUCE_KEY
 l_log =PAY_INTERNAL_LOG_WRITE('(GLBPRT) GLB_EARN_REDUCE_DAYS_KEY '||GLB_EARN_REDUCE_DAYS_KEY)

  l_reduce=WSA_GET(GLB_EARN_REDUCE_EARNING_KEY,0)
 l_reduce_hours=WSA_GET(GLB_EARN_REDUCE_HOURS_KEY,0)
  l_reduce_days=WSA_GET(GLB_EARN_REDUCE_DAYS_KEY,0)
 l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) Initial reduce regular earning : '||TO_CHAR(l_reduce))  
l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) Initial reduce regular hours: '||TO_CHAR(l_reduce_hours))  
 l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) Initial reduce regular days: '||TO_CHAR(l_reduce_days))  

 GLB_ABS_EARN_REDUCE_KEY = ENTRY_LEVEL||'-'||TO_CHAR(ee_id)||'-'|| TO_CHAR(l_payroll_rel_action_id)||'_ABSENCE'
l_dummy =PAY_INTERNAL_LOG_WRITE('(GLBPRT) GLB_ABS_EARN_REDUCE_KEY '||GLB_ABS_EARN_REDUCE_KEY)

   GLB_ABS_EARN_REDUCE_EARNING_KEY = 'EARNING_'||GLB_ABS_EARN_REDUCE_KEY
   l_dummy =PAY_INTERNAL_LOG_WRITE('(GLBPRT) GLB_ABS_EARN_REDUCE_EARNING_KEY ' ||GLB_ABS_EARN_REDUCE_EARNING_KEY)

   GLB_ABS_EARN_REDUCE_HOURS_KEY = 'HOUR_'|| GLB_ABS_EARN_REDUCE_KEY
   l_dummy =PAY_INTERNAL_LOG_WRITE('(GLBPRT) GLB_ABS_EARN_REDUCE_HOURS_KEY ' ||GLB_ABS_EARN_REDUCE_HOURS_KEY)

      GLB_ABS_EARN_REDUCE_DAYS_KEY = 'DAY_'|| GLB_ABS_EARN_REDUCE_KEY
   l_dummy =PAY_INTERNAL_LOG_WRITE('(GLBPRT) GLB_ABS_EARN_REDUCE_DAYS_KEY ' ||GLB_ABS_EARN_REDUCE_DAYS_KEY)

    l_reduce_abs=WSA_GET(GLB_ABS_EARN_REDUCE_EARNING_KEY,0)
  l_reduce_abs_hours=WSA_GET(GLB_ABS_EARN_REDUCE_HOURS_KEY,0)
    l_reduce_abs_days=WSA_GET(GLB_ABS_EARN_REDUCE_DAYS_KEY,0)
  l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) Initial absence reduce regular earning : '||TO_CHAR(l_reduce_abs))  
 l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) Initial absence reduce regular hours: '||TO_CHAR(l_reduce_abs_hours))  
 l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) Initial absence reduce regular days: '||TO_CHAR(l_reduce_abs_days)) 
 if (l_reduce_abs_hours > 0 and l_hours > 0) OR (l_report_unit='ORA_HOURSWORK') then
 (
 If l_reduce_abs_hours <= l_hours Then
   (
  l_hours = l_hours - l_reduce_abs_hours
   l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) Absence Reduce Hour: '||TO_CHAR(l_reduce_abs_hours))
   )
   Else
   (
   l_reduce_abs_hours = l_hours
   l_hours = 0
   if(prorate_end=PAY_EARN_PERIOD_END) then (
       mesg = 'Insufficient absence hours to reduce'
      l_log = PAY_LOG_WARNING('PAY:PAY_RED_REG_LIMIT')
     )
   )
 )
 if (l_reduce_abs_days > 0 and l_days_worked > 0) OR (l_report_unit = 'ORA_WORKDAYS') then 
 (
   If l_reduce_abs_days <= l_days_worked Then
   (
  l_days_worked = l_days_worked - l_reduce_abs_days
   l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) Absence Reduce Day: '||TO_CHAR(l_reduce_abs_days))
   )
   Else
   (
   l_reduce_abs_days =  l_days_worked
   l_days_worked = 0
   if(prorate_end=PAY_EARN_PERIOD_END) then (
       mesg = 'Insufficient absence days to reduce'
      l_log = PAY_LOG_WARNING('PAY:PAY_RED_REG_LIMIT')
     )
   )
 )
 If l_reduce_abs <= l_value then
 (
   l_value = l_value - l_reduce_abs
        l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) Absence Reduce Earning: '||TO_CHAR(l_reduce_abs))
  )
  Else
  (
    l_reduce_abs =  l_value
    l_value = 0
    if(prorate_end=PAY_EARN_PERIOD_END) then (
       mesg = 'Insufficient absence value to reduce'
      l_log = PAY_LOG_WARNING('PAY:PAY_RED_REG_LIMIT')
     )
  )
 if (l_reduce_hours > 0 and l_hours > 0) OR (l_report_unit='ORA_HOURSWORK') then
 (
 If l_reduce_hours <= l_hours Then
   (
   l_hours = l_hours - l_reduce_hours
   l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) Reduce Hour: '||TO_CHAR(l_reduce_hours))
   )
   Else
   (
   l_reduce_hours =  l_hours
   l_hours = 0

   if(prorate_end=PAY_EARN_PERIOD_END) then (
       mesg = 'Insufficient hours to reduce'
      l_log = PAY_LOG_WARNING('PAY:PAY_RED_REG_LIMIT')
       )
     )
   )
 if (l_reduce_days > 0 and l_days_worked > 0) OR (l_report_unit = 'ORA_WORKDAYS') then 
 (
   If l_reduce_days <= l_days_worked Then
   (
   l_days_worked = l_days_worked - l_reduce_days
   l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) Reduce Day: '||TO_CHAR(l_reduce_days))
   )
   Else
   (
   l_reduce_days = l_days_worked
   l_days_worked = 0
    if(prorate_end=PAY_EARN_PERIOD_END) then (
       mesg = 'Insufficient days to reduce'
      l_log = PAY_LOG_WARNING('PAY:PAY_RED_REG_LIMIT')
     )
   )
 )
  If l_reduce <= l_value then
  (
    l_value = l_value - l_reduce
     l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) Reduce Earning: '||TO_CHAR(l_reduce))
   )
   Else
   (
    l_reduce =  l_value
    l_value = 0
    if(prorate_end=PAY_EARN_PERIOD_END) then (
       mesg = 'Insufficient earnings to reduce'
      l_log = PAY_LOG_WARNING('PAY:PAY_RED_REG_LIMIT')
     )


   )

   l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT)  hours worked: '||TO_CHAR(L_HOURS))
   l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT)  pay value : '||TO_CHAR(l_value))
   l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT)  days worked : '||TO_CHAR(l_days_worked))
   l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) Absence Reduce Hour: '||TO_CHAR(l_reduce_abs_hours))
   l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) Absence Reduce Day: '||TO_CHAR(l_reduce_abs_days))
   l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) Absence Reduce Earning: '||TO_CHAR(l_reduce_abs))
   l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) Reduce Hour: '||TO_CHAR(l_reduce_hours))
   l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) Reduce Day: '||TO_CHAR(l_reduce_days))
   l_log = PAY_INTERNAL_LOG_WRITE('(GLBPRT) Reduce Earning: '||TO_CHAR(l_reduce))
    pay_value = l_value
    HOURS_WORKED = L_HOURS
    DAYS_WORKED = l_days_worked
    reduce_regular_earnings=l_reduce
  Reduce_Regular_Days=l_reduce_days
  reduce_regular_hours=l_reduce_hours
  Reduce_Regular_Absence_Earnings=l_reduce_abs
    Reduce_Regular_Absence_Days=l_reduce_abs_days
  Reduce_Regular_Absence_Hours=l_reduce_abs_hours



    return pay_value, hours_worked,Calculated_Hours,calculated_days,calculated_rate,days_worked,reduce_regular_earnings, reduce_regular_hours,Reduce_Regular_Days,Reduce_Regular_Absence_Days,Reduce_Regular_Absence_Earnings,Reduce_Regular_Absence_Hours