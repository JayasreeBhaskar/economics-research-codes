/*
FILE:     01_soil_index_construction.do
PURPOSE:  Build a standardised soil-quality index for each household-wave from
          three self-reported plot characteristics (sq1 = fertility, sq3 =
          erosion, sq7 = workability). Requires 00_setup.do to have been run.

METHOD:
  1. Recode each raw component to a 1-4 ordinal scale, reverse-coded so that
     4 = best quality; non-soil / missing response categories set to missing.
  2. Standardise each recoded component to mean 0, sd 1.
  3. Average the three standardised components into a single index, then
     re-standardise the average (soil_index_std). Kept alongside the three
     individual ordinal components (sq1_ord, sq3_ord, sq7_ord) so the main
     specification can enter them separately, with soil_index_std used as a
     composite-index robustness check (see 04_robustness.do) given sq3/sq7
     are correlated (r = 0.72).
  4. Repeat for each of the 5 waves and append into a single household-wave
     panel, using hh_id_merge as the cross-wave household identifier.
*/

do "00_setup.do"

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

* Household ID variable name differs by wave in the raw LSMS-ISA files
local id_var1 "household_id"
local id_var2 "household_id2"
local id_var3 "household_id2"
local id_var4 "household_id"
local id_var5 "household_id"

foreach w of local waves {

    use "$input/`input_folder`w''/`raw_file`w''", clear

    //Harmonise the household identifier across waves
    rename `id_var`w'' hh_id_merge

    // Step 1: recode to ordinal 1-4, reverse-coded (4 = best quality)
    //   raw categories 5/6/7 denote "not applicable"/"don't know"/other and
    //   are set to missing rather than treated as a quality level
    foreach v in sq1 sq3 sq7 {
        recode `v' (1=4) (2=3) (3=2) (4=1) (5 6 7 = .), gen(`v'_ord)
    }

    // Step 2: standardise each component
    foreach v in sq1_ord sq3_ord sq7_ord {
        egen `v'_z = std(`v')
    }

    // Step 3: equal-weighted composite, re-standardised
    gen soil_index_ord = (sq1_ord_z + sq3_ord_z + sq7_ord_z) / 3
    egen soil_index_std = std(soil_index_ord)

    gen wave = `w'

    keep hh_id_merge wave sq1_ord sq3_ord sq7_ord soil_index_std
    drop if missing(hh_id_merge)

    save "$temp/`temp_folder`w''/soil_ordinal_w`w'.dta", replace
}

// Append all waves into a single soil-quality panel
use "$temp/ESS11/soil_ordinal_w1.dta", clear
forvalues w = 2/5 {
    local tfold = cond(`w' == 2, "ESS13", ///
                  cond(`w' == 3, "ESS15", ///
                  cond(`w' == 4, "ESS18", "ESS21")))
    append using "$temp/`tfold'/soil_ordinal_w`w'.dta"
}

////
duplicates report hh_id_merge wave
tab wave
summarize soil_index_std sq1_ord sq3_ord sq7_ord

save "$temp/soil_panel_ordinal.dta", replace
