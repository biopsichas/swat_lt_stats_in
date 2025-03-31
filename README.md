# Update Statistical Information for Lithuanian River Modeling System

This repository contains R scripts to update statistical information (crop yields and livestock data) for [the Lithuanian river modeling system](https://srees.sggw.edu.pl/article/view/9790/8738), which runs the SWAT (Soil and Water Assessment Tool) model. The workflow involves downloading data from the Lithuanian Statistical Department, preprocessing it, and uploading it to a PostgreSQL database for use in the modeling system.

## Project Overview

- **Created on**: 2025-03-13  
- **Last Modified**: 2025-03-30  
- **Author**: Svajunas Plunge  
- **Email**: svajunas_plunge@sggw.edu.pl  

This project automates the preprocessing of statistical data on crop yields and livestock numbers across Lithuanian municipalities. The processed data is formatted for integration into the Lithuanian river modeling system, which uses the SWAT model for hydrological simulations.

### Key Features
1. **Data Preprocessing**: Processes crop yield and livestock data from the Lithuanian Statistical Department.
2. **Output Generation**: Produces formatted CSV and Excel files for use in the modeling system.
3. **Database Integration**: Uploads processed data to a PostgreSQL database.
4. **Quality Control**: Includes visualization and summary statistics for data validation.

## Repository Structure

```
Update-Statistical-Information/
├── Data/                          # Input data directory
│   ├── Stat_Dep/                  # Folder for statistical data (yields and livestock)
│   ├── Counties/                  # Folder for county shapefile (Counties.shp)
│   ├── unique_animal_names.xlsx   # Livestock units data
│   ├── Yield_Statistics_codes.xlsx # SWAT codes for yield statistics
│   ├── areas_by_type.txt          # SWAT raster zonal statistics
│   ├── landuse_swat_raster_lookup.csv # Lookup table for SWAT raster IDs
│   └── livestock_by_county.xlsx   # Previous livestock data for comparison
├── Output/                        # Output directory for processed data
├── main.R                         # Main script to preprocess data
├── pg_upload.R                    # Script to upload data to PostgreSQL
└── README.md                      # This file
```


## Prerequisites

### Software Requirements

- R version >= 4.0.0
- PostgreSQL (for database integration)
- Required R packages:
  - `readxl`
  - `dplyr`
  - `ggplot2`
  - `sf`
  - `stringr`
  - `openxlsx`
  - `DBI`
  - `RPostgres`

Install the required R packages using the following command in R:

```R
install.packages(c("readxl", "dplyr", "ggplot2", "sf", "stringr", "openxlsx", "DBI", "RPostgres"))
```
No other installations is required - just run the script. However, you need to manually download the necessary data from the Statistical Department database, available at:  
[https://osp.stat.gov.lt/statistiniu-rodikliu-analize#/](https://osp.stat.gov.lt/statistiniu-rodikliu-analize#/).

### Data Requirements

- Statistical data from the Lithuanian Statistical Department, available at: https://osp.stat.gov.lt/statistiniu-rodikliu-analize#/:
  - **Livestock numbers**: "Gyvulių ir paukščių skaičius metų pradžioje" (Number of livestock at the beginning of each year in each municipality).
  - **Crop yields**: "Žemės ūkio augalų derlingumas" (Annual yield of crops in each municipality).
- Place these datasets in the `Data/Stat_Dep/` folder with filenames like `yieldsYYYY.csv` and `livestockYYYY.csv` (e.g., `yields2020.csv`, `livestock2020.csv`).
- Additional data files (included in the repository):
  - `unique_animal_names.xlsx`: Livestock units data.
  - `Yield_Statistics_codes.xlsx`: SWAT codes for yield statistics.
  - `areas_by_type.txt`: SWAT raster zonal statistics.
  - `landuse_swat_raster_lookup.csv`: Lookup table for SWAT raster IDs.
  - `Counties/Counties.shp`: Shapefile for Lithuanian counties.
- Access to a PostgreSQL database (required for data upload).

## Usage

1. **Clone the Repository**:
```bash
  git clone https://github.com/biopsichas/swat_lt_stats_in.git
  cd Update-Statistical-Information
```
2. **Download and Prepare Data**:
   - Download the required statistical data from https://osp.stat.gov.lt/statistiniu-rodikliu-analize#/.
   - Place the files in the `Data/Stat_Dep/` folder with the correct naming convention (e.g., `yields2020.csv`, `livestock2020.csv`).

3. **Configure Settings**:
   - Edit `main.R` to specify:
     - `years_to_process`: Years to process (e.g., `c("2020", "2021", "2022", "2023", "2024")`).
     - `swat_codes_not_agri`: SWAT codes not related to agriculture.
     - Paths to input data files (e.g., `livestock_units_path`, `swat_codes_to_yield_stat_path`).
   - Edit `pg_upload.R` to specify:
     - Database connection details (`dbname`, `host`, `port`, `user`, `password`).
     - Schema and table version (e.g., `schema_name = "management"`, `version = "v2025"`).

4. **Run the Preprocessing Script**:
- Execute `main.R` to preprocess the data:
```bash
Rscript main.R
```

- This will generate the following output files in the `Output/` directory:
  - `Output/planned_yield.csv`: Processed crop yield data.
  - `Output/livestock_by_county.xlsx`: Processed livestock data.
  - Data frames `crop_pg_in` and `livestock_pg_in` for database upload.

5. **Upload Data to PostgreSQL**:
- Execute `pg_upload.R` to upload the processed data to a PostgreSQL database:
```bash
Rscript pg_upload.R
```
- This will create two tables in the database: `management.yield_data_v2025` and `management.livestock_data_v2025`.

6. **Update the River Modeling System**:
- Update the `settings.py` file in the river modeling system (lines ~633-640):
```python
Class Fert:
  LIVESTOCK = ("management", "livestock_data_v2025")
  PLANNEDYIELD = ("management", "yield_data_v2025")
```
- Ensure the table names match those written to the database.

7. **Run the River Modeling System**:
- The modeling system is now ready to use the updated statistical data.

## Workflow Steps

1. **Download and Prepare Data**:
   - Obtain statistical data and place it in the `Data/Stat_Dep/` folder.
2. **Preprocess Data**:
   - Run `main.R` to process crop yields and livestock data, generating output files and data frames.
3. **Upload to Database**:
   - Run `pg_upload.R` to upload the processed data to PostgreSQL.
4. **Update Modeling System**:
   - Modify `settings.py` in the river modeling system to point to the new database tables.
5. **Run Modeling System**:
   - Use the updated data in the SWAT-based river modeling system.

## Example Configuration 

`main.R`

```R
years_to_process <- c("2020", "2021", "2022", "2023", "2024")
swat_codes_not_agri <- c("BARR", "FRSD", "FRSE", "FRST", "OAK", 
                         "PINE", "POPL", "RNGB", "UIDU", "URHD", 
                         "URLD", "URMD", "URML", "UTRN", "WATR", 
                         "WETF", "WETL", "WILL")
livestock_units_path <- "Data/unique_animal_names.xlsx"
swat_codes_to_yield_stat_path <- "Data/Yield_Statistics_codes.xlsx"
counties <- "Data/Counties/Counties.shp"
raster_zonal <- "Data/areas_by_type.txt"
raster_lookup <- "Data/landuse_swat_raster_lookup.csv"
out_path <- "Output"
```

`pg_upload.R`

```R
con <- dbConnect(
  RPostgres::Postgres(),
  dbname = "LTSWAT2020_coarse",
  host = "localhost",
  port = 5444,
  user = "postgres",
  password = "your_password"
)
schema_name <- "management"
version <- "v2025"
```

## Outputs

- Processed Files:
  - `Output/planned_yield.csv`: Tab-separated file with crop yield data.
  - `Output/livestock_by_county.xlsx`: Excel file with livestock data by county.
- Database Tables:
  - `management.yield_data_v2025`: Crop yield data.
  - `management.livestock_data_v2025`: Livestock data.
- Quality Control:
  - Summary statistics and maps generated in `main.R` for data validation (e.g., livestock unit maps).

## Notes
- Ensure all file paths in `main.R` are accessible and correctly formatted.
- The `Counties.shp` shapefile uses the Lithuanian Coordinate System (EPSG:3346).
- Update the password in `pg_upload.R` to match your PostgreSQL database credentials.
- Processing time depends on data size and system resources.

## Acknowledgments

This work was carried out within the LIFE22-IPE-LT-LIFE-SIP-Vanduo project (Integratedwater management in Lithuania, ref: LIFE22-IPE-LT-LIFE-SIP-Vanduo/101104645,cinea.ec.europa.eu), funded by the European Union LIFE program under the grant agreementNo 101104645.
