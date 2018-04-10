library(tidyverse)
library(viridis)

df <- read_rds("data/checkins.RDS")


df_plot <- df %>%
  mutate(
    p_scaled = ifelse(checkin_nr == 1, 1, p_scaled),
    line_id = paste0(day, id)
  ) %>%
  group_by(line_id) %>%
  mutate(
    n_checkins = n(),
    checkin_nr_scaled = checkin_nr / n_checkins,
    p_cume = cumsum(p_scaled),
    #mgn = checkin_nr_scaled - lag(checkin_nr_scaled, default = 0),
    #ang = (180*(1 - p_scaled)) * (pi/180), # degree to radians
    #ang = cumsum(ang),
    # x = ifelse(checkin_nr == 1, 0, mgn*cos(ang)),
    # y = ifelse(checkin_nr == 1, 0, mgn*sin(ang)),
    ang = 1-p_scaled,
    x = ifelse(checkin_nr == 1, 0, cumsum(ang)),
    y = ifelse(checkin_nr == 1, 0, 1), #(1-p_scaled)),
    x = cumsum(x),
    y = cumsum(y),
    p_scaled_next = lead(p_scaled, default = NA),
    disp = (max(x) - min(x))/n()
  )

df_lines <- df_plot %>% 
  group_by(line_id) %>%
  summarize(
    id = first(id),
    n_checkins = first(n_checkins),
    low_p = any(p_scaled < .2)
  ) 

checkin_qauntiles <- quantile(df_lines$n_checkins, seq(0, 1, length.out = 13))


sample_ids <- sample(df_lines$id, 100)

df_plot <- df_plot %>%
  ungroup() %>%
  filter(id %in% sample_ids) %>%
  mutate(group = cut(n_checkins, checkin_qauntiles, include.lowest = TRUE)) %>%
  mutate(
    x_offset = dense_rank(disp) * 5, 
    x = x + x_offset
  ) %>%
  arrange(desc(n_checkins), line_id)


df_end <- df_plot %>%
  group_by(line_id) %>%
  mutate(p_total = mean(p_scaled)) %>%
  filter(checkin_nr == max(checkin_nr))


df_plot %>%
  #filter(checkin_nr != 1) %>%
  ggplot(aes(x, y, group = line_id)) +
  geom_path(aes(color = p_scaled_next), alpha = .9, show.legend = T, size =.1) +
  geom_point(color = "white", alpha = .7, show.legend = T, data = df_end) +
  #geom_point(aes(x = 0, y = 0), size = 2, color = "white", alpha = .8) +
  scale_color_viridis(option = "A", direction = 1, begin = 0.2, end = 1) +
  theme(
    axis.title = element_blank(),
    axis.text = element_blank(),
    axis.ticks = element_blank(),
    panel.grid = element_blank(),
    panel.background = element_rect(fill = "black"),
    panel.spacing = unit(0, "npc"),
    strip.background = element_rect(fill = "black"),
    strip.text = element_text(colour = "white"),
    legend.position = "bottom"
  ) #+
  #scale_x_reverse() #+
  #labs(color = "Transitional\nprobability") #+
  #facet_wrap(~ group, nrow = 4)
ggsave("sketch4.png", width = 8)
