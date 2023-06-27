---
title: "Speeding up R"
date: "2023-06-28"
author: "Stuart Lacy"
execute: 
  cache: true
  keep-md: true
format: 
  revealjs:
    smaller: false
    slide-number: c/t
    show-slide-number: all
    scrollable: true
    theme: default
    navigation-mode: linear
    width: 1280
    height: 700
---



## Introduction

  - Focus on techniques for speeding up analysis of tabular data
  - Subjects:
    - Vectorization
    - Joins
    - `Rcpp`
    - `data.table`
    - Alternative backends
  

::: {.cell hash='slides_cache/revealjs/setup_c692544b88c50c5b21c686f1485c8bc1'}

:::

::: {.cell hash='slides_cache/revealjs/pprint_e70f75c8480610540ac388eb6c505a83'}

:::


    
# Vectorization

## Vectorization Concept

  > For loops in R are slow - many StackOverflow posts
  
  - In general, if you're using a `for` loop (or a `sapply` variant), then your code could be sped up by using a `vectorised` function
  - Definition: `f(x[i]) = f(x)[i]` for $i \in 1, ..., N$
  
. . .

  - `sqrt(c(4, 9, 16)) = 2, 3, 4`, therefore `sqrt` is vectorised
  - Using vectorised functions often results in **cleaner code** with less chance for bugs
  - There are a lot of vectorised functions available in the standard library
  
## Standard library vectorised functions {.smaller}


::: {.cell hash='slides_cache/revealjs/df-creation_8ec57ef65c8a12154770a9915e6812cb'}

:::


:::: {.columns}

::: {.column width="50%"}

  - Non-vectorised

```r
for (i in 1:nrow(df)) {
  # New column based on 2 others
  if (df$x[i] > 5 && df$y[i] < 0) {
    df$y[i] <- 5
  } else {
    df$y[i] <- 0
  }
  
  # Replace NAs with error code
  if (is.na(df$z[i])) {
    df$z[i] <- 9999 
  }
  
  # String concatenate columns
  df$xy[i] <- paste(df$x[i], df$y[i], sep="_")
}
  
# Distance between every row
dists <- matrix(nrow=nrow(df), ncol=nrow(df))
for (i in 1:nrow(df)) {
  for (j in 1:nrow(df)) {
    if (j != i) {
      dists[i, j] <- sqrt((df$x[i] - df$x[j])**2 + (df$y[i] - df$y[j])**2)
    }
  }
}
```

:::

::: {.column width="50%"}

  - Vectorised

```r

# New column based on 2 others
df$y <- ifelse(df$x > 5 & df$y < 0, 5, 0)





# Replace NAs with error code
df$z[is.na(df$z)] <- 9999



# Concatenate columns
df$xy <- paste(df$x, df$y, sep="_")


# Distance between every row
dist(df[, c('x', 'y')])
```

:::

::::

