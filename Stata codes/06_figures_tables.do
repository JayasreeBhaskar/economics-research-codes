/*
FILE:     06_figures_tables.do
PURPOSE:  Descriptive figures and summary statistics table for the write-up.
*/

do "00_setup.do"
use "$output/ETH_working_tfp_new_index.dta", clear

// Standardise region-name spellings (raw survey rounds use inconsistent
// casing/spelling for admin_1_name)
replace admin_1_name = "Tigray" if admin_1_name == "TIGRAY"
replace admin_1_name = "Afar" if admin_1_name == "AFAR"
replace admin_1_name = "Amhara" if admin_1_name == "AMHARA"
replace admin_1_name = "Oromia" if admin_1_name == "OROMIA"
replace admin_1_name = "Somali" if inlist(admin_1_name, "SOMALI", "Somalie")
replace admin_1_name = "Benishangul-Gumuz" if inlist(admin_1_name, "BENISHANGUL GUMUZ", "Benshagul Gumuz")
replace admin_1_name = "Gambela" if inlist(admin_1_name, "GAMBELA", "Gambelia")
replace admin_1_name = "Harari" if admin_1_name == "HARAR"
replace admin_1_name = "Dire Dawa" if inlist(admin_1_name, "DIRE DAWA", "Diredwa")

//-------------------------------------------------------------------------

// Summary statistics table
cap ssc install estout
estpost summarize harvest_value_USD harvest_kg ///
    total_labor_days plot_area ///
    seed_value_USD inorganic_fertilizer_value_USD ///
    tfp_lp soil_index_std sq1_ord sq3_ord sq7_ord ///
    hh_size hh_primary_education hh_asset_index ///
    irrigated improved, detail

esttab using "$output/summary_stats.rtf", ///
    cells("mean(fmt(3)) sd(fmt(3)) min(fmt(3)) max(fmt(3)) count(fmt(0))") ///
    nomtitle nonumber label replace

//-------------------------------------------------------------------------

// Figures 
histogram tfp_lp, normal ///
    title("Distribution of Farm TFP") ///
    xtitle("Log TFP (Levinsohn-Petrin)") ytitle("Density") ///
    scheme(s2mono)
graph export "$output/tfp_distribution.png", replace

graph box tfp_lp, over(wave) ///
    title("TFP Distribution by Wave") ytitle("Log TFP") ///
    scheme(s2mono)
graph export "$output/tfp_by_wave.png", replace

graph box tfp_lp, over(admin_1_name, sort(1) descending) ///
    title("TFP Distribution by Region") ytitle("Log TFP") ///
    scheme(s2mono)
graph export "$output/tfp_by_region.png", replace

histogram soil_index_std, normal ///
    title("Distribution of Soil Quality Index") ///
    xtitle("Soil Quality Index (standardised)") ytitle("Density") ///
    scheme(s2mono)
graph export "$output/soil_distribution.png", replace

cap ssc install binscatter
binscatter tfp_lp soil_index_std, ///
    title("TFP and Soil Quality") ///
    xtitle("Soil Quality Index") ytitle("Log TFP")
graph export "$output/tfp_soil_scatter.png", replace
