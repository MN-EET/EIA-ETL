# scripts/reliability.R
source(here::here("scripts", "helpers.R"))
library(rvest)

cat("=== Reliability ===\n")

region_colors <- c("Minnesota" = "#008EAA", "U.S. Total" = "#0D5257", "West North Central Region" = "#8D3F2B")

reliability_fetch <- function(url) {
  read_html(url) |> html_table() |> pluck(2) |> clean_names() |>
    select(1:31) |> row_to_names(row_number = 1) |> clean_names()
}

med_fetch <- function(url, measure_name) {
  reliability_fetch(url) |>
    select(1:11) |> row_to_names(row_number = 1) |> rename(region = 1) |>
    mutate(across(!c(region), as.numeric)) |>
    pivot_longer(!region, names_to = "year", values_to = measure_name) |>
    filter(region %in% c("Minnesota", "West North Central", "U.S. Total"))
}

womed_fetch <- function(url, measure_name) {
  reliability_fetch(url) |>
    select(1, 12:21) |> row_to_names(row_number = 1) |> rename(region = 1) |>
    mutate(across(!c(region), as.numeric)) |>
    pivot_longer(!region, names_to = "year", values_to = measure_name) |>
    filter(region %in% c("Minnesota", "West North Central", "U.S. Total"))
}

rename_region <- function(df) {
  df |> mutate(region = case_when(region == "West North Central" ~ "West North Central Region", TRUE ~ region))
}

# SAIDI
saidi_url <- "https://www.eia.gov/electricity/annual/html/epa_11_04.html"

# 1. SAIDI with major events
p <- med_fetch(saidi_url, "saidi") |> rename_region() |>
  ggplot() + aes(x = year, y = saidi, group = region) +
  geom_line(aes(colour = factor(region)), linewidth = 1) +
  scale_color_manual(values = region_colors, name = "Region") +
  theme_eia() + ylab("SAIDI with Major Events") +
  ggtitle("System Average Interruption Duration Index - With Major Event Days") +
  labs(caption = "Source: Energy Information Administration") + ylim(0, 550)
save_plot(p, "saidi_with_major_events.png")

# 2. SAIDI without major events
p <- womed_fetch(saidi_url, "saidi") |> rename_region() |>
  ggplot() + aes(x = year, y = saidi, group = region) +
  geom_line(aes(colour = factor(region)), linewidth = 1) +
  scale_color_manual(values = region_colors, name = "Region") +
  theme_eia() + ylab("SAIDI without Major Events") +
  ggtitle("System Average Interruption Duration Index - Without Major Event Days") +
  labs(caption = "Source: Energy Information Administration") + ylim(0, 550)
save_plot(p, "saidi_without_major_events.png")

# SAIFI
saifi_url <- "https://www.eia.gov/electricity/annual/html/epa_11_05.html"

# 3. SAIFI with major events
p <- med_fetch(saifi_url, "SAIFI") |> rename_region() |> rename(Year = year) |>
  ggplot() + aes(x = Year, y = SAIFI, group = region) +
  geom_line(aes(colour = factor(region)), linewidth = 1) +
  scale_color_manual(values = region_colors, name = "Region") +
  theme_eia() + ylab("SAIFI with Major Events") +
  ggtitle("System Average Interruption Frequency Index - With Major Event Days") +
  labs(caption = "Source: Energy Information Administration") + ylim(0, 2)
save_plot(p, "saifi_with_major_events.png")

# 4. SAIFI without major events
p <- womed_fetch(saifi_url, "SAIFI") |> rename_region() |> rename(Year = year) |>
  ggplot() + aes(x = Year, y = SAIFI, group = region) +
  geom_line(aes(colour = factor(region)), linewidth = 1) +
  scale_color_manual(values = region_colors, name = "Region") +
  theme_eia() + ylab("SAIFI without Major Events") +
  ggtitle("System Average Interruption Frequency Index - Without Major Event Days") +
  labs(caption = "Source: Energy Information Administration") + ylim(0, 2)
save_plot(p, "saifi_without_major_events.png")

cat("=== Reliability complete ===\n\n")
