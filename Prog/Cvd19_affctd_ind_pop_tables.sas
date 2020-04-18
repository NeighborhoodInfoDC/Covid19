/**************************************************************************
 Program:  Cvd19_affctd_ind_pop_tables.sas
 Library:  Covid19
 Project:  Urban-Greater DC
 Author:   P. Tatian
 Created:  04/04/20
 Version:  SAS 9.4
 Environment:  Local Windows session (desktop)
 GitHub issue:  1
 
 Description:  Create tables on COVID-19 affected workers and
 households. 

 Modifications:
**************************************************************************/

%include "L:\SAS\Inc\StdLocal.sas";

** Define libraries **;
%DCData_lib( Covid19 )
%DCData_lib( Ipums )

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
    1-3 = 'At or below low income (0-80% AMI)'
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
    
run;  

** Examine earnings for outliers **;

proc univariate data=Covid19.cvd19_affctd_ind_pop;
  where mwcog_region = 1 and cvd19_affctd_ind = 1 and incearn > 0;
  var incearn;
run;

%let CVD19_TOP_1PCT_EARNINGS = 235658;
%let CVD19_BOT_1PCT_EARNINGS = 262;

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
footnote3 ' ';
footnote4 '\b DRAFT - NOT FOR CITATION OR RELEASE';

title2 ' ';


**** Worker tables ****;

title3 'Workers and earnings by COVID-19 affected industry status, MWCOG region';

proc tabulate data=Covid19.cvd19_affctd_ind_pop format=comma16.0 noseps missing;
  where mwcog_region = 1 and &CVD19_BOT_1PCT_EARNINGS < incearn < &CVD19_TOP_1PCT_EARNINGS;
  weight perwt;
  class cvd19_affctd_ind /order=data preloadfmt;
  var total inctot incearn cvd19_affctd_incearn fulltime;
  table 

    /** Rows **/
    all='Total' cvd19_affctd_ind=' ',

    /** Columns **/
    n='N (unwtd)' * total=' ' * f=comma8.0
    sum='Workers' * total=' ' * f=comma10.0
    
    mean='Full time workers' * fulltime=' ' * f=percent10.0

    sum='Annual income ($ 2018), 2014-18' * 
    ( inctot='Total income' 
      incearn='Total earnings'
      cvd19_affctd_incearn='Earnings from COVID-19 affected industries' )

    pctsum<inctot>='COVID-19 affected earnings as pct. total income' * 
    cvd19_affctd_incearn=' ' *
    f=comma12.1

    pctsum<incearn>='COVID-19 affected earnings as pct. total earnings' * 
    cvd19_affctd_incearn=' ' *
    f=comma12.1
  ;
  table 

    /** Rows **/
    all='Total' cvd19_affctd_ind=' ',

    /** Columns **/
    n='N (unwtd)' * total=' ' * f=comma8.0
    sum='Workers' * total=' ' * f=comma10.0
    
    mean='Full time workers' * fulltime=' ' * f=percent10.0

    mean='Annual income per capita ($ 2018), 2014-18' * 
    ( inctot='Total income' 
      incearn='Total earnings'
      cvd19_affctd_incearn='Earnings from COVID-19 affected industries' )

    pctsum<inctot>='COVID-19 affected earnings as pct. total income' * 
    cvd19_affctd_incearn=' ' *
    f=comma12.1

    pctsum<incearn>='COVID-19 affected earnings as pct. total earnings' * 
    cvd19_affctd_incearn=' ' *
    f=comma12.1
  ;
  format cvd19_affctd_ind cvd19_affctd_ind.;
run;


title3 'Workers and earnings in COVID-19 affected industries by industry type, MWCOG region';

