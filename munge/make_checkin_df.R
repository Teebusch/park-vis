# Make a data frame of visitors checkins
# Run this once to create `data/checkins.RDS` 

library(tidyverse)
library(lubridate)

source("munge/helpers.R")

df <- read_rds("data/park_data.RDS")
locations <- read_rds("data/checkin_locs.RDS")

# checkout: timestamp of next registered movement
# duration: duration of stay
# prev_checkin_id: The previous registered check-in location of that 
#   visitor (0 if jsut entering park)
# next_checkin_id: The next registered check-in location of that user 
#  (99 if leaving park)
checkins <- df %>%
  group_by(day, id) %>%
  #arrange(timestamp) %>% # not necessary, df is already sorted like this
  mutate(checkout = lead(timestamp, default = NA)) %>%
  filter(type == "check-in") %>%
  rename(checkin = timestamp) %>%
  mutate(duration = minutes_between(checkin, checkout)) %>% 
  left_join(locations, by = c("checkin_id", "x", "y")) %>%
  mutate(
    prev_checkin_id = lag(checkin_id, default = "0"),
    next_checkin_id = lead(checkin_id, default = "99")
  ) %>%
  ungroup()

# remove some useless columns and change order
checkins <- checkins %>%
  select(day, id, checkin_nr, checkin_id, name, category, checkin, checkout,
         duration, visit_time, prev_checkin_id, next_checkin_id, x, y, 
         everything(), -type, - movement_nr)

head(checkins)


# Calculate simple transitional probabilities
tps <- checkins %>%
  group_by(checkin_id, prev_checkin_id) %>%
  summarize(n = n()) %>%
  group_by(checkin_id) %>%
  mutate(p = n / sum(n)) %>%
  ungroup()

# add missing transitions and scaled probabilities
tps <- full_join(tps, expand(tps, checkin_id, prev_checkin_id)) %>%
  mutate(n = coalesce(n, as.integer(0)), p = coalesce(p, 0)) %>%
  group_by(checkin_id) %>%
  mutate(p_scaled = (p - min(p)) / (max(p) - min(p)))


checkins <- left_join(checkins, select(tps, -n))

glimpse(checkins)

write_rds(checkins, "data/checkins.RDS", compress = "gz")
