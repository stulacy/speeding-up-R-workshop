library(tidytable)
library(lubridate)
library(stringr)
library(tictoc)

tic()
df <- fread("BasicCompanyDataAsOneFile-2023-05-01.csv") |>
  mutate(IncorporationDate = as_date(IncorporationDate, format="%d/%m/%Y"))
time_read <- toc(quiet=TRUE)


tic()
df |> 
  count(CompanyName) |> 
  filter(n > 2) |>
  nrow()
time_count <- toc(quiet=TRUE)

tic()
df |> 
  filter(RegAddress.PostTown == 'YORK') |> 
  mutate(postcode = word(RegAddress.PostCode, 1)) |>
  count(postcode) |>
  arrange(desc(n)) |>
  head(5)
time_postcode <- toc(quiet=TRUE)

tic()
sic_10_companies <- df |> 
                count(SICCode.SicText_1) |>
                filter(n >= 10) |>
                select(SICCode.SicText_1)

df |>
  select(CompanyNumber, SICCode.SicText_1, SICCode.SicText_2, SICCode.SicText_3, SICCode.SicText_4) |> 
  inner_join(sic_10_companies, by="SICCode.SicText_1") |>
  mutate(first_classification = SICCode.SicText_1) |>
  pivot_longer(c(SICCode.SicText_1, SICCode.SicText_2, SICCode.SicText_3, SICCode.SicText_4)) |>
  filter(!is.na(value)) |>
  count(CompanyNumber, first_classification) |>
  group_by(first_classification) |>
  summarise(mean_classifications = mean(n, na.rm=T)) |>
  arrange(desc(mean_classifications))
time_sic <- toc(quiet=TRUE)

results <- list(
  read=time_read$toc - time_read$tic,
  count=time_count$toc - time_count$tic,
  postcode=time_postcode$toc - time_postcode$tic,
  sic=time_sic$toc - time_sic$tic
)

saveRDS(results, "benchmarks/results/tidytable.rds")
