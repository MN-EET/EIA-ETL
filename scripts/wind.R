# scripts/wind.R
source(here::here("scripts", "helpers.R"))
library(duckdb)

cat("=== Wind ===\n")

db_path <- Sys.getenv("GENERATOR_DB_PATH",
  unset = "I:/Enrgy_div/SEO/CleanEnegyTechUnit/CET Projects/Data Repository/generator_database_shared/generator_database_dbt/dev.duckdb")

db <- dbConnect(duckdb::duckdb(), db_path, read_only = TRUE)
raw_wind <- dbGetQuery(db, "
  SELECT utility, operating_year AS year_interconnected, nameplate_mw, nameplate_mw * 1000 AS kwac
  FROM main.mart_total__wind_capacity
") |> tibble()
dbDisconnect(db, shutdown = TRUE)

save_data(raw_wind, "wind_capacity_mn.csv")

total_wind <- paste(round(sum(raw_wind$kwac, na.rm = TRUE) / 1000, digits = 2), "MW")
top_year <- max(raw_wind$year_interconnected, na.rm = TRUE)
bottom_year <- top_year - 15
year_limit <- top_year + 3

# 1. Cumulative wind capacity
p <- raw_wind |>
  filter(complete.cases(year_interconnected)) |>
  group_by(year_interconnected) |> summarize(total_kwac = sum(kwac, na.rm = TRUE)) |>
  mutate(cumulative_kwac = cumsum(total_kwac),
         total_label = ifelse(year_interconnected == max(year_interconnected), total_wind, "")) |>
  filter(year_interconnected >= bottom_year) |>
  ggplot() + aes(x = year_interconnected, y = cumulative_kwac / 1000) +
  geom_line(color = "#9BCBEB", linewidth = 1) +
  scale_x_continuous(limits = c(bottom_year, year_limit), breaks = seq(bottom_year, top_year, by = 5), name = "Year") +
  geom_text_repel(aes(label = total_label), nudge_x = 1) +
  theme_eia() + ylab("Cumulative Wind Capacity (MW/AC)") + ggtitle("Cumulative Wind Capacity") +
  labs(caption = "Source: Energy Information Administration Form EIA-860")
save_plot(p, "cumulative_wind_capacity.png")

# 2. Annual wind installations
p <- raw_wind |>
  filter(complete.cases(year_interconnected)) |>
  group_by(year_interconnected) |> summarize(total_mw = sum(kwac, na.rm = TRUE) / 1000) |>
  filter(year_interconnected >= bottom_year) |>
  ggplot() + aes(x = year_interconnected, y = total_mw) +
  geom_col(fill = "#9BCBEB") +
  geom_text(aes(label = round(total_mw)), vjust = -1) +
  theme_eia() + ylim(0, 600) +
  xlab("Year") + ylab("Annual Additions (MW)") + ggtitle("Annual Wind Installations")
save_plot(p, "annual_wind_installations.png")

cat("=== Wind complete ===\n\n")
