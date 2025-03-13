# Update Statistical Information

## Overview

This script updates statistical information in the Lithuanian river modeling system.

## Requirements

Dependencies needed to run the project.

- R version >= 4.0.0

Required packages:

- readxl
- dplyr
- ggplot2
- sf
- stringr
- openxlsx
- DBI
- RPostgres

No installation is required - just run the script. However, you need to manually download the necessary data from the Statistical Department database, available at:  
[https://osp.stat.gov.lt/statistiniu-rodikliu-analize#/](https://osp.stat.gov.lt/statistiniu-rodikliu-analize#/).

Two datasets are required:  

1. **Livestock numbers**: The number of livestock at the beginning of each year in each municipality (*Gyvulių ir paukščių skaičius metų pradžioje*).  
2. **Crop yields**: The annual yield of crops in each municipality (*Žemės ūkio augalų derlingumas*).  

Example datasets are provided in the repository under the `Data/Stat_Dep` folder.

## File Structure
```
├── Data/               # Input data directory
├── main.R              # Main script to preprocess data
├── pg_upload.R         # Script to upload data to PostgreSQL
└── README.md           # This file
```
---

## Workflow

### 1. Download and Prepare Data  
- Download the required statistical data.  
- Place the files in the `Data/Stat_Dep` folder in the correct format.  

### 2. Run the `main.R` Script  
Executing `main.R` will generate the following files:  

- `planned_yield.csv`  
- `livestock_by_county.xlsx`  

These outputs match the format of previous preprocessing scripts used in the modeling system.  

Additionally, `main.R` produces two key data frames:  

- `crop_pg_in`  
- `livestock_pg_in`  

These data frames contain formatted data ready for insertion into the PostgreSQL database used by the modeling system.

### 3. Upload Data to the Database  
Run the `pg_upload.R` script to upload the processed data to the database.  

**Requirements:**  
- A running PostgreSQL database on the local machine.  
- Database connection details.

### 4. Update `settings.R` in the River Modeling System  
Once the data is successfully uploaded, update the `settings.R` file in the river modeling system. Modify the following lines (around 633-640):

```python
# 
Class Fert:
  LIVESTOCK = ("management", "livestock_data_v2025")
  PLANNEDYIELD = ("management", "yield_data_v2025")
```
Ensure that the table names match those written to the database.

### 5. Run the Modeling System

After updating `settings.R`, the modeling system is ready to use the new statistical data.
