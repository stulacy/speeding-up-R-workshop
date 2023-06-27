library(tidyverse)
library(DBI)
library(RSQLite)
library(tictoc)

tic()
con_sql <- dbConnect(SQLite(), "data.sql")
time_read <- toc(quiet=TRUE)


tic()
tbl(con_sql, "data_full") |> 
  count(CompanyName) |> 
  filter(n > 2) |>
  count() |>
  collect()
time_count <- toc(quiet=TRUE)

tic()
tbl(con_sql, "data_full") |> 
  filter(RegAddress.PostTown == 'YORK') |> 
  mutate(postcode = substr(RegAddress.PostCode, 1, 4)) |>
  count(postcode) |>
  arrange(desc(n)) |>
  head(5) |>
  collect()
time_postcode <- toc(quiet=TRUE)

tic()
sic_10_companies_sql <- tbl(con_sql, "data_full") |> 
                count(SICCode.SicText_1) |>
                filter(n >= 10) |>
                select(SICCode.SicText_1)

tbl(con_sql, "data_full") |>
  select(CompanyNumber, SICCode.SicText_1, SICCode.SicText_2, SICCode.SicText_3, SICCode.SicText_4) |> 
  inner_join(sic_10_companies_sql, by="SICCode.SicText_1") |>
  mutate(first_classification = SICCode.SicText_1) |>
  pivot_longer(c(SICCode.SicText_1, SICCode.SicText_2, SICCode.SicText_3, SICCode.SicText_4)) |>
  filter(!is.na(value)) |>
  count(CompanyNumber, first_classification) |>
  group_by(first_classification) |>
  summarise(mean_classifications = mean(n, na.rm=T)) |>
  arrange(desc(mean_classifications)) |>
  collect()
time_sic <- toc(quiet=TRUE)

results <- list(
  read=time_read$toc - time_read$tic,
  count=time_count$toc - time_count$tic,
  postcode=time_postcode$toc - time_postcode$tic,
  sic=time_sic$toc - time_sic$tic
)
dbDisconnect(con_sql)

saveRDS(results, "benchmarks/results/sqlite.rds")
