/**************************************************************************
 Program:  Cvd19_affctd_ind_hh_foodinsecurity.sas
 Library:  Covid19
 Project:  Urban-Greater DC
 Author:   P. Tatian
 Created:  04/04/20
 Version:  SAS 9.4
 Environment:  Local Windows session (desktop)
 GitHub issue:  1
 
 Description:  Expanded tables on COVID-19 affected workers and
 households. 
 
 RTF tables use Styles.Rtf_arial_9pt ODS style, which must first be created 
 by batch submitting L:\Libraries\General\Prog\Style_rtf_arial_9pt.sas. 

 Modifications:
**************************************************************************/

%include "L:\SAS\Inc\StdLocal.sas";

** Define libraries **;
%DCData_lib( Covid19 )
%DCData_lib( Ipums )


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

  value family_type (notsorted)
     0 = 'Not applicable/Undetermined'
	 1 = 'Married family with children'
	 2 = 'Married family without children'
	 3 = 'Single family with children'
	 4 = 'Single family without children';

  value hh_size (notsorted)
    1 = '1 person HH'
	2 = '2 person HH'
	3 = '3 person HH'
	4 = '4 person HH'
	5 = '5 person HH'
	6-high = '6+ person HH';
    
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

ods rtf file="&_dcdata_default_path\Covid19\Prog\vd19_affctd_ind_hh_foodinsecurity_tables.rtf" /*style=Styles.Rtf_arial_9pt*/;
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

proc tabulate data=Covid19.cvd19_affctd_ind_pop format=comma16.0 noseps missing;
  where mwcog_region = 1 and cvd19_affctd_ind = 1 and &CVD19_BOT_1PCT_EARNINGS < incearn < &CVD19_TOP_1PCT_EARNINGS
        and 1 <= hud_inc <= 3;
  weight perwt;
  class ind /order=data preloadfmt;
  class 
    statefip upuma age sex race_ethn poverty hud_inc classwkrd fulltime yearround educd 
    ownershp hsg_cost_ratio numprec famtype
    /order=data preloadfmt; 
  var total inctot incearn cvd19_affctd_incearn;
  table 

	/** Sheets **/
    upuma =' ',
    /** Rows **/
    all='Total' 
	numprec='\line \i By household size'
	famtype='\line \i By family type'
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
         hud_inc hudinc. fulltime yearround yesnona. famtype family_type. numprec hh_size.;
run;


**** Household tables ****;

title3 'Characteristics of Households with affected workers, MWCOG region';

proc tabulate data=Covid19.cvd19_affctd_ind_pop format=comma16.0 noseps missing;
  where mwcog_region = 1 and pernum = 1 and cvd19_affctd_incearn_sum > 0 and cvd19_affctd_ind_Sum > 0;
  weight hhwt;
  class statefip hud_inc famtype;
  class upuma / preloadfmt order=data;
  var total inctot_sum incearn_sum cvd19_affctd_incearn_sum numprec child_sum elder_sum numprec;
  table 
    
    /** Sheets **/
    upuma = ' ',
    /** Rows **/
	famtype='\line \i By family type'
    ,


    /** Columns **/
	sum="People"*numprec
	sum="Children"*child_sum
	sum="Elders"*elder_sum
    ;

    format ind ind_sum. age age_sum. raced race_sum. hispand hispan_sum. poverty poverty_sum. educd educ_sum.
         hsg_cost_ratio hsg_cost_ratio. upuma $upuma_to_mwcog_jurisd. race_ethn race_ethn.
         hud_inc hudinc_low. fulltime yearround yesnona. famtype family_type.;
run;

ods rtf close;
ods listing;

title2;
footnote1;
