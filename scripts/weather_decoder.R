# METAR present-weather decoding for the midway model table.
# metar_precipitation() is copied unchanged from proposal/scripts/weather_helpers.R (the proposal pilot
# decoder) so that the clean model keeps the same precipitation definition; proposal/ is left untouched.
#   - only precipitation codes count (RA DZ SN SG PL GS UP GR IC); mist/fog/haze/smoke do not
#   - vicinity (VC) and blowing/drifting (BL, DR) codes are excluded; remarks (RMK) are ignored
#   - intensity = highest of light (-) / moderate (none) / heavy (+); NA if the report is missing or
#     only hail/ice crystals are present (no standard intensity)

metar_precipitation <- function(report) {
  unknown <- list(intensity = NA_character_, codes = NA_character_)
  if (is.na(report) || !nzchar(report) || report == "M" ||
      grepl("\\b(NIL|PWINO)\\b", report)) return(unknown)
  body <- sub(" RMK .*", "", report)
  tokens <- strsplit(gsub("=", "", body, fixed = TRUE), "[[:space:]]+")[[1]]
  if (!any(grepl("^[A-Z][A-Z0-9]{3}$", tokens)) ||
      !any(grepl("^[0-9]{6}Z$", tokens))) return(unknown)
  pattern <- paste0("^[-+]?(VC)?(MI|PR|BC|DR|BL|SH|TS|FZ)?",
                    "(DZ|RA|SN|SG|IC|PL|GR|GS|UP|BR|FG|FU|VA|DU|SA|HZ|PY|PO|SQ|FC|SS|DS)+$")
  codes <- tokens[grepl(pattern, tokens)]
  codes <- codes[!grepl("^[-+]?(VC|BL|DR)", codes)]
  contains_precipitation <- vapply(codes, function(token) {
    stripped <- sub("^[-+]", "", token)
    pairs <- substring(stripped, seq(1, nchar(stripped), 2), seq(2, nchar(stripped), 2))
    any(pairs %in% c("RA", "DZ", "SN", "SG", "PL", "GS", "UP", "GR", "IC"))
  }, logical(1))
  codes <- codes[contains_precipitation]
  if (!length(codes)) return(list(intensity = "none", codes = ""))
  # Hail/ice crystals alone do not have an assigned standard intensity category.
  supported <- vapply(codes, function(token) {
    stripped <- sub("^[-+]", "", token)
    pairs <- substring(stripped, seq(1, nchar(stripped), 2), seq(2, nchar(stripped), 2))
    any(pairs %in% c("RA", "DZ", "SN", "SG", "PL", "GS", "UP"))
  }, logical(1))
  if (!all(supported)) return(list(intensity = NA_character_, codes = paste(codes, collapse = " ")))
  severity <- ifelse(startsWith(codes, "-"), 1L, ifelse(startsWith(codes, "+"), 3L, 2L))
  list(intensity = c("light", "moderate", "heavy")[max(severity)], codes = paste(codes, collapse = " "))
}

# Adds precip_intensity (0 none, 1 light, 2 moderate, 3 heavy) and snow_fzra_flag
# (snow, snow grains, ice pellets, ice crystals, freezing rain/drizzle; not freezing fog, not blowing snow).
decode_present_weather <- function(metar) {
  decoded <- lapply(metar, metar_precipitation)
  intensity <- vapply(decoded, `[[`, character(1), "intensity")
  codes <- vapply(decoded, `[[`, character(1), "codes")
  tibble::tibble(
    precip_intensity = unname(c(none = 0, light = 1, moderate = 2, heavy = 3)[intensity]),
    snow_fzra_flag = ifelse(is.na(codes), NA_real_, as.numeric(grepl("SN|SG|PL|IC|FZ", codes)))
  )
}
