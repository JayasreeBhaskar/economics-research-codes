/*==============================================================================
FILE:     02_construct_tfp.do
PURPOSE:  Build the household-wave working dataset and estimate farm-level
          TFP via Levinsohn-Petrin. This is the file that produces
          ETH_working_tfp.dta, which 03_merge_soil_panel.do then merges the
          soil-quality panel into.

STEPS:
  1. Collapse plot-level records to one household-wave observation (sum
     harvest/input quantities across plots; take max of plot-level 0/1
     shock and technology indicators; take the first value of
     household/geographic variables that don't vary across plots).
  2. Merge in household-level characteristics (household file) not already
     present at the plot level.
  3. Construct log output, labour, land and materials variables and estimate
     the Levinsohn-Petrin production function.
  4. Compute TFP as the residual of log output net of the LP-predicted
     input contribution, and winsorise at the 1st/99th percentile to limit
     the influence of outliers.

NOTE: ETH_FINAL_plot.dta and ETH_FINAL_hh.dta (the inputs to this file) are
      the harmonised LSMS-ISA panel produced following the procedure in
      Bentze, T., & Wollburg, P. (2025), Scientific Data, 12, 1843 (see
      00_setup.do). The collapse, TFP estimation, and everything downstream
      of that harmonised panel are original to this project.
==============================================================================*/

do "00_setup.do"
use "$output/ETH_FINAL_plot.dta", clear
drop if urban == 1

* Collapse plot-level records to one household-wave observation.
* NOTE: the (first) key must be hh_id_merge, not hh_id_obs - collapsing on
* hh_id_obs as the (first) target produced duplicate hh_id_obs-wave pairs
* whenever a household's plots disagreed on a nominally household-level
* field; hh_id_merge is the unique cross-wave identifier and does not have
* this problem.
collapse (sum) harvest_kg harvest_value_USD ///
               seed_value_USD inorganic_fertilizer_value_USD ///
               total_labor_days plot_area ///
         (max) irrigated organic_fertilizer inorganic_fertilizer ///
               improved used_pesticides crop_shock drought_shock ///
               tractor ///
         (first) hh_id_merge pw strataid ///
                 admin_1 admin_1_name ea_id_obs ///
                 lat_modified lon_modified ///
                 elevation dist_market agro_ecological_zone twi ///
                 nutrient_availability rooting_conditions ///
                 workability soil_fertility_index, ///
         by(hh_id_obs wave)

merge 1:1 hh_id_merge wave using "$output/ETH_FINAL_hh.dta", ///
    keep(master match) nogen ///
    keepusing(hh_size hh_primary_education hh_dependency_ratio ///
              hh_electricity_access hh_asset_index ///
              nonfarm_enterprise totcons_USD urban HDDS ///
              nb_fallow_plots nb_plots share_kg_sold hh_shock)

xtset hh_id_obs wave
duplicates report hh_id_obs wave

* --- Production function variables ------------------------------------------
gen materials_USD = seed_value_USD + inorganic_fertilizer_value_USD

gen ly = ln(harvest_value_USD)
gen ll = ln(total_labor_days + 1)
gen lk = ln(plot_area)
gen lm = ln(materials_USD + 1)

drop if missing(ly) | harvest_value_USD == 0
drop if missing(lk) | plot_area == 0

count
tab wave

* --- Levinsohn-Petrin estimation --------------------------------------------
levpet ly, free(ll) proxy(lm) capital(lk) reps(50) level(95)

* Fitted values are computed manually from the reported LP coefficients
* rather than via `predict, omega`: the built-in prediction produced an
* implausible TFP distribution on this sample (likely due to how `omega`
* is recovered when the proxy variable has a meaningful mass point at
* materials_USD = 0), so the coefficients are applied directly instead.
gen ly_hat = 0.4994104*ll + 0.2564934*lk
gen tfp_lp = ly - ly_hat

summarize tfp_lp, detail

* Winsorise at the 1st/99th percentile to limit outlier influence, rather
* than dropping extreme observations outright
winsor2 tfp_lp, cuts(1 99) replace
summarize tfp_lp, detail

histogram tfp_lp, normal ///
    title("TFP Distribution") ///
    xtitle("Log TFP (Levinsohn-Petrin)") ytitle("Density")

save "$output/ETH_working_tfp.dta", replace
