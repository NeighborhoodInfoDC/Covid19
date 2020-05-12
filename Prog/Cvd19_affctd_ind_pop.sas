/**************************************************************************
 Program:  Cvd19_affctd_ind_pop.sas
 Library:  Covid19
 Project:  Urban-Greater DC
 Author:   P. Tatian
 Created:  03/28/20
 Version:  SAS 9.4
 Environment:  Local Windows session (desktop)
 GitHub issue:  1
 
 Description:  Describe characteristics of population in COVID-19
 affected industries: transportation, hospitality, mining, travel
 using ACS IPUMS data. 

 Modifications:
**************************************************************************/

%include "L:\SAS\Inc\StdLocal.sas";

** Define libraries **;
%DCData_lib( Covid19 )
%DCData_lib( Ipums )

%let RegPumas = "1100101", "1100102", "1100103", "1100104", "1100105", "2401600", "2400301", "2400302","2401001", "2401002", 
				"2401003", "2401004", "2401005", "2401006", "2401007", "2401101", "2401102", "2401103", "2401104", "2401105", 
				"2401106", "2401107", "5101301", "5101302", "5159301", "5159302", "5159303", "5159304", "5159305", "5159306", 
				"5159307", "5159308", "5159309", "5110701", "5110702" , "5110703", "5151244", "5151245", "5151246", "5151255" ;

%let keep_vars = 
  serial pernum numprec perwt hhwt ind occ year statefip countyfip met2013 upuma
  age sex 
  raced racwht racblk racasian racamind racpacis racother hispand
  educd school schltype
  hud_inc poverty inc: 
  labforce empstatd wkswork2 uhrswork tranwork classwkrd
  ownershp ownershpd rentgrs owncost gq plumbing hotwater;

data A;

  set
    Ipums.Acs_2014_18_dc (keep=&keep_vars)
    Ipums.Acs_2014_18_md (keep=&keep_vars)
    Ipums.Acs_2014_18_va (keep=&keep_vars)
    Ipums.Acs_2014_18_wv (keep=&keep_vars);

  where met2013 = 47900;
  
  retain total 1;

  if upuma in (&RegPumas.) then MWCOG_region = 1;
  else MWCOG_region = 0;
  
  /* Flag 35+ hours worked as full time */
  if uhrswork >= 35 then fulltime=1;
  else if uhrswork > 0 then fulltime=0;
  else fulltime = .n;

  /* Flag 50-52 weeks per year as year-round */
  if wkswork2 = 6  then yearround=1;
  else if wkswork2 > 0 then yearround=0;
  else yearround = .n;

  if 9920 > ind > 0 then do; 
  
    select;
    
      when ( year in ( 2008:2018 ) ) do;
        if ind in ( 370:490, 6070:6090, 6180:6190, 6280, 7670, 8560:8590, 8660:8690 ) then cvd19_affctd_ind = 1;
        else cvd19_affctd_ind = 0;
      end;
    
      otherwise do;
        %err_put( msg="ACS industry not coded for this year. " year= )
      end;
      
    end;
    
  end;
  else cvd19_affctd_ind = .n;
  
  cvd19_affctd_incearn = cvd19_affctd_ind * incearn;
  cvd19_affctd_incwage = cvd19_affctd_ind * incwage;
  cvd19_affctd_incbus00 = cvd19_affctd_ind * incbus00;
  
  format MWCOG_region fulltime yearround cvd19_affctd_ind dyesno.;

run;

proc sort data=A;
  by year serial pernum;
run;

proc freq data=A;
  tables cvd19_affctd_ind;
  tables cvd19_affctd_ind * ind / list nocum nopercent;
run;

proc means data=A n sum mean min max;
  var inc: cvd19_affctd_inc: ;
run;

proc summary data=A;
  by year serial;
  var cvd19_affctd_ind inc: cvd19_affctd_inc: ;
  output out=cvd19_affctd_ind_hh (drop=_type_ _freq_) sum= /autoname;
run;


