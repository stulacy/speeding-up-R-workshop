## Speeding up R

Slides and materials for the Research Coding Club talk given on 2023-06-28.

The slides themselves are a standalone HTML file: `slides.html`.

If you want to build the slides yourself or to follow along with the code then you can download the code onto your computer by cloning this repo:
I.e. within RStudio: File - New Project -> Version Control -> Git -> Repository URL: `https://github.com/stulacy/speeding-up-R-workshop.git`


## Building slides

You'll need to ensure you have all the required packages installed (RStudio will prompt you when opening `slides.qmd`) and have downloaded the example dataset and placed it in this directory.
The dataset contains Company House data of all companies incorporated in the UK since 1856 ([440MB archive download](http://download.companieshouse.gov.uk/en_output.html), extracts to 2.4GB).
The slides load results from pre-run benchmarks on the full dataset (to save memory), the results from running it on my laptop are included in this repo, but you can run them yourself (scripts are found in `benchmark/scripts`).

The Quarto presentation is self-contained; building it will generate the slides with all the results and takes around 10 minutes on my laptop for the first time, although it uses a cache for subsequent builds.
