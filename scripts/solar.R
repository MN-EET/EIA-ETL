# scripts/solar.R
source(here::here("scripts", "helpers.R"))
library(duckdb)

cat("=== Solar ===\n")

# Analysts: update this path as necessary
db_path <- Sys.getenv("GENERATOR_DB_PATH",
  unset = "I:/Enrgy_div/SEO/CleanEnegyTechUnit/CET Projects/Data Repository/generator_database_shared/generator_database_dbt/dev.duckdb")

db <- dbConnect(duckdb::duckdb(), db_path, read_only = TRUE)
raw_solar <- dbGetQuery(db, "
  SELECT *, ROUND(nameplate_mw * 1000) AS kwac
  FROM main.mart_combined__solar_capacity
  WHERE year_interconnected <= 2024
") |> tibble() |> mutate(customer_type = str_to_title(customer_type))
dbDisconnect(db, shutdown = TRUE)

save_data(raw_solar, "solar_capacity_mn.csv")

total_solar <- paste(round(sum(raw_solar$kwac, na.rm = TRUE) / 1000, digits = 2), "MW")
top_year <- max(raw_solar$year_interconnected, na.rm = TRUE)
bottom_year <- top_year - 15
year_limit <- top_year + 3

# 1. Cumulative solar capacity
p <- raw_solar |>
  filter(complete.cases(year_interconnected)) |>
  group_by(year_interconnected) |> summarize(total_kwac = sum(kwac, na.rm = TRUE)) |>
  mutate(cumulative_kwac = cumsum(total_kwac),
         total_label = ifelse(year_interconnected == max(year_interconnected), total_solar, "")) |>
  filter(year_interconnected >= bottom_year) |>
  ggplot() + aes(x = year_interconnected, y = cumulative_kwac / 1000) +
  geom_line(color = "#FFC845", linewidth = 1) +
  scale_x_continuous(limits = c(bottom_year, year_limit), breaks = seq(bottom_year, top_year, by = 5), name = "Year") +
  geom_text_repel(aes(label = total_label), nudge_x = 1) +
  theme_eia() + ylab("Cumulative Solar Capacity (MW/AC)") + ggtitle("Cumulative Solar Capacity") +
  labs(caption = "Source: Minnesota PUC Annual DG Reports,\nEnergy Information Administration Form EIA-860")
save_plot(p, "cumulative_solar_capacity.png")

# 2. Solar by installation type (cumulative)
installation_colors <- c("Other" = "#003865", "Community Solar" = "#78BE21", "Large-Scale" = "#008EAA")

installation_labels <- raw_solar |>
  mutate(installation_type = case_when(
    nameplate_mw >= 10 ~ "Large-Scale",
    customer_type %in% c("Community Solar Garden", "community solar garden", "community") ~ "Community Solar", 
    TRUE ~ "Other"
  )) %>% 
  group_by(installation_type) |>
  summarise(total_mw_label = trunc(sum(nameplate_mw, na.rm = TRUE)))

p <- raw_solar |>
  filter(complete.cases(year_interconnected)) |>
  mutate(installation_type = case_when(
    nameplate_mw >= 10 ~ "Large-Scale",
    customer_type %in% c("Community Solar Garden", "community solar garden", "community") ~ "Community Solar", 
    TRUE ~ "Other"
  )) |>
  group_by(year_interconnected, installation_type) |>
  summarise(total_mw = sum(kwac, na.rm = TRUE) / 1000, .groups = "drop") |>
  group_by(installation_type) |> 
  mutate(cumulative_mw = cumsum(total_mw)) |>
  filter(year_interconnected >= bottom_year) |>
  left_join(installation_labels, by = "installation_type") |>
  mutate(total_mw_label = ifelse(year_interconnected == max(year_interconnected), paste0(total_mw_label, " MW"), "")) |>
  ggplot() + aes(x = year_interconnected, y = cumulative_mw) +
  geom_line(aes(color = factor(installation_type)), linewidth = 1) +
  scale_color_manual(values = installation_colors, name = "") +
  geom_text_repel(aes(label = total_mw_label), nudge_x = .5, size = 3.5) +
  scale_x_continuous(limits = c(bottom_year - 1, year_limit), breaks = seq(bottom_year, top_year, by = 5), name = "Year") +
  theme_eia() + ylab("Cumulative Solar Capacity (MW/AC)") +
  ggtitle("Minnesota's Cumulative Solar Installations by Type") +
  labs(caption = "Source: Minnesota PUC Annual DG Reports,\nEnergy Information Administration Form EIA-860\nNote: Large Scale is installations 10MW or larger")

save_plot(p, "solar_capacity_by_type_cumulative.png")

# 3. Annual solar installations
bottom_year_annual <- top_year - 8
annual_labels <- raw_solar |>
  filter(complete.cases(year_interconnected)) |>
  group_by(year_interconnected) |> summarise(total_mw = round(sum(kwac, na.rm = TRUE) / 1000)) |>
  filter(year_interconnected >= bottom_year_annual)

p <- raw_solar |>
  filter(complete.cases(year_interconnected)) |>
  mutate(installation_type = case_when(
    nameplate_mw >= 10 ~ "Large-Scale",
    customer_type %in% c("Community Solar Garden", "community solar garden", "community") ~ "Community Solar", 
    TRUE ~ "Other"
  )) |>
  filter(year_interconnected >= bottom_year_annual) |>
  group_by(year_interconnected, installation_type) |>
  summarise(total_mw = sum(kwac, na.rm = TRUE) / 1000, .groups = "drop") |>
  mutate(installation_type = factor(installation_type, levels = c("Large-Scale", "Community Solar", "Other"))) |>
  ggplot() + aes(x = year_interconnected, y = total_mw, fill = installation_type) +
  geom_bar(stat = "identity", position = "stack") +
  scale_fill_manual(values = installation_colors, name = "") +
  geom_text(aes(year_interconnected, total_mw + 20, label = total_mw, fill = NULL), data = annual_labels) +
  scale_x_continuous(limits = c(bottom_year_annual - 1, top_year + 1), breaks = bottom_year_annual:top_year, name = "Year") +
  theme_eia() + ylab("Annual Additions (MW/AC)") + ggtitle("Minnesota's Annual Solar Installations") +
  labs(caption = "Source: Minnesota PUC Annual DG Reports,\nEnergy Information Administration Form EIA-860\nNote: Large Scale is installations 10MW or larger")

save_plot(p, "annual_solar_installations.png")

# 4. Capacity by type (bar)
total_kwac <- sum(raw_solar$kwac, na.rm = TRUE)

p <- raw_solar |>
  mutate(installation_type = case_when(
    nameplate_mw >= 10 ~ "Large-Scale",
    customer_type %in% c("Community Solar Garden", "community solar garden", "community") ~ "Community Solar", 
    TRUE ~ "Other"
  ))|>
  group_by(installation_type) |>
  summarise(percent_gen = sum(kwac, na.rm = TRUE) / total_kwac) |>
  mutate(gen_label = paste0(round(percent_gen * 100), "%")) |>
  ggplot() + aes(x = percent_gen, y = fct_reorder(as_factor(installation_type), percent_gen), fill = installation_type, label = gen_label) +
  geom_bar(stat = "identity") + scale_x_continuous(limits = c(0, 1)) +
  scale_fill_manual(values = installation_colors, name = "") +
  geom_text(nudge_x = .05) +
  theme_eia() + theme(axis.title.y = element_blank(), axis.text.x = element_blank(), axis.ticks.x = element_blank(), legend.position = "none") +
  xlab("Percent of Solar Capacity") + ggtitle("Solar Capacity by Installation Type") +
  labs(caption = "Source: Minnesota PUC Annual DG Reports,\nEnergy Information Administration Form EIA-860")

save_plot(p, "solar_capacity_by_type_bar.png")

cat("=== Solar complete ===\n\n")
