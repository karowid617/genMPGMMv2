#' Summarize a multi-profile GMM object
#'
#' @param object An object of class \code{"MPObject"}.
#' @param ... Further arguments passed to or from other methods.
#'
#' @return The input object, invisibly.
#' @export
summary.MPObject <- function(object, ...) {
  cat("=== Multi-profile GMM summary ===\n")
  cat("X dimension:", nrow(object$X), "features x", ncol(object$X), "observations\n")
  cat("Profiles:", object$settings$P, "\n")
  cat("Feature groups per profile:", paste(object$settings$n_feature_patterns, collapse = ", "), "\n")
  cat("Observation components per profile:", paste(object$settings$n_components, collapse = ", "), "\n")
  cat("Noise features:", length(object$noise_feature_indices), "\n\n")

  cat("Achieved ARI matrix for feature partitions:\n")
  print(round(object$achieved_ari_features, 3))

  cat("\nAchieved mixture proportions:\n")
  print(object$achieved_mixing)

  cat("\nAchieved feature-group proportions:\n")
  print(object$achieved_feature_group_props)

  cat("\nPairwise Mahalanobis distance matrices:\n")
  for (p in seq_len(object$settings$P)) {
    cat(sprintf("\nProfile %d:\n", p))
    print(round(object$achieved_mahalanobis[[p]], 3))
  }

  invisible(object)
}
