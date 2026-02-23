# scripts/helpers.R
# Shared helper functions and setup for all EIA scripts

library(tidyverse)
library(jsonlite)
library(httr)
library(janitor)
library(ggrepel)
library(keyring)
library(here)

# API key
eia_key <- key_get("eia_api")

# Common values
today <- format(Sys.Date(), format = "%m-%d-%Y")
options(scipen = 999)

# Output directories
plots_dir <- here("output", "plots")
data_dir <- here("output", "data")
dir.create(plots_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(data_dir, showWarnings = FALSE, recursive = TRUE)

# Common theme
theme_eia <- function() {
  theme(
    panel.grid.major = element_blank(),
    panel.grid.minor = element_blank(),
    panel.background = element_blank(),
    axis.line = element_line(colour = "black"),
    text = element_text(size = 11)
  )
}

# Fetch from EIA operational data (generation endpoint)
fetch_eia_generation <- function(location) {
  raw <- GET(
    paste0(
      "https://api.eia.gov/v2/electricity/electric-power-operational-data/data?api_key=",
      eia_key,
      "&data[]=generation&frequency=annual&facets[location][]=", location,
      "&facets[sectorid][]=99"
    )
  )
  fromJSON(rawToChar(raw$content))
}

# Fetch from EIA SEDS endpoint
fetch_eia_seds <- function(series_id, state = "MN", direction = "desc", start = NULL) {
  url <- paste0(
    "https://api.eia.gov/v2/seds/data/?frequency=annual&data[0]=value&api_key=",
    eia_key,
    "&facets[seriesId][]=", series_id,
    "&facets[stateId][]=", state,
    "&sort[0][column]=period&sort[0][direction]=", direction,
    "&offset=0&length=5000"
  )
  if (!is.null(start)) url <- paste0(url, "&start=", start)
  raw <- GET(url)
  fromJSON(rawToChar(raw$content))
}

# Save plot helper
save_plot <- function(plot, filename, width = 8, height = 5) {
  ggsave(file.path(plots_dir, filename), plot, width = width, height = height)
  cat("  Saved plot:", filename, "\n")
}

# Save data helper
save_data <- function(data, filename) {
  write_csv(data, file.path(data_dir, filename))
  cat("  Saved data:", filename, "\n")
}
