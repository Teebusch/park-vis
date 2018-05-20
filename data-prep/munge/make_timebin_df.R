# Make summaries for each checkin location per time interval. Only needs to run once.
# After that, use e.g. `read_rds("data/timebins_15.RDS")`

library(tidyverse)
library(lubridate)

df <- read_rds("data/checkins.RDS")
checkin_ids <- sort(unique(df$checkin_id))
locations <- read_rds("data/checkin_locs.RDS")

# split data frame by attraction
df_fltrd <- map(checkin_ids, ~ filter(df, checkin_id == .x)) %>%
  setNames(checkin_ids)

# some parameters for making timebins
t1 <- min(df$checkin)
t2 <- max(df$checkin)
opening_hours <- range(hour(df$checkin))


# function for making data frame of time intervals
make_timebin_df <- function(t1, t2, intvl, hours = c(0,24)) {
  bin_starts <- seq(floor_date(t1, intvl), ceiling_date(t2, intvl), intvl)
  
  tibble(
    start = bin_starts,
    end = lead(bin_starts),
    day = weekdays(bin_starts)
  ) %>%
    filter(
      !is.na(end),
      hour(start) >= hours[1],
      hour(end) <= hours[2]
    )
}

# function to summarize a given interval and checkin-location 
# makes three types of summaries: 
#   - by previous checkin location (split_by = "next")
#   - by next checkin location (split_by = "prev")
#   - total (split_by = "total")
# use filter to select the summry that is needed
summarize_bin <- function(df, id, t1, t2) {
   df_fltr <- df[[id]] %>%
    filter(between(checkin, t1, t2) | between(checkout, t1, t2)) 
   
   df_prev <- df_fltr %>%
     group_by(prev_checkin_id) %>%
     summarize(
       n_checkedin = n(),
       n_checkingin = sum(between(checkin, t1, t2)),
       n_checkingout = sum(between(checkout, t1, t2)),
       median_duration = coalesce(median(duration), 0),
       split_by = "prev"
     )
   
   df_next <- df_fltr %>%
     group_by(next_checkin_id) %>%
     summarize(
       n_checkedin = n(),
       n_checkingin = sum(between(checkin, t1, t2)),
       n_checkingout = sum(between(checkout, t1, t2)),
       median_duration = coalesce(median(duration), 0),
       split_by = "next"
     )
   
   df_total <- df_fltr %>%
    summarize(
      n_checkedin = n(),
      n_checkingin = sum(between(checkin, t1, t2)),
      n_checkingout = sum(between(checkout, t1, t2)),
      median_duration = coalesce(median(duration), 0),
      split_by = "total"
    )
   
   print(id)
   bind_rows(df_prev, df_next, df_total)
}


# make bins for 15 minute intervals.
# takes a long time. There is probably a more efficient way,
# but since it's a one-time operation...
df_timebins_15 <- make_timebin_df(t1, t2, "15 min", opening_hours) %>%
  expand(checkin_id = checkin_ids, nesting(start, end, day)) %>%
  mutate(smry = pmap(list(checkin_id, start, end), 
                     ~summarize_bin(df_fltrd, ..1, ..2, ..3))) %>%
  unnest(smry) %>%
  left_join(locations, by = c("checkin_id"))

head(df_timebins_15)


# make bins for 5 minute intervals (takes even longer...)

df_timebins_5 <- make_timebin_df(t1, t2, "5 min", opening_hours) %>%
  expand(checkin_id = checkin_ids, nesting(start, end, day)) %>%
  mutate(smry = pmap(list(checkin_id, start, end), 
                     ~summarize_bin(df_fltrd, ..1, ..2, ..3))) %>%
  unnest(smry) %>%
  left_join(locations, by = c("checkin_id"))

head(df_timebins_5)


#...one minute intervals
df_timebins_1 <- make_timebin_df(t1, t2, "1 min", opening_hours) %>%
  expand(checkin_id = checkin_ids, nesting(start, end, day)) %>%
  mutate(smry = pmap(list(checkin_id, start, end), 
                     ~summarize_bin(df_fltrd, ..1, ..2, ..3))) %>%
  unnest(smry) %>%
  left_join(locations, by = c("checkin_id"))

head(df_timebins_1)


# store for later use
write_rds(df_timebins_1, "data/timebins_1.RDS") 
write_rds(df_timebins_5, "data/timebins_5.RDS") 
write_rds(df_timebins_15, "data/timebins_15.RDS") 
