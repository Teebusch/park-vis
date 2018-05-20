library(tidyverse)

source("munge/helpers.R")

df <- read_rds("data/park_data.RDS")

# Let's look at some simple summary stats 
df %>% 
  group_by(day) %>%
  summarize(
    n_obs = n(),
    n_visitors = length(unique(id)),
    n_moves = sum(type == "movement", na.rm = TRUE),
    n_checkins = sum(type == "check-in", na.rm = TRUE),
    n_ids = length(unique(id)),
    moves_pp = round(n_moves / n_ids, 1), # moves per person
    checkins_pp = round(n_checkins / n_ids, 1), # checkins per person
    start = min(timestamp, na.rm = TRUE),
    end = max(timestamp, na.rm = TRUE)
  )

# Check-ins
df2 <- df %>%
  filter(type == "check-in") %>%
  group_by(day, id) %>%
  summarize(n = n(), 
            n_unique = length(unique(checkin_id)),
            avg_stay = mean(stay))

df2 %>%
  summarize(avg = mean(n), 
            min = min(n),
            max = max(n),
            avg_unique = mean(n_unique), 
            min_unique = min(n_unique),
            max_unique = max(n_unique))

table(df2$n_unique)

df <- df %>%
  mutate(hour = hour_of_day(timestamp)) %>%
  group_by(day, id) %>%
  arrange(timestamp) %>%
  mutate(
    checkout = lead(timestamp),
    stay = minutes_between(timestamp, checkout),
    move = cumsum(x != lag(x, default = FALSE) & y != lag(y, default = FALSE))
  )







rides %>%
  ggplot(aes(x, y)) +
  geom_text(aes(label = ride_id), show.legend = FALSE) +
  scale_color_distiller(type = "seq") +
  coord_equal() +
  theme_void()

# all distinct locations and nr of check-ins
df_distinct <- df %>%
  group_by(type, x, y) %>%
  summarize(n = n()) %>%
  ungroup()

df_distinct %>%
  group_by(type) %>%
  mutate(n = (n-min(n)) / (max(n)-min(n))) %>%
  filter(type == "check-in") %>%
  ggplot(aes(x, y)) +
  geom_point(aes(color = n, size = sqrt(n)), show.legend = FALSE) +
  scale_color_distiller(type = "seq") +
  coord_equal() +
  theme_void() +
  theme(panel.background = element_rect(fill = "black"))

df_distinct %>%
  group_by(type) %>%
  mutate(n = scale(n)) %>%
  filter(type == "movement") %>%
  ggplot(aes(x, y)) +
  geom_point(aes(color = n), size = 1.5, show.legend = FALSE) +
  scale_color_distiller(type = "div") +
  coord_equal() +
  theme_void() +
  theme(panel.background = element_rect(fill = "black"))


df_smp <- df %>%
  filter(id %in% smp_ids)



df_smp %>%
  filter(type == "check-in") %>%
  ggplot(aes(x = timestamp, y = as.factor(id))) +
  geom_point() +
  facet_wrap(~day, scale = "free_x")


df_one <- filter(df_smp, id %in% smp_ids[1:16]) 

df_one %>%
  filter(type == "movement") %>%
  ggplot(aes(x,y, group = id, color = timestamp)) +
  scale_color_distiller(type = "seq") +
  geom_path(show.legend = FALSE) +
  facet_wrap(~as.factor(id)) +
  geom_point(data = filter(df_one, type == "check-in"), 
             color = "hotpink", alpha = .6) +
  coord_equal() +
  theme_void() +
  theme(
    panel.background = element_rect(fill = "white"),
    strip.text = element_blank(),
    panel.spacing = unit(0, "cm")
  )
        