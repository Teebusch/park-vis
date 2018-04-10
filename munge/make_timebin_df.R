# Make summaries for each checkin location per time interval. Only needs to run once.
# After that, use `read_rds("data/timebins.RDS")`

library(tidyverse)
library(lubridate)

df <- read_rds("data/checkins.RDS")
checkin_ids <- sort(unique(df$checkin_id))


# make data frame of time
intvl <- "15 min"
opening_hours <- range(hour(df$checkin))

df_timebins <- data.frame(
  start = seq(floor_date(min(df$checkin), intvl),
              ceiling_date(max(df$checkin), intvl),
              intvl)) %>%
  mutate(
    end = lead(start),
    day = weekdays(start)
  ) %>%
  expand(checkin_id = checkin_ids, nesting(start, end, day)) %>%
  filter(
    !is.na(end),
    hour(start) >= opening_hours[1],
    hour(end) <= opening_hours[2]
  )


# get summaries for each interval (takes a while...)
summarize_bin <- function(i, t1, t2) {
  df %>%
    filter(between(checkin, t1, t2) | 
             between(checkout, t1, t2),
           checkin_id == i
          ) %>%
    summarize(
      n_checkedin = length(id),
      median_duration = median(duration)
    )
}

df_timebins <- df_timebins %>%
  mutate(smry = pmap(list(checkin_id, start, end), summarize_bin)) %>%
  unnest(smry)

df_timebins <- df_timebins %>%
  mutate(median_duration = coalesce(median_duration, 0))


head(df_timebins)
write_rds(df_timebins, "data/timebins.RDS") 
