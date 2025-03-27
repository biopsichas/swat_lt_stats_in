# Load required libraries
library(terra)
library(dplyr)
library(ggplot2)
library(tidyr)
library(exactextractr)
library(sf)

# Start the timer
start_time <- Sys.time()

# Define file paths
counties_path <- "Data/Counties/Counties.shp"
lu_raster_path <- "G:/LIFE_AAA/swat_lt/Projects/Setup_2020_common/Data/Rasters/LUraster_bck.tif"

# Load the land use raster and counties vector
lu_raster <- rast(lu_raster_path)
county_sf <- read_sf(counties_path)

# Compute zonal statistics: count the number of raster cells per land use type in each county
zonal_stat <- exact_extract(lu_raster, county_sf, progress = TRUE, fun = function(vals, covs) {
  # Create a table of land use values and count occurrences
  data.frame(table(factor(vals, exclude = NULL)))
})
zonal_stat$Var1 <- as.numeric(as.character(zonal_stat$Var1)) 
## NA value added 
NA_value <- max(unique(zonal_stat$Var1), na.rm = TRUE)+1
zonal_stat$Var1[is.na(zonal_stat$Var1)] <- NA_value 

## A loop to transform the table
group_start <- 1    # Start of current group
current_val <- 1    # Current value for comparison
county_idx <- 1     # Index for county_sf$KODAS
result_df <- data.frame(Var1 = sort(unique(zonal_stat$Var1), na.last = TRUE))

for(pos in seq_along(zonal_stat$Var1)) {
  next_val <- zonal_stat$Var1[pos + 1]
  if(current_val > next_val | is.na(next_val)) {
    print(county_sf$KODAS[[county_idx]])
    group_data <- zonal_stat[group_start:pos, ]
    colnames(group_data)[2] <- paste0("A_", county_sf$KODAS[[county_idx]])
    result_df <- left_join(result_df, group_data, by = "Var1")
    ## Setting indexes
    group_start <- pos + 1
    current_val <- 1
    county_idx <- county_idx + 1
  } else {
    current_val <- next_val
  }
}

## Replace NA with 0 in all columns except Var1
result_df[-1][is.na(result_df[-1])] <- 0

## Multiply with raster cell area to convert cell counts to areas
cell_size <- res(lu_raster)
raster_cell_area <- cell_size[1]*cell_size[2]
result_df[-1] <- result_df[-1] * raster_cell_area 

## Check the NA areas in the results
paste("NA areas in lu raster are coverring:", round(sum(result_df[result_df$Var1 == NA_value,])/1000000, 1), "km2")

## Check, if area results in calculation corresponds to vector data
column_sums <- colSums(result_df[result_df$Var1 != NA_value,-1])
transposed_df <- data.frame(
  KODAS = gsub("A_", "", names(column_sums)),
  AREA= as.numeric(column_sums)
) %>% left_join(county_sf %>% st_drop_geometry %>% select(KODAS, Shape_Area), by = "KODAS") %>% 
  mutate(diff_prec = round(100 * ((AREA -  Shape_Area)/ Shape_Area), 3))

ggplot(transposed_df, aes(x = "", y = diff_prec)) +
  geom_boxplot(width = 0.1) +
  geom_hline(yintercept = 0, color = "red", linewidth = 2, linetype = "dashed") +
  labs(y = "Difference in % of areas for county", title = "Plot to check how do final result and vector file areas match") +
  theme_bw()

##Check how total areas between result and shape file area different. Less than 0.2 % is OK. 
paste("Total areas are different by:" , round(100*((sum(column_sums) - sum(county_sf$Shape_Area))/ sum(county_sf$Shape_Area)), 2), "%")

## If checks are fine, write results
to_csv <- result_df[result_df$Var1 != NA_value,] %>% 
  rename(VALUE = Var1) %>% 
  mutate(OBJECTID = VALUE)%>% 
  select(OBJECTID, VALUE, everything())

write.table(to_csv, "Data/areas_by_type_new.txt", sep = ",", row.names = F, 
            col.names = T, quote = F)
