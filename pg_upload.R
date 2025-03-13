## Load required libraries
library(DBI)
library(RPostgres)
## Adding new tables to postgress data base
con <- dbConnect(
  RPostgres::Postgres(),
  dbname = "LTSWAT2020_coarse",
  host = "localhost",   # e.g., "localhost" or a remote IP
  port = 5444,          # Default PostgreSQL port
  user = "postgres",
  password = "your_password"
)


# Define schema and table name
schema_name <- "management" 
version <- "v2025"

## Write into database
DBI::dbWriteTable(con, DBI::Id(schema = schema_name, table = paste0("yield_data", "_", version)), crop_pg_in, row.names = FALSE, overwrite = TRUE)
DBI::dbWriteTable(con, DBI::Id(schema = schema_name, table = paste0("livestock_data", "_", version)), livestock_pg_in, row.names = FALSE, overwrite = TRUE)

## Check the tables
dbGetQuery(con, sprintf("SELECT * FROM %s LIMIT 5;", paste0(schema_name, ".",  paste0("yield_data", "_", version))))
dbGetQuery(con, sprintf("SELECT * FROM %s LIMIT 5;", paste0(schema_name, ".",  paste0("livestock_data", "_", version))))

## Check the table list
query <- sprintf(
  "SELECT table_name FROM information_schema.tables WHERE table_schema = '%s';",
  schema_name
)
tables <- dbGetQuery(con, query)
print(tables)

## Close
dbDisconnect(con)
