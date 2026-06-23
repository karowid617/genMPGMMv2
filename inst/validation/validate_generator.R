# ============================================================
# Extended validation script for genMPGMM
# Run interactively or via Rscript — NOT included in R CMD check.
# ============================================================

library(genMPGMM)

cat("======================================================\n")
cat("genMPGMM validation script\n")
cat("======================================================\n\n")

n_seeds <- 10
tol_ari   <- 0.05   # wider than ari_tol to allow for stochastic variation
tol_mah   <- 0.10   # relative tolerance for Mahalanobis

pass <- function(msg) cat(sprintf("  [PASS] %s\n", msg))
fail <- function(msg) { cat(sprintf("  [FAIL] %s\n", msg)); .GlobalEnv$.fails <- .GlobalEnv$.fails + 1 }
.GlobalEnv$.fails <- 0

# ============================================================
# 1. ARI target accuracy — vs_reference mode
# ============================================================
cat("-- 1. ARI target accuracy (vs_reference) --\n")
for (tgt in c(0.0, 0.3, 0.6)) {
  achieved_vals <- numeric(n_seeds)
  for (s in seq_len(n_seeds)) {
    res <- suppressWarnings(genMPGMM(
      n_feature_patterns        = c(2, 2),
      n_components              = c(2, 2),
      feature_group_proportions = list(c(0.5, 0.5), c(0.5, 0.5)),
      mixing_proportions        = list(c(0.5, 0.5), c(0.5, 0.5)),
      dist_mahalanobis          = 3,
      target_ari                = c(1, tgt),
      ari_tol                   = 0.02,
      ari_max_iter              = 5000,
      M = 80, N = 60,
      covariance_spec           = list(type = "diagonal"),
      noise_feature_fraction    = 0,
      seed = s
    ))
    achieved_vals[s] <- res$achieved_ari_features[1, 2]
  }
  mean_err <- mean(abs(achieved_vals - tgt))
  max_err  <- max(abs(achieved_vals - tgt))
  if (max_err <= tol_ari) {
    pass(sprintf("ARI target %.2f: mean err=%.3f, max err=%.3f", tgt, mean_err, max_err))
  } else {
    fail(sprintf("ARI target %.2f: max err=%.3f > tol %.2f (mean err=%.3f)",
                 tgt, max_err, tol_ari, mean_err))
  }
}

# ============================================================
# 2. Mahalanobis target accuracy — K_p = 2 (should be exact)
# ============================================================
cat("\n-- 2. Mahalanobis target accuracy --\n")
for (tgt in c(2, 5, 10)) {
  errs <- numeric(n_seeds)
  for (s in seq_len(n_seeds)) {
    res <- suppressWarnings(genMPGMM(
      n_feature_patterns        = c(2, 2),
      n_components              = c(2, 2),
      feature_group_proportions = list(c(0.5, 0.5), c(0.5, 0.5)),
      mixing_proportions        = list(c(0.5, 0.5), c(0.5, 0.5)),
      dist_mahalanobis          = tgt,
      target_ari                = c(1, 0.3),
      M = 40, N = 60,
      covariance_spec           = list(type = "diagonal"),
      noise_feature_fraction    = 0,
      seed = s
    ))
    errs[s] <- abs(res$achieved_mahalanobis[[1]][1, 2] - tgt)
  }
  max_err <- max(errs)
  if (max_err < 1e-5) {
    pass(sprintf("Mahalanobis K_p=2 target %g: max abs err = %.2e (exact)", tgt, max_err))
  } else {
    fail(sprintf("Mahalanobis K_p=2 target %g: max abs err = %.2e > 1e-5", tgt, max_err))
  }
}

