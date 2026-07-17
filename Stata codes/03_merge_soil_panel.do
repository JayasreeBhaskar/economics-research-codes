/*
FILE:     03_merge_soil_panel.do
PURPOSE:  Merge the soil-quality panel (01_soil_index_construction.do) into
          the household-wave working file with TFP estimates
          (ETH_working_tfp.dta, built in 02_construct_tfp.do), producing the
          analysis-ready dataset used by 04-06.
*/

do "00_setup.do"

use "$output/ETH_working_tfp.dta", clear

// m:1 merge: multiple plots per household can share the same household-level
// soil-quality reading in a given wave
merge m:1 hh_id_merge wave using "$temp/soil_panel_ordinal.dta", ///
    keep(master match) nogen

// Match-rate check by wave
tab wave if missing(soil_index_std)
summarize soil_index_std sq1_ord sq3_ord sq7_ord

save "$output/ETH_working_tfp_new_index.dta", replace
