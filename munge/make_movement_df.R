# Make a 

# move_nr: number each visitor's "moves" (movements/checkins)
move_nr = cumsum(x != lag(x, default = FALSE) & y != lag(y, default = FALSE)),
# stay: how long do people stay in the rides and locations? (for movements, the 
# duration should always be 1s, i.e. 0.08 min)
stay = minutes_between(timestamp, lead(timestamp))

# prev_checkin: The previous registered check-in location of that user
# next_checkin: The next registered check-in location of that user
df <- df %>%
  mutate(
    prev_checkin = lag(checkin_id),
    next_checkin = lead(checkin_id)
  ) %>%
  fill(prev_checkin) %>%
  fill(next_checkin, direction = "up")

df <- df %>%
  ungroup()

head(df %>% select(checkin_id, prev_checkin))