proc tabulate data=Covid19.cvd19_affctd_ind_pop format=comma16.0 noseps missing;
  where mwcog_region = 1 and cvd19_affctd_ind = 1 and &CVD19_BOT_1PCT_EARNINGS < incearn < &CVD19_TOP_1PCT_EARNINGS;
  weight perwt;
  class ind /order=data preloadfmt;
  var total inctot incearn cvd19_affctd_incearn fulltime;
  table 

    /** Rows **/
    all='Total' ind='\line \i By industry type',

    /** Columns **/
    n='N (unwtd)' * total=' ' * f=comma8.0
    sum='Workers' * total=' ' * f=comma10.0
    
    mean='Full time workers' * fulltime=' ' * f=percent10.0

    sum='Annual income ($ 2018), 2014-18' * 
    ( inctot='Total income' 
      cvd19_affctd_incearn='Earnings from COVID-19 affected industries' )

    mean='Annual income per capita ($ 2018), 2014-18' * 
    ( inctot='Total income' 
      cvd19_affctd_incearn='Earnings from COVID-19 affected industries' )

    pctsum<inctot>='COVID-19 affected earnings as pct. total income' * 
    cvd19_affctd_incearn=' ' *
    f=comma12.1

  ;
  format ind ind_sum.;
run;


title3 'Characteristics of workers in COVID-19 affected industries with annual earnings, MWCOG region';

proc tabulate data=Covid19.cvd19_affctd_ind_pop format=comma16.0 noseps missing;
  where mwcog_region = 1 and cvd19_affctd_ind = 1 and &CVD19_BOT_1PCT_EARNINGS < incearn < &CVD19_TOP_1PCT_EARNINGS;
  weight perwt;
  class ind /order=data preloadfmt;
  class 
    statefip upuma age sex race_ethn poverty hud_inc classwkrd fulltime yearround educd 
    ownershp hsg_cost_ratio
    /order=data preloadfmt; 
  var total inctot incearn cvd19_affctd_incearn;
  table 

    /** Rows **/
    all='Total' 
    statefip='\line \i By state'
    upuma='\line \i By jurisdiction'
    age='\line \i By age'
    sex='\line \i By sex'
    race_ethn='\line \i By race/ethnicity'
    poverty='\line \i By family poverty status (pre-COVID-19)'
    hud_inc='\line \i By HUD income category (pre-COVID-19)'
    classwkrd='\line \i By class of worker'
    fulltime='\line \i By full time worker status'
    yearround='\line \i By year-round worker status'
    educd='\line \i By educational attainment'
    ownershp='\line \i By housing tenure'
    hsg_cost_ratio='\line \i By housing cost burden (pre-COVID-19)'
    ,

    /** Columns **/
    n='N (unwtd)' * total=' ' * f=comma8.0
    sum='Workers' * total=' ' * f=comma10.0
    pctsum='% workers' * total=' ' * f=comma10.1
    
    mean='Annual income per capita ($ 2018), 2014-18' * 
    ( inctot='Total income' 
      cvd19_affctd_incearn='Earnings from COVID-19 affected industries' )

  ;
  format ind ind_sum. age age_sum. raced race_sum. hispand hispan_sum. poverty poverty_sum. educd educ_sum.
         hsg_cost_ratio hsg_cost_ratio. upuma $upuma_to_mwcog_jurisd. race_ethn race_ethn.
         fulltime yearround yesnona.;
run;


title3 'Characteristics of workers by COVID-19 affected industry status, MWCOG region';

proc tabulate data=Covid19.cvd19_affctd_ind_pop format=comma16.0 noseps missing;
  where mwcog_region = 1 and &CVD19_BOT_1PCT_EARNINGS < incearn < &CVD19_TOP_1PCT_EARNINGS;
  weight perwt;
  class ind cvd19_affctd_ind /order=data preloadfmt;
  class 
    statefip upuma age sex race_ethn poverty hud_inc classwkrd fulltime yearround educd 
    ownershp hsg_cost_ratio
    /order=data preloadfmt; 
  var total inctot incearn cvd19_affctd_incearn;
  table 

    /** Rows **/
    all='Total' 
    statefip='\line \i By state'
    upuma='\line \i By jurisdiction'
    age='\line \i By age'
    sex='\line \i By sex'
    race_ethn='\line \i By race/ethnicity'
    poverty='\line \i By family poverty status (pre-COVID-19)'
    hud_inc='\line \i By HUD income category (pre-COVID-19)'
    classwkrd='\line \i By class of worker'
    fulltime='\line \i By full time worker status'
    yearround='\line \i By year-round worker status'
    educd='\line \i By educational attainment'
    ownershp='\line \i By housing tenure'
    hsg_cost_ratio='\line \i By housing cost burden (pre-COVID-19)'
    ,

    /** Columns **/
    cvd19_affctd_ind=' ' * (
      n='N (unwtd)' * total=' ' * f=comma8.0
      sum='Workers' * total=' ' * f=comma10.0
      colpctsum='% workers' * total=' ' * f=comma10.1
    )
    
  ;
  format ind ind_sum. age age_sum. raced race_sum. hispand hispan_sum. poverty poverty_sum. educd educ_sum.
         hsg_cost_ratio hsg_cost_ratio. upuma $upuma_to_mwcog_jurisd. race_ethn race_ethn.
         cvd19_affctd_ind cvd19_affctd_ind.  
         fulltime yearround yesnona.;
