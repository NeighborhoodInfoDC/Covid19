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

proc format;

  value ind_sum (notsorted)
    8680, 8690 = 'Food & drink establishments'
    6070 = 'Air transportation'
    6080, 6090, 6180, 6190 = 'Other transportation'
    6280, 7670, 8660, 8670 = 'Tourism & travel'
    8560-8590 = 'Arts & recreation'
    0370-0490 = 'Other COVID-19 affected industries';

  value race_sum (notsorted)
    100 = 'White'
    200 = 'Black'
    400-620, 640-679 = 'Asian'
    /*
    300-399 = 'American Indian/Alaska Native'
    630,680-699 = 'Native Hawaiian/Pacific Islander'
    700 = 'Other race'
    */
    300-399, 630,680-699, 700 = 'Other races'
    801-996 = 'Multiple races';
    
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
    
  value yesnona (notsorted)
    1 = 'Yes'
    0 = 'No'
    .n = 'n/a';
    
run;  

** Worker tables **;

options nodate nonumber;

%fdate()

ods rtf file="&_dcdata_default_path\Covid19\Prog\Cvd19_affctd_ind_pop_tables.rtf" style=Styles.Rtf_arial_9pt;

footnote1 height=9pt "Prepared by Urban-Greater DC (greaterdc.urban.org), &fdate..";
footnote2 height=9pt j=r '{Page}\~{\field{\*\fldinst{\pard\b\i0\chcbpat8\qc\f1\fs19\cf1{PAGE }\cf0\chcbpat0}}}';

title2 ' ';
title3 'Workers in COVID-19 affected industries by industry, MWCOG region';

proc tabulate data=Covid19.cvd19_affctd_ind_pop format=comma16.0 noseps missing;
  where mwcog_region = 1 and cvd19_affctd_ind = 1;
  weight perwt;
  class ind /order=data preloadfmt;
  var total inctot incearn cvd19_affctd_incearn fulltime;
  table 

    /** Rows **/
    all='Total' ind='\line \i By industry',

    /** Columns **/
    sum='Workers' * total=' ' * f=comma10.0
    
    mean='Full time workers' * fulltime=' ' * f=percent10.0

    sum='Annual income ($ 2016), 2012-16' * 
    ( inctot='Total income' 
      cvd19_affctd_incearn='Earnings from COVID-19 affected industries' )

    mean='Annual income per capita ($ 2016), 2012-16' * 
    ( inctot='Total income' 
      cvd19_affctd_incearn='Earnings from COVID-19 affected industries' )

    pctsum<inctot>='COVID-19 affected earnings as pct. total income' * 
    cvd19_affctd_incearn=' ' *
    f=comma12.1

  ;
  format ind ind_sum.;
run;


title3 'Characteristics of workers in COVID-19 affected industries, MWCOG region';

proc tabulate data=Covid19.cvd19_affctd_ind_pop format=comma16.0 noseps missing;
  where mwcog_region = 1 and cvd19_affctd_ind = 1;
  weight perwt;
  class ind /order=data preloadfmt;
  class statefip sex raced hispand poverty hud_inc classwkrd fulltime yearround educd /order=data preloadfmt; 
  var total inctot incearn cvd19_affctd_incearn;
  table 

    /** Rows **/
    all='Total' 
    statefip='\line \i By state'
    sex='\line \i By sex'
    raced='\line \i By race'
    hispand='\line \i By Hispanic status'
    poverty='\line \i By family poverty status'
    hud_inc='\line \i By HUD income category'
    classwkrd='\line \i By class of worker'
    fulltime='\line \i By full time worker status'
    yearround='\line \i By year-round worker status'
    educd='\line \i By educational attainment'
    ,

    /** Columns **/
    sum='Workers' * total=' ' * f=comma10.0
    pctsum='% workers' * total=' ' * f=comma10.1
    
    mean='Annual income per capita ($ 2016), 2012-16' * 
    ( inctot='Total income' 
      cvd19_affctd_incearn='Earnings from COVID-19 affected industries' )

  ;
  format ind ind_sum. raced race_sum. hispand hispan_sum. poverty poverty_sum. educd educ_sum.
         fulltime yearround yesnona.;
run;

ods rtf close;

title2;
footnote1;
