# Unobserved Productivity Differences and Heterogeneity in Soil Quality: Evidence from Ethiopia

MSc extended essay, London School of Economics (LSE).

## Research question

Does variation in soil quality explain part of the persistent productivity
gap between smallholder farms, once unobserved household heterogeneity
(farmer ability, management practices) is accounted for? Further, we assess the
effect of transient and permanent wealth shocks, investment and education levels
on farm productivity.

## Data

Ethiopia Socioeconomic Survey (ESS / LSMS-ISA), five waves, World Bank
(public). Household geovariable files provide plot-level soil quality
indicators (fertility, erosion, workability); main survey modules provide
inputs and outputs used to estimate farm-level total factor productivity via
Levinsohn-Petrin.

**Attribution:** the harmonised panel this project builds on
(`ETH_FINAL_plot.dta`, `ETH_FINAL_hh.dta`) follows the cross-wave
harmonisation procedure described in Bentze, T., & Wollburg, P. (2025), "A
longitudinal cross-country dataset on agricultural productivity and welfare
in sub-Saharan Africa," *Scientific Data*, 12, 1843
(https://doi.org/10.1038/s41597-025-05639-9). That harmonisation is not my
own work. Everything from the soil-quality index construction onward - the
TFP estimation approach, the Mundlak identification strategy, and all
specifications and robustness checks - is original to this project.

## Method

1. **Soil quality index**: three self-reported plot characteristics are
   recoded to a common 1-4 ordinal scale, standardised, and combined into a
   single index (kept as separate components for the main
   specification).
2. **TFP estimation**: Levinsohn-Petrin production function estimation
   (see `02_merge_panel.do` header) yields
   household-plot-wave log TFP.
3. **Identification**: the main challenge is that farmers with better
   underlying ability may both select onto better land and achieve higher
   TFP for reasons unrelated to the land itself. The preferred specification
   uses a **Mundlak** device (within-household means of time-varying
   controls) to purge the soil-quality coefficient of this bias, alongside
   wave and agro-ecological-zone (AEZ) fixed effects.
4. **Robustness**: a composite soil index (addressing collinearity between
   components), a balanced-subsample check (attrition), an attrition probit,
   an IV specification using soil quality as an instrument for land input in
   the production function itself, and re-estimating TFP on harvest
   quantity rather than harvest value to rule out price variation driving
   the result.

## File guide

| File | Purpose |
|---|---|
| `do/00_setup.do` | Project path globals |
| `do/01_soil_index_construction.do` | Build soil-quality panel across 5 waves |
| `do/02_construct_tfp.do` | Collapse to household-wave level, merge household controls, estimate Levinsohn-Petrin TFP |
| `do/03_merge_soil_panel.do` | Merge soil panel into the household-wave TFP dataset |
| `do/04_main_specifications.do` | Naive → controlled → Mundlak specification progression |
| `do/05_robustness.do` | Composite index, balanced subsample, attrition, IV, alternative-output-measure checks |
| `do/06_figures_tables.do` | Descriptive figures and summary statistics table |

## Notes

Raw LSMS-ISA files are not included (available directly from the World Bank
Microdata Library).
