# helper function - minutes between two timestamps
minutes_between <- function(t1, t2) {
  as.duration(t1 %--% t2) %>%
    as.numeric("minutes") %>% 
    round(2)
}


# get hour of the day from datetime as numeric 
# e.g. 1:45pm = 13.75
hour_of_day <- function(t) {
  return(hour(t) + (minute(t)/60))
}
