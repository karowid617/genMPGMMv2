
<!-- README.md is generated from README.Rmd. Please edit that file -->

# genMPGMM

<!-- badges: start -->
<!-- badges: end -->

genMPGMM is an R package for generating synthetic datasets from
multi-profile Gaussian mixture models.

The generator creates an M by N data matrix where rows correspond to
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
remotes::install_github("karowid617/genMPGMM")
```

## Example

This is a basic example which shows you how to generate a dataset:

``` r
library(genMPGMM)

sim <- genMPGMM(
  P = 2,
  L_vec = c(2, 2),
  K_vec = c(2, 2),
  feature_group_proportions = list(
    c(0.5, 0.5),
    c(0.7, 0.3)
  ),
  mixing_proportions = list(
    c(0.2, 0.8),
    c(0.6, 0.4)
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

print.mp_gmm_data(sim)
#> Multi-profile GMM data
#>   Features:      80
#>   Observations:  60
#>   Profiles:      2
#>   Feature groups per profile:         2, 2
#>   Observation components per profile:         2, 2
#>   Noise features: 0
summary.mp_gmm_data(sim)
#> === Multi-profile GMM summary ===
#> X dimension: 80 features x 60 observations
#> Profiles: 2 
#> Feature groups per profile: 2, 2 
#> Observation components per profile: 2, 2 
#> Noise features: 0 
#> 
#> Achieved ARI matrix for feature partitions:
#>       [,1]  [,2]
#> [1,] 1.000 0.194
#> [2,] 0.194 1.000
#> 
#> Achieved mixture proportions:
#> [[1]]
#> [1] 0.2 0.8
#> 
#> [[2]]
#> [1] 0.6 0.4
#> 
#> 
#> Achieved feature-group proportions:
#> [[1]]
#> [1] 0.5 0.5
#> 
#> [[2]]
#> [1] 0.7 0.3
#> 
#> 
#> Pairwise Mahalanobis distance matrices:
#> 
#> Profile 1:
#>      [,1] [,2]
#> [1,]    0    3
#> [2,]    3    0
#> 
#> Profile 2:
#>      [,1] [,2]
#> [1,]    0    4
#> [2,]    4    0
```
