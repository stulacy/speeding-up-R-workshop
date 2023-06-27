library(data.table)
library(lubridate)
library(stringr)
library(tictoc)

tic()
dt <- fread("BasicCompanyDataAsOneFile-2023-05-01.csv")
dt[, IncorporationDate := as_date(IncorporationDate, format="%d/%m/%Y") ]  # Creates a new column by *reference*
time_read <- toc(quiet=TRUE)


tic()
nrow( dt[ , .N, by=.(CompanyName) ][ N > 2 ] )
time_count <- toc(quiet=TRUE)

tic()
setorder(dt[ RegAddress.PostTown == 'YORK', .(postcode = word(RegAddress.PostCode, 1))][, .N, by=postcode], -N)[, head(.SD, 5)]
time_postcode <- toc(quiet=TRUE)

tic()
sic_10_companies_dt <- dt[, .N, by=.(SICCode.SicText_1)][ N >= 10, .(SICCode.SicText_1) ]
dt_companies_wide <- dt[ sic_10_companies_dt,
                         .(CompanyNumber, 
                           first_classification = SICCode.SicText_1,
                           SICCode.SicText_1,
                           SICCode.SicText_2,
                           SICCode.SicText_3,
                           SICCode.SicText_4),
                          on=.(SICCode.SicText_1)]
dt_companies_long <- melt(dt_companies_wide, id.vars=c('CompanyNumber', 'first_classification'))
dt_companies_mean <- dt_companies_long[ value != '', .N, by=.(CompanyNumber, first_classification)][, .(mean_classifications = mean(N, na.rm=T)), by=.(first_classification)]
dt_companies_mean[ order(mean_classifications, decreasing = TRUE)]
time_sic <- toc(quiet=TRUE)

results <- list(
  read=time_read$toc - time_read$tic,
  count=time_count$toc - time_count$tic,
  postcode=time_postcode$toc - time_postcode$tic,
  sic=time_sic$toc - time_sic$tic
)

saveRDS(results, "benchmarks/results/datatable.rds")
