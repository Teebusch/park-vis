library(tidyverse)
library(viridis)
library(lubridate)
library(Cairo)

df <- read_rds("data/checkins.RDS")
df_timebins <- read_rds("data/timebins.RDS")

ids <- unique(df$checkin_id)

df_pos <- data.frame(
  id = ids,
  xpos_norm = seq_along(unique(df$checkin_id)) / length(unique(df$checkin_id))
)

get_x_pos <- function(x, id) {
  xpos_norm <- df_pos[match(id, df_pos$id), "xpos_norm"]
  x_hr <- (9*60) + (14*60) * xpos_norm
  res <- floor_date(x, "day") + minutes(floor(x_hr))
  return(res)
}

df_plot <- df %>%
  filter(day == "Friday") %>%
  filter(checkin_id == "2") %>%
  gather(type, t, checkin, checkout) %>%
  mutate(
    x = as_datetime(t),
    y = 0,
    xend = if_else(type == "checkin", 
                   get_x_pos(x, prev_checkin_id),
                   get_x_pos(x, next_checkin_id)),
    yend = if_else(type == "checkin", 2, -2)
  )

df_highlight <- filter(df_plot, 
                      between(hour, 16, 16.25))
                       #(type == "checkin" & prev_checkin_id == 3) |
                         #(type == "checkout" & next_checkin_id == 3))

df_plot %>%
  #mutate(
  #   name = fct_collapse(name, 
  #                       Entrances = c("Entrance North", "Entrance West", "Entrance East"),
  #                       `Watching Rapids` = c("Watching Rapids I", "Watching Rapids II", "Watching Rapids III")
  #                       )
  # ) %>% 
  ggplot(aes(x, y, xend = xend, yend = yend, color = duration)) +
  geom_curve(alpha =.05, curvature = .1) +
  #geom_curve(alpha = .6, curvature = .1, data = df_highlight) +
  # geom_rect(aes(xmin = start, xmax = end, ymin = 0, ymax = n_checkedin/200),
  #           inherit.aes = F, fill = "black", color = NA, alpha = .5,
  #           data = filter(df_timebins, checkin_id == 10, day == "Friday")) +
  # geom_rect(aes(xmin = start, xmax = end, ymin = -median_duration/40, ymax = 0, fill = median_duration),
  #           inherit.aes = F, color = NA, alpha = .8,
  #           data = filter(df_timebins, checkin_id == 10, day == "Friday"), show.legend = FALSE) +
  geom_point(aes(x = start, y = 0, size = n_checkedin, color = median_duration), inherit.aes = F,
             data = filter(df_timebins, day == "Friday", checkin_id == "2"), color = "black") +
  geom_point(aes(x = xend, y = yend)) +
  #scale_y_continuous(expand = c(-1, 1)) +
  scale_fill_viridis(option = "B") +
  scale_color_viridis(option = "B") +
  facet_wrap(~ name) +
  theme_minimal() +
  theme(panel.grid.major.y = element_blank(),
        panel.grid.minor.y = element_blank(),
        axis.text.y = element_blank(),
        legend.position = "bottom")



ggsave(file="filename0.png", type="cairo-png", dpi = 150, width = 8, height = 6, scale = 2)
