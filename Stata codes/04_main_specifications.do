/*
FILE:     04_main_specifications.do
PURPOSE:  Estimate the relationship between soil quality and farm TFP,
          building up from a naive cross-sectional regression to the
          preferred Mundlak specification that accounts for unobserved
          time-invariant household heterogeneity.

OUTCOME:  tfp_lp - log TFP from Levinsohn-Petrin estimation
KEY REGRESSORS: sq1_ord, sq3_ord, sq7_ord - soil fertility, erosion,
          workability (1-4 ordinal, 4 = best)
*/

do "00_setup.do"
use "$output/ETH_working_tfp_new_index.dta", clear

// Household-level means of time-varying controls (Mundlak device): these
// proxy for the unobserved household-specific effect correlated with both
// soil quality and input choices
bysort hh_id_obs: egen mean_hh_size     = mean(hh_size)
bysort hh_id_obs: egen mean_asset       = mean(hh_asset_index)
bysort hh_id_obs: egen mean_irrigated   = mean(irrigated)
bysort hh_id_obs: egen mean_dist_market = mean(dist_market)
bysort hh_id_obs: egen mean_nonfarm     = mean(nonfarm_enterprise)
bysort hh_id_obs: egen mean_educ        = mean(hh_primary_education)

//-------------------------------------------------------------------------
// Spec 1: naive - TFP on soil quality only, no controls
reg tfp_lp sq1_ord sq3_ord sq7_ord, robust
eststo spec1

//-------------------------------------------------------------------------
// Spec 2: add household controls and survey-wave fixed effects
reg tfp_lp sq1_ord sq3_ord sq7_ord ///
    hh_size hh_primary_education hh_asset_index ///
    irrigated dist_market nonfarm_enterprise ///
    i.wave, robust
eststo spec2

//-------------------------------------------------------------------------
// Spec 3 (preferred): Mundlak - adds within-household means of the
// time-varying controls to purge the soil-quality coefficient of bias from
// unobserved, time-invariant household characteristics (e.g. persistent
// farmer ability) that could be correlated with both soil quality and TFP
reg tfp_lp sq1_ord sq3_ord sq7_ord ///
    hh_size hh_primary_education hh_asset_index ///
    irrigated dist_market nonfarm_enterprise ///
    drought_shock crop_shock ///
    elevation twi i.agro_ecological_zone ///
    i.wave ///
    mean_hh_size mean_asset mean_irrigated ///
    mean_dist_market mean_nonfarm mean_educ, robust
eststo spec3

esttab spec1 spec2 spec3 using "$output/main_results.rtf", ///
    label replace se star(* 0.10 ** 0.05 *** 0.01) ///
    title("TFP and Soil Quality: Naive, Controlled, and Mundlak Specifications")
