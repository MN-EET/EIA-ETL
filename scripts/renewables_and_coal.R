# scripts/renewables_and_coal.R
source(here::here("scripts", "helpers.R"))
library(rio)
library(lubridate)
library(zoo)

cat("=== Renewables and Coal ===\n")

raw_mn <- fetch_eia_generation("MN")
raw_us <- fetch_eia_generation("US")

# 1. Coal trend MN vs US
cleanup_coal <- function(x, area) {
  x$response$data |> tibble() |> clean_names() |>
    mutate(period = as.numeric(period), generation = as.numeric(generation)) |>
    filter(fuel_type_description %in% c("all fuels", "all coal products")) |>
    select(period, fuel_type_description, generation) |>
    pivot_wider(names_from = fuel_type_description, values_from = generation) |>
    rename(coal = `all coal products`) |>
    mutate(coal = coal / `all fuels`) |>
    select(period, coal) |> mutate(area = area)
}

mn_coal <- cleanup_coal(raw_mn, "Minnesota")
us_coal <- cleanup_coal(raw_us, "US")
area_colors <- c("Minnesota" = "#008EAA", "US" = "#000000")
top_year <- max(mn_coal$period)
bottom_year <- min(mn_coal$period)

p <- bind_rows(mn_coal, us_coal) |>
  mutate(percent_label = ifelse(period == max(period), paste0(round(coal * 100), "%"), "")) |>
  ggplot() + aes(x = period, y = coal) +
  geom_line(aes(color = factor(area)), linewidth = 1) +
  scale_color_manual(values = area_colors, name = "") +
  theme_eia() + theme(axis.title.y = element_blank()) +
  scale_y_continuous(labels = scales::percent, limits = c(0, 1)) +
  scale_x_continuous(name = "Year", limits = c(bottom_year, top_year + 3), breaks = seq(bottom_year, top_year, by = 5)) +
  geom_text_repel(aes(label = percent_label), nudge_x = 1) +
  ggtitle("Minnesota and US Coal Generated Electricity Trend") +
  labs(caption = paste0("Source: Energy Information Administration\nAccessed ", today))
save_plot(p, "coal_electricity_trend.png")

# 2. Carbon Intensity
emissions_data <- rio::import("https://www.eia.gov/electricity/data/state/emission_annual.xlsx") |>
  tibble() |> clean_names() |>
  filter(state %in% c("MN", "US-TOTAL"),
         producer_type == "Total Electric Power Industry",
         energy_source == "All Sources")

cleanup_gen <- function(x, area) {
  x$response$data |> tibble() |> clean_names() |>
    mutate(period = as.numeric(period), generation = as.numeric(generation)) |>
    filter(fuel_type_description == "all fuels") |>
    select(period, generation) |> mutate(area = area)
}

us_gen <- cleanup_gen(raw_us, "US")
mn_gen <- cleanup_gen(raw_mn, "Minnesota")

carbon_intensity <- function(emissions, gen, state_code) {
  emissions |> filter(state == state_code) |>
    select(year, co2_metric_tons) |>
    filter(year %in% gen$period) |>
    left_join(gen, by = c("year" = "period")) |>
    mutate(carbon_intensity = co2_metric_tons / (generation * 1000)) |>
    select(year, carbon_intensity, area)
}

us_ci <- carbon_intensity(emissions_data, us_gen, "US-TOTAL")
mn_ci <- carbon_intensity(emissions_data, mn_gen, "MN")
bottom_year <- min(us_ci$year)
top_year <- max(us_ci$year)

p <- bind_rows(us_ci, mn_ci) |>
  mutate(percent_label = ifelse(year == max(year), as.character(round(carbon_intensity, 2)), "")) |>
  ggplot() + aes(x = year, y = carbon_intensity) +
  geom_line(aes(color = area), linewidth = 1) +
  scale_color_manual(values = area_colors, name = "") +
  theme_eia() +
  scale_y_continuous(name = "Carbon Intensity (Tons CO2/MWh)", limits = c(0, 1)) +
  scale_x_continuous(name = "Year", limits = c(bottom_year, top_year + 3), breaks = seq(bottom_year, top_year, by = 5)) +
  ggtitle("Carbon Intensity of Electricity") +
  geom_text_repel(aes(label = percent_label), nudge_x = 1.5) +
  labs(caption = paste0("Source: Energy Information Administration\nAccessed ", today))
save_plot(p, "carbon_intensity.png")

