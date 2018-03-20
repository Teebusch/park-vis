# Calculate distances between check-in locations and produces a distance matrix
# for shortest distances between check-in locations.
# Assumes that 'prepare_data.R' was run, so that `df` and `checkin_locations` 
# are available

# load data, see prepare_data.R and match_location_ids.R for more info
df <- read_rds("data/park_data.RDS")
locations <- read_rds("data/checkin_locs.RDS")

# Park is layed out in a grid. To get the distances we make a network of 
# xy-coordinates. Each coordinate is a node and can be *directly* connected to 
# up to 8 other nodes (its neighbours). 
# We start by making a data frame with all neighbours.

# All walkable locations (x,y coordinates) get an id
df_xys <- df %>%
  distinct(x,y) %>%
  mutate(i = row_number())

# all pairs of adjacent walkable locations (ids)
# First get ALL possible pairs, then remove those where the x or y difference is
# larger than 1. Note: requires expand.grid.df from the reshape package.
neighbours <- reshape::expand.grid.df(
  transmute(df_xys, i = row_number(), x1 = x, y1 = y),
  transmute(df_xys, j = row_number(), x2 = x, y2 = y)) %>%
  filter((abs(x1 - x2) <= 1) & (abs(y1 - y2) <= 1)) %>%
  select(i,j)

head(neighbours)

# we use the igraph library to make a graph. Then we use its `distances()`
# function to get a distance matrix for the distances between the checkin
# locations, i.e. the minimal number of nodes one has to cross to get from A to
# B.

park_graph <- igraph::graph_from_data_frame(neighbours, directed = FALSE)

# see "prepare_data.R" for origin of `locations` data frame.
checkin_locs <- inner_join(locations, df_xys, by = c("x", "y"))

loc_distances <- igraph::distances(park_graph, 
                                   v = as.character(checkin_locs$i), 
                                   to = as.character(checkin_locs$i))

# i is the "id" of the node in the graph. Since the matrix only contains the checkin locations, we can replace the node-ids with the check-in ids again.
colnames(loc_distances) <- checkin_locs$checkin_id
rownames(loc_distances) <- checkin_locs$checkin_id

# Now we can get the distance between any two checkin locations using the matrix
# like this:
loc_distances[1, 1]
loc_distances[1, 2]
loc_distances[4, 24]

saveRDS(loc_distances, file = "data/loc_distances.RDS")

# Free some memory
rm(df_xys, neighbours, checkin_locs, park_graph)
