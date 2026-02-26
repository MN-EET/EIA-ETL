# scripts/storage.R
source(here::here("scripts", "helpers.R"))
library(duckdb)

cat("=== Storage ===\n")

db_path <- Sys.getenv("GENERATOR_DB_PATH",
  unset = "I:/Enrgy_div/SEO/CleanEnegyTechUnit/CET Projects/Data Repository/generator_database_shared/generator_database_dbt/prod.duckdb")

db <- dbConnect(duckdb::duckdb(), db_path, read_only = TRUE)
storage <- dbGetQuery(db, "
  SELECT *, nameplate_mw * 1000 AS kwac
  FROM main.mart_combined__storage_capacity
  WHERE year_interconnected <= 2024
") |> tibble()
dbDisconnect(db, shutdown = TRUE)

save_data(storage, "storage_capacity_mn.csv")

total_storage <- paste(round(sum(storage$kwac, na.rm = TRUE) / 1000, digits = 2), "MW")
top_year <- max(as.numeric(storage$year_interconnected), na.rm = TRUE)
bottom_year <- top_year - 10
year_limit <- top_year + 3

cumulative_storage <- storage |>
  group_by(year_interconnected) |>
  summarise(total_mwac = sum(kwac) / 1000) |>
  mutate(cumulative_mwac = cumsum(total_mwac),
         total_label = ifelse(year_interconnected == max(year_interconnected), total_storage, ""))

p <- cumulative_storage |>
  mutate(year_interconnected = as.numeric(year_interconnected)) |>
  ggplot() + aes(x = year_interconnected, y = cumulative_mwac) +
  geom_line(color = "#0D5257", linewidth = 1) +
  scale_x_continuous(limits = c(bottom_year, year_limit), breaks = seq(bottom_year, top_year, by = 5), name = "Year") +
  geom_text_repel(aes(label = total_label), nudge_x = 1) +
  theme_eia() + ylab("Cumulative Storage Capacity (MW)") +
  ggtitle("Cumulative Storage Capacity") +
  labs(caption = paste0("Source: Minnesota PUC Annual DG Reports,\nEnergy Information Administration Form EIA-860\nAccessed ", today))
save_plot(p, "cumulative_storage_capacity.png")

cat("=== Storage complete ===\n\n")
