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
  #mutate(
  #   name = fct_collapse(name, 
  #                       Entrances = c("Entrance North", "Entrance West", "Entrance East"),
  #                       `Watching Rapids` = c("Watching Rapids I", "Watching Rapids II", "Watching Rapids III")
  #                       )
  # ) %>% 
  filter(checkin_id == 10) %>%
  ggplot(aes(x, y, xend = xend, yend = yend, color = duration)) +
  geom_curve(alpha =.1) +
  geom_rect(aes(xmin = start, xmax = end, ymin = 0, ymax = n_checkedin/200),
            inherit.aes = F, fill = "black", color = NA, alpha = .5,
            data = filter(df_timebins, checkin_id == 10, day == "Friday")) +
  geom_rect(aes(xmin = start, xmax = end, ymin = -median_duration/40, ymax = 0, fill = median_duration),
            inherit.aes = F, color = NA, alpha = .8,
            data = filter(df_timebins, checkin_id == 10, day == "Friday"), show.legend = FALSE) +
  # geom_point(aes(x = start, y = 0, size = n_checkedin, color = median_duration), inherit.aes = F,
  #            data = filter(df_timebins, day == "Friday")) +
  scale_y_continuous(expand = c(.3, .3)) +
  scale_fill_viridis(option = "A", direction = 1) +
  scale_color_viridis(option = "A") +
  facet_wrap(~ name) +
  theme_minimal() +
  theme(panel.grid.major.y = element_blank(),
        panel.grid.minor.y = element_blank(),
        axis.text.y = element_blank(),
        legend.position = "bottom")
  

p

nrow(df_plot)

ggsave(p, file="filename2.png", type="cairo-png", dpi = 150, width = 6, height = 6, scale = 2)
ggsave(p, file="filename.png", type="cairo-png", dpi = 150, width = 10, height = 10, scale = 3)
