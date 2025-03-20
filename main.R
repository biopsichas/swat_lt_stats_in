# Load required libraries
library(readxl)
library(dplyr)
library(ggplot2)
library(sf)
library(stringr)
library(openxlsx)

## =============================================================================
## Settings
## =============================================================================

## Set years to be included (data should be available in Data folder as well)
years_to_process <- c("2020", "2021", "2022", "2023", "2024")

## Provide the list of SWAT codes that are not related to agriculture
swat_codes_not_agri <- c("BARR", "FRSD", "FRSE", "FRST", "OAK", 
                         "PINE", "POPL", "RNGB", "UIDU", "URHD", 
                         "URLD", "URMD", "URML", "UTRN", "WATR", 
                         "WETF", "WETL", "WILL")

## Provide path to the data about the livestock units
livestock_units_path <- "Data/unique_animal_names.xlsx"

## Provide path to the data about the SWAT codes related to the yield statistics
swat_codes_to_yield_stat_path <- "Data/Yield_Statistics_codes.xlsx"

## Provide path to the counties shape data
counties <- "Data/Counties/Counties.shp"

## Provide path to the SWAT raster zonal statistics data
raster_zonal <- "Data/areas_by_type.txt"
## Provide path to lookup table for SWAT raster id values
raster_lookup <- "Data/landuse_swat_raster_lookup.csv"
## Provide output folder
out_path <- "Output"
## =============================================================================
## FOLLOWING CODE IS USED TO PROCESS THE DATA
## 
## =============================================================================
## 1) CROP DATA
## =============================================================================
# Check if the folder exists, and create it if not
if (!dir.exists(out_path)) dir.create(out_path, recursive = TRUE)

## Collect the data for crop yields
crop <- NULL
livestock <- NULL
for(y in years_to_process){
  ## Read the data for crop yields
  crop_yields <- read.csv2(paste0("Data/Stat_Dep/yields", y, ".csv"), sep = ",", 
                           encoding = "UTF-8", stringsAsFactors = FALSE,
                           col.names = c("Metai", "Rodiklis", "Adm", "Augalai", 
                                         "Tipas", "Vnt", "Reikšmė"))
  ## Read the data for livestock
  livestock_numbers <- read.csv2(paste0("Data/Stat_Dep/livestock", y, ".csv"), sep = ",",
                                 encoding = "UTF-8", stringsAsFactors = FALSE,
                                 col.names = c("Metai", "Rodiklis", "Adm", 
                                               "Gyvūliai", "Vnt", "Reikšmė"))
  ## Collect the data in one data frame
  if(is.null(crop)) crop <- crop_yields else crop <- bind_rows(crop, crop_yields)
  if(is.null(livestock)) livestock <- livestock_numbers else livestock <- 
    bind_rows(livestock, livestock_numbers)
}
rm(y, crop_yields, livestock_numbers)

## Get the codes for the crop yields
df_codes <- read_excel(swat_codes_to_yield_stat_path)

## Read the data for the counties
df_counties <- st_read(counties, options = "ENCODING=WINDOWS-1257") %>% 
  mutate(SAVIV_PAV = case_when(KODAS == 16 ~ "Jonavos r. sav.",
                               KODAS == 15 ~ "Molėtų r. sav.",
                               KODAS == 14 ~ "Jurbarko r. sav.",
                               KODAS == 13 ~ "Kazlų Rūdos sav.",
                               KODAS == 12 ~ "Druskininkų sav.",
                               KODAS == 11 ~ "Visagino sav.",
                               KODAS == 10 ~ "Neringos sav.",
                               KODAS == 2 ~ "Vilniaus m. sav.",
                               KODAS == 1 ~ "Birštono sav.",
                               KODAS == 3 ~ "Alytaus m. sav.",
                               KODAS == 4 ~ "Kauno m. sav.",
                               KODAS == 5 ~ "Šiaulių m. sav.",
                               KODAS == 6 ~ "Marijampolės r. sav.",
                               KODAS == 7 ~ "Panevėžio m. sav.",
                               KODAS == 8 ~ "Palangos m. sav.",
                               KODAS == 9 ~ "Klaipėdos m. sav.",
                               TRUE ~ as.character(SAVIV_PAV))) %>% 
  mutate(SAVIV_PAV = str_replace(SAVIV_PAV, "Marijampolės sav.", 
                                 "Marijampolės r. sav.")) %>% 
  select(KODAS, SAVIV_PAV)

