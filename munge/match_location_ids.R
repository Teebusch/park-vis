# add correct id for each check-in location
# Real and temporary ids were matched manually outside of R. 
# This code need not be run again - just read in checkin_locs.RDS
# 
# TODO: Some of the locations on the map cannot be checked into (shopping, food,
# toilets.) It is a bit more difficult to define when a visitor is `in` one of
# these. Maybe later...

df <- read_rds("data/park_data.RDS")

checkin_locs <- df %>%
  filter(type == "check-in") %>%
  select(x, y) %>%
  distinct() %>%
  arrange(x, y) %>%
  mutate(temp_id = row_number())

ggplot(checkin_locs, aes(x, y, label = temp_id)) +
  geom_text() +
  coord_equal(expand = TRUE) +
  theme_void()

ggsave("plots/ids.svg", height = 5, width = 5)
write_csv(checkin_locs, "data/temp_ids.csv")

# ...
# I manually made a csv file here and matched the correct IDs and location names
# I got the location names and categories using `onlineocr.net` and matched them
# to the temporary ids using the plot, the image of the park and a vector 
# graphic software (Affinity Designer)
# ...

locs <- read_csv("data/checkin_locs.csv") 

# Test
library(ggrepel)

ggplot(locs, aes(x, y)) +
  geom_point(size = 3, aes(color = category)) +
  geom_label_repel(
    aes(label = checkin_id, fill = category),
    color = 'white',
    box.padding = 0.2, 
    point.padding = 0.1,
    segment.color = 'black'
  ) +
  coord_equal()

ggsave("data/G0R72A/additional-files/locs.png", type = "cairo-png")
write_rds(locs, "data/checkin_locs.RDS")