## Worked example

  - Example taken from [Jim Hester's blog post](https://www.jimhester.com/post/2018-04-12-vectorize/)
  
  > Given a path some/path/abc/001.txt, create a fast function to return abc_001.txt
  
. . .
  
  - First attempt works on a single path at a time, separating it by `/` and concatenating the last directory and filename
  - Doesn't work for a vector input, is there an easy way to vectorise it?
  

::: {.cell hash='slides_cache/revealjs/string-1_7920124f2b1c52f749d9f5cf1692218a'}

```{.r .cell-code}
example_1 <- function(path) {
  path_list <- str_split(path, "/") %>% unlist()
  paste(path_list[length(path_list) - 1], path_list[length(path_list)], sep = "_")
}
example_1(c("foo/bar/car/001.txt", "har/far/lar/002.txt"))
```

::: {.cell-output .cell-output-stdout}
```
[1] "lar_002.txt"
```
:::
:::


## Version 1 - `Vectorize`

  - `Vectorize` takes a function that works on a single element, and returns a vectorised version - job done!

. . .

  - However, it just uses `apply` under the hood and **isn't quicker**, mostly just syntatical sugar


::: {.cell hash='slides_cache/revealjs/string-1-vec_82c0c0b15559b4d51015b6e9ebd7355e'}

```{.r .cell-code}
example_1_vectorised <- Vectorize(example_1)  # This returns a *function*
example_1_vectorised(c("foo/bar/car/001.txt", "har/far/lar/002.txt"))
```

::: {.cell-output .cell-output-stdout}
```
foo/bar/car/001.txt har/far/lar/002.txt 
      "car_001.txt"       "lar_002.txt" 
```
:::
:::


## Version 2

  - Want to replace this implicit for loop with inbuilt vectorised functions
  - ✅ `str_split` is vectorised, returning a list over the input entries
  - ✅ `paste` is also vectorised
  - ❌ Need to use a for loop (`sapply`) to grab the last dir and filename from each entry
  - Overall have reduced the computation done inside the for loop


::: {.cell hash='slides_cache/revealjs/string-2_d816ef7920027d8b9489b507edff7cc3'}

```{.r .cell-code}
example_2 <- function(paths) {
  path_list <- str_split(paths, "/")
  last_two <- sapply(path_list, tail, 2)
  paste(last_two[1, ], last_two[2, ], sep="_")
}
example_2(c("foo/bar/car/001.txt", "har/far/lar/002.txt"))
```

::: {.cell-output .cell-output-stdout}
```
[1] "car_001.txt" "lar_002.txt"
```
:::
:::


## Version 3

  - We can't directly replace this for loop with a single vectorised function, have to take another approach
  - `dirname('foo/bar/dog.txt') = foo/bar`
  - `basename('foo/bar/dog.txt') = dog.txt`
  - Combining these can give us our entire functionality in 4 inbuilt vectorised function calls!


::: {.cell hash='slides_cache/revealjs/string-3_1f4e44e776f48cff5fd5dee6ebad07ac'}

```{.r .cell-code}
example_3 <- function(paths) {
  paste(basename(dirname(paths)), basename(paths), sep="_")
}
example_3(c("foo/bar/car/001.txt", "har/far/lar/002.txt"))
```

::: {.cell-output .cell-output-stdout}
```
[1] "car_001.txt" "lar_002.txt"
```
:::
:::


## Comparison

  - The `microbenchmark` library makes it easy to time snippets of code
  - The `Vectorize` version isn't doing anything different from manually looping through with `sapply`


::: {.cell hash='slides_cache/revealjs/string-comp_347f8de9499fc41d71d83f46ee33390b'}

```{.r .cell-code}
library(microbenchmark)
# Construct 100 paths
paths <- rep(c("some/path/abc/001.txt", "another/directory/xyz/002.txt"), 100)

res <- microbenchmark(
  example_1_vectorised(paths),
  sapply(paths, example_1),
  example_2(paths),
  example_3(paths)
)

summary(res)[c("expr", "median")]
```

::: {.cell-output .cell-output-stdout}
```
                         expr   median
1 example_1_vectorised(paths) 6207.758
2    sapply(paths, example_1) 6086.460
3            example_2(paths) 1078.590
4            example_3(paths)  107.691
```
:::
:::


## Conclusions {.smaller}

  > In general, if you're using a `for` loop (or a `sapply` variant), then your code could be sped up by using a `vectorised` function - Me (7 slides ago)

  - This wasn't fully correct, as vectorised functions can have for loops under the hood and will thus still be slow
  - The difference between a vectorised function built using `Vectorize` or an inbuilt function like `basename` is that the latter will have a for loop, **but it will be written in C/C++ rather than R**
  
. . .
  
  > In general, if you're using a `for` loop (or a `sapply` variant), then your code could be sped up by using a for loop written in C/C++, preferably part of the standard library - Me (now)
  
  - Later on will demonstrate how to write our own C++ functions

# DataFrames & Joining

## Basic DataFrame operations {.smaller}

  - Fortunately working with `data.frame`s and the `tidyverse` core verbs pushes you towards using vectorised functions
  - `group_by() |> summarise()` is both quicker and more legible than manually looping over the groups and combining the results
  - `filter(f(x))` assumes that `f()` is vectorised and returns a boolean `TRUE/FALSE` for every row
  - `mutate(newcol=f(oldcol))` assumes `f()` is vectorised and returns a value per row

. . .

  - **Caution**, can run into errors or unexpected behaviour if not using vectorised functions

:::: {.columns}

::: {.column width="50%"}
  

::: {.cell hash='slides_cache/revealjs/string-error_2de242efc670815476ea594e475d9564'}

```{.r .cell-code}
# Non-vectorised version didn't Error, 
# but gave an unexpected result
data.frame(path=paths) |>
  mutate(path_clean1 = example_1(path),
         path_clean2 = example_3(path)) |>
  head()
```

::: {.cell-output .cell-output-stdout}
```
                           path path_clean1 path_clean2
1         some/path/abc/001.txt xyz_002.txt abc_001.txt
2 another/directory/xyz/002.txt xyz_002.txt xyz_002.txt
3         some/path/abc/001.txt xyz_002.txt abc_001.txt
4 another/directory/xyz/002.txt xyz_002.txt xyz_002.txt
5         some/path/abc/001.txt xyz_002.txt abc_001.txt
6 another/directory/xyz/002.txt xyz_002.txt xyz_002.txt
```
:::
:::


:::

::: {.column width="50%"}


::: {.cell hash='slides_cache/revealjs/string-ifelse_5374e799d3911bcca5a2d82140022768'}

```{.r .cell-code}
# This function isn't vectorised due to the if/else statement
# Solution: Use ifelse() instead
replace_both_NA_9999 <- function(x, y) {
  if (is.na(x) && is.na(y)) {
    return(9999)
  } else {
    return(0)
  }
}

data.frame(a=c(5, 3, NA, 2, NA), 
           b=c(NA, 2, NA, 1, 9)) |>
  mutate(c = replace_both_NA_9999(a, b))
```

::: {.cell-output .cell-output-error}
```
Error in `mutate()`:
ℹ In argument: `c = replace_both_NA_9999(a, b)`.
Caused by error in `is.na(x) && is.na(y)`:
! 'length = 5' in coercion to 'logical(1)'
```
:::
:::


:::

::::

## Joining {.smaller}

  - Linking 2 datasets together using the `join` family of functions is an integral part of data analysis
  - However, `join` functions are highly efficient functions and can be useful in a number of siutations, even when we don't have 2 separate datasets
  - `inner_join` links two dataframes together based on a column in common, with the number of rows equal to the number of rows in the 'left' table that have a matching row in the 'right' table
  

::: {.cell hash='slides_cache/revealjs/join-setup_f3f4ab57dc4ab33cad1b04972d1c0555'}

:::


:::: {.columns}

::: {.column width="30%"}


::: {.cell hash='slides_cache/revealjs/join-display_b1f1ca78e852a5c648e7b900d75fbe1c'}
::: {.cell-output-display}

`````{=html}
<table class="table" style="font-size: 18px; margin-left: auto; margin-right: auto;">
<caption style="font-size: initial !important;">df_1: Rows 1 - 3 out of 3</caption>
 <thead>
  <tr>
   <th style="text-align:left;"> group </th>
   <th style="text-align:right;"> value1 </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> a </td>
   <td style="text-align:right;"> 1 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> b </td>
   <td style="text-align:right;"> 2 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> c </td>
   <td style="text-align:right;"> 3 </td>
  </tr>
</tbody>
</table>

`````

:::
:::



::: 

::: {.column width="30%"}


::: {.cell hash='slides_cache/revealjs/join-display-2_3cd0e335e1018796e33a3aa082284381'}
::: {.cell-output-display}

`````{=html}
<table class="table" style="font-size: 18px; margin-left: auto; margin-right: auto;">
<caption style="font-size: initial !important;">df_2: Rows 1 - 3 out of 3</caption>
 <thead>
  <tr>
   <th style="text-align:left;"> group </th>
   <th style="text-align:right;"> value2 </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> b </td>
   <td style="text-align:right;"> 4 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> c </td>
   <td style="text-align:right;"> 5 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> d </td>
   <td style="text-align:right;"> 6 </td>
  </tr>
</tbody>
</table>

`````

:::
:::


:::

::: {.column width="40%"}


::: {.cell hash='slides_cache/revealjs/join-display-3_9450ce021707eefaa62379557ca4205b'}

```{.r .cell-code}
joined <- df_1 |> inner_join(df_2, by="group")
```
:::

::: {.cell hash='slides_cache/revealjs/join-display-4_fdabf00e61248d6234256d99084afefc'}
::: {.cell-output-display}

`````{=html}
<table class="table" style="font-size: 18px; margin-left: auto; margin-right: auto;">
<caption style="font-size: initial !important;">joined: Rows 1 - 2 out of 2</caption>
 <thead>
  <tr>
   <th style="text-align:left;"> group </th>
   <th style="text-align:right;"> value1 </th>
   <th style="text-align:right;"> value2 </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> b </td>
   <td style="text-align:right;"> 2 </td>
   <td style="text-align:right;"> 4 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> c </td>
   <td style="text-align:right;"> 3 </td>
   <td style="text-align:right;"> 5 </td>
  </tr>
</tbody>
</table>

`````

:::
:::


:::

::::

## Example usage: inner join instead of `ifelse` {.smaller}
  
  - Can think of `inner_join` as being able to both `filter` and `mutate` new columns
  - Example: apply different per-group scaling factor to 300,000 measurements from 3 groups
  - On one joining column `join` isn't much quicker, but it's far more legible and scales well to both having more groups in the joining column, and additional joining columns

:::: {.columns}
  
::: {.column width="30%"}


::: {.cell hash='slides_cache/revealjs/join-setup-2_fc556e11cb53937edbb1a79ad710eb8f'}

:::

::: {.cell hash='slides_cache/revealjs/join-display-5_f729535ee7a426942f83d2f6b51e5120'}
::: {.cell-output-display}

`````{=html}
<table class="table" style="font-size: 15px; margin-left: auto; margin-right: auto;">
<caption style="font-size: initial !important;">df: Rows 1 - 5 out of 300000</caption>
 <thead>
  <tr>
   <th style="text-align:left;"> group </th>
   <th style="text-align:left;"> time </th>
   <th style="text-align:right;"> value </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> a </td>
   <td style="text-align:left;"> 2020-03-05 00:00:00 </td>
   <td style="text-align:right;"> 0.5987276 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> a </td>
   <td style="text-align:left;"> 2020-03-05 00:01:00 </td>
   <td style="text-align:right;"> -0.5292368 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> a </td>
   <td style="text-align:left;"> 2020-03-05 00:02:00 </td>
   <td style="text-align:right;"> 0.6289489 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> a </td>
   <td style="text-align:left;"> 2020-03-05 00:03:00 </td>
   <td style="text-align:right;"> -0.3701616 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> a </td>
   <td style="text-align:left;"> 2020-03-05 00:04:00 </td>
   <td style="text-align:right;"> 1.7871348 </td>
  </tr>
</tbody>
</table>

`````

:::
:::


:::

::: {.column width="30%"}


::: {.cell hash='slides_cache/revealjs/join-scales_f0ad6c85dc72e59908913694eeebd2e2'}

:::

::: {.cell hash='slides_cache/revealjs/join-scales-2_1b3678666cc420103c7d221d8152bfce'}
::: {.cell-output-display}

`````{=html}
<table class="table" style="font-size: 15px; margin-left: auto; margin-right: auto;">
<caption style="font-size: initial !important;">scales: Rows 1 - 3 out of 3</caption>
 <thead>
  <tr>
   <th style="text-align:left;"> group </th>
   <th style="text-align:right;"> scale </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> a </td>
   <td style="text-align:right;"> 2.0 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> b </td>
   <td style="text-align:right;"> 7.8 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> c </td>
   <td style="text-align:right;"> 9.0 </td>
  </tr>
</tbody>
</table>

`````

:::
:::


:::

::: {.column width="30%"}


::: {.cell hash='slides_cache/revealjs/join-scales-3_521bea5c2cbc471931bc3cb4870ee073'}

:::

::: {.cell hash='slides_cache/revealjs/join-scales-4_8bbbac3b48d36c14a35ca4aa10b68738'}
::: {.cell-output-display}

`````{=html}
<table class="table" style="font-size: 15px; margin-left: auto; margin-right: auto;">
<caption style="font-size: initial !important;">joined: Rows 1 - 5 out of 300000</caption>
 <thead>
  <tr>
   <th style="text-align:left;"> group </th>
   <th style="text-align:left;"> time </th>
   <th style="text-align:right;"> value </th>
   <th style="text-align:right;"> scale </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> a </td>
   <td style="text-align:left;"> 2020-03-05 00:00:00 </td>
   <td style="text-align:right;"> 0.5987276 </td>
   <td style="text-align:right;"> 2 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> a </td>
   <td style="text-align:left;"> 2020-03-05 00:01:00 </td>
   <td style="text-align:right;"> -0.5292368 </td>
   <td style="text-align:right;"> 2 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> a </td>
   <td style="text-align:left;"> 2020-03-05 00:02:00 </td>
   <td style="text-align:right;"> 0.6289489 </td>
   <td style="text-align:right;"> 2 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> a </td>
   <td style="text-align:left;"> 2020-03-05 00:03:00 </td>
   <td style="text-align:right;"> -0.3701616 </td>
   <td style="text-align:right;"> 2 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> a </td>
   <td style="text-align:left;"> 2020-03-05 00:04:00 </td>
   <td style="text-align:right;"> 1.7871348 </td>
   <td style="text-align:right;"> 2 </td>
  </tr>
</tbody>
</table>

`````

:::
:::


:::

::::

. . .


::: {.cell hash='slides_cache/revealjs/join-scales-comp_b726334c55145b383ee6d37f107a5439'}

```{.r .cell-code}
f_join <- function() {
  df |> inner_join(scales, by="group")
}

f_ifelse <- function() {
  df |>
    mutate(scale = ifelse(group == 'a', 2,
                          ifelse(group == 'b', 7.8,
                                 ifelse(group == 'c', 9, NA))))
  
}

res <- microbenchmark(f_join(), f_ifelse(), times=10)
summary(res)[c("expr", "median")]
```

::: {.cell-output .cell-output-stdout}
```
        expr   median
1   f_join() 18.82268
2 f_ifelse() 23.34759
```
:::
:::


## `left_join`

  - A `left_join` returns **all rows** in the left table, but only those in the right that match the condition
  - Any column from the right table that didn't have a match in the left table is filled with `NA`
  

::: {.cell hash='slides_cache/revealjs/join-inner-1_f55966afd3f724885a334a4d09ad4c4a'}

:::

  
:::: {.columns}

::: {.column width="15%"}
  

::: {.cell hash='slides_cache/revealjs/join-left-1_576b2fa35c75a307ec4d90e5c63578a7'}

```{.r .cell-code}
df1
```

::: {.cell-output .cell-output-stdout}
```
  group val1
1     a    1
2     b    2
3     c    3
4     d    4
```
:::
:::


:::

::: {.column width="15%"}


::: {.cell hash='slides_cache/revealjs/join-left-2_d1630d039f3edab51b6940691bd2cabf'}

```{.r .cell-code}
df2
```

::: {.cell-output .cell-output-stdout}
```
  group val2
1     a    1
2     b    4
3     c    9
```
:::
:::


:::

::: {.column width="35%"}


::: {.cell hash='slides_cache/revealjs/join-left-3_7349fd02b26b9e4967c12843338bc31b'}

```{.r .cell-code}
df1 |> 
  left_join(df2, by="group")
```

::: {.cell-output .cell-output-stdout}
```
  group val1 val2
1     a    1    1
2     b    2    4
3     c    3    9
4     d    4   NA
```
:::
:::


:::

::: {.column width="35%"}


::: {.cell hash='slides_cache/revealjs/join-left-4_73931d226d7959c93443e16d2f549b27'}

```{.r .cell-code}
df1 |> 
  inner_join(df2, by="group")
```

::: {.cell-output .cell-output-stdout}
```
  group val1 val2
1     a    1    1
2     b    2    4
3     c    3    9
```
:::
:::


:::

::::

## Example usage: filling gaps with `left_join`

  - Very useful if want to be aware of missing values
  - Useful for filling gaps in non-uniformly sampled time-series so can count missingness or interpolate

:::: {.columns}

::: {.column width="30%"}


::: {.cell hash='slides_cache/revealjs/join-left-5_6126a702e01c7035dce1d4b753549a2d'}

:::

::: {.cell hash='slides_cache/revealjs/join-left-6_d31e65671f47e742bae857bd6ac21b41'}

```{.r .cell-code}
df
```

::: {.cell-output .cell-output-stdout}
```
        date measurement
1 2020-01-01  0.22433188
2 2020-01-03  0.24482316
3 2020-01-05 -0.08055568
```
:::
:::


:::

::: {.column width="20%"}


::: {.cell hash='slides_cache/revealjs/join-left-7_45da68ccd507a1fe713c0816139b6b2b'}

:::

::: {.cell hash='slides_cache/revealjs/join-left-8_b0bc63c92820cab3a3b0c86c98093eed'}

```{.r .cell-code}
all_times
```

::: {.cell-output .cell-output-stdout}
```
        date
1 2020-01-01
2 2020-01-02
3 2020-01-03
4 2020-01-04
5 2020-01-05
```
:::
:::


:::

::: {.column width="50%"}


::: {.cell hash='slides_cache/revealjs/join-left-9_4371eae0a32ca59150595332514540de'}

```{.r .cell-code}
all_times |> left_join(df, by="date")
```

::: {.cell-output .cell-output-stdout}
```
        date measurement
1 2020-01-01  0.22433188
2 2020-01-02          NA
3 2020-01-03  0.24482316
4 2020-01-04          NA
5 2020-01-05 -0.08055568
```
:::
:::


:::

::::

## Interval joins {.smaller}

  - Joins aren't limited to joining on equal values, can also join on **intervals** or **closest value**
  - Example: Have measurements from every day in 2020, but want to limit analysis to 5 specific weeks
  

::: {.cell hash='slides_cache/revealjs/join-intervals-1_fb538d0d964181acd721fcb903777c70'}

:::


:::: {.columns}

::: {.column width="20%"}


::: {.cell hash='slides_cache/revealjs/join-intervals-2_d2db5c820260263fbd2181b2f836631d'}
::: {.cell-output-display}

`````{=html}
<table class="table" style="font-size: 15px; margin-left: auto; margin-right: auto;">
<caption style="font-size: initial !important;">df_interval: Rows 1 - 10 out of 366</caption>
 <thead>
  <tr>
   <th style="text-align:left;"> time </th>
   <th style="text-align:right;"> measurement </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> 2020-01-01 </td>
   <td style="text-align:right;"> -0.6576604 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> 2020-01-02 </td>
   <td style="text-align:right;"> 1.4838342 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> 2020-01-03 </td>
   <td style="text-align:right;"> 1.3895139 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> 2020-01-04 </td>
   <td style="text-align:right;"> -0.1295129 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> 2020-01-05 </td>
   <td style="text-align:right;"> 1.0107976 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> 2020-01-06 </td>
   <td style="text-align:right;"> -1.4932955 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> 2020-01-07 </td>
   <td style="text-align:right;"> -0.2289131 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> 2020-01-08 </td>
   <td style="text-align:right;"> 0.6771906 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> 2020-01-09 </td>
   <td style="text-align:right;"> 1.0269499 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> 2020-01-10 </td>
   <td style="text-align:right;"> -0.5570999 </td>
  </tr>
</tbody>
</table>

`````

:::
:::


:::

::: {.column width="25%"}


::: {.cell hash='slides_cache/revealjs/join-intervals-3_e226bde143ddbbb9eceb1ba2f99d6d1a'}
::: {.cell-output-display}

`````{=html}
<table class="table" style="font-size: 15px; margin-left: auto; margin-right: auto;">
<caption style="font-size: initial !important;">weeks: Rows 1 - 5 out of 5</caption>
 <thead>
  <tr>
   <th style="text-align:left;"> week_group </th>
   <th style="text-align:left;"> week_start </th>
   <th style="text-align:left;"> week_end </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> a </td>
   <td style="text-align:left;"> 2020-02-14 </td>
   <td style="text-align:left;"> 2020-02-21 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> b </td>
   <td style="text-align:left;"> 2020-03-17 </td>
   <td style="text-align:left;"> 2020-03-24 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> c </td>
   <td style="text-align:left;"> 2020-05-08 </td>
   <td style="text-align:left;"> 2020-05-15 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> d </td>
   <td style="text-align:left;"> 2020-09-20 </td>
   <td style="text-align:left;"> 2020-09-27 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> e </td>
   <td style="text-align:left;"> 2020-11-13 </td>
   <td style="text-align:left;"> 2020-11-20 </td>
  </tr>
</tbody>
</table>

`````

:::
:::


:::

::: {.column width="50%"}


::: {.cell hash='slides_cache/revealjs/join-intervals-4_f6380cad96ad8ff56f8278008108cb8d'}

```{.r .cell-code}
joined <- df_interval |>
  inner_join(weeks, 
             by=join_by(time >= week_start, time < week_end))
```
:::

::: {.cell hash='slides_cache/revealjs/join-intervals-5_8b4fc879acca9daa7165341c3214306a'}
::: {.cell-output-display}

`````{=html}
<table class="table" style="font-size: 15px; margin-left: auto; margin-right: auto;">
<caption style="font-size: initial !important;">joined: Rows 1 - 10 out of 35</caption>
 <thead>
  <tr>
   <th style="text-align:left;"> time </th>
   <th style="text-align:right;"> measurement </th>
   <th style="text-align:left;"> week_group </th>
   <th style="text-align:left;"> week_start </th>
   <th style="text-align:left;"> week_end </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> 2020-02-14 </td>
   <td style="text-align:right;"> -0.5619612 </td>
   <td style="text-align:left;"> a </td>
   <td style="text-align:left;"> 2020-02-14 </td>
   <td style="text-align:left;"> 2020-02-21 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> 2020-02-15 </td>
   <td style="text-align:right;"> -0.2133952 </td>
   <td style="text-align:left;"> a </td>
   <td style="text-align:left;"> 2020-02-14 </td>
   <td style="text-align:left;"> 2020-02-21 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> 2020-02-16 </td>
   <td style="text-align:right;"> 1.7400116 </td>
   <td style="text-align:left;"> a </td>
   <td style="text-align:left;"> 2020-02-14 </td>
   <td style="text-align:left;"> 2020-02-21 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> 2020-02-17 </td>
   <td style="text-align:right;"> -1.0639221 </td>
   <td style="text-align:left;"> a </td>
   <td style="text-align:left;"> 2020-02-14 </td>
   <td style="text-align:left;"> 2020-02-21 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> 2020-02-18 </td>
   <td style="text-align:right;"> -1.9508774 </td>
   <td style="text-align:left;"> a </td>
   <td style="text-align:left;"> 2020-02-14 </td>
   <td style="text-align:left;"> 2020-02-21 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> 2020-02-19 </td>
   <td style="text-align:right;"> 1.2910768 </td>
   <td style="text-align:left;"> a </td>
   <td style="text-align:left;"> 2020-02-14 </td>
   <td style="text-align:left;"> 2020-02-21 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> 2020-02-20 </td>
   <td style="text-align:right;"> -0.5042165 </td>
   <td style="text-align:left;"> a </td>
   <td style="text-align:left;"> 2020-02-14 </td>
   <td style="text-align:left;"> 2020-02-21 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> 2020-03-17 </td>
   <td style="text-align:right;"> 1.3886904 </td>
   <td style="text-align:left;"> b </td>
   <td style="text-align:left;"> 2020-03-17 </td>
   <td style="text-align:left;"> 2020-03-24 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> 2020-03-18 </td>
   <td style="text-align:right;"> 0.3820922 </td>
   <td style="text-align:left;"> b </td>
   <td style="text-align:left;"> 2020-03-17 </td>
   <td style="text-align:left;"> 2020-03-24 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> 2020-03-19 </td>
   <td style="text-align:right;"> 0.6009245 </td>
   <td style="text-align:left;"> b </td>
   <td style="text-align:left;"> 2020-03-17 </td>
   <td style="text-align:left;"> 2020-03-24 </td>
  </tr>
</tbody>
</table>

`````

:::
:::


:::

::::

## Benchmark {.smaller}

  - On only 366 rows with 5 groups it is 10x as fast, will scale better, and is more understandable


::: {.cell hash='slides_cache/revealjs/join-intervals-6_284cb8aef8e5dfafbb98a9251909858f'}

```{.r .cell-code}
f_intervaljoin <- function() {
  df_interval |>
    inner_join(weeks, by=join_by(time >= week_start, time < week_end))
}

f_ifelse <- function() {
  df_interval |>
    mutate(week_group = ifelse(time >= as_date("2020-02-14") & time < as_date("2020-02-21"),
                               'a',
                               ifelse(time >= as_date("2020-03-17") & time < as_date("2020-03-24"),
                                      'b',
                                      ifelse(time >= as_date("2020-05-08") & time < as_date("2020-05-15"),
                                             'c',
                                             ifelse(time >= as_date("2020-09-20") & time < as_date("2020-09-27"),
                                                    'd',
                                                    ifelse(time >= as_date("2020-11-13") & time < as_date("2020-11-20"),
                                                           'e', 
                                                           NA)))))) |>
    filter(!is.na(week_group))
}

res <- microbenchmark(f_intervaljoin(), f_ifelse(), times=10)
summary(res)[c("expr", "median")]
```

::: {.cell-output .cell-output-stdout}
```
              expr    median
1 f_intervaljoin()  1.645427
2       f_ifelse() 20.924986
```
:::
:::


# Different backends

## Example dataset {.smaller}

  - What if we're using fast functions but still experiencing slow performance due to dataset's *size*?
  - Example dataset: Company House data containing 5 million rows ([440MB archive download](http://download.companieshouse.gov.uk/en_output.html), extracts to 2.4GB) of all companies incorporated in the UK since 1856
  - Using first million rows as an example
  

::: {.cell hash='slides_cache/revealjs/company-house-1_726d7113ca9289eda84278dd3efe5538'}

```{.r .cell-code}
df <- read_csv("BasicCompanyDataAsOneFile-2023-05-01.csv", n_max=1e6, show_col_types=FALSE)
df$IncorporationDate <- as_date(df$IncorporationDate, format="%d/%m/%Y")
dim(df)
```

::: {.cell-output .cell-output-stdout}
```
[1] 1000000      55
```
:::
:::

::: {.cell hash='slides_cache/revealjs/company-house-2_44dc0a1dc8a81cc1c445b396ab3b3850'}

```{.r .cell-code}
df |> 
  select(CompanyName, RegAddress.PostTown, IncorporationDate, SICCode.SicText_1) |>
  head()
```

::: {.cell-output .cell-output-stdout}
```
# A tibble: 6 × 4
  CompanyName            RegAddress.PostTown IncorporationDate SICCode.SicText_1
  <chr>                  <chr>               <date>            <chr>            
1 ! HEAL UR TECH LTD     GUILDFORD           2022-10-12        33140 - Repair o…
2 ! LTD                  LEEDS               2012-09-11        99999 - Dormant …
3 !? LTD                 ROMILEY             2018-06-05        47710 - Retail s…
4 !BIG IMPACT GRAPHICS … LONDON              2018-12-28        18129 - Printing…
5 !GOBERUB LTD           BISHOP'S STORTFORD  2021-05-17        62020 - Informat…
6 !NFOGENIE LTD          LONDON              2021-07-21        58290 - Other so…
```
:::
:::


## Question 1: How many companies have the same name?

  - Will use several basic research questions to have some 'real-world' analysis code to benchmark
  - How many companies have the same name?


::: {.cell hash='slides_cache/revealjs/company-house-3_83cd453d50a787ecb886bc1f11d42891'}

```{.r .cell-code}
df |> 
  count(CompanyName) |> 
  filter(n > 1) |>
  nrow()
```

::: {.cell-output .cell-output-stdout}
```
[1] 773
```
:::
:::


## Question 2: What York postcode has the most businesses?

  - Want to find the 5 postcodes with most businesses being created in York
  - Need to do some string manipulation to extract the first part of the `YOXX YYY` postcode format


::: {.cell hash='slides_cache/revealjs/company-house-4_a3833e6257aedf3e6ce9d585299f4212'}

```{.r .cell-code}
df |> 
  filter(RegAddress.PostTown == 'YORK') |> 
  mutate(postcode = word(RegAddress.PostCode, 1, sep=" ")) |>
  count(postcode) |>
  arrange(desc(n)) |>
  head(5)
```

::: {.cell-output .cell-output-stdout}
```
# A tibble: 5 × 2
  postcode     n
  <chr>    <int>
1 YO30       486
2 YO19       325
3 YO26       271
4 YO1        241
5 YO31       179
```
:::
:::


## Question 3: Classifications {.smaller}

  - Companies can be assigned with up to 4 classifications from a list of 1,042 options
  - Do classifications tend to cluster together? I.e. is the average number of classifications a company has related to the first classification?
  - Slightly tenuous example but wanted to demonstrate pivoting + joining!
  - Only want to look at classifications that are used by at least 10 companies (`inner_join` to filter)
  - Multiple classifications are stored in 4 **wide columns** that are NA when unused - easier to count the number of non-null column entries in **long** format


::: {.cell hash='slides_cache/revealjs/company-house-5_46001da6ec1d31873a7c4da0ce2b6485'}
::: {.cell-output .cell-output-stdout}
```
# A tibble: 6 × 5
  CompanyName              SICCode.SicText_1 SICCode.SicText_2 SICCode.SicText_3
  <chr>                    <chr>             <chr>             <chr>            
1 ! HEAL UR TECH LTD       33140 - Repair o… 47421 - Retail s… <NA>             
2 ! LTD                    99999 - Dormant … <NA>              <NA>             
3 !? LTD                   47710 - Retail s… <NA>              <NA>             
4 !BIG IMPACT GRAPHICS LI… 18129 - Printing… 59112 - Video pr… 63120 - Web port…
5 !GOBERUB LTD             62020 - Informat… 70229 - Manageme… 79110 - Travel a…
6 !NFOGENIE LTD            58290 - Other so… <NA>              <NA>             
# ℹ 1 more variable: SICCode.SicText_4 <chr>
```
:::
:::


## Question 3: Classifications (code) {.smaller}


::: {.cell hash='slides_cache/revealjs/company-house-8_dc73b0140510c75762b46cd9ae39cb79'}

```{.r .cell-code}
# 755 rows containing the SIC codes that at least 10 companies have
# Only 1 column, SICCode.SicText_1
sic_10_companies <- df |> 
                count(SICCode.SicText_1) |>
                filter(n >= 10) |>
                select(SICCode.SicText_1)

df |>
  # Could do a filter to restrict to these 10 companies, but it's actually quicker to use an inner join
  inner_join(sic_10_companies, by="SICCode.SicText_1") |>
  select(CompanyNumber, SICCode.SicText_1, SICCode.SicText_2, SICCode.SicText_3, SICCode.SicText_4) |> 
  mutate(first_classification = SICCode.SicText_1) |>
  # Pivoting to make it easier to count how many non-NULL classifications each company has
  pivot_longer(c(SICCode.SicText_1, SICCode.SicText_2, SICCode.SicText_3, SICCode.SicText_4)) |>
  filter(!is.na(value)) |>
  # Count how many classifications each company has
  count(CompanyNumber, first_classification) |>
  # Calculate the average number per the first classification
  group_by(first_classification) |>
  summarise(mean_classifications = mean(n, na.rm=T)) |>
  arrange(desc(mean_classifications)) |>
  head()
```

::: {.cell-output .cell-output-stdout}
```
# A tibble: 6 × 2
  first_classification                                      mean_classifications
  <chr>                                                                    <dbl>
1 7210 - Hardware consultancy                                               3   
2 07100 - Mining of iron ores                                               2.48
3 10611 - Grain milling                                                     2.43
4 18110 - Printing of newspapers                                            2.43
5 14131 - Manufacture of other men's outerwear                              2.40
6 01280 - Growing of spices, aromatic, drug and pharmaceut…                 2.39
```
:::
:::

  
# data.table

## Introduction {.smaller}

  - `data.table` is an alternative to data.frame/tibble that is optimised for speed and low memory usage
  - The trade-off is that its API is a bit/lot less user friendly


::: {.cell hash='slides_cache/revealjs/data-table-1_21aa6c81b64dc6ee6b782e6d28405ced'}

```{.r .cell-code}
library(data.table)
dt <- fread("BasicCompanyDataAsOneFile-2023-05-01.csv", nrows=1e6)         # fread is the equivalent of read.csv
dt[, IncorporationDate := as_date(IncorporationDate, format="%d/%m/%Y") ]  # Creates a new column by *reference*
dim(dt)
```

::: {.cell-output .cell-output-stdout}
```
[1] 1000000      55
```
:::
:::

::: {.cell hash='slides_cache/revealjs/data-table-2_1dccb9a90a6c53bb666082c4ef9e1af1'}

```{.r .cell-code}
# Display rows 1-5 and the specified columns
dt[1:5, .(CompanyName, RegAddress.PostTown, IncorporationDate, SICCode.SicText_1)]
```

::: {.cell-output .cell-output-stdout}
```
                    CompanyName RegAddress.PostTown IncorporationDate
1:           ! HEAL UR TECH LTD           GUILDFORD        2022-10-12
2:                        ! LTD               LEEDS        2012-09-11
3:                       !? LTD             ROMILEY        2018-06-05
4: !BIG IMPACT GRAPHICS LIMITED              LONDON        2018-12-28
5:                 !GOBERUB LTD  BISHOP'S STORTFORD        2021-05-17
                                       SICCode.SicText_1
1:                33140 - Repair of electrical equipment
2:                               99999 - Dormant Company
3: 47710 - Retail sale of clothing in specialised stores
4:                               18129 - Printing n.e.c.
5: 62020 - Information technology consultancy activities
```
:::
:::


## Counting number of companies with the same name

  - Generally, `dt[i, j, k]` means for data table `dt`, filter on rows `i`, create and/or select columns `j`, and group by `k`
  - `data.table` operations don't use the Pipe (`|>` or `%>%`), so can either chain together `[]` or create intermediate variables
  - `data.table` have `data.frame` as a class so can use standard functions on them, just won't benefit from the speed up
  - `.N` is the equivalent of `count`


::: {.cell hash='slides_cache/revealjs/data-table-3_5eb15b839c060ce5afe26be6c9b55237'}

```{.r .cell-code}
nrow( dt[ , .N, by=.(CompanyName) ][ N > 1 ] )
```

::: {.cell-output .cell-output-stdout}
```
[1] 773
```
:::
:::


## York Postcodes with most business

  - In this example it's easier to create an intermediate variable than use a one-liner
  - `.SD` applies an operation to a subset of columns (all by default)


::: {.cell hash='slides_cache/revealjs/data-table-4_9b9b22146b9abe7c732d3a4fd1c5c6bb'}

```{.r .cell-code}
postcodes <- dt[ RegAddress.PostTown == 'YORK', .(postcode = word(RegAddress.PostCode, 1))][, .N, by=postcode]
postcodes[order(-postcodes$N), head(.SD, 5)]
```

::: {.cell-output .cell-output-stdout}
```
   postcode   N
1:     YO30 486
2:     YO19 325
3:     YO26 271
4:      YO1 241
5:     YO31 179
```
:::

```{.r .cell-code}
# Alternative one-liner
#setorder(dt[ RegAddress.PostTown == 'YORK', .(postcode = word(RegAddress.PostCode, 1))][, .N, by=postcode], -N)[, head(.SD, 5)]
```
:::


## Number of classifications {.smaller}

  - Joins are less intuitive. `x[y]` is equal to `left_join(y, x)`, **NOT** `inner_join(x, y)`
  - `melt` is equivalent to `pivot_longer` and IMO less intuitive
  - Intermdiate variables everywhere!


::: {.cell hash='slides_cache/revealjs/data-table-5_66d7c810d2e5f5932207d67f9a7763a3'}

```{.r .cell-code}
sic_10_companies_dt <- dt[, .N, by=.(SICCode.SicText_1)][ N >= 10, .(SICCode.SicText_1) ]
dt_companies_wide <- dt[ sic_10_companies_dt,  # This is a join!
                         .(CompanyNumber, 
                           first_classification = SICCode.SicText_1,
                           SICCode.SicText_1,
                           SICCode.SicText_2,
                           SICCode.SicText_3,
                           SICCode.SicText_4),
                          on=.(SICCode.SicText_1)]
dt_companies_long <- melt(dt_companies_wide, id.vars=c('CompanyNumber', 'first_classification'))
dt_companies_mean <- dt_companies_long[ value != '',  # Removes the unused SIC columns
                                        .N, 
                                        by=.(CompanyNumber, first_classification)][, 
                                                                                   .(mean_classifications = mean(N, na.rm=T)), 
                                                                                   by=.(first_classification)]
head(dt_companies_mean[ order(mean_classifications, decreasing = TRUE)])
```

::: {.cell-output .cell-output-stdout}
```
                                                 first_classification
1:                                        7210 - Hardware consultancy
2:                                        07100 - Mining of iron ores
3:                                     18110 - Printing of newspapers
4:                                              10611 - Grain milling
5:                       14131 - Manufacture of other men's outerwear
6: 01280 - Growing of spices, aromatic, drug and pharmaceutical crops
   mean_classifications
1:             3.000000
2:             2.478261
3:             2.428571
4:             2.428571
5:             2.401606
6:             2.392157
```
:::
:::


## Speed comparison with tidyverse


::: {.cell hash='slides_cache/revealjs/data-table-6_9943235b163e225e32e4fd065e997628'}

:::

::: {.cell hash='slides_cache/revealjs/data-table-comparison-benchmark_68986427a11570d1a35766f9b3c7598a'}

:::

::: {.cell hash='slides_cache/revealjs/data-table-comparison-results_e48dfc90a357548e9ac6c7b99ca64cb9'}
::: {.cell-output-display}
![](slides_files/figure-revealjs/data-table-comparison-results-1.png){width=960}
:::
:::


# `tidytable` and `dtplyr`

## `tidytable`: introduction {.smaller}

:::: {.columns}

::: {.column width="40%"}

  - `tidytable` is a drop-in replacement for common tidyverse functions that under the hood work on a `data.table` object
  - So (in theory!) you get the speed of `data.table` but the user friendly API of the `tidyverse`
  - Just load the library then all subsequent calls to `mutate`, `inner_join`, `count`, `select`, `filter` etc... will use the `tidytable` versions that work on a `data.table`
  - **Beware**: not all functions have been ported over and it explicitly overwrites the `dplyr`, `tidyr`, `purrr` functions
  - There's a lag between changes to `tidyverse` being reflected in `tidytable`
  
:::
  
::: {.column width="60%"}

```{.r}
library(tidytable)
# Here we explicitly create tidytable from a regular data.frame
# But passing a regular data.frame or data.table into any tidytable function
# will implicitly change it to be a tidytable object
dtt <- as_tidytable(df)

dtt |> 
    count(SICCode.SicText_1) |>
    filter(n >= 10) |>
    select(SICCode.SicText_1) 
```


::: {.cell hash='slides_cache/revealjs/unnamed-chunk-1_7bb53bafc5911ba8217ab1fa28b173a7'}
::: {.cell-output .cell-output-stdout}
```
# A tidytable: 755 × 1
   SICCode.SicText_1                                                       
   <chr>                                                                   
 1 01110 - Growing of cereals (except rice), leguminous crops and oil seeds
 2 01120 - Growing of rice                                                 
 3 01130 - Growing of vegetables and melons, roots and tubers              
 4 01160 - Growing of fibre crops                                          
 5 01190 - Growing of other non-perennial crops                            
 6 01210 - Growing of grapes                                               
 7 01220 - Growing of tropical and subtropical fruits                      
 8 01240 - Growing of pome fruits and stone fruits                         
 9 01250 - Growing of other tree and bush fruits and nuts                  
10 01270 - Growing of beverage crops                                       
# ℹ 745 more rows
```
:::
:::

::: {.cell hash='slides_cache/revealjs/tidytable-1-hidden_7e17f0722fd4789aba28b493b99f9de5'}

:::


:::

::::
  
## `dtplyr`: introduction {.smaller}

:::: {.columns}

::: {.column width="40%"}

  - An alternative `data.table` wrapper is `dtplyr` (developed by RStudio team)
  - Works differently to `tidytable`: it sequentially builds up the equivalent `data.table` query, but only executes the code when you **explicitly** request it (using `collect()` or `as.data.frame/table()`)
  - Loading the package **doesn't** affect your environment
  - Has less coverage than `tidytable`
  
:::

::: {.column width="60%"}
  

::: {.cell hash='slides_cache/revealjs/dtplyr-1_0ca5683774109b69085f552219ca65ed'}

```{.r .cell-code}
library(dtplyr)

# dtplyr operates on `lazy data.tables` which are only created by this function
dtp <- lazy_dt(df)

dtp |> 
    count(SICCode.SicText_1) |>
    filter(n >= 10) |>
    select(SICCode.SicText_1) 
```

::: {.cell-output .cell-output-stdout}
```
Source: local data table [755 x 1]
Call:   `_DT1`[, .(n = .N), keyby = .(SICCode.SicText_1)][n >= 10, .(SICCode.SicText_1)]

  SICCode.SicText_1                                                       
  <chr>                                                                   
1 01110 - Growing of cereals (except rice), leguminous crops and oil seeds
2 01120 - Growing of rice                                                 
3 01130 - Growing of vegetables and melons, roots and tubers              
4 01160 - Growing of fibre crops                                          
5 01190 - Growing of other non-perennial crops                            
6 01210 - Growing of grapes                                               
# ℹ 749 more rows

# Use as.data.table()/as.data.frame()/as_tibble() to access results
```
:::
:::


:::

::::

## `dtplyr`: usage {.smaller}

:::: {.columns}

::: {.column width="45%"}

  - Can view the generated `data.table` query (subtly different to the one I manually wrote)


::: {.cell hash='slides_cache/revealjs/dtplyr-2_7b4b188a6bf8edac57309d005102966d'}

```{.r .cell-code}
dtp |> 
    count(SICCode.SicText_1) |>
    filter(n >= 10) |>
    select(SICCode.SicText_1) |>
    show_query()
```

::: {.cell-output .cell-output-stdout}
```
`_DT1`[, .(n = .N), keyby = .(SICCode.SicText_1)][n >= 10, .(SICCode.SicText_1)]
```
:::
:::


:::

::: {.column width="45%"}

  - Run `collect()` to execute it and return a `tibble`


::: {.cell hash='slides_cache/revealjs/dtplyr-3_5c63101be893ce574b51f19f765973e7'}

```{.r .cell-code}
dtp |> 
    count(SICCode.SicText_1) |>
    filter(n >= 10) |>
    select(SICCode.SicText_1) |>
    collect() |> 
    head()
```

::: {.cell-output .cell-output-stdout}
```
# A tibble: 6 × 1
  SICCode.SicText_1                                                       
  <chr>                                                                   
1 01110 - Growing of cereals (except rice), leguminous crops and oil seeds
2 01120 - Growing of rice                                                 
3 01130 - Growing of vegetables and melons, roots and tubers              
4 01160 - Growing of fibre crops                                          
5 01190 - Growing of other non-perennial crops                            
6 01210 - Growing of grapes                                               
```
:::
:::


:::

::::

## `dtplyr`: chaining queries {.smaller}

  - `dtplyr` queries that haven't been `collect()` can be used in joins 


::: {.cell hash='slides_cache/revealjs/dtplyr-4_5bc1714a7abb02d6fe20fc91204e4979'}

```{.r .cell-code}
# NB: this returns a datatable QUERY, not a dataset itself
sic_10_companies_dtp <- dtp |> 
    count(SICCode.SicText_1) |>
    filter(n >= 10) |>
    select(SICCode.SicText_1) 

# Can join that query into the middle of another query to return another query
results_dtp <- dtp |>
  inner_join(sic_10_companies_dtp, by="SICCode.SicText_1") |>
  select(CompanyNumber, SICCode.SicText_1, SICCode.SicText_2, SICCode.SicText_3, SICCode.SicText_4) |> 
  mutate(first_classification = SICCode.SicText_1) |>
  pivot_longer(c(SICCode.SicText_1, SICCode.SicText_2, SICCode.SicText_3, SICCode.SicText_4)) |>
  filter(!is.na(value)) |>
  count(CompanyNumber, first_classification) |>
  group_by(first_classification) |>
  summarise(mean_classifications = mean(n, na.rm=T)) |>
  arrange(desc(mean_classifications))

# Finally execute the full query
results_dtp |>
  collect() |>
  head()
```

::: {.cell-output .cell-output-stdout}
```
# A tibble: 6 × 2
  first_classification                                      mean_classifications
  <chr>                                                                    <dbl>
1 7210 - Hardware consultancy                                               3   
2 07100 - Mining of iron ores                                               2.48
3 10611 - Grain milling                                                     2.43
4 18110 - Printing of newspapers                                            2.43
5 14131 - Manufacture of other men's outerwear                              2.40
6 01280 - Growing of spices, aromatic, drug and pharmaceut…                 2.39
```
:::
:::



## Benchmark


::: {.cell hash='slides_cache/revealjs/data-table-all-1_f655cb96d6811ca4e49429a864aeef16'}

:::

::: {.cell hash='slides_cache/revealjs/data-table-all-2_191ffc7483e198c47c63f865eea7d691'}

:::

::: {.cell hash='slides_cache/revealjs/data-table-all-plot_5628650b1fb899bab7e4d0ddae104089'}
::: {.cell-output-display}
![](slides_files/figure-revealjs/data-table-all-plot-1.png){width=960}
:::
:::


# Embedded databases

## Introduction {.smaller}

  - All these options require reading the full dataset into memory, not viable if we have **larger than memory data**
  - Embedded relational databases are stored on disk and only reading into memory as needed

. . .

  - Will look at 2 variants:
    - `SQLite`
    - `duckdb`
  - They use SQL (Structured Query Language, its own programming language) to interact with the data, but fortunately in R we can use our `tidyverse` functions just like `dtplyr` rather than learn a new language

## Interfacing with SQLite in R

  - Connect to the DB using `dbConnect()` from `library(DBI)`
  - DBs are organised into tables (can think of a table as a CSV file)
  - `dbWriteTable()` will write a dataframe to the DB
  
```{.r}
library(DBI)  # General database library
library(RSQLite)
# If data.sql doesn't exist, it will be created
con_sql <- dbConnect(SQLite(), "data.sql")
dbWriteTable(con_sql, "data_1e6", df)
```


::: {.cell hash='slides_cache/revealjs/sqlite-1_ff8b067b53fcf1ba0a5f92bfb99a24d0'}

:::


## SQLite usage {.smaller}

:::: {.columns}

::: {.column width="50%"}

  - Can view SQL query with *identical* code to `dtplyr`, except the source is from `tbl`


::: {.cell hash='slides_cache/revealjs/sqlite-2_592ee34047454122b784270881ebb619'}

```{.r .cell-code}
tbl(con_sql, "data_1e6") |> 
  filter(RegAddress.PostTown == 'YORK') |> 
  mutate(postcode = word(RegAddress.PostCode, 1)) |>
  count(postcode) |>
  arrange(desc(n)) |>
  head(50) |>
  show_query()
```

::: {.cell-output .cell-output-stdout}
```
<SQL>
SELECT `postcode`, COUNT(*) AS `n`
FROM (
  SELECT *, word(`RegAddress.PostCode`, 1.0) AS `postcode`
  FROM `data_1e6`
  WHERE (`RegAddress.PostTown` = 'YORK')
)
GROUP BY `postcode`
ORDER BY `n` DESC
LIMIT 50
```
:::
:::


:::

::: {.column width="50%"}

  - **Errors** because the developers haven't translated `word` into SQL yet, so it is translated directly but `word` isn't a function in SQL
  - Solution: use `substr` from `base` which has been translated but doesn't do exactly the same
  - This is more likely to happen the more specific and uncommon a function is


::: {.cell hash='slides_cache/revealjs/sqlite-3_e9b98dd8a951f5bcefb85b6ae7fbc6ad'}

```{.r .cell-code}
tbl(con_sql, "data_1e6") |> 
  filter(RegAddress.PostTown == 'YORK') |> 
  mutate(postcode = substr(RegAddress.PostCode, 1, 4)) |>
  count(postcode) |>
  arrange(desc(n)) |>
  head(50) |>
  collect()
```

::: {.cell-output .cell-output-stdout}
```
# A tibble: 23 × 2
   postcode     n
   <chr>    <int>
 1 "YO30"     486
 2 "YO19"     325
 3 "YO26"     271
 4 "YO1 "     241
 5 "YO31"     180
 6 "YO24"     178
 7 "YO10"     172
 8 "YO32"     169
 9 "YO23"     161
10 "YO42"     142
# ℹ 13 more rows
```
:::
:::


:::

::::

## `duckdb`: introduction

  - Designed for **fast analytics** (column-oriented) whereas SQLite is designed for **transactions** (row-oriented)
  - Very new, first demo was 2020 (SQLite first release was 2000)
  - Can read directly from CSV or has its database files like SQLite
  - Use the same `dbConnect()` function but passing in a different driver
  
```{.r}
library(duckdb)
con_dd <- dbConnect(duckdb(), "data.duckdb")
dbWriteTable(con_dd, "data_1e6", df)
```
  

::: {.cell hash='slides_cache/revealjs/duckdb-1_21f86f15fd13341d27bd10a95461b7c8'}

:::


## `duckdb`: usage {.smaller}

:::: {.columns}

::: {.column width="50%"}

  - Duckdb uses the same SQL language, albeit with subtle differences in available functions


::: {.cell hash='slides_cache/revealjs/duckdb-2_39c697a4e146d7f94574fdd7180e750f'}

```{.r .cell-code}
tbl(con_dd, "data_1e6") |> 
  filter(RegAddress.PostTown == 'YORK') |> 
  mutate(postcode = substr(RegAddress.PostCode, 1, 4)) |>
  count(postcode) |>
  arrange(desc(n)) |>
  head(50) |>
  show_query()
```

::: {.cell-output .cell-output-stdout}
```
<SQL>
SELECT postcode, COUNT(*) AS n
FROM (
  SELECT *, SUBSTR("RegAddress.PostCode", 1, 4) AS postcode
  FROM data_1e6
  WHERE ("RegAddress.PostTown" = 'YORK')
) q01
GROUP BY postcode
ORDER BY n DESC
LIMIT 50
```
:::
:::


:::

::: {.column width="50%"}

  - `word` is also not ported to duckdb so again use the `substr` version
  - Code is again identical to both `SQLite` and `dtplyr`
  

::: {.cell hash='slides_cache/revealjs/duckdb-3_1ba81f2a4e1746b5e0494c2e263cd3ff'}

```{.r .cell-code}
tbl(con_dd, "data_1e6") |> 
  filter(RegAddress.PostTown == 'YORK') |> 
  mutate(postcode = substr(RegAddress.PostCode, 1, 4)) |>
  count(postcode) |>
  arrange(desc(n)) |>
  head(50) |>
  collect()
```

::: {.cell-output .cell-output-stdout}
```
# A tibble: 23 × 2
   postcode     n
   <chr>    <dbl>
 1 "YO30"     486
 2 "YO19"     325
 3 "YO26"     271
 4 "YO1 "     241
 5 "YO31"     180
 6 "YO24"     178
 7 "YO10"     172
 8 "YO32"     169
 9 "YO23"     161
10 "YO42"     142
# ℹ 13 more rows
```
:::
:::


:::

::::


## Overall benchmark {.smaller}


::: {.cell hash='slides_cache/revealjs/db-comparison-1_ca89b3a62a0da6e24525f7e5a9588650'}

:::

::: {.cell hash='slides_cache/revealjs/db-comparison-2_690c5d9ab57ec00ad1e333943e58839e'}

:::

::: {.cell hash='slides_cache/revealjs/db-comparison-3_a58dfe776fce29e734b709d7fa851383'}

:::


:::: {.columns}

::: {.column width="60%"}


::: {.cell hash='slides_cache/revealjs/unnamed-chunk-2_51238d92a9290b2e07940d70bc8bd237'}

:::

::: {.cell hash='slides_cache/revealjs/db-comparison-4_3ebac547fe941f54c16fff8ae0946482'}
::: {.cell-output-display}
![](slides_files/figure-revealjs/db-comparison-4-1.png){width=960}
:::
:::


:::

::: {.column width="40%"}

  - `data.table` is the fastest! But it requires learning a new 'language'
  - All of the other options are still much faster than `tidyverse` and still let you use same code
  - `tidytable` is my personal sweetspot between ease of use and performance gains
  - `duckdb` and `sqlite` are also useful when data storage is a concern:
    - CSV: 2.4GB
    - SQLite: 1.9GB
    - Duckdb: 500MB

:::

::::

## Benchmark - all 5 million rows


::: {.cell hash='slides_cache/revealjs/benchmark-5million_cc041c358a079b895a0c128b9c3db8e7'}
::: {.cell-output-display}
![](slides_files/figure-revealjs/benchmark-5million-1.png){width=960}
:::
:::


# Rcpp

## Introduction {.smaller}

  - Sometimes for loops are necessary:
    - No inbuilt vectorised solution
    - Recurrent algorithm such as stepping through time or space
    - Performant critical code and need more specialised data structures
  - `Rcpp`, which combines R and C++, to the rescue!
  
. . .

  - C++ is **compiled** which makes it very fast, but it also requires more effort to both write programs in it and interface with R:
  - `Rcpp` makes this process easy by providing:
    - A C++ library that contains similar data structures and functions to R
    - An R package that compiles C++ code and makes them easily accessible within R
  
## Basic example {.smaller}

  - Can use `Rcpp::cppFunction()` to write a C++ function as a string or `Rcpp::sourceCpp()` if it's in a separate file
  - Both methods do the same:
    - Compile C++ code
    - Create an R function that calls it
  - C++ has many differences with R, having to assign every variable a type is most notable


::: {.cell hash='slides_cache/revealjs/rcpp-1_f802530e1546104a8720b9ff90266895'}

```{.r .cell-code}
library(Rcpp)
cppFunction("double sumRcpp(NumericVector x) {
  int n = x.size();  // R objects have their own type (NumericVector) with useful attributes
  double total = 0;  // Need to instantiate variables before use
  for (int i = 0; i < n; i++) {  // C++ indexes start at 0
    total += x[i];
  }
  return total;
}")
# The sumRcpp function is instantly available within R
sumRcpp(c(1, 2, 3))
```

::: {.cell-output .cell-output-stdout}
```
[1] 6
```
:::
:::

::: {.cell hash='slides_cache/revealjs/unnamed-chunk-3_eea634577bcfe167a2e0e6431e63b97e'}

:::


## Syntatic sugar - data structures {.smaller}

  - When calling an Rcpp function, the inputs are automatically converted from their R type into the specified C++ type
  - `NumericVector` is a special Rcpp data structure that represents a vector of floats, so will accept both `c(1.2, 2.4, 3.6)`, and `c(1, 2, 3)`, but not `c('a', 'b', 'c')`
  - `IntegerVector` coerces floats into integers
  - `CharacterVector` also exists for strings, and `NumericMatrix` for 2D structures
  - For scalar values can use standard C++ data types `int`, `double`, `char` etc...
  - Can also use any other C++ data structure
  - `wrap()` is an Rcpp function that converts back from C++ to R, useful when returning at the end of a function!

## Syntatic sugar - functions

  - There's no penalty to using for loops in C++ so they are very common
  - But to save typing boiler plate code, Rcpp provides 'syntatical sugar' functions that operate on the R-specific data types
  - Examples: `mean`, `log`, `exp`, `sin`, `any`, `all`
  - The for loop wasn't necessary!


::: {.cell hash='slides_cache/revealjs/rcpp-4_09b2cdcdda7fc8eb27a59fdb7afd9faf'}

```{.r .cell-code}
cppFunction("double sumRcppsugar(NumericVector x) {
  return sum(x);
}")
sumRcppsugar(c(1, 2, 3))
```

::: {.cell-output .cell-output-stdout}
```
[1] 6
```
:::
:::


## `sum` benchmarks

:::: {.columns}

::: {.column width="40%"}


::: {.cell hash='slides_cache/revealjs/unnamed-chunk-4_febd498d0934611e4a8fc162356a0529'}

```{.r .cell-code}
sumR <- function(x) {
  total <- 0
  for (i in seq(length(x))) {
    total <- total + x[i]
  }
  total
}
```
:::


  - The Rcpp implementations are around 30x faster than the R version
  - The syntatic sugar version is the same speed as the for loop
  - The inbuilt `sum` is highly optimised
  
:::

::: {.column width="60%"}


::: {.cell hash='slides_cache/revealjs/unnamed-chunk-5_6efdad2912da0e3d801d1e6b84e42ee7'}
::: {.cell-output-display}
![](slides_files/figure-revealjs/unnamed-chunk-5-1.png){width=960}
:::
:::


:::

::::

## Real world example: Kalman Filter {.smaller}


::: {.cell hash='slides_cache/revealjs/rcpp-5_40cdd1dd4048846b52a7cb054b896002'}

:::


:::: {.columns}

::: {.column width="50%"}


::: {.cell hash='slides_cache/revealjs/rcpp-6_878d3dc4dfafe424c7b112167adee61f'}

```{.r .cell-code  code-line-numbers="8-15"}
kf_r <- function(y, m, Q=0.5, H=0.5) {
  n <- length(y)
  alpha <- array(NA, dim=c(n+1, m))
  P <- array(NA, dim=c(m, m, n+1))
  alpha[1] <- 0  # Initialise with zero mean and high variance
  P[, , 1] <- 1e3
  Z <- array(1, dim=c(n, m)) 
  for (i in 1:n) {
    P_updated <- P[, , i] + Q
    # Calculate kalman gain
    K <- P_updated %*% t(Z[i, ]) %*% solve(Z[i, ] %*% P_updated %*% t(Z[i, ]) + H)
    # Update state and covariance
    alpha[i+1, ] <- alpha[i, ] + K %*% (y[i] - Z[i, ] %*% alpha[i, ])
    P[, , i+1] <- (diag(m) - K %*% Z[i, ]) %*% P_updated
  }
  list(alpha=alpha, P=P)
}
```
:::


:::

::: {.column width="50%"}

  - The Kalman Filter is an algorithm that estimates unobserved parameters in a noisy system
  - It is recursive, the estimate at time $t$ solely depends on the value at time $t-1$, hence is a good candidate for Rcpp
  - R implementation is straight forward series of matrix operations
  

::: {.cell hash='slides_cache/revealjs/rcpp-7_b18594f9655b4ba17c4b3f09159b2080'}
::: {.cell-output-display}
![](slides_files/figure-revealjs/rcpp-7-1.png){width=960}
:::
:::


:::


::::


## Kalman Filter - Rcpp implementation {.smaller}

:::: {.columns}

::: {.column width="60%"}


::: {.cell hash='slides_cache/revealjs/rcpp-8_9139958184505af802d5131ad47a9b83'}

```{.r .cell-code}
cppFunction("NumericVector kf_rcpp(arma::vec y, int m, float Q=0.5, float H=0.5) {
  int n = y.n_rows;
  
  arma::mat alpha(n+1, m, arma::fill::none);
  arma::cube P(m, m, n+1, arma::fill::none);
  arma::mat Z(n, m, arma::fill::ones);
  
  // Initialise
  alpha.row(0).fill(0);
  P.slice(0).diag().fill(1000);
  
  // Run filter
  arma::mat P_updated(m, m);
  arma::mat K(m, m);
  for (int i=0; i<n; i++) {
    P_updated = P.slice(i) + Q;
    // Calculate kalman gain:
    K = P_updated * Z.row(i).t() * arma::inv(Z.row(i) * P_updated * Z.row(i).t() + H);
    // Update state and covariance
    alpha.row(i+1) = alpha.row(i) + K * (y[i] - Z.row(i) * alpha.row(i));
    P.slice(i+1) = (arma::eye(m, m) - K * Z.row(i)) * P_updated;
  }
  
  return wrap(alpha);  // This is crucial, converts the Armadillo matrix into an R NumericVector
}", depends="RcppArmadillo")
```
:::


:::

::: {.column width="40%"}

  - Rcpp implementation is very similar, only using the `RcppArmadillo` library for access to 3D arrays
  - Can then call `kf_r()` or `kf_rcpp()` identically

:::

::::


## Benchmark

  - ~80x quicker in Rcpp!
  - Been able to go from hourly to minutely time-resolution
  - Core library function so worth investing the development time


::: {.cell hash='slides_cache/revealjs/rcpp-9_6bcef79d198234f885997735ce588c86'}
::: {.cell-output-display}
![](slides_files/figure-revealjs/rcpp-9-1.png){width=960}
:::
:::



## Parallelisation / Viking {.smaller}

  - For iterative jobs that don't fit within tabular data can run **parallelised** for loops
    - Fitting models
    - Network downloads/uploads
    - File processing
  - For 'small' jobs can run locally using `parallel::mclapply` (Linux), `doParallel` and `foreach` (Windows), or `furrr` (all OS, Tidyverse, combines `future` and `purrr`)

. . .

  - For larger jobs (both duration of each iteration and number of iterations), **Viking** is very useful with [array jobs](https://wiki.york.ac.uk/display/RCS/VK4%29+Job+script+configuration#VK4\)Jobscriptconfiguration-Arrayjobs)
  - Viking also useful to free up PC when running a computationally intensive library (e.g. Stan, INLA, Keras). Optimising these is application-specific

. . . 

  - `future.batchtools` offers the ability to remove the boilerplate of creating Slurm job scripts for array jobs and allow you to easily switch between running sequentially, local multi-core parallelisation, and independent processes Slurm array jobs. **UNTESTED**

## Resources {.smaller}

  - Vectorisation: [Chapter in Advanced R](https://adv-r.hadley.nz/perf-improve.html#vectorise)
  - Joining: [Tidyverse docs](https://dplyr.tidyverse.org/reference/mutate-joins.html), [interactive visual join viewer](https://joins.spathon.com/) (nb: 'outer' joins are called 'full' joins in R)
  - `data.table`: [vignette](https://cran.r-project.org/web/packages/data.table/vignettes/datatable-intro.html), [syntax comparison with tidyverse](https://wetlandscapes.com/blog/a-comparison-of-r-dialects/#joining-data-full-join)
  - `tidytable` vs `dtplyr`: [benchmarking](https://markfairbanks.github.io/tidytable/articles/speed_comparisons.html) between `tidytable`, `data.table`, `dtplyr`, and `tidyverse` and `pandas` (nb: from `tidytable` author)
  - SQLite: [tutorial](https://www.sqlitetutorial.net/)
  - `duckdb`: [official docs](https://duckdb.org/docs/api/r)
  - `Rcpp`: [chapter in Advanced R](https://adv-r.hadley.nz/rcpp.html), [Rcpp book](https://link.springer.com/book/10.1007/978-1-4614-6868-4) (thorough), [Rcpp for everyone book](https://teuder.github.io/rcpp4everyone_en/) (accessible)
  - Parallelisation: [chapter in R Programming for Data Science ebook](https://bookdown.org/rdpeng/rprogdatascience/parallel-computation.html#building-a-socket-cluster)
  - Viking: [wiki](https://wiki.york.ac.uk/display/RCS/Viking+-+University+of+York+Research+Computing+Cluster)
  
# Misc

## Worked example - regex {visibility="uncounted"}

  - The `basename` and `dirname` solution was faster than `regex`


::: {.cell hash='slides_cache/revealjs/unnamed-chunk-6_6ee900d66e0092eb6621f262e5facc69'}

```{.r .cell-code}
example_4 <- function(paths) {
  gsub(".+\\/+([[:alnum:]]+)\\/([[:alnum:]]+\\.[[:alnum:]]+)$", "\\1_\\2", paths)
}
example_4(c("foo/bar/car/001.txt", "har/far/lar/002.txt"))
```

::: {.cell-output .cell-output-stdout}
```
[1] "car_001.txt" "lar_002.txt"
```
:::
:::

::: {.cell hash='slides_cache/revealjs/unnamed-chunk-7_bf0eb13b7a3fd1757992872237a8ebfb'}
::: {.cell-output .cell-output-stdout}
```
                         expr    median
1 example_1_vectorised(paths) 6650.4320
2    sapply(paths, example_1) 6630.4525
3            example_2(paths) 1180.3090
4            example_3(paths)  116.3725
5            example_4(paths)  366.1625
```
:::
:::


## Case when {visibility="uncounted"}

  - No speed difference between `ifelse` and `case_when`


::: {.cell hash='slides_cache/revealjs/unnamed-chunk-8_a34a24a198757127fabc1b3e2d5a7bf0'}

```{.r .cell-code}
f_casewhen <- function() {
  df_interval |>
    mutate(week_group = case_when(
      time >= as_date("2020-02-14") & time < as_date("2020-02-21") ~ 'a',
      time >= as_date("2020-03-17") & time < as_date("2020-03-24") ~ 'b',
      time >= as_date("2020-05-08") & time < as_date("2020-05-15") ~ 'c',
      time >= as_date("2020-09-20") & time < as_date("2020-09-27") ~ 'd',
      time >= as_date("2020-11-13") & time < as_date("2020-11-20") ~ 'e',
      .default = NA_character_
    )) |>
      filter(!is.na(week_group))
}

res <- microbenchmark(f_intervaljoin(), f_ifelse(), f_casewhen(), times=10)
summary(res)[c("expr", "median")]
```

::: {.cell-output .cell-output-stdout}
```
              expr    median
1 f_intervaljoin()  1.779534
2       f_ifelse() 21.635221
3     f_casewhen() 21.336844
```
:::
:::

::: {.cell hash='slides_cache/revealjs/db-disconnect_f570592c0deaa7b44a619a94d88d697f'}

:::

  
## Filter vs inner join speed {visibility="uncounted"}

  - When limiting analysis to the classifications with at least 10 companies, it was quicker to reduce the main dataset by an `inner_join` than `filter`


::: {.cell hash='slides_cache/revealjs/unnamed-chunk-9_e7c70581750b24deee49bbcb07d25ba8'}
::: {.cell-output .cell-output-stdout}
```
            expr   median
1     f_filter() 339.3404
2 f_inner_join() 365.2718
```
:::
:::
