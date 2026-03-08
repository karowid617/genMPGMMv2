
<!-- README.md is generated from README.Rmd. Please edit that file -->

# mpGMM

<!-- badges: start -->
<!-- badges: end -->

mpGMM is an R package for generating synthetic datasets from
multi-profile Gaussian mixture models.

The generator creates an M × N data matrix where rows correspond to
features and columns correspond to observations.

Each latent profile defines (1) a partition of features into feature
groups, (2) a partition of observations into mixture components.

Similarity between feature partitions across profiles can be controlled
using the Adjusted Rand Index (ARI), while separation between
observation components is controlled via Mahalanobis distance.

## Installation

You can install the development version of mpGMM like so:

``` r
install.packages("remotes")
remotes::install_github("karowid617/mpGMM")
```

## Example

This is a basic example which shows you how to generate a dataset:

``` r
library(mpGMM)

sim <- generate_multprofile_gmm(
  P = 2,
  L_vec = c(2, 2),
  K_vec = c(3, 3),
  feature_group_proportions = list(
    c(0.5, 0.5),
    c(0.7, 0.3)
  ),
  mixing_proportions = list(
    c(0.2, 0.2, 0.6),
    c(0.7, 0.1, 0.2)
  ),
  dist_mahalanobis = c(3, 4),
  target_ari_features = c(1, 0.2),
  M = 80,
  N = 60,
  covariance_spec = list(
    type = "diagonal",
    diag_values = list(
      rep(1, 80),
      rep(1.5, 80)
    )
  ),
  seed = 123
)

summary(sim)
#>                              Length Class  Mode   
#> X                            4800   -none- numeric
#> X_signal                     4800   -none- numeric
#> X_profiles                      2   -none- list   
#> s                               2   -none- list   
#> z                               2   -none- list   
#> templates                       2   -none- list   
#> feature_baselines               2   -none- list   
#> delta                           2   -none- list   
#> mu                              2   -none- list   
#> Sigma                           2   -none- list   
#> achieved_ari_features           4   -none- numeric
#> achieved_mixing                 2   -none- list   
#> achieved_feature_group_props    2   -none- list   
#> achieved_mahalanobis            2   -none- list   
#> noise_feature_indices           0   -none- numeric
#> settings                       22   -none- list
```
