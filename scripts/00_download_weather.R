
# Run from the R project root. Cached files are reused unless refresh is given.
source("scripts/weather_helpers.R")
dir.create("data/raw/weather", recursive = TRUE, showWarnings = FALSE)
refresh <- "--refresh" %in% commandArgs(trailingOnly = TRUE)
options(timeout = max(180, getOption("timeout")))
metadata <- list()
for (year in weather_config$years) {
  fields <- c("tmpf", "dwpf", "sknt", "gust", "vsby", "p01i",
              "wxcodes", "skyc1", "skyl1", "metar")
  parameters <- c(
    station = weather_config$station, network = weather_config$network,
    sts = sprintf("%d-12-31T00:00:00Z", year - 1L),
    ets = sprintf("%d-07-01T00:00:00Z", year),
    tz = "Etc/UTC", format = "onlycomma", latlon = "no", elev = "no",
    missing = "M", trace = "T", direct = "no",
    report_type = "3", report_type = "4", setNames(fields, rep("data", length(fields)))
  )
  query <- paste(paste0(names(parameters), "=", vapply(parameters, URLencode,
                    character(1), reserved = TRUE)), collapse = "&")
  url <- paste0("https://mesonet.agron.iastate.edu/cgi-bin/request/asos.py?", query)
  path <- sprintf("data/raw/weather/%s_JanJun_%d_weather.csv", weather_config$station, year)
  metadata_path <- sub("\\.csv$", "_download.csv", path)
  if (!file.exists(path) || refresh) {
    temporary <- tempfile(tmpdir = dirname(path), fileext = ".csv")
    succeeded <- FALSE
    for (attempt in 1:2) {
      status <- try(download.file(url, temporary, method = "libcurl", mode = "wb"), silent = TRUE)
      if (!inherits(status, "try-error") && identical(status, 0L)) {
        downloaded <- try(read.csv(temporary, stringsAsFactors = FALSE), silent = TRUE)
        if (!inherits(downloaded, "try-error") && nrow(downloaded) > 0 &&
            all(c("station", "valid", "sknt", "p01i", "metar") %in% names(downloaded))) {
          succeeded <- TRUE
          break
        }
      }
    }
    if (!succeeded) stop("Weather download failed; existing cache was preserved: ", url)
    if (!file.copy(temporary, path, overwrite = TRUE)) stop("Cannot save weather file: ", path)
    unlink(temporary)
    write.csv(data.frame(url = url,
                        retrieved_utc = format(Sys.time(), tz = "UTC", usetz = TRUE)),
              metadata_path, row.names = FALSE)
  }
  data <- read.csv(path, stringsAsFactors = FALSE)
  stopifnot(nrow(data) > 0, all(data$station == weather_config$station),
            all(c("valid", "sknt", "p01i", "wxcodes", "metar") %in% names(data)))
  stopifnot(min(data$valid) < sprintf("%d-01-01", year),
            max(data$valid) >= sprintf("%d-06-30", year))
  provenance <- read.csv(metadata_path, stringsAsFactors = FALSE)
  metadata[[as.character(year)]] <- data.frame(
    year = year, file = path, rows = nrow(data),
    first_observation_utc = min(data$valid), last_observation_utc = max(data$valid),
    md5 = unname(tools::md5sum(path)), url = provenance$url,
    retrieved_utc = provenance$retrieved_utc
  )
  message("Weather cache ready: ", path, " (", nrow(data), " reports)")
}
write.csv(do.call(rbind, metadata), "data/raw/weather/download_manifest.csv", row.names = FALSE)