# K_p > 2: median should be close
cat("\n  K_p = 4 (median should be within relative tolerance):\n")
for (tgt in c(3, 7)) {
  errs <- numeric(n_seeds)
  for (s in seq_len(n_seeds)) {
    res <- suppressWarnings(genMPGMM(
      n_feature_patterns        = c(2, 2),
      n_components              = c(4, 4),
      feature_group_proportions = list(c(0.5, 0.5), c(0.5, 0.5)),
      mixing_proportions        = list(rep(0.25,4), rep(0.25,4)),
      dist_mahalanobis          = tgt,
      target_ari                = c(1, 0.3),
      M = 60, N = 120,
      covariance_spec           = list(type = "diagonal"),
      noise_feature_fraction    = 0,
      seed = s
    ))
    D     <- res$achieved_mahalanobis[[1]]
    dvals <- D[upper.tri(D)]
    errs[s] <- abs(median(dvals) - tgt) / tgt
  }
  max_rel <- max(errs)
  if (max_rel < 1e-5) {
    pass(sprintf("Mahalanobis K_p=4 median target %g: max rel err = %.2e", tgt, max_rel))
  } else {
    fail(sprintf("Mahalanobis K_p=4 median target %g: max rel err = %.3f", tgt, max_rel))
  }
}

# ============================================================
# 3. Mixing proportion accuracy
# ============================================================
cat("\n-- 3. Mixing proportion accuracy --\n")
for (s in seq_len(5)) {
  res <- suppressWarnings(genMPGMM(
    n_feature_patterns        = c(2, 2),
    n_components              = c(3, 3),
    feature_group_proportions = list(c(0.5, 0.5), c(0.5, 0.5)),
    mixing_proportions        = list(c(0.2, 0.5, 0.3), c(0.4, 0.4, 0.2)),
    dist_mahalanobis          = 3,
    target_ari                = c(1, 0.3),
    M = 40, N = 300,
    covariance_spec           = list(type = "diagonal"),
    noise_feature_fraction    = 0,
    seed = s
  ))
  err <- max(abs(res$achieved_mixing[[1]] - c(0.2, 0.5, 0.3)))
  if (err < 1/300 + 1e-9) {
    pass(sprintf("seed %d mixing proportions err = %.4f", s, err))
  } else {
    fail(sprintf("seed %d mixing proportions err = %.4f > 1/N = %.4f", s, err, 1/300))
  }
}

# ============================================================
# 4. Covariance validity
# ============================================================
cat("\n-- 4. Covariance validity --\n")
for (cov_type in c("diagonal", "full_shared")) {
  res <- suppressWarnings(genMPGMM(
    n_feature_patterns        = c(2, 2),
    n_components              = c(2, 2),
    feature_group_proportions = list(c(0.5, 0.5), c(0.5, 0.5)),
    mixing_proportions        = list(c(0.5, 0.5), c(0.5, 0.5)),
    dist_mahalanobis          = 3,
    target_ari                = c(1, 0.3),
    M = 10, N = 40,
    covariance_spec           = list(type = cov_type),
    noise_feature_fraction    = 0,
    seed = 1
  ))
  all_pd <- all(sapply(res$cov_mtx, function(S) {
    all(eigen(S, only.values = TRUE, symmetric = TRUE)$values > 0)
  }))
  if (all_pd) {
    pass(sprintf("covariance type '%s': all profile matrices positive definite", cov_type))
  } else {
    fail(sprintf("covariance type '%s': some matrices NOT positive definite", cov_type))
  }
}

# Diagonal mode: off-diagonal must be zero
res <- suppressWarnings(quick_diag <- genMPGMM(
  n_feature_patterns        = c(2, 2),
  n_components              = c(2, 2),
  feature_group_proportions = list(c(0.5, 0.5), c(0.5, 0.5)),
  mixing_proportions        = list(c(0.5, 0.5), c(0.5, 0.5)),
  dist_mahalanobis          = 3,
  target_ari                = c(1, 0.3),
  M = 10, N = 40,
  covariance_spec           = list(type = "diagonal"),
  noise_feature_fraction    = 0,
  seed = 1
))
off_ok <- all(sapply(res$cov_mtx, function(S) all(S[lower.tri(S)] == 0)))
if (off_ok) pass("diagonal mode: all off-diagonal entries are exactly zero") else
  fail("diagonal mode: off-diagonal entries are non-zero")