run;


title3 'Characteristics of workers in COVID-19 affected industries by HUD household income category, MWCOG region';

proc tabulate data=Covid19.cvd19_affctd_ind_pop format=comma16.0 noseps missing;
  where mwcog_region = 1 and cvd19_affctd_ind = 1 and &CVD19_BOT_1PCT_EARNINGS < incearn < &CVD19_TOP_1PCT_EARNINGS
        and hud_inc >= 1;
  weight perwt;
  class ind /order=data preloadfmt;
  class 
    statefip upuma age sex race_ethn poverty hud_inc classwkrd fulltime yearround educd 
    ownershp hsg_cost_ratio
    /order=data preloadfmt; 
  var total inctot incearn cvd19_affctd_incearn;
  table 

    /** Rows **/
    all='Total' 
    statefip='\line \i By state'
    upuma='\line \i By jurisdiction'
    age='\line \i By age'
    sex='\line \i By sex'
    race_ethn='\line \i By race/ethnicity'
    poverty='\line \i By family poverty status (pre-COVID-19)'
    classwkrd='\line \i By class of worker'
    fulltime='\line \i By full time worker status'
    yearround='\line \i By year-round worker status'
    educd='\line \i By educational attainment'
    ownershp='\line \i By housing tenure'
    hsg_cost_ratio='\line \i By housing cost burden (pre-COVID-19)'
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
         hud_inc hudinc_low.  
         fulltime yearround yesnona.;
run;


title3 'Characteristics of workers in COVID-19 affected industries by affected earnings share of household income, MWCOG region';

proc tabulate data=Covid19.cvd19_affctd_ind_pop format=comma16.0 noseps missing;
  where mwcog_region = 1 and cvd19_affctd_ind = 1 and &CVD19_BOT_1PCT_EARNINGS < incearn < &CVD19_TOP_1PCT_EARNINGS;
  weight perwt;
  class ind pct_inc_less_cvd19_affctd_sum /order=data preloadfmt;
  class 
    statefip upuma age sex race_ethn poverty hud_inc classwkrd fulltime yearround educd 
    ownershp hsg_cost_ratio
    /order=data preloadfmt; 
  var total inctot incearn cvd19_affctd_incearn;
  table 

    /** Rows **/
    all='Total' 
    statefip='\line \i By state'
    upuma='\line \i By jurisdiction'
    age='\line \i By age'
    sex='\line \i By sex'
    race_ethn='\line \i By race/ethnicity'
    poverty='\line \i By family poverty status (pre-COVID-19)'
    classwkrd='\line \i By class of worker'
    fulltime='\line \i By full time worker status'
    yearround='\line \i By year-round worker status'
    educd='\line \i By educational attainment'
    ownershp='\line \i By housing tenure'
    hsg_cost_ratio='\line \i By housing cost burden (pre-COVID-19)'
    ,

    /** Columns **/
    pct_inc_less_cvd19_affctd_sum=' ' * (
      n='N (unwtd)' * total=' ' * f=comma8.0
      sum='Workers' * total=' ' * f=comma10.0
      colpctsum='% workers' * total=' ' * f=comma10.1
    )
    
  ;
  format ind ind_sum. age age_sum. raced race_sum. hispand hispan_sum. poverty poverty_sum. educd educ_sum.
         hsg_cost_ratio hsg_cost_ratio. upuma $upuma_to_mwcog_jurisd. race_ethn race_ethn.
         pct_inc_less_cvd19_affctd_sum pct_inc_split.  
         fulltime yearround yesnona.;
run;


title3 'Characteristics of workers in COVID-19 affected industries by race/ethnicity, MWCOG region';

