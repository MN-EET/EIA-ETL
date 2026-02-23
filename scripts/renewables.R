# scripts/renewables.R
source(here::here("scripts", "helpers.R"))

cat("=== Renewables ===\n")

# 1. Renewable consumption vs total
renewable_data <- fromJSON(rawToChar(GET(paste0("https://api.eia.gov/v2/seds/data/?api_key=", eia_key, "&frequency=annual&data[0]=value&facets[seriesId][]=RETCB&facets[stateId][]=MN&sort[0][column]=period&sort[0][direction]=desc&offset=0&length=5000"))$content))
total_data <- fromJSON(rawToChar(GET(paste0("https://api.eia.gov/v2/seds/data/?api_key=", eia_key, "&frequency=annual&data[0]=value&facets[seriesId][]=TETCB&facets[stateId][]=MN&sort[0][column]=period&sort[0][direction]=desc&offset=0&length=5000"))$content))

api_cleanup <- function(data_use, fuel) {
  tibble(data_use$response$data) |>
    mutate(year = as.numeric(period), consumption = as.numeric(value) / 1000, fuel_type = fuel) |>
    select(year, consumption, fuel_type)
}

consumption_data <- bind_rows(api_cleanup(total_data, "Total"), api_cleanup(renewable_data, "Renewables")) |>
  mutate(consumption_label = case_when(year == max(year) ~ as.character(consumption), TRUE ~ ""))

renewable_25_goal <- consumption_data |> filter(fuel_type == "Total", year == max(year)) |> mutate(goal = .25 * consumption) |> pull(goal)
top_year <- max(consumption_data$year)
bottom_year <- top_year - 20
consumption_top <- ifelse(max(consumption_data$consumption) < 2000, 2000, 2500)

p <- consumption_data |>
  ggplot() + aes(x = year, y = consumption, label = consumption_label) +
  geom_line(aes(colour = factor(fuel_type)), linewidth = 1) +
  geom_hline(yintercept = renewable_25_goal) +
  geom_text_repel(nudge_x = 1.1) +
  scale_x_continuous(limits = c(bottom_year, top_year + 1.5), breaks = seq(bottom_year, top_year, by = 5)) +
  scale_y_continuous(breaks = c(0, renewable_25_goal, consumption_top), labels = c("0", "25% Goal", as.character(consumption_top))) +
  scale_color_manual(values = c("Renewables" = "#78BE21", "Total" = "#003865"), name = "") +
  theme_eia() + ylab("Trillion BTU") + xlab("Year") +
  ggtitle("Total Energy Consumption from Renewables") +
  labs(caption = paste0("Source: Energy Information Administration\nAccessed ", today))
save_plot(p, "renewable_energy_consumption_goal.png")

# 2. Renewable electricity by type
raw_generation <- fetch_eia_generation("MN")
renewable_generation <- raw_generation$response$data |>
  tibble() |> clean_names() |>
  mutate(period = as.numeric(period), generation = as.numeric(generation)) |>
  filter(fueltypeid %in% c("BIO", "HYC", "SUN", "WND", "ALL")) |>
  mutate(fuel_type_description = str_replace_all(fuel_type_description, c("wind" = "Wind", "solar" = "Solar", "conventional hydroelectric" = "Hydroelectric", "biomass" = "Biomass"))) |>
  select(period, fuel_type_description, generation) |>
  pivot_wider(names_from = fuel_type_description, values_from = generation) |>
  mutate(across(c(Biomass, Hydroelectric, Wind, Solar), .fns = ~ . / `all fuels`)) |>
  select(-`all fuels`) |>
  pivot_longer(!period, names_to = "fuel_type", values_to = "percent")

top_year <- max(renewable_generation$period)
bottom_year <- top_year - 20
renewable_colors <- c("Wind" = "#9BCBEB", "Solar" = "#FFC845", "Hydroelectric" = "#008EAA", "Biomass" = "#8D3F2B")

p <- renewable_generation |>
  mutate(percent_label = ifelse(period == max(period), paste0(round(percent * 100), "%"), "")) |>
  ggplot() + aes(x = period, y = percent) +
  geom_line(aes(colour = factor(fuel_type)), linewidth = 1) +
  scale_color_manual(values = renewable_colors, name = "") +
  theme_eia() + theme(axis.title.y = element_blank()) +
  scale_y_continuous(labels = scales::percent, limits = c(0, .3)) +
  geom_text_repel(aes(label = percent_label), nudge_x = 1) +
  scale_x_continuous(limits = c(bottom_year, top_year + 3), breaks = seq(bottom_year, top_year, by = 5), name = "Year") +
  ggtitle(paste0("Renewable Electricity in Minnesota: ", bottom_year, "-", top_year)) +
  labs(caption = paste0("Source: Energy Information Administration\nAccessed ", today))
save_plot(p, "renewable_electricity_trend_mn.png")

# 3. MN vs US renewable electricity trend
cleanup_re <- function(x, area) {
  x$response$data |> tibble() |> clean_names() |>
    mutate(period = as.numeric(period), generation = as.numeric(generation)) |>
    filter(fuel_type_description %in% c("all fuels", "all renewables", "conventional hydroelectric")) |>
    select(period, fuel_type_description, generation) |>
    pivot_wider(names_from = fuel_type_description, values_from = generation) |>
    mutate(renewables = (`all renewables` + `conventional hydroelectric`) / `all fuels`) |>
    select(period, renewables) |> mutate(area = area)
}

mn_re <- cleanup_re(fetch_eia_generation("MN"), "Minnesota")
us_re <- cleanup_re(fetch_eia_generation("US"), "US")
total_re <- bind_rows(mn_re, us_re)
save_data(total_re, "renewable_electricity_mn_vs_us.csv")

top_year <- max(mn_re$period)
bottom_year <- min(mn_re$period)

p <- total_re |>
  mutate(percent_label = ifelse(period == max(period), paste0(round(renewables * 100), "%"), "")) |>
  ggplot() + aes(x = period, y = renewables) +
  geom_line(aes(color = factor(area)), linewidth = 1) +
  scale_color_manual(values = c("Minnesota" = "#78BE21", "US" = "#000000"), name = "") +
  theme_eia() + theme(axis.title.y = element_blank()) +
  scale_y_continuous(labels = scales::percent) +
  scale_x_continuous(name = "Year", limits = c(bottom_year, top_year + 3), breaks = seq(bottom_year, top_year, by = 5)) +
  geom_text_repel(aes(label = percent_label), nudge_x = 1) +
  ggtitle("Minnesota and US Renewable Electricity Trend") +
  labs(caption = paste0("Source: Energy Information Administration\nAccessed ", today))
save_plot(p, "renewable_electricity_mn_vs_us.png")

cat("=== Renewables complete ===\n\n")
