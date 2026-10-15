# Open the RStudio project, then source this file from the project root.
# Weather downloads use the cache; only missing pilot files require a download.
source("scripts/00_download_weather.R")
source("scripts/02_prepare_data.R")
source("scripts/03_fit_models.R")
source("scripts/04_proposal_results.R")
message("Finished. See results/pilot/proposal_comparison.md; reserved test not scored.")
