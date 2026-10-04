# Descriptive figure 1: coverage timing as a tile-grid map. Primary states are coloured by adoption cohort year (first_treated_quarter);
# sensitivity states (start quarter unknown, treated) are a pale tint with a dashed border; never-treated states are grey.
# A down-arrow marks states whose coverage later ended or lapsed (any quarter with a lower covered share than the quarter before).
source(here::here("R", "db.R"))
source(here::here("R", "theme.R"))
library(geofacet)
library(tidyr)

panel <- get_mart("mart_did_panel")

st <- panel |>
  arrange(state_code, quarter_start) |>
  group_by(state_code) |>
  summarise(analysis_group = first(analysis_group), first_treated_quarter = first(first_treated_quarter),
            start_quarter_earliest = first(start_quarter_earliest), start_quarter_latest = first(start_quarter_latest),
            withdrew = any(covered_days_share < lag(covered_days_share, default = 0)), .groups = "drop") |>
  mutate(cohort_year = ifelse(analysis_group == "primary", substr(first_treated_quarter, 1, 4), NA_character_),
         fill_key = case_when(analysis_group == "primary" ~ cohort_year, analysis_group == "sensitivity" ~ "Sensitivity (start range)",
                              TRUE ~ "Never treated"),
         label = case_when(analysis_group == "primary" ~ paste0(state_code, "\n", first_treated_quarter),
                           analysis_group == "sensitivity" ~ paste0(state_code, "\n", start_quarter_earliest, "-", substr(start_quarter_latest, 3, 6)),
                           TRUE ~ state_code),
         label = ifelse(withdrew, paste0(label, " ↓"), label))

grid <- tibble::as_tibble(as.data.frame(geofacet::us_state_grid2)) |> filter(code %in% st$state_code) |> left_join(st, by = c("code" = "state_code"))

years <- sort(unique(na.omit(st$cohort_year)))
ramp <- scales::seq_gradient_pal("#FBD9BF", "#8E3A00")(seq(0, 1, length.out = length(years)))
fills <- c(setNames(ramp, years), "Sensitivity (start range)" = col_sensitivity, "Never treated" = "#E4E4E4")
grid$fill_key <- factor(grid$fill_key, levels = names(fills))

n_prim <- sum(st$analysis_group == "primary"); n_sens <- sum(st$analysis_group == "sensitivity"); n_never <- sum(st$analysis_group == "never_treated")
rng <- range(st$first_treated_quarter[st$analysis_group == "primary"])

p <- ggplot(grid, aes(col, -row, fill = fill_key)) +
  geom_tile(aes(linetype = analysis_group == "sensitivity"), colour = "white", linewidth = 0.9, width = 0.96, height = 0.96, show.legend = TRUE) +
  geom_text(aes(label = label), size = 2.3, lineheight = 0.85, colour = "#1A1A1A") +
  scale_fill_manual(values = fills, name = "Primary cohort (year coverage began)", drop = FALSE) +
  scale_linetype_manual(values = c("solid", "dashed"), guide = "none") +
  coord_equal() +
  labs(title = stringr::str_wrap(sprintf("%d states began Medicaid coverage of Wegovy/Zepbound between %s and %s; %d more are treated with an uncertain start", n_prim, rng[1], rng[2], n_sens), 85),
       subtitle = stringr::str_wrap(sprintf("50 states and DC: %d primary (cohort = first quarter with coverage), %d sensitivity (start range shown), %d never treated. ↓ = coverage later ended or lapsed.", n_prim, n_sens, n_never), 120),
       caption = "Source: state Medicaid documents compiled in the warehouse coverage table (medicaid_obesity_coverage). Data through SDUD 2026 Q1 (preliminary).") +
  theme_incretin() + theme(axis.text = element_blank(), axis.title = element_blank(), panel.grid = element_blank(), legend.position = "bottom")

save_fig(p, "01_coverage_timing_map", width = 11, height = 7.5)
save_table(st |> select(state_code, analysis_group, first_treated_quarter, start_quarter_earliest, start_quarter_latest, withdrew), "coverage_timing_by_state")
print(st |> filter(analysis_group != "never_treated") |> arrange(analysis_group, first_treated_quarter) |> select(-label, -fill_key), n = 20)