# 3. Seasonal coal dispatch
start_date <- paste(as.character(year(Sys.Date()) - 4), "12", "01", sep = "-")
monthly_gen <- fromJSON(rawToChar(GET(paste0("https://api.eia.gov/v2/electricity/electric-power-operational-data/data?api_key=", eia_key,
  "&data[]=generation&frequency=monthly&facets[location][]=MN&facets[sectorid][]=99&start=", start_date))$content))

coal_monthly <- monthly_gen$response$data |> tibble() |> clean_names() |>
  mutate(generation = as.numeric(generation), period = ym(period)) |>
  filter(fuel_type_description == "all coal products") |>
  select(period, generation) |> arrange(period)

p <- coal_monthly |>
  ggplot() + aes(x = period, y = generation) +
  geom_line(linewidth = 1.2) +
  scale_x_date(breaks = seq(from = min(coal_monthly$period), to = max(coal_monthly$period), by = "6 months")) +
  theme_eia() + theme(axis.text.x = element_text(angle = 45, vjust = .5), axis.title.x = element_blank()) +
  scale_y_continuous(name = "Thousand Megawatthours") +
  ggtitle("Seasonal Dispatch of Coal") +
  labs(caption = paste0("Source: Energy Information Administration\nAccessed ", today))
save_plot(p, "seasonal_coal_dispatch.png")

# 4. MN electricity generation transition (monthly moving average)
fuel_colors <- c("Renewables" = "#78BE21", "Coal" = "#000000", "Natural Gas" = "#8D3F2B")
start_date <- as.Date(paste(as.character(year(Sys.Date()) - 3), "12", "01", sep = "-"))

monthly_gen2 <- fromJSON(rawToChar(GET(paste0("https://api.eia.gov/v2/electricity/electric-power-operational-data/data/?api_key=", eia_key,
  "&frequency=monthly&data[0]=generation&facets[location][]=MN&facets[fueltypeid][]=ALL&facets[fueltypeid][]=AOR&facets[fueltypeid][]=COW&facets[fueltypeid][]=HYC&facets[fueltypeid][]=NG&facets[sectorid][]=99&sort[0][column]=period&sort[0][direction]=desc&offset=0&length=5000"))$content))

transition <- monthly_gen2$response$data |> tibble() |> clean_names() |>
  mutate(generation = if_else(is.na(as.numeric(generation)), 0, as.numeric(generation))) |>
  filter(fuel_type_description %in% c("all renewables", "conventional hydroelectric", "all coal products", "natural gas", "all fuels")) |>
  select(period, fuel_type_description, generation) |>
  pivot_wider(names_from = fuel_type_description, values_from = generation) |>
  arrange(period) |>
  mutate(renewables = `all renewables` + `conventional hydroelectric`,
         period = ym(period),
         Coal = rollmean(`all coal products`, 12, na.pad = TRUE, align = "right"),
         Renewables = rollmean(renewables, 12, na.pad = TRUE, align = "right"),
         `Natural Gas` = rollmean(`natural gas`, 12, na.pad = TRUE, align = "right"),
         all = rollmean(`all fuels`, 12, na.pad = TRUE, align = "right")) |>
  filter(period >= start_date) |>
  mutate(across(c(Coal, Renewables, `Natural Gas`), .fns = ~ . / all)) |>
  select(period, Coal, Renewables, `Natural Gas`) |>
  pivot_longer(!period, names_to = "fuel", values_to = "generation") |>
  filter(complete.cases(generation))

p <- transition |>
  mutate(label = ifelse(period == max(period), paste0(round(generation * 100), "%"), "")) |>
  ggplot() + aes(x = period, y = generation) +
  geom_line(aes(color = fuel), linewidth = 1.2) +
  scale_color_manual(values = fuel_colors, name = "") +
  scale_x_date(breaks = seq(from = min(transition$period), to = max(transition$period), by = "6 months")) +
  theme_eia() + theme(axis.text.x = element_text(angle = 45, vjust = .5), axis.title.x = element_blank()) +
  scale_y_continuous(labels = scales::percent, name = "12 Month Moving Average", limits = c(0, .5)) +
  ggtitle("Minnesota Electricity Generation Transition") +
  geom_text_repel(aes(label = label), nudge_x = 1.5, size = 3.5) +
  labs(caption = paste0("Source: Energy Information Administration\nAccessed ", today))
save_plot(p, "generation_transition_mn.png")

cat("=== Renewables and Coal complete ===\n\n")
