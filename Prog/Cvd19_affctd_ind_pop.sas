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
  ownershp ownershpd rentgrs owncost gq plumbing hotwater
  hhtype;

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
  
  /* Life stage flags */

  if age < 18 then child = 1; else child = 0;
  if age >= 65 then elder = 1; else elder = 0;

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
  var cvd19_affctd_ind inc: cvd19_affctd_inc: child elder;
  output out=cvd19_affctd_ind_hh (drop=_type_ _freq_) sum= /autoname;
run;

proc means data=cvd19_affctd_ind_hh n sum mean min max;
  var child_sum elder_sum;
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
  
  ** Family type **;

  if hhtype = 1 then do;
	if child_sum > 0 then famtype = 1;
	else if child_sum = 0 then famtype = 2;
	end;
  else if hhtype ~= 1 then do;
		if hhtype in (0, 9) then famtype = 0;
		else if hhtype in (2,3,4,5,6,7) and child_sum > 0 then famtype = 3;
		else if hhtype in (2,3,4,5,6,7) and child_sum = 0 then famtype = 4;
		*else famtype = 5;
		end;

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
    yearround = "Year round worker (50-52 weeks per year)"
	child_sum = "Total number of children in HH"
	elder_sum = "Total number of elders in HH"
	famtype = "Family Type";

run;

proc means data=cvd19_affctd_ind_pop n sum mean min max;
  var child_sum elder_sum famtype;
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




** Global macro variables **;

%global ACS_YEAR DOLLAR_YEAR CVD19_BOT_1PCT_EARNINGS CVD19_TOP_1PCT_EARNINGS;

%let ACS_YEAR = 2014-18;
%let DOLLAR_YEAR = 2018;


** Formats **;

%Fmt_ind_2017f()
%Fmt_occ_2018f()

proc format;

  value ind_sum (notsorted)
    8680, 8690 = 'Food & drink establishments'
    6070 = 'Air transportation'
    6080, 6090, 6180, 6190 = 'Other transportation'
    6280, 7670, 8660, 8670 = 'Tourism & travel'
    8560-8590 = 'Arts & recreation'
    0370-0490 = 'Other COVID-19 affected industries';
    
  value age_sum
    16-20 = '16 - 20 years'
    21-30 = '21 - 30'
    31-40 = '31 - 40'
    41-50 = '41 - 50'
    51-60 = '51 - 60'
    61-high = '61 and older';

  value race_sum (notsorted)
    100 = 'White'
    200 = 'Black'
    400-620, 640-679 = 'Asian'
    /*
    300-399 = 'American Indian/Alaska Native'
    630,680-699 = 'Native Hawaiian/Pacific Islander'
    700 = 'Other race'
    */
    /*
    300-399, 630,680-699, 700 = 'Other races'
    801-996 = 'Multiple races';
    */
    300-399, 630,680-699, 700, 801-996 = 'All other races';
    
  value hispan_sum (notsorted)
    416 = 'Salvadoran'
    401-415, 417 = 'Other Central American'
    100-300, 420-499 = 'Other Latino/Hispanic origin'
    0 = 'Not Latino/Hispanic';
    
  value poverty_sum (notsorted)
    1-100 = 'At or below poverty'
    100<-200 = '101 to 200% poverty'
    200<-high = 'Above 200% poverty'
    0 = 'Poverty status not determined';
    
  value educ_sum (notsorted)
    0 - 61 = 'Less than HS diploma'
    62 - 71 = 'HS diploma/GED'
    81 = 'Associates degree'
    101 = 'Bachelors degree'
    114-high = 'Masters degree or higher';
    
  value hsg_cost_ratio (notsorted)
    0.50 - high = 'Severe cost burden (50%+ income)'
    0.30 -< 0.50 = 'Cost burden (30 - 49%)'
    0 -< 0.30 = 'No cost burden (< 30%)'
    .n = 'n/a';
    
  value yesnona (notsorted)
    1 = 'Yes'
    0 = 'No'
    .n = 'n/a';
    
  value OWNERSHP_f (notsorted)
    1 = "Owned or being bought (loan)"
    2 = "Rented"
    0 = "n/a"
  ;
    
  /** HUD Income Categories **/
  value hudinc (notsorted)
    1 = 'Extremely low (0-30% AMI)'
    2 = 'Very low (31-50%)'
    3 = 'Low (51-80%)'
    4 = 'Middle (81-120%)'
    5 = 'High (over 120%)'
    .n = 'n/a';    
    
  value hudinc_low (notsorted)
    1 = 'Extremely low income (0-30% AMI)'
	2 = 'Very low income (31-50% AMI)'
	3 = 'Low income (51-80% AMI)'
    4-5 = 'Above low income (81% AMI and higher)'
    .n = 'n/a';    
    
  value $upuma_to_mwcog_jurisd (notsorted) 
    "5159301", "5159302", "5159303", "5159304", "5159305", "5159306", "5159307", "5159308", "5159309" = "Fairfax Co., Fairfax city, and Falls Church"
    "2401101", "2401102", "2401103", "2401104", "2401105", "2401106", "2401107" = "Prince George's County"
    "2401001", "2401002", "2401003", "2401004", "2401005", "2401006", "2401007" = "Montgomery County"
    "1100101", "1100102", "1100103", "1100104", "1100105" = "District of Columbia"
    "5151244", "5151245", "5151246" = "Prince William Co., Manassas, and Manassas Park" 
    "5110701", "5110702" , "5110703" = "Loudoun County"
    "2400301", "2400302" = "Frederick County"
    "5101301", "5101302" = "Arlington County"
    "5151255" = "Alexandria"
    "2401600" = "Charles County"
    other = "Not in MWCOG region";
    
  value race_ethn (notsorted)
     1 = "White non-Latino"
     2 = "Black non-Latino"
     3 = "Latino"
     4 = "Asian non-Latino"
     5 = "All other non-Latino"
    .n = "Not available";
    
  value cvd19_affctd_ind (notsorted) 
    1 = 'In COVID-19 affected industry'
    0 = 'Not in COVID-19 affected industry'
    other = 'n/a';
    
  value pct_inc_split (notsorted)
    40 <- high = 'Above 40% household income'
    0 - 40 = 'At or below 40% household income'
    other = 'n/a';

  value hh_size (notsorted)
    1 = '1 person HH'
	2 = '2 person HH'
	3 = '3 person HH'
	4 = '4 person HH'
	5 = '5 person HH'
	6-high = '6+ person HH';
    
  value family_type (notsorted)
     0 = 'Not applicable/Undetermined'
	 1 = 'Married family with children'
	 2 = 'Married family without children'
	 3 = 'Single family with children'
	 4 = 'Single family without children';
