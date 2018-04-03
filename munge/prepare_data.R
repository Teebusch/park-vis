# This will create park_data.RDS which is a data frame with the raw movement 
# data, plus some additional useful columns. It does not need to be run again afterwards. Just do `df <- read_rds("data/park_data.RDS")`

library(tidyverse)
library(lubridate)

source("munge/helpers.R")

# Load the data ---------------------------------------------------------------

fri <- read_csv("data/G0R72A/movement-data/park-movement-Fri.csv")
sat <- read_csv("data/G0R72A/movement-data/park-movement-Sat.csv")
sun <- read_csv("data/G0R72A/movement-data/park-movement-Sun.csv")

# there is an additional header row and a timestamp without any other 
# info somewhere in the data from Sunday. We remove it.
sun <- sun %>%
  filter(Timestamp != "Timestamp", !is.na(X), !is.na(Y))

df <- bind_rows(Friday = fri, 
                Saturday = sat, 
                Sunday = sun, 
                .id = "day")

# make lower-case column names, for consistency
df <- df %>% 
  mutate(timestamp = ymd_hms(Timestamp), x = X, y = Y) %>%
  select(-Timestamp, -X, -Y)

rm(fri, sat, sun)

head(df)

# Add some columns that can be useful -----------------------------------------
# Add proper location ids (matching those on the map). 
# See match_location_ids.R for more info
locations <- read_rds("data/checkin_locs.RDS")
head(locations)

df <- df %>%
  left_join(locations %>%
              select(x, y, checkin_id) %>%
              mutate(type = "check-in"), # in case there's same xy as movement 
            by = c("type", "x", "y"))


# hour: time of day as numeric, e.g. 1.30pm = 13.5
# visit_time: how long (minutes) since we first saw the visitor (i.e. since she 
# entered the park)?
# checkin_nr: order of the check-ins for each visitor (1st check-in, 
# 2nd check-in..., nth check-in)
# movement_nr: order of the movements for each visitor (moving between 1st and 
# 2nd check-in, between 2nd and 3rd check-in,..., between n-1th and nth check-in
df <- df %>%
  group_by(day, id) %>%
  arrange(timestamp) %>%
  mutate(
    hour = hour_of_day(timestamp),
    visit_time = minutes_between(first(timestamp), timestamp),
    step = cumsum(type == "check-in"), # only temporarily needed
    checkin_nr = ifelse(type == "check-in", step, NA),
    movement_nr = ifelse(type == "movement", step, NA)
  ) %>%
  select(-step) %>% 
  ungroup()


write_rds(df, "data/park_data.RDS", compress = "gz")