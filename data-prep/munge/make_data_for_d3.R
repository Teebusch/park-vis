# make data for D3 visualization

library(tidyverse)
library(lubridate)
library(jsonlite)

read_rds("data/checkin_locs.RDS") %>%
  select(locId = checkin_id, label = name, category, x, y) %>%
  filter((!is.na(x) & !is.na(y)) | locId == "OP") %>%
  mutate(category = fct_collapse(
    category,
    Other = c("Other", "Entrance", "Information & Assistance")
  )) %>%
  write_csv("d3/locations.csv")


locs <- read_csv("data/checkin_locs.csv") 

df_checkins <- read_rds("data/checkins.RDS") %>%
  select(day, id, checkin_id, checkin, checkout, duration, 
         prev_checkin_id, next_checkin_id)

# something for the report? 
# On Friday someone checks into Scholtz' right after entering the park through EN
# and is never seen again.
# At Sunday 10:19 someone checks into 
# Kauf's and is never seen again. 
df_checkins %>% filter(id %in% c(657863, 898576))

df <- df_checkins %>% 
  rename(
    focusLoc = checkin_id,
    from = prev_checkin_id,
    to = next_checkin_id
  ) %>%
  gather(direction, locId, from, to) %>%
  mutate(time = if_else(direction == "from", checkin, checkout)) %>%
  select(-checkin, -checkout, -id)

df %>% filter(is.na(time)) # the strange cases mentioned above

df <- df %>% filter(!is.na(time))

# Add rows for OP (outside of park) "checkins"
dfop <- df %>% 
  filter(locId == "OP") %>%
  mutate(
    locId = focusLoc, 
    focusLoc = "OP", 
    direction = ifelse(direction == "from", "to", "from"),
    duration = NA
  )

df <- bind_rows(df, dfop)


(checkin_ids <- sort(unique(df$focusLoc)))


# some parameters for making timebins
t1 <- min(df$time, na.rm = TRUE) #- hours(1)
t2 <- max(df$time, na.rm = TRUE)
opening_hours <- range(hour(df$time), na.rm = TRUE)


# function for making data frame of time intervals
make_timebin_df <- function(t1, t2, intvl) {
  
  bin_starts <- seq(floor_date(t1, intvl), ceiling_date(t2, intvl), intvl)
  
  tibble(
    timeBin = seq_along(bin_starts),
    intvl = intvl,
    start = bin_starts,
    end = lead(bin_starts),
    day = weekdays(bin_starts)
  ) %>%
    filter(
      !is.na(end)
    )
}

timegrid60 <- make_timebin_df(t1, t2, "60 min")
timegrid10 <- make_timebin_df(t1, t2, "10 min")
timegrid <- bind_rows(timegrid60, timegrid10)

# ------------------ Make Flow -------------------------------------------------


add_timebin <- function(df, tdf) {
  df$timeBin = NA
  pwalk(list(tdf$start, tdf$end, tdf$timeBin), 
    function(t1, t2, b){
      i = which(between(df$time, t1, t2))
      df[i, "timeBin"] <<- b
    })
  return(df)
}

df60 <- add_timebin(df, timegrid60) %>% mutate(intvl = "60 min")
df10 <- add_timebin(df, timegrid10) %>% mutate(intvl = "10 min")

df <- bind_rows(df60, df10)

# add time bin foreign keys
add_timebinCtxt <- function(df, tdf) {
  df$timeBinCtxt = NA
  pwalk(list(tdf$start, tdf$end, tdf$timeBin), 
        function(t1, t2, b){
          i = which(between(df$time, t1, t2))
          df[i, "timeBinCtxt"] <<- b
        })
  return(df)
}

df <- add_timebinCtxt(df, timegrid60)
df

flow <- df %>% 
  group_by(intvl, focusLoc, locId, direction, timeBin, timeBinCtxt)  %>%
  summarize(n = n()) %>%
  ungroup()



locLabels <- locs %>% select(locId = checkin_id, category, name) %>%
  mutate(category = fct_collapse(category,
    Other = c("Other", "Entrance", "Information & Assistance")
  ))

flow %>%
  left_join(locLabels, by = "locId") %>% 
  rename(time = timeBin) %>%
  write_csv("d3/flow.csv")

# ----------------- Summary Stats ---------------------------------------------

# get median duration per focusloc, timeSlot
summary_stats <- df %>% 
  group_by(intvl, focusLoc, timeBin) %>%
  summarize(medianDuration = median(duration, na.rm = T))

# get total number of visitors checked-in per focusloc, timeSlot
df2 <- df_checkins %>%
  select(focusLoc = checkin_id, checkin, checkout)


ff <- function(f, t1, t2, intvl) { 
  filter(df2,
         focusLoc == f,
         intvl == intvl,
         ((t1 >= checkin & t1 < checkout) |
         (t2 >= checkin & t2 < checkout))
         ) %>%
    nrow()
}

summary_stats <- summary_stats %>% 
  left_join(timegrid %>% select(start, end, intvl, timeBin), 
            by = c("intvl", "timeBin")) %>%
  mutate(totalVisitors = pmap_dbl(list(focusLoc, start, end, intvl), ff)) %>%
  select(-start, -end)

summary_stats

# ---------------- Make TimeSlots ----------------------------------------------

timeSlots <- flow %>% 
  group_by(intvl, timeBin, focusLoc, direction) %>%
  nest()

tg10 <- expand.grid(
  intvl = "10 min",
  timeBin = timegrid10$timeBin,
  focusLoc = checkin_ids,
  direction = c("to", "from")
)

tg60 <- expand.grid(
  intvl = "60 min",
  timeBin = timegrid60$timeBin,
  focusLoc = checkin_ids,
  direction = c("to", "from")
)

tg <- as.tibble(bind_rows(tg10, tg60))

timeSlots <- tg %>%
  left_join(timegrid, by = c("intvl", "timeBin")) %>%
  left_join(timeSlots, by = c("intvl", "timeBin", "focusLoc", "direction")) %>%
  spread(direction, data) %>%
  rename(nFrom = from, nTo = to) %>%
  left_join(summary_stats, by = c("intvl", "focusLoc", "timeBin"))

# add summary stats
timeSlots <- timeSlots %>%
  mutate(
    nFromTotal = map_int(nFrom, function(d) sum(d$n)),
    nToTotal   = map_int(nTo, function(d) sum(d$n)),
    nToFromMax = map2_int(nTo, nFrom, function(a,b) { 
      c <- c(a$n, b$n)
      if(is.null(c)) {
        return(as.integer(0))
      } else {
        return(max(c, na.rm = TRUE))
      }
    })
  ) %>% 
  mutate(
    totalVisitors = coalesce(totalVisitors, 0),
    medianDuration = coalesce(medianDuration, 0)
  ) %>%
  rename(
    stat1 = totalVisitors,
    stat2 = medianDuration
  )

timeSlots

# add time bin foreign keys
add_timebinCtxt <- function(df, tdf) {
  df$timeBinCtxt = NA
  pwalk(list(tdf$start, tdf$end, tdf$timeBin), 
        function(t1, t2, b){
          i = which(between(df$start, t1, t2))
          df[i, "timeBinCtxt"] <<- b
        })
  return(df)
}

timeSlots <- add_timebinCtxt(timeSlots, timegrid60)
View(timeSlots %>% select(intvl, timeBinCtxt, timeBin, everything()))

# make nFrom and nTo nested named-lists rather than tibbles, for json export
timeSlots$nFrom[1]

timeSlots %>%
  rename(time = timeBin) %>%
  mutate(
    nFrom = map(nFrom, function(x) { setNames(as.list(x$n), x$locId) }),
    nTo   = map(nTo,   function(x) { setNames(as.list(x$n), x$locId) })
  ) %>%
  write_json("d3/timeSlots.json", simplifyVector = T, 
             pretty = F, auto_unbox = T, POSIXt = "ISO8601")


# --------------------- Make Context Data --------------------------------------

park_data <- read_rds("data/park_data.RDS")

park_data
timegrid10

pd <- park_data %>%
  select(timestamp, id)

ff <- function(t1, t2) { 
  print(paste(t1, t2))
  idx <- which(pd$timestamp >= t1 & pd$timestamp < t2)
  print(length(idx))
  
  res <- length(unique(pd[idx, ]$id))
  print(res)
  
  return(res)
}

park_summary <- timegrid10 %>%
  mutate(totalVisitors = map2_int(start, end, ff))

park_summary <- add_timebinCtxt(park_summary, timegrid60)

park_summary

park_summary  %>% 
  write_csv("d3/context.csv")


# ------------------- Make Distance Matrix -------------------------------------

dist <- read_rds("data/loc_distances.RDS")

dist %>%
  as_tibble(rownames = "locId") %>%
  write_csv("d3/distmat.csv")

# ---- make xy data ------------------------------------------------------------

pd <- park_data %>%
  select(timestamp, id, x, y)

xy <- pd %>% distinct(x, y)

pd$timeBin <- NA

for (i in 1:nrow(timegrid)) {
  print(i)
  t1 <- timegrid[[i, "start"]]
  t2 <- timegrid[[i, "end"]]
  tb <- timegrid[[i, "timeBin"]]
  idx <- which(pd$timestamp >= t1 & pd$timestamp < t2)
  
  print(length(idx))
  
  pd[idx, "timeBin"] <- tb
}

park_summary <- pd %>% 
  group_by(timeBin, x,y) %>%
  summarize(n = length(unique(id))) 

park_summary %>% 
  write_csv("d3/xy.csv")