data Cvd19_affctd_ind_pop;

  merge A cvd19_affctd_ind_hh;
  by year serial;
  
  ** Race/ethnicity **;
  
  if hispand = 0 then do;
    if raced=100 then race_ethn = 1;  /** White non-Hispanic **/
    else if raced=200 then race_ethn = 2;  /** Black non-Hispanic **/
    else if 400 <= raced <= 679 then race_ethn = 4;  /** Asian non-Hispanic **/
    else race_ethn = 5;  /** All other non-Hispanic **/
  end;
  else race_ethn = 3;  /** Hispanic **/
  
  ** Income changes **;
  
  if cvd19_affctd_incearn > 0 then inc_less_cvd19_affctd = inctot - cvd19_affctd_incearn;
  if cvd19_affctd_incearn_sum > 0 then inc_less_cvd19_affctd_sum = inctot_sum - cvd19_affctd_incearn_sum;
  
  if inctot_sum > 0 then 
    pct_inc_less_cvd19_affctd_sum = 100 * ( 1 - ( inc_less_cvd19_affctd_sum / inctot_sum ) );
  
  ** Housing cost ratio **;
  
  %macro hsg_cost_ratio( inc=, var= );
  
    if &inc > 0 then do;
      if ownershp = 2 then &var = ( rentgrs * 12 ) / &inc;
      else if ownershp = 1 then &var = ( owncost * 12 ) / &inc;
      else if ownershp = 0 then &var = .n;
    end;
    else if not( missing( &inc ) ) then do;
      if ownershp = 2 and rentgrs > 0 then &var = 1;
      else if ownershp = 1 and owncost > 0 then &var = 1;
      else if ownershp = 0 then &var = .n;
      else &var = 0;
    end;
  
  %mend hsg_cost_ratio;
  
  %hsg_cost_ratio( inc=inctot_sum, var=hsg_cost_ratio )
  
  %hsg_cost_ratio( inc=inc_less_cvd19_affctd_sum, var=hsg_cost_ratio_cvd19 )
  
  ** HUD income catagories **;
  
  hud_inc_orig = hud_inc;
  
  if not( missing( inc_less_cvd19_affctd_sum ) ) then do;
    %Hud_inc_all( hhinc=inc_less_cvd19_affctd_sum, hhsize=numprec )
  end;
  
  format hud_inc_orig Hud_inc hudinc.;

  rename hud_inc_orig=hud_inc hud_inc=hud_inc_cvd19;

  format cvd19_affctd_ind_Sum ;
  
  label
    MWCOG_region = "In MWCOG region"
    cvd19_affctd_incbus00 = "Personal business and farm income from COVID-affected industries"
    cvd19_affctd_incbus00_Sum = "HH business and farm income from COVID-affected industries"
    cvd19_affctd_incearn = "Total personal earned income from COVID-affected industries" 
    cvd19_affctd_incearn_Sum = "Total HH earned income from COVID-affected industries"
    cvd19_affctd_incwage = "Personal wage and salary income from COVID-affected industries"
    cvd19_affctd_incwage_Sum = "HH wage and salary income from COVID-affected industries"
    cvd19_affctd_ind = "Worker in COVID-affected industry"
    cvd19_affctd_ind_Sum = "Total HH workers in COVID-affected industries"
    fulltime = "Full time worker (35+ hours per week)"
    hsg_cost_ratio = "Ratio of housing costs to HH income, original"
    hsg_cost_ratio_cvd19 = "Ratio of housing costs to HH income, less COVID-related earnings"
    hud_inc_orig = "HUD HH income category, original"
    hud_inc = "HUD HH income category, less COVID-related earnings"
    inc_less_cvd19_affctd = "Total personal income, less COVID-related earnings"
    inc_less_cvd19_affctd_sum = "Total HH income, less COVID-related earnings"
    pct_inc_less_cvd19_affctd_sum = "Percentage reduction in total HH income from loss of COVID-related earnings"
    race_ethn = "Race/ethnicity"
    total = "Total person/household count"
    yearround = "Year round worker (50-52 weeks per year)";

run;


%Finalize_data_set( 
  data=Cvd19_affctd_ind_pop,
  out=Cvd19_affctd_ind_pop,
  outlib=Covid19,
  label="Workers and households in COVID-19-affected industries, ACS, 2014-18, Washington metro (partial)",
  sortby=serial pernum,
  revisions=%str(Corrected hsg_cost_ratio_cvd19 to exclude HHs w/o affected workers.),
  freqvars=mwcog_region cvd19_affctd_ind race_ethn fulltime yearround
)


** Diagnostic output **;

proc freq data=Cvd19_affctd_ind_pop;
  tables cvd19_affctd_ind * empstatd * fulltime * yearround /list missing nopercent nocum;
run;

proc univariate data=Cvd19_affctd_ind_pop;
  var hsg_cost_ratio hsg_cost_ratio_cvd19;
run;

** Tables **;

%Fmt_ind_2017f()

title3 'Workers in COVID-19 affected industries by industry';

proc tabulate data=Cvd19_affctd_ind_pop format=comma16.0 noseps missing;
  where cvd19_affctd_ind = 1;
  weight perwt;
  class ind;
  var total inctot incearn cvd19_affctd_incearn;
  table 

    /** Rows **/
    all='Washington metro area (excl WV)' ind=' ',

    /** Columns **/
    sum='Workers' * total=' ' * f=comma12.0

    sum='Annual income ($ 2018), 2014-18' * 
    ( inctot='Total income' 
      incearn='Earnings' 
      cvd19_affctd_incearn='Earnings from COVID-19 affected industries' )

    pctsum<inctot>='COVID-19 affected earnings as pct. total income' * 
    cvd19_affctd_incearn=' ' *
    f=comma12.1

    pctsum<incearn>='COVID-19 affected earnings as pct. total earnings' * 
    cvd19_affctd_incearn=' ' *
    f=comma12.1
  ;
  format ind ind_2017f.;
run;


title3 'Households with workers in COVID-19 affected industries by state';

proc tabulate data=Cvd19_affctd_ind_pop format=comma16.0 noseps missing;
  where pernum = 1 and cvd19_affctd_ind_Sum > 0;
  weight hhwt;
  class statefip;
  var total inctot_sum incearn_sum cvd19_affctd_incearn_sum;
  table 

    /** Rows **/
    all='Washington metro area (excl WV)' statefip=' ',

    /** Columns **/
    sum='Households' * total=' ' * f=comma12.0

    sum='Annual household income ($ 2018), 2014-18' * 
    ( inctot_sum='Total income' 
      incearn_sum='Earnings' 
      cvd19_affctd_incearn_sum='Earnings from COVID-19 affected industries' )

    pctsum<inctot_sum>='COVID-19 affected earnings as pct. total income' * 
    cvd19_affctd_incearn_sum=' ' *
    f=comma12.1

    pctsum<incearn_sum>='COVID-19 affected earnings as pct. total earnings' * 
    cvd19_affctd_incearn_sum=' ' *
    f=comma12.1
  ;
run;

title2;