proc tabulate data=Covid19.cvd19_affctd_ind_pop format=comma16.0 noseps missing;
  where mwcog_region = 1 and cvd19_affctd_ind = 1 and &CVD19_BOT_1PCT_EARNINGS < incearn < &CVD19_TOP_1PCT_EARNINGS
        and 1 <= race_ethn <= 4;
  weight perwt;
  class ind pct_inc_less_cvd19_affctd_sum /order=data preloadfmt;
  class 
    statefip upuma age sex race_ethn poverty hud_inc classwkrd fulltime yearround educd 
    ownershp hsg_cost_ratio 
    /order=data preloadfmt; 
  var total inctot incearn cvd19_affctd_incearn;
  table 

    /** Rows **/
    all='Total' 
    statefip='\line \i By state'
    upuma='\line \i By jurisdiction'
    age='\line \i By age'
    sex='\line \i By sex'
    poverty='\line \i By family poverty status (pre-COVID-19)'
    classwkrd='\line \i By class of worker'
    fulltime='\line \i By full time worker status'
    yearround='\line \i By year-round worker status'
    educd='\line \i By educational attainment'
    ownershp='\line \i By housing tenure'
    hsg_cost_ratio='\line \i By housing cost burden (pre-COVID-19)'
    pct_inc_less_cvd19_affctd_sum='\line \i By share COVID-19 affected earnings'
    ,

    /** Columns **/
    race_ethn=' ' * (
      sum='Workers' * total=' ' * f=comma10.0
      colpctsum='% workers' * total=' ' * f=comma10.1
    )
    
  ;
  format ind ind_sum. age age_sum. raced race_sum. hispand hispan_sum. poverty poverty_sum. educd educ_sum.
         hsg_cost_ratio hsg_cost_ratio. upuma $upuma_to_mwcog_jurisd. race_ethn race_ethn.
         pct_inc_less_cvd19_affctd_sum pct_inc_split.  
         fulltime yearround yesnona.;
run;



**** Household tables ****;

title3 'Households with workers in COVID-19 affected industries by state and jurisdiction, MWCOG region';

proc tabulate data=Covid19.cvd19_affctd_ind_pop format=comma16.0 noseps missing;
  where mwcog_region = 1 and pernum = 1 and incearn_sum > 0;
  weight hhwt;
  class statefip;
  class upuma / preloadfmt order=data;
  var total inctot_sum incearn_sum cvd19_affctd_incearn_sum;
  table 

    /** Rows **/
    all='Total' statefip=' ' * ( all=' ' upuma=' ' ),

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
  format upuma $upuma_to_mwcog_jurisd.;
run;

title3 'Households with workers in COVID-19 affected industries by potential change in HUD income category, MWCOG region';

proc tabulate data=Covid19.cvd19_affctd_ind_pop format=comma16.0 noseps missing;
  where mwcog_region = 1 and pernum = 1 and incearn_sum > 0 and not( missing( hud_inc ) );
  weight hhwt;
  class statefip hud_inc hud_inc_cvd19;
  var total;
  table 
  
    /** Pages **/
    all='MWCOG region' statefip=' ',

    /** Rows **/
    all='Total' hud_inc=' ',

    /** Columns **/
    n='N (unwtd)' * total=' ' * f=comma8.0
    sum='Households' * total=' ' * f=comma12.0

    sum='By HUD income category without COVID-19 affected earnings' * total=' ' * hud_inc_cvd19=' '
    
    /box = 'By HUD income category, 2014-18' condense
  ;
run;


title3 'Households with workers in COVID-19 affected industries by potential change in housing cost burden, MWCOG region';

proc tabulate data=Covid19.cvd19_affctd_ind_pop format=comma16.0 noseps missing;
  where mwcog_region = 1 and pernum = 1 and incearn_sum > 0 and not( missing( hud_inc ) );
  weight hhwt;
  class statefip hsg_cost_ratio hsg_cost_ratio_cvd19 / order=data preloadfmt;
  var total;
  table 

    /** Pages **/
    all='MWCOG region' statefip=' ',

    /** Rows **/
    all='Total' hsg_cost_ratio=' ',

    /** Columns **/
    n='N (unwtd)' * total=' ' * f=comma8.0
    sum='Households' * total=' ' * f=comma12.0

    sum='By housing cost burden without COVID-19 affected earnings' * total=' ' * hsg_cost_ratio_cvd19=' '
    
    /box = 'By housing cost burden, 2014-18' condense
  ;
  format hsg_cost_ratio hsg_cost_ratio_cvd19 hsg_cost_ratio.;