run;  

** Examine earnings for outliers **;

proc univariate data=Covid19.cvd19_affctd_ind_pop noprint;
  where mwcog_region = 1 and cvd19_affctd_ind = 1 and incearn > 0;
  var incearn;
  output out=incearn_ptiles p1=incearn_p1 p99=incearn_p99;
run;

proc sql noprint;
  select incearn_p1, incearn_p99 into :CVD19_BOT_1PCT_EARNINGS, :CVD19_TOP_1PCT_EARNINGS from incearn_ptiles;
  quit;

%put CVD19_BOT_1PCT_EARNINGS=&CVD19_BOT_1PCT_EARNINGS; 
%put CVD19_TOP_1PCT_EARNINGS=&CVD19_TOP_1PCT_EARNINGS; 

** Find median pct. of affected household earnings **;

proc means data=Covid19.cvd19_affctd_ind_pop n median mean min max;
  where mwcog_region = 1 and cvd19_affctd_ind = 1 and &CVD19_BOT_1PCT_EARNINGS < incearn < &CVD19_TOP_1PCT_EARNINGS;
  weight perwt;
  var pct_inc_less_cvd19_affctd_sum;
run;


** Worker and household tables **;

options nodate nonumber;
options orientation=portrait;

%fdate()

ods rtf file="&_dcdata_default_path\Covid19\Prog\Cvd19_affctd_ind_pop_tables.rtf" style=Styles.Rtf_arial_9pt;
ods listing close;

footnote1 height=9pt "Prepared by Urban-Greater DC (greaterdc.urban.org), &fdate..";
footnote2 height=9pt j=r '{Page}\~{\field{\*\fldinst{\pard\b\i0\chcbpat8\qc\f1\fs19\cf1{PAGE }\cf0\chcbpat0}}}';
/*
footnote3 ' ';
footnote4 '\b DRAFT - NOT FOR CITATION OR RELEASE';
*/

title2 ' ';


**** Worker tables ****;


title3 'Characteristics of workers in COVID-19 affected industries by HUD household income category, MWCOG region';

proc tabulate data=cvd19_affctd_ind_pop format=comma16.0 noseps missing;
  where mwcog_region = 1 and cvd19_affctd_ind = 1
        and 1 <= hud_inc <= 3;
  weight perwt;
  class ind /order=data preloadfmt;
  class 
    statefip upuma age sex race_ethn poverty hud_inc classwkrd fulltime yearround educd 
    ownershp hsg_cost_ratio numprec hhtype
    /order=data preloadfmt; 
  var total inctot incearn cvd19_affctd_incearn;
  table 

	/** Sheets **/
    upuma = '',
    /** Rows **/
    all='Total' 
	numprec='\line \i By household size'
	famtype='\line \i By household type'
    ,

    /** Columns **/
    hud_inc=' ' * (
      n='N (unwtd)' * total=' ' * f=comma8.0
      sum='Workers' * total=' ' * f=comma10.0
      colpctsum='% workers' * total=' ' * f=comma10.1
    )
    
  ;
  format ind ind_sum. age age_sum. raced race_sum. hispand hispan_sum. poverty poverty_sum. educd educ_sum.
         hsg_cost_ratio hsg_cost_ratio. upuma $upuma_to_mwcog_jurisd. race_ethn race_ethn.
         hud_inc hudinc_low. fulltime yearround yesnona.;
run;


**** Household tables ****;

title3 'Households with workers in COVID-19 affected industries by state and jurisdiction, MWCOG region';

proc tabulate data=Covid19.cvd19_affctd_ind_pop format=comma16.0 noseps missing;
  where mwcog_region = 1 and pernum = 1 and cvd19_affctd_incearn_sum > 0 and cvd19_affctd_ind_Sum > 0;
  weight hhwt;
  class statefip;
  class upuma / preloadfmt order=data;
  var total inctot_sum incearn_sum cvd19_affctd_incearn_sum;
  table 

    /** Rows **/
    all='Total' statefip=' ' * ( all=' ' upuma=' ' ),

    /** Columns **/
    sum='Households' * total=' ' * f=comma12.0

    sum="Annual household income ($ &DOLLAR_YEAR.), &ACS_YEAR." * 
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
  format upuma $upuma_to_mwcog_jurisd.;
run;