## Clean the crop data
crop1 <- crop %>% 
  filter(Adm %in% unique(df_counties$SAVIV_PAV)) %>% 
  inner_join(df_codes, by = c("Augalai" = "StatName"), relationship = "many-to-many") %>% 
  mutate(`Reikšmė` = as.numeric(`Reikšmė`)) %>%
  filter(!is.na(`Reikšmė`)) %>%
  select(Adm, SWATCODE, `Reikšmė`) %>% 
  group_by(Adm, SWATCODE) %>%
  summarize(mean_yield = mean(`Reikšmė`, na.rm = TRUE))

## Prepare the data for the crop yields
crop_final <- NULL
for (c1 in unique(crop1$SWATCODE)){
  c1_df <- filter(crop1, SWATCODE == c1)
  df_c1 <- left_join(df_counties %>% st_drop_geometry(), c1_df, 
                     by = c("SAVIV_PAV" = "Adm")) %>% 
    mutate(mean_yield = ifelse(is.na(mean_yield), mean(c1_df$mean_yield), mean_yield),
           SWATCODE = ifelse(is.na(SWATCODE), c1, SWATCODE)) %>% 
    rename(countyid = KODAS, planned_yield = mean_yield) %>% 
    select(-SAVIV_PAV)
  if(is.null(crop_final)) crop_final <- df_c1 else crop_final <- 
    bind_rows(crop_final, df_c1)
}

rm(c1, c1_df, df_c1, crop1, df_codes, crop)

## Write csv file, seperated by tab
write.table(crop_final, paste0(out_path, "planned_yield.csv"), row.names = FALSE, 
            sep = "\t", quote = FALSE)

## Prepare table to write into postgres
crop_pg_in <- mutate(crop_final, id = row_number()) %>% 
  rename(swat_id = SWATCODE, kodas = countyid) %>% 
  mutate(planned_yield = round(planned_yield, 2)) %>% 
  select(kodas, swat_id, planned_yield)

## =============================================================================
## 2) LIVESTOCK DATA
## =============================================================================

## Get the values for the livestock units
sgv <- read_excel(livestock_units_path) %>% 
  .[!is.na(.$SGV), c("name", "SGV")]

## Get zonal statistics for different areas in Lithuania
areas <- read.csv2(raster_zonal, sep = ",") %>% 
  select(-OBJECTID) %>% 
  tidyr::pivot_longer(cols = -c("VALUE"), names_to = "KODAS", values_to = "area") %>% 
  mutate(KODAS = gsub("A_", "", KODAS))

## Get the lookup table for the raster values (A is for agricultural areas, 
## N for not agricultural areas)
lookup <- read.csv2(raster_lookup, sep = ",") %>%
  rename(swatcode = 1,raster_id = 2) %>% 
  mutate(agri = ifelse(swatcode %in% swat_codes_not_agri, "N", "A"))

## Get the areas for the agricultural and non-agricultural areas in the counties 
agri_areas_bck <- left_join(areas, lookup, by = c("VALUE" = "raster_id")) %>% 
  select(KODAS, agri, area) %>% 
  mutate(area = as.numeric(area)) %>% 
  group_by(KODAS, agri) %>%
  summarise(area = sum(area, na.rm = TRUE), .groups = "drop") %>%
  tidyr::pivot_wider(names_from = agri, values_from = area, id_cols = KODAS) %>% 
  left_join(st_drop_geometry(df_counties), by = "KODAS") 

## Get the agricultural areas in each district
agri_areas <- select(agri_areas_bck, SAVIV_PAV, A) %>% 
  group_by(SAVIV_PAV) %>%
  summarise(A = sum(A, na.rm = TRUE), .groups = "drop") %>% 
  filter(!is.na(SAVIV_PAV))