run;


**** Graphics ****;

footnote2;
footnote3 ' ';
footnote4 'DRAFT - NOT FOR CITATION OR RELEASE';

title3 'Workers in COVID-19 affected industries by annual earnings, MWCOG region';

proc sgplot data=Covid19.cvd19_affctd_ind_pop;
  where mwcog_region = 1 and cvd19_affctd_ind = 1 and &CVD19_BOT_1PCT_EARNINGS < incearn < &CVD19_TOP_1PCT_EARNINGS;
  histogram incearn / weight=perwt;
  label incearn = 'Annual earnings ($ 2018), 2014-18';
run;


title3 'Households with workers in COVID-19 affected industries by potential annual income loss, MWCOG region';

/*** NEED TO TRIM OUTLIERS FROM THIS CHART ***
proc sgplot data=Covid19.cvd19_affctd_ind_pop;
  where mwcog_region = 1 and pernum = 1 and incearn_sum > 0 and 0 <= pct_inc_less_cvd19_affctd_sum <= 100;
  histogram cvd19_affctd_incearn_sum / weight=hhwt;
  label 
    cvd19_affctd_incearn_sum = 'Potential lost annual earnings ($ 2018), 2014-18'
    pct_inc_less_cvd19_affctd_sum = 'Potential lost annual earnings at pct. total household income, 2014-18';
run;
****/

proc sgplot data=Covid19.cvd19_affctd_ind_pop;
  where mwcog_region = 1 and pernum = 1 and incearn_sum > 0 and 0 <= pct_inc_less_cvd19_affctd_sum <= 100;
  histogram pct_inc_less_cvd19_affctd_sum / weight=hhwt;
  label 
    cvd19_affctd_incearn_sum = 'Potential lost annual earnings ($ 2018), 2014-18'
    pct_inc_less_cvd19_affctd_sum = 'Potential lost annual earnings as pct. total household income, 2014-18';
run;


**** Details ****;

footnote2 height=9pt j=r '{Page}\~{\field{\*\fldinst{\pard\b\i0\chcbpat8\qc\f1\fs19\cf1{PAGE }\cf0\chcbpat0}}}';
footnote3 ' ';
footnote4 '\b DRAFT - NOT FOR CITATION OR RELEASE';

title2 ' ';
title3 'Workers in COVID-19 affected industries by industry (detailed), MWCOG region';

proc tabulate data=Covid19.cvd19_affctd_ind_pop format=comma16.0 noseps missing;
  where mwcog_region = 1 and cvd19_affctd_ind = 1 and &CVD19_BOT_1PCT_EARNINGS < incearn < &CVD19_TOP_1PCT_EARNINGS;
  weight perwt;
  class ind /order=freq;
  var total inctot incearn cvd19_affctd_incearn fulltime;
  table 

    /** Rows **/
    all='Total' ind='\line \i By industry',

    /** Columns **/
    n='N (unwtd)' * total=' ' * f=comma8.0
    ( sum='Workers' * f=comma10.0 pctsum='% workers' * f=comma10.1 ) * total=' ' 
    
  ;
  format ind ind_2017f. occ occ_2018f.;
run;


title3 'Workers in COVID-19 affected industries by occupation (detailed), MWCOG region';

proc tabulate data=Covid19.cvd19_affctd_ind_pop format=comma16.0 noseps missing;
  where mwcog_region = 1 and cvd19_affctd_ind = 1 and &CVD19_BOT_1PCT_EARNINGS < incearn < &CVD19_TOP_1PCT_EARNINGS;
  weight perwt;
  class occ /order=freq;
  var total inctot incearn cvd19_affctd_incearn fulltime;
  table 

    /** Rows **/
    all='Total' occ='\line \i By occupation',

    /** Columns **/
    n='N (unwtd)' * total=' ' * f=comma8.0
    ( sum='Workers' * f=comma10.0 pctsum='% workers' * f=comma10.1 ) * total=' ' 
    
  ;
  format ind ind_2017f. occ occ_2018f.;
run;


ods rtf close;
ods listing;

title2;
footnote1;
