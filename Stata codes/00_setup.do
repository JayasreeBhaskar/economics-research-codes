/*
PROJECT:  Unobserved Productivity Differences and Heterogeneity in Soil Quality:
          Evidence from Ethiopia
FILE:     00_setup.do
PURPOSE:  Define project directory globals. Run once at the start of any
          session before executing 01-06.
DATA:     LSMS-ISA Ethiopia Socioeconomic Survey (ESS), Waves 1-5 (public,
          World Bank). Household geovariable files + main survey modules.
		  
		  Harmonised dataset complied through the procedure described by
		  Bentze, T., & Wollburg, P. (2025). A longitudinal cross-country dataset
		  on agricultural productivity and welfare in sub-saharan africa.
		  Scientific Data, 12, 1843. https://doi.org/10.1038/s41597-025-05639-9
*/
clear all
set more off
//-------------------------------------------------------------------------
global root   "`c(pwd)'"                       // project root
global input  "$root/input_data"               // raw LSMS-ISA files (by wave)
global temp   "$root/temp_data"                // intermediate panel files
global output "$root/output"                   // final datasets, tables, figures
// -----------------------------------------------------------------------------
cap mkdir "$temp"
cap mkdir "$output"
// Wave <-> folder-naming lookup used throughout (raw folders contain spaces,
// temp folders do not)
local waves 1 2 3 4 5
local input_folder1  "ESS 11"
local input_folder2  "ESS 13"
local input_folder3  "ESS 15"
local input_folder4  "ESS 18"
local input_folder5  "ESS 21"
local temp_folder1   "ESS11"
local temp_folder2   "ESS13"
local temp_folder3   "ESS15"
local temp_folder4   "ESS18"
local temp_folder5   "ESS21"
local raw_file1 "Pub_ETH_HouseholdGeovariables_Y1.dta"
local raw_file2 "Pub_ETH_HouseholdGeovars_Y2.dta"
local raw_file3 "ETH_HouseholdGeovars_y3.dta"
local raw_file4 "ETH_HouseholdGeovariables_Y4.dta"
local raw_file5 "eth_householdgeovariables_y5.dta"
foreach w of local waves {
    cap mkdir "$temp/`temp_folder`w''"
}
