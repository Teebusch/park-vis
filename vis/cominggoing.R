library(tidyverse)
library(viridis)
library(lubridate)
library(Cairo)

df <- read_rds("data/checkins.RDS")
df_timebins <- read_rds("data/timebins.RDS")
  
df_plot <- df %>%
  filter(day == "Friday") %>%
  gather(type, t, checkin, checkout) %>%
  mutate(
    x = as_datetime(t),
    xend = if_else(type == "checkin", 
                   floor_date(x, "day") + hours(9), 
                   floor_date(x, "day") + hours(23)),
    y = 0,
    yend = if_else(type == "checkin", 1, -1)
  )

p <- df_plot %>%
  ggplot(aes(x, y, xend = xend, yend = yend, color = duration)) +
  geom_curve(alpha =.1) +
  # geom_rect(aes(xmin = start, xmax = end, ymin = 0, ymax = n_checkedin/1000), 
  #           inherit.aes = F, fill = "black", color = "white", alpha = .5,
  #           data = filter(df_timebins, checkin_id == 34, day == "Sunday")) +
  # geom_rect(aes(xmin = start, xmax = end, ymin = -median_duration/20, ymax = 0, fill = median_duration), 
  #           inherit.aes = F, color = "white", alpha = .5,
  #           data = filter(df_timebins, checkin_id == 34, day == "Sunday")) +
  geom_point(aes(x = start, y = 0, size = n_checkedin, color = median_duration), inherit.aes = F,
             data = filter(df_timebins, day == "Friday")) +
  scale_y_continuous(expand = c(.3, .3)) +
  scale_fill_viridis(option = "A") +
  scale_color_viridis(option = "A") +
  facet_wrap(~ checkin_id) +
  theme_minimal() +
  theme(panel.grid.major.y = element_blank(),
        panel.grid.minor.y = element_blank(),
        axis.text.y = element_blank(),
        legend.position = "bottom")
  

ggsave(p, file="filename.png", type="cairo-png", dpi = 150, width = 15, height = 12, scale = 3)