## Get the livestock data per district, and calculate the density of livestock
## units per hectare of agricultural land
livestock_per_district <- livestock[c("Adm", "Gyvūliai", "Reikšmė")] %>% 
  mutate(Adm = str_replace(Adm, "Marijampolės sav.", "Marijampolės r. sav.")) %>% 
  group_by(Adm, Gyvūliai) %>%
  summarise_all(mean, na.rm = TRUE, .group = "drop") %>% 
  left_join(sgv, by = c("Gyvūliai" = "name")) %>%
  filter(grepl("sav.", Adm) & !is.na(SGV)) %>% 
  mutate(value = round(`Reikšmė` * SGV, 1)) %>% 
  select(Adm, value) %>% 
  group_by(Adm) %>%
  summarise_all(sum, na.rm = TRUE) %>% 
  left_join(agri_areas, by = c("Adm" = "SAVIV_PAV")) %>% 
  mutate(density = value/A)

## Get the livestock data per county
livestock_by_county <- left_join(agri_areas_bck[c("KODAS", "A", "SAVIV_PAV")], 
               livestock_per_district[c("Adm", "density")], 
               by = c("SAVIV_PAV" = "Adm")) %>% 
  rename(kodas = KODAS) %>% 
  mutate(kodas = as.numeric(kodas)) %>% 
  arrange(kodas) %>% 
  mutate(Livestock_units = round(density * A, 1),
         Agricultural_Area = round(A / 10000, 1),
         ID = row_number()) %>% 
  select(ID, kodas, Livestock_units, Agricultural_Area)

rm(livestock_per_district, agri_areas, agri_areas_bck, areas, lookup, sgv, livestock)

##Write excel file with openxlsx
write.xlsx(livestock_by_county, paste0(out_path, "/livestock_by_county.xlsx"), rowNames = FALSE, 
           sheetName = "Sheet1")

## Prepare table to write into postgres
livestock_pg_in <- rename(livestock_by_county, id = ID, livestock_units = Livestock_units,  agricultural_area = Agricultural_Area) %>% 
  select(kodas, livestock_units, agricultural_area) %>% 
  mutate(kodas = as.character(kodas),
         livestock_units = ifelse(is.na(livestock_units), 0 , livestock_units))

## =============================================================================
## FOR QUALITY CONTROL

## =============================================================================
## Check the data output data
## =============================================================================

##Check the crop data
## Summary of the data
select(crop_final, -countyid) %>% 
  group_by(SWATCODE) %>%
  summarize_all(mean)

## Plot the data
crop2 <- full_join(df_counties, crop_final, by = c("KODAS" = "countyid"))
plot_list <- list()
for(c1 in unique(crop2$SWATCODE)){
  p <- ggplot(data = filter(crop2, SWATCODE == c1)) +
    geom_sf(aes(fill = planned_yield), color = "black") +
    scale_fill_gradient(low = "green", high = "red", name = "Planned Yield") +
    ggtitle(c1) +
    theme_void() +
    theme(legend.position.inside = c(0.1, 0.2))
  plot_list[[c1]] <- p
  print(p)
}

## Check the livestock data
## Map of livestock units by county new
ggplot(data =  left_join(df_counties, livestock_by_county %>% 
                           mutate(kodas = as.character(kodas)), 
                         by = c("KODAS" = "kodas"))) +
  geom_sf(aes(fill = Livestock_units), color = "black") +
  scale_fill_gradient(low = "green", high = "red", name = "Livestock units new") +
  theme_void() +
  theme(legend.position = c(0.1, 0.2))

## Map of livestock units by county old
ggplot(data = left_join(df_counties, read_excel("Data/livestock_by_county.xlsx"), 
                        by = c("KODAS" = "kodas"))) +
  geom_sf(aes(fill = Livestock_units), color = "black") +
  scale_fill_gradient(low = "green", high = "red", name = "Livestock units old") +
  theme_void() +
  theme(legend.position = c(0.1, 0.2))

## Sums of the data
livestock_by_county[c("Livestock_units", "Agricultural_Area")]%>% 
  summarise_all(sum)
read_excel("Data/livestock_by_county.xlsx")[c("Livestock_units", "Agricultural_Area")] %>% 
  summarise_all(sum, na.rm = TRUE)