# ============================================================
# 5. Noise behavior
# ============================================================
cat("\n-- 5. Noise feature behavior --\n")
res <- suppressWarnings(genMPGMM(
  n_feature_patterns        = c(2, 2),
  n_components              = c(2, 2),
  feature_group_proportions = list(c(0.5, 0.5), c(0.5, 0.5)),
  mixing_proportions        = list(c(0.5, 0.5), c(0.5, 0.5)),
  dist_mahalanobis          = 3,
  target_ari                = c(1, 0.3),
  M = 100, N = 200,
  covariance_spec           = list(type = "diagonal"),
  noise_feature_fraction    = 0.2,
  seed = 42
))
nf <- res$noise_feature_indices
z_bin <- as.numeric(res$z[[1]])
if (length(nf) == 20) {
  pass(sprintf("noise feature count: %d (expected 20 = floor(100*0.2))", length(nf)))
} else {
  fail(sprintf("noise feature count: %d (expected 20)", length(nf)))
}
max_cor <- max(abs(apply(res$X[nf,], 1, function(r) cor(r, z_bin))))
if (max_cor < 0.3) {
  pass(sprintf("noise features uncorrelated with z: max |cor| = %.3f < 0.3", max_cor))
} else {
  fail(sprintf("noise features correlated with z: max |cor| = %.3f >= 0.3", max_cor))
}

# ============================================================
# 6. K_p = 1 edge case
# ============================================================
cat("\n-- 6. K_p = 1 edge case --\n")
res <- suppressWarnings(genMPGMM(
  n_feature_patterns        = c(2, 2),
  n_components              = c(1, 1),
  feature_group_proportions = list(c(0.5, 0.5), c(0.5, 0.5)),
  mixing_proportions        = list(c(1), c(1)),
  dist_mahalanobis          = 5,
  target_ari                = c(1, 0.3),
  M = 20, N = 40,
  covariance_spec           = list(type = "diagonal"),
  noise_feature_fraction    = 0,
  seed = 1
))
if (all(sapply(res$achieved_mahalanobis, function(D) D == 0))) {
  pass("K_p=1: achieved Mahalanobis distance is 0 for all profiles")
} else {
  fail("K_p=1: achieved Mahalanobis distance is not 0")
}
if (identical(dim(res$X), c(20L, 40L))) {
  pass("K_p=1: output dimensions correct")
} else {
  fail("K_p=1: output dimensions wrong")
}

# ============================================================
# 7. Diagonal vs full_shared covariance behavior
# ============================================================
cat("\n-- 7. Diagonal vs full covariance behavior --\n")
r_diag <- suppressWarnings(genMPGMM(
  n_feature_patterns        = c(2, 2),
  n_components              = c(2, 2),
  feature_group_proportions = list(c(0.5, 0.5), c(0.5, 0.5)),
  mixing_proportions        = list(c(0.5, 0.5), c(0.5, 0.5)),
  dist_mahalanobis          = 3,
  target_ari                = c(1, 0.3),
  M = 30, N = 200,
  covariance_spec           = list(type = "diagonal", diag_values = rep(1, 30)),
  noise_feature_fraction    = 0, seed = 1
))
r_full <- suppressWarnings(genMPGMM(
  n_feature_patterns        = c(2, 2),
  n_components              = c(2, 2),
  feature_group_proportions = list(c(0.5, 0.5), c(0.5, 0.5)),
  mixing_proportions        = list(c(0.5, 0.5), c(0.5, 0.5)),
  dist_mahalanobis          = 3,
  target_ari                = c(1, 0.3),
  M = 30, N = 200,
  covariance_spec           = list(type = "full_shared"),
  noise_feature_fraction    = 0, seed = 1
))
# Diagonal mode: empirical off-diagonal correlations should be smaller
emp_cor_diag <- cor(t(r_diag$X))
emp_cor_full <- cor(t(r_full$X))
off_d <- abs(emp_cor_diag[lower.tri(emp_cor_diag)])
off_f <- abs(emp_cor_full[lower.tri(emp_cor_full)])
if (median(off_f) > median(off_d)) {
  pass(sprintf("full_shared has higher median feature correlation (%.3f) than diagonal (%.3f)",
               median(off_f), median(off_d)))
} else {
  fail("full_shared does NOT have higher median feature correlation than diagonal")
}

# ============================================================
# Summary
# ============================================================
cat("\n======================================================\n")
if (.GlobalEnv$.fails == 0) {
  cat("All validation checks PASSED.\n")
} else {
  cat(sprintf("%d validation check(s) FAILED. Review output above.\n", .GlobalEnv$.fails))
}
cat("======================================================\n")
