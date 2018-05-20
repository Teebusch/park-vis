# Prepare data for the app

library(tidyverse)
library(lubridate)
source('munge/helpers.R')


df5 <- read_rds("data/timebins_5.RDS") %>%
  filter(split_by == "total", n_checkedin > 0) %>%
  select(day, checkin_id, name, start, n_checkingin, n_checkingout, median_duration) %>%
  gather(stat, n, n_checkingin, n_checkingout) %>%
  mutate(
    x = start + minutes(2) + seconds(30),
    xend = if_else(stat == "n_checkingin",
                   floor_date(x, "day") + hours(9),
                   floor_date(x, "day") + hours(23)),
    y = 0,
    yend = if_else(stat == "n_checkingin", 1, -1) #checking in or checking out
  ) %>%
  select(day, checkin_id, name, x, y, xend, yend, stat, n, median_duration)

write_rds(df5, "shiny-app/df5.RDS")


df15 <- read_rds("data/timebins_15.RDS") %>%
  filter(split_by == "total", n_checkedin > 0) %>%
  mutate(
    x = start + minutes(7) + seconds(30),
    y = 0
  ) %>%
  select(day, checkin_id, name, x, y, n_checkedin, median_duration)

write_rds(df15, "shiny-app/df15.RDS")




ids <- unique(df5$checkin_id)

df_pos <- data.frame(
  id = ids,
  xpos_norm = seq_along(ids) / length(ids)
)

get_x_pos <- function(x, id) {
  xpos_norm <- df_pos[match(id, df_pos$id), "xpos_norm"]
  x_hr <- (9*60) + (14*60) * xpos_norm
  res <- floor_date(x, "day") + minutes(floor(x_hr))
  return(res)
}


dfdetail <- read_rds("data/timebins_1.RDS") %>%
  filter(split_by != "total", n_checkedin > 0) %>%
  mutate(
    x = start + seconds(30),
    y = 0,
    xend = if_else(split_by == "prev", 
                   get_x_pos(x, prev_checkin_id),
                   get_x_pos(x, next_checkin_id)),
    yend = if_else(split_by == "prev", 2, -2),
    hour = hour_of_day(x),
    n = if_else(split_by == "prev", 
               get_x_pos(x, n_checkingin),
               get_x_pos(x, n_checkingout)),
  ) %>%
  select(day, checkin_id, name, x, y, xend, yend, n_checkedin, median_duration, 
         split_by, prev_checkin_id, next_checkin_id, hour, n)

write_rds(dfdetail, "shiny-app/dfdetail.RDS")



