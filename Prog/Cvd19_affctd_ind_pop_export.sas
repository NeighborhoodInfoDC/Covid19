/**************************************************************************
 Program:  Cvd19_affctd_ind_pop_export.sas
 Library:  Covid19
 Project:  Urban-Greater DC
 Author:   P. Tatian
 Created:  04/30/20
 Version:  SAS 9.4
 Environment:  Local Windows session (desktop)
 GitHub issue:  1
 
 Description:  Export Covid19.Cvd19_affctd_ind_pop as CSV file.

 Modifications:
**************************************************************************/

%include "L:\SAS\Inc\StdLocal.sas";

** Define libraries **;
%DCData_lib( Covid19 )
%DCData_lib( Ipums )

/** Macro Export - Start Definition **/

%macro Export( data=, out=, desc= );

  %local lib file;
  
  %if %scan( &data, 2, . ) = %then %do;
    %let lib = work;
    %let file = &data;
  %end;
  %else %do;
    %let lib = %scan( &data, 1, . );
    %let file = %scan( &data, 2, . );
  %end;

  %if &out = %then %let out = &file;
  
  %if %length( &desc ) = 0 %then %do;
    proc sql noprint;
      select memlabel into :desc from dictionary.tables
        where upcase(libname)=upcase("&lib") and upcase(memname)=upcase("&file");
      quit;
    run;
  %end;

  filename fexport "&out_folder\&out..csv" lrecl=2000;

  proc export data=&data
      outfile=fexport
      dbms=csv replace;

  run;
  
  filename fexport clear;

  proc contents data=&data out=_cnt_&out (keep=varnum name label label="&desc") noprint;

  proc sort data=_cnt_&out;
    by varnum;
  run;      
  
  %let file_list = &file_list &out;

%mend Export;

/** End Macro Definition **/


/** Macro Dictionary - Start Definition **/

%macro Dictionary( );

  %local desc;

  ** Start writing to XML workbook **;
    
  ods listing close;

  ods tagsets.excelxp file="&out_folder\Data dictionary.xls" style=Normal 
      options( sheet_interval='Proc' orientation='landscape' );

  ** Write data dictionaries for all files **;

  %local i k;

  %let i = 1;
  %let k = %scan( &file_list, &i, %str( ) );

  %do %until ( &k = );
   
    proc sql noprint;
      select memlabel into :desc from dictionary.tables
        where upcase(libname)="WORK" and upcase(memname)=upcase("_cnt_&k");
      quit;
    run;

    ods tagsets.excelxp 
        options( sheet_name="&k" 
                 embedded_titles='yes' embedded_footnotes='yes' 
                 embed_titles_once='yes' embed_footers_once='yes' );

    proc print data=_cnt_&k label;
      id varnum;
      var name label;
      label 
        varnum = 'Col #'
        name = 'Name'
        label = 'Description';
      title1 bold "Data dictionary for file: &k..csv";
      title2 bold "&desc";
      title3 height=10pt "Prepared by Urban-Greater DC on %left(%qsysfunc(date(),worddate.)).";
      footnote1;
    run;

    %let i = %eval( &i + 1 );
    %let k = %scan( &file_list, &i, %str( ) );

  %end;

  ** Close workbook **;

  ods tagsets.excelxp close;
  ods listing;

  run;
  
%mend Dictionary;


** Examine earnings for outliers **;

%global CVD19_BOT_1PCT_EARNINGS CVD19_TOP_1PCT_EARNINGS;

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


** Create data set for export **;

%Fmt_ind_2017f()
%Fmt_occ_2018f()

data Cvd19_affctd_ind_pop;

  set Covid19.cvd19_affctd_ind_pop;
  where MWCOG_region = 1;
  
  Worker_keep = ( &CVD19_BOT_1PCT_EARNINGS < incearn < &CVD19_TOP_1PCT_EARNINGS );
  
  label Worker_keep = "Workers with positive, non-outlier earnings (trimmed top/bottom 1%)";
  
  format Worker_keep dyesno.;
  
  ** Convert .N to regular missing **;
  
  array a{*} OWNCOST INC: hsg_cost_ratio: hud_inc: ;
  
  do i = 1 to dim( a );
  
    if missing( a{i} ) then a{i} = .;
    
  end;
  
  format ind ind_2017f. occ occ_2018f.;

  drop total MET2013 i;

run;

proc freq data=cvd19_affctd_ind_pop;
  tables Worker_keep;
run;

options missing=' ';


%global file_list out_folder;

** DO NOT CHANGE - This initializes the file_list macro variable **;
%let file_list = ;

** Fill in the folder location where the export files should be saved **;
%let out_folder = &_dcdata_default_path\Covid19\Raw;

** Export individual data sets **;
%Export( data=Cvd19_affctd_ind_pop )

** Create data dictionary **;
%Dictionary()

run;
