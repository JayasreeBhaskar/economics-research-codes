/*
FILE:     05_robustness.do
PURPOSE:  Robustness checks for the preferred Mundlak specification in
          04_main_specifications.do.

CHECKS:
  A. Composite soil index (soil_index_std) in place of the three separate
     components - addresses collinearity between sq3_ord and sq7_ord
     (r = 0.72).
  B. Balanced-subsample check - restrict to households observed in >= 3
     waves, to test whether attrition is driving the main result.
  C. Attrition probit - test whether wave-1 household characteristics
     predict subsequent dropout (selective attrition would bias the panel
     estimates).
  D. IV check - soil quality as an instrument for land input in the
     production function, to gauge whether land elasticity estimates are
     sensitive to land-quality-driven measurement error.
  E. Alternative output measure - re-estimate TFP using harvest quantity
     (kg) rather than harvest value (USD) as the output measure, so the
     main result is not an artefact of price variation across markets/time
     being absorbed into the value-based TFP measure.
*/

do "00_setup.do"
use "$output/ETH_working_tfp_new_index.dta", clear

bysort hh_id_obs: egen mean_hh_size     = mean(hh_size)
bysort hh_id_obs: egen mean_asset       = mean(hh_asset_index)
bysort hh_id_obs: egen mean_irrigated   = mean(irrigated)
bysort hh_id_obs: egen mean_dist_market = mean(dist_market)
bysort hh_id_obs: egen mean_nonfarm     = mean(nonfarm_enterprise)
bysort hh_id_obs: egen mean_educ        = mean(hh_primary_education)

//-------------------------------------------------------------------------

//A. Composite soil index
correlate sq1_ord sq3_ord sq7_ord

reg tfp_lp soil_index_std ///
    hh_size hh_primary_education hh_asset_index ///
    irrigated dist_market nonfarm_enterprise ///
    drought_shock crop_shock ///
    elevation twi i.agro_ecological_zone ///
    i.wave ///
    mean_hh_size mean_asset mean_irrigated ///
    mean_dist_market mean_nonfarm mean_educ, robust
eststo robust_composite

//-------------------------------------------------------------------------
// B. Balanced subsample (households observed in >= 3 waves)
bysort hh_id_obs: gen n_waves = _N

reg tfp_lp sq1_ord sq3_ord sq7_ord ///
    hh_size hh_primary_education hh_asset_index ///
    irrigated dist_market nonfarm_enterprise ///
    drought_shock crop_shock ///
    elevation twi i.agro_ecological_zone ///
    i.wave ///
    mean_hh_size mean_asset mean_irrigated ///
    mean_dist_market mean_nonfarm mean_educ ///
    if n_waves >= 3, robust
eststo robust_balanced

esttab robust_composite robust_balanced using "$output/robustness_results.rtf", ///
    label replace se star(* 0.10 ** 0.05 *** 0.01) ///
    title("Robustness: Composite Soil Index and Balanced Subsample")

//-------------------------------------------------------------------------
// C. Attrition probit - does wave-1 farm/household profile predict dropout?
preserve
    use "$output/ETH_FINAL_plot.dta", clear
    drop if urban == 1

    collapse (first) farm_size ag_asset_index urban elevation ///
        dist_market formal_education_manager, ///
        by(hh_id_obs wave)

    bysort hh_id_obs: gen n_waves_seen = _N
    gen attrites = (n_waves_seen == 1)
    keep if wave == 1

    tab attrites
    probit attrites farm_size ag_asset_index urban ///
        elevation dist_market formal_education_manager, robust
    margins, dydx(*)
restore

//-------------------------------------------------------------------------
// D. IV: soil quality as instrument for land input in the production
//    function (checks sensitivity of the land elasticity estimate to
//    land-quality-driven measurement error, rather than the TFP-soil
//    relationship itself)
ivregress 2sls tfp_lp (lk = sq1_ord sq3_ord sq7_ord) ///
    ll lm i.wave, robust
estat firststage
reg lk sq1_ord sq3_ord sq7_ord ll lm i.wave, robust

//-------------------------------------------------------------------------
// E. Alternative output measure: harvest quantity (kg) instead of harvest
//    value (USD). A value-based TFP measure can conflate true productivity
//    differences with price variation across markets/time; re-estimating
//    LP on log harvest_kg checks whether the soil-quality result survives
//    under a purely physical output measure.
preserve
    drop if missing(harvest_kg) | harvest_kg == 0
    gen ly_kg = ln(harvest_kg)
    count
    tab wave

    levpet ly_kg, free(ll) proxy(lm) capital(lk) reps(50) level(95)

    // Coefficients taken directly from the levpet output above, following
    // the same manual-fitted-value approach used in 02_construct_tfp.do
    gen ly_kg_hat = 0.4202745*ll + 0.4076765*lk
    gen tfp_kg_lp = ly - ly_kg_hat
    summarize tfp_kg_lp, detail
    winsor2 tfp_kg_lp, cuts(1 99) replace

    reg tfp_kg_lp sq1_ord sq3_ord sq7_ord ///
        hh_size hh_primary_education hh_asset_index ///
        irrigated dist_market nonfarm_enterprise ///
        drought_shock flood_shock crop_shock rain_shock ///
        elevation twi i.agro_ecological_zone ///
        i.wave ///
        mean_hh_size mean_asset mean_irrigated ///
        mean_dist_market mean_nonfarm mean_educ, robust
    eststo robust_kg_output

    esttab robust_kg_output using "$output/robustness_kg_results.rtf", ///
        label replace se star(* 0.10 ** 0.05 *** 0.01) ///
        title("Robustness: TFP Estimated on Harvest Quantity Rather Than Value")
restore
