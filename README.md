# Code for "Visualization in Data Science" Course
**Note:** This is a work in progress. I will add more scripts and plots as I go along.

## Instructions

  + The raw data is _not included_ because I wasn't sure about the licensing. So, after you clone the repository, you will have to put the `G0R72A` folder into the `data` folder `data/G0R72A/movement-data/park-movement-[Fri, Sat, Sun].csv`
  + Run `prepare_data.R`. It will read the csv files, add some variables and store everything in `data/park_data.RDS` for further use (and faster loading).
  
## What did I compute?

### True location Ids and meta information
I made a table with the real location IDs (i.e. the same as on the map) for each check-in location, as well as the corresponding meta-information (name of the ride, category of ride). The table can be found in `data/checkin_locs.RDS` (and `checkin_locs.csv` for non-R users). 
The correct ids have also already been added to `park_data.RDS`. The name and category can easily be added with `dplyr::left_join()`.
See `munge/match_location_ids.R` for infos on how I did it (it involved some manual work -- yikes!)

### Distances between locations
I made a distance matrix for shortest walking distances between all check-in locations. That is, how many tiles does a visitor _at least_ need to cross to get from **A** to **B**? 

See `munge/get_location_distances.R` for the script and `data/loc_distances.RDS` for the matrix. 

### Some other variables
In `prepare_data.R` I've added a few other variables that might come in handy to `park_data.RDS`:
  
  + **hour:** time of day as numeric, e.g. 1.30pm = 13.5
  + **visit_time:** how long (minutes) since we first saw the visitor (i.e. since she 
entered the park)?
  + **checkin_nr:** order of the check-ins for each visitor (1st check-in, 
2nd check-in..., nth check-in)
  + **movement_nr:** order of the movements for each visitor (moving between 1st and 
2nd check-in, between 2nd and 3rd check-in,..., between nth and n+1th check-in

  

