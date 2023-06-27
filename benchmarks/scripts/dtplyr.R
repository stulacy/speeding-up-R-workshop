library(tidyverse)
library(data.table)
library(dtplyr)
library(lubridate)
library(stringr)
library(tictoc)

tic()
dt <- fread("BasicCompanyDataAsOneFile-2023-05-01.csv")
dt[, IncorporationDate := as_date(IncorporationDate, format="%d/%m/%Y") ]  # Creates a new column by *reference*
dtp <- lazy_dt(dt)
time_read <- toc(quiet=TRUE)


tic()
dtp |> 
  count(CompanyName) |> 
  filter(n > 2) |>
  collect() |>
  nrow()
time_count <- toc(quiet=TRUE)

tic()
dtp |> 
  filter(RegAddress.PostTown == 'YORK') |> 
  mutate(postcode = word(RegAddress.PostCode, 1)) |>
  count(postcode) |>
  arrange(desc(n)) |>
  head(5) |>
  collect()
time_postcode <- toc(quiet=TRUE)

tic()
sic_10_companies_dtp <- dtp |> 
                count(SICCode.SicText_1) |>
                filter(n >= 10) |>
                select(SICCode.SicText_1)

dtp |>
  select(CompanyNumber, SICCode.SicText_1, SICCode.SicText_2, SICCode.SicText_3, SICCode.SicText_4) |> 
  inner_join(sic_10_companies_dtp, by="SICCode.SicText_1") |>
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

saveRDS(results, "benchmarks/results/dtplyr.rds")
