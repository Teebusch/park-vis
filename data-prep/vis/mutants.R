library(ggthemes)
library(tidyverse)

df <- read_rds("data/visitors.RDS")
locs <- read_rds("data/checkin_locs.RDS")
id_order <- arrange(locs, category, name)$checkin_id

df_plot <- df %>%
  gather(checkin_id, count, `1`:`9`) %>%
  mutate(checkedin = count > 0) %>%
  left_join(locs, by = c("checkin_id")) %>%
  group_by(cluster, category, checkin_id) %>%
    summarize(n = sum(checkedin), 
              tot = length(checkedin)) %>%
  group_by(cluster) %>%
    mutate(p = n / tot,
           checkin_id = factor(checkin_id, levels = id_order))

df_plot %>%
  ggplot(aes(x = as.factor(cluster), y = checkin_id, size = p, color = category)) +
  geom_point() +
  theme_minimal()



# Another plot
df_plot <- df %>%
  group_by(cluster) %>%
    arrange(desc(mean_dist)) %>%
  ungroup() %>%
  gather(checkin_id, count, `1`:`9`) %>%
  left_join(locs, by = c("checkin_id")) %>%
  group_by(cluster, category, checkin_id) %>%
    mutate(xpos = row_number()) %>%
  ungroup() %>%
  mutate(checkedin = count > 0) %>%
  mutate(checkin_id = factor(checkin_id, levels = id_order))

df_plot %>%
  filter(checkedin == TRUE) %>%
  ggplot(aes(checkin_id, xpos, fill = category)) +
  geom_raster(show.legend = TRUE) +
  scale_fill_ptol() +
  facet_wrap(~ cluster, ncol = 3) +
  theme(
    legend.position = "bottom",
    panel.grid = element_blank(),
    strip.text = element_blank(),
    axis.title = element_blank(),
    axis.text = element_blank(),
    axis.ticks = element_line(color = NA)
  )
