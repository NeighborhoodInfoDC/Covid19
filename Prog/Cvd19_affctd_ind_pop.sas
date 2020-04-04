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
  serial pernum perwt hhwt ind occ year statefip countyfips met2013 upuma
  age sex 
  raced racwht racblk racasian racamind racpacis racother hispand
  educd school schltype
  hud_inc poverty inc: 
  labforce empstatd wkswork2 uhrswork tranwork classwkrd
  gq plumbing hotwater;

data A;

  set
    Ipums.Acs_2012_16_dc (keep=&keep_vars)
    Ipums.Acs_2012_16_md (keep=&keep_vars)
    Ipums.Acs_2012_16_va (keep=&keep_vars)
    Ipums.Acs_2012_16_wv (keep=&keep_vars);

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
    
      when ( year in ( 2018 ) )
        if ind in ( 370:490, 6070:6090, 6180:6190, 6280, 7670, 8560:8590, 8660:8690 ) then cvd19_affctd_ind = 1;
        else cvd19_affctd_ind = 0;
    
      when ( year in ( 2013:2017 ) )
        if ind in ( 370:490, 6070:6090, 6180:6190, 6280, 7670, 8560:8590, 8660:8690 ) then cvd19_affctd_ind = 1;
        else cvd19_affctd_ind = 0;
        
      when ( year in ( 2008:2012 ) )
        if ind in ( 370:490, 6070:6090, 6180:6190, 6280, 7670, 8560:8590, 8660:8690 ) then cvd19_affctd_ind = 1;
        else cvd19_affctd_ind = 0;
        
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


data Covid19.cvd19_affctd_ind_pop;

  merge A cvd19_affctd_ind_hh;
  by year serial;

run;

%File_info( data=Covid19.cvd19_affctd_ind_pop, freqvars=mwcog_region cvd19_affctd_ind fulltime yearround )

proc freq data=Covid19.cvd19_affctd_ind_pop;
  tables cvd19_affctd_ind * empstatd * fulltime * yearround /list missing nopercent nocum;
run;

** Tables **;

%Fmt_ind_2017f()

title3 'Workers in COVID-19 affected industries by industry';

proc tabulate data=Covid19.cvd19_affctd_ind_pop format=comma16.0 noseps missing;
  where cvd19_affctd_ind = 1;
  weight perwt;
  class ind;
  var total inctot incearn cvd19_affctd_incearn;
  table 

    /** Rows **/
    all='Washington metro area (excl WV)' ind=' ',

    /** Columns **/
    sum='Workers' * total=' ' * f=comma12.0

    sum='Annual income ($ 2016), 2012-16' * 
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

proc tabulate data=Covid19.cvd19_affctd_ind_pop format=comma16.0 noseps missing;
  where pernum = 1;
  weight hhwt;
  class statefip;
  var total inctot_sum incearn_sum cvd19_affctd_incearn_sum;
  table 

    /** Rows **/
    all='Washington metro area (excl WV)' statefip=' ',

    /** Columns **/
    sum='Households' * total=' ' * f=comma12.0

    sum='Annual household income ($ 2016), 2012-16' * 
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
