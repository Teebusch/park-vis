library(tidyverse)

options(tibble.print_max = 40, tibble.print_min = 30)

df <- read_rds("data/checkins.RDS")

# for each user, count how many times they have checked into each ride
# we don't care about which entrance someone takes or whether they got to the
# information desk
df_visitors <- df %>%
  filter(category %in% c("Kiddie Rides", "Thrill Rides", "Rides for Everyone")) %>%
  group_by(id, checkin_id) %>%
  tally() %>%
  spread(checkin_id, n, fill = 0) %>%
  ungroup()

# add total number of checkins
df_visitors$n_checkins <- df_visitors %>%
  select(-id) %>%
  rowSums()

# add total number of unique checkins
df_visitors$n_unique_checkins <- df_visitors %>%
  select(-id) %>%
  mutate_all(~ . > 0) %>%
  rowSums()


# To find the distances between any two users we use the hamming distance
# Note that it simply tests for elementwise equality
# examples (requires package e1071):
e1071::hamming.distance(c(0,0,0), c(0,0,0)) # --> 0
e1071::hamming.distance(c(0,0,0), c(0,1,0)) # --> 1
e1071::hamming.distance(c(0,0,0), c(0,8,0)) # --> also 1!
e1071::hamming.distance(c(0,1,0), c(0,0,1)) # --> 2

# The function from e1071 takes a long time. The function below is much faster, 
# but only works for binary matrices. The output is the same as that from e1071 
# https://johanndejong.wordpress.com/2015/09/23/fast-hamming-distance-in-r/
binary_hamming_distance <- function(X) {
  D <- (1 - X) %*% t(X)
  D + t(D)
}

# Make the distance matrix. 
# This creates a 1 Gb large matrix.
dist_mat <- df_visitors %>% 
  select(-id, -n_checkins, -n_unique_checkins) %>%
  mutate_all(~ . > 0) %>%
  as.matrix() %>%
  binary_hamming_distance()

# add the visitor ids as row names 
rownames(dist_mat) <- df_visitors$id
colnames(dist_mat) <- df_visitors$id


# we can also define the uniqueness of a given visitor, i.e. how
# many other visitors have exactly the same pattern? 
df_visitors$n_equal <- apply(dist_mat, 2, function(x) names(which(x == 0))) %>%
  map_int(~length(.x))

df_visitors$mean_dist <- apply(dist_mat, 2, function(x) mean(x))

table(df_visitors$n_equal)
plot(hist(df_visitors$mean_dist))


# Now for the clustering...
# The distance matrix based on the hamming distances turns out to be less useful
# because most visitors try almost all rides *once*. The real difference lies in
# how often they go on the same ride
# dist_mat <- as.dist(dist_mat)

# to make the (euclidean) distance matrix on the raw numbers of check-in, 
# we can just use the dist() function.
dist_mat <- df_visitors %>% 
  select(-id, -n_checkins, -n_unique_checkins) %>%
  dist()

# With this distance matrix we can now cluster visitors
cls <- hclust(dist_mat, method = "ward.D2")
plot(cls, labels = FALSE)

df_visitors$cluster <- cutree(cls, k = 6)


write_rds(df_visitors, "data/visitors.RDS")
