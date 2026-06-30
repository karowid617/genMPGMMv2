# ============================================================
# Visualisation for MPObject
# ============================================================
#
# Public API
# ----------
#   plot.MPObject(x, which, ask, ...)
#   report_MPObject(x, file, which, open, ...)
#
# Internal helpers are prefixed with .mp_
# ============================================================

# ---- dependency guard -------------------------------------

.mp_check_deps <- function() {
  missing_pkgs <- Filter(
    function(p) !requireNamespace(p, quietly = TRUE),
    c("ggplot2", "gridExtra", "scales")
  )
  if (length(missing_pkgs) > 0) {
    stop(
      "The following packages must be installed to use plotting functions:\n",
      "  ", paste(missing_pkgs, collapse = ", "), "\n",
      "Install them with:\n",
      '  install.packages(c(', paste0('"', missing_pkgs, '"', collapse = ", "), '))',
      call. = FALSE
    )
  }
}

# ---- shared theme & colours --------------------------------

.mp_theme <- function(base_size = 10) {
  ggplot2::theme_bw(base_size = base_size) +
    ggplot2::theme(
      panel.grid.minor  = ggplot2::element_blank(),
      plot.title        = ggplot2::element_text(face = "bold", size = base_size + 1),
      plot.subtitle     = ggplot2::element_text(colour = "grey40", size = base_size - 1,
                                                lineheight = 1.3),
      legend.key.size   = ggplot2::unit(0.4, "cm"),
      strip.text        = ggplot2::element_text(face = "bold"),
      strip.background  = ggplot2::element_rect(fill = "white")
    )
}

.mp_group_colours <- function(n) {
  all_cols <- c("#E07B54", "#5B8DB8", "#6BAB6E", "#9B59B6", "#F39C12",
                "#1ABC9C", "#E74C3C", "#3498DB", "#2ECC71")
  all_cols[seq_len(min(n, length(all_cols)))]
}

.mp_comp_colours <- function(n) {
  all_cols <- c("#D62728", "#1F77B4", "#2CA02C", "#9467BD",
                "#FF7F0E", "#8C564B", "#E377C2", "#7F7F7F")
  all_cols[seq_len(min(n, length(all_cols)))]
}

# ---- individual plot builders ------------------------------

# 1. Heatmap of the data matrix X, sorted by profile-1 structure
.mp_plot_heatmap <- function(dat) {
  M          <- dat$settings$M
  N          <- dat$settings$N
  noise_rows <- dat$noise_feature_indices

  col_ord <- order(dat$z[[1]])
  row_ord <- order(dat$s[[1]])

  X_sorted <- dat$X[row_ord, col_ord]
  cap       <- stats::quantile(abs(X_sorted), 0.99)
  X_cap     <- pmin(pmax(X_sorted, -cap), cap)

  hm_df <- data.frame(
    Feature     = as.integer(row(X_cap)),
    Observation = as.integer(col(X_cap)),
    Value       = as.vector(X_cap)
  )

  group_breaks <- which(diff(dat$s[[1]][row_ord]) != 0) + 0.5
  comp_breaks  <- which(diff(dat$z[[1]][col_ord]) != 0) + 0.5
  noise_pos    <- which(row_ord %in% noise_rows)

  p <- ggplot2::ggplot(hm_df,
                       ggplot2::aes(.data$Observation, .data$Feature,
                                    fill = .data$Value)) +
    ggplot2::geom_raster() +
    ggplot2::scale_fill_gradientn(
      colours = c("#313695", "#4575b4", "#74add1", "#e0f3f8",
                  "#fee090", "#f46d43", "#a50026"),
      name = "Value"
    ) +
    ggplot2::geom_hline(yintercept = group_breaks,
                        colour = "white", linewidth = 1, linetype = "dashed") +
    ggplot2::geom_vline(xintercept = comp_breaks,
                        colour = "white", linewidth = 1, linetype = "dashed") +
    ggplot2::scale_x_continuous(expand = c(0, 0)) +
    ggplot2::scale_y_continuous(expand = c(0, 0)) +
    ggplot2::labs(
      title    = "Data matrix X",
      subtitle = paste0(
        "Features sorted by profile-1 group (dashed horizontal = group boundaries).\n",
        "Observations sorted by profile-1 component (dashed vertical = component boundary).",
        if (length(noise_pos) > 0)
          sprintf("\nGrey dotted rows = %d noise features.", length(noise_pos))
        else ""
      ),
      x = "Observation", y = "Feature"
    ) +
    .mp_theme() +
    ggplot2::theme(axis.text  = ggplot2::element_blank(),
                   axis.ticks = ggplot2::element_blank())

  if (length(noise_pos) > 0) {
    p <- p + ggplot2::geom_hline(yintercept = noise_pos,
                                 colour = "grey60", linewidth = 0.2,
                                 linetype = "dotted")
  }
  p
}

# 2. Feature partitions: one coloured bar per profile
.mp_plot_feature_parts <- function(dat) {
  P      <- dat$settings$P
  M      <- dat$settings$M
  L_vals <- dat$settings$n_feature_patterns

  fp_df <- do.call(rbind, lapply(seq_len(P), function(p) {
    data.frame(
      Feature = seq_len(M),
      Profile = sprintf("Profile %d  (L=%d)", p, L_vals[p]),
      Group   = factor(dat$s[[p]])
    )
  }))

  ari_mat  <- dat$achieved_ari_features
  ari_strs <- vapply(seq_len(P), function(p) {
    if (p == 1) "reference" else
      sprintf("ARI vs profile 1 = %.3f", ari_mat[1, p])
  }, character(1))

  all_levels <- as.character(seq_len(max(L_vals)))
  pal        <- stats::setNames(.mp_group_colours(length(all_levels)), all_levels)

  ggplot2::ggplot(fp_df,
                  ggplot2::aes(.data$Feature, 1, fill = .data$Group)) +
    ggplot2::geom_tile(height = 0.8) +
    ggplot2::scale_fill_manual(values = pal, name = "Feature group",
                               drop = FALSE) +
    ggplot2::facet_wrap(~Profile, ncol = 1) +
    ggplot2::labs(
      title    = "Feature partitions per profile",
      subtitle = paste0(
        "Each bar = M features coloured by group assignment.\n",
        "ARI close to 1 -> groups align across profiles.  ",
        "ARI close to 0 -> groups independent.\n",
        "Target ARI: ", paste(
          vapply(seq_len(P), function(p) {
            if (p == 1) "1.000 (ref)"
            else sprintf("%.3f", .mp_scalar_target_ari(dat, p))
          }, character(1)),
          collapse = "  |  "
        )
      ),
      x = "Feature index", y = NULL
    ) +
    ggplot2::scale_x_continuous(expand = c(0, 0)) +
    ggplot2::scale_y_continuous(expand = c(0, 0)) +
    .mp_theme() +
    ggplot2::theme(axis.text.y  = ggplot2::element_blank(),
                   axis.ticks.y = ggplot2::element_blank(),
                   panel.grid   = ggplot2::element_blank())
}

# Helper: extract scalar ARI target for profile p (vs reference)
.mp_scalar_target_ari <- function(dat, p) {
  ta <- dat$settings$target_ari
  if (is.matrix(ta)) return(ta[1, p])
  full <- if (length(ta) == 1) c(1, rep(ta, dat$settings$P - 1))
          else if (length(ta) == dat$settings$P - 1) c(1, ta)
          else ta
  full[p]
}

# 3. Observation (component) partitions
.mp_plot_obs_parts <- function(dat) {
  P      <- dat$settings$P
  N      <- dat$settings$N
  K_vals <- dat$settings$n_components

  obs_df <- do.call(rbind, lapply(seq_len(P), function(p) {
    data.frame(
      Obs     = seq_len(N),
      Profile = sprintf("Profile %d  (K=%d)", p, K_vals[p]),
      Comp    = factor(dat$z[[p]])
    )
  }))

  K_max  <- max(K_vals)
  all_lv <- as.character(seq_len(K_max))
  pal    <- stats::setNames(.mp_comp_colours(K_max), all_lv)

  prop_strs <- vapply(seq_len(P), function(p) {
    vals <- round(dat$settings$mixing_proportions[[p]], 2)
    sprintf("P%d: (%s)", p, paste(vals, collapse = ", "))
  }, character(1))

  ggplot2::ggplot(obs_df,
                  ggplot2::aes(.data$Obs, 1, fill = .data$Comp)) +
    ggplot2::geom_tile(height = 0.8) +
    ggplot2::scale_fill_manual(values = pal, name = "Component", drop = FALSE) +
    ggplot2::facet_wrap(~Profile, ncol = 1) +
    ggplot2::labs(
      title    = "Observation (component) partitions",
      subtitle = paste0(
        "Each bar = N observations coloured by component assignment.\n",
        "Bar widths reflect mixing proportions: ",
        paste(prop_strs, collapse = "  |  ")
      ),
      x = "Observation index", y = NULL
    ) +
    ggplot2::scale_x_continuous(expand = c(0, 0)) +
    ggplot2::scale_y_continuous(expand = c(0, 0)) +
    .mp_theme() +
    ggplot2::theme(axis.text.y  = ggplot2::element_blank(),
                   axis.ticks.y = ggplot2::element_blank(),
                   panel.grid   = ggplot2::element_blank())
}

# 4. PCA: one panel per profile, coloured by component assignment
# Returns a LIST of P ggplot objects
.mp_plot_pca <- function(dat) {
  P           <- dat$settings$P
  noise_rows  <- dat$noise_feature_indices
  signal_rows <- setdiff(seq_len(dat$settings$M), noise_rows)

  if (length(signal_rows) < 2) {
    return(list(ggplot2::ggplot() +
                  ggplot2::annotate("text", x = 0.5, y = 0.5,
                                    label = "Not enough signal features for PCA.") +
                  ggplot2::theme_void()))
  }

  pca_fit <- stats::prcomp(t(dat$X[signal_rows, ]), scale. = TRUE)
  var_pct <- round(100 * pca_fit$sdev^2 / sum(pca_fit$sdev^2), 1)
  x_lab   <- sprintf("PC1  (%.1f %%)", var_pct[1])
  y_lab   <- sprintf("PC2  (%.1f %%)", var_pct[2])

  K_max <- max(dat$settings$n_components)
  pal   <- stats::setNames(.mp_comp_colours(K_max), as.character(seq_len(K_max)))

  lapply(seq_len(P), function(p) {
    pca_df <- data.frame(
      PC1  = pca_fit$x[, 1],
      PC2  = pca_fit$x[, 2],
      Comp = factor(dat$z[[p]])
    )
    ggplot2::ggplot(pca_df,
                    ggplot2::aes(.data$PC1, .data$PC2, colour = .data$Comp)) +
      ggplot2::geom_point(size = 1.8, alpha = 0.7) +
      # ggplot2::stat_ellipse(linewidth = 0.6, level = 0.75, show.legend = FALSE) +
      ggplot2::scale_colour_manual(values = pal, name = "Component", drop = FALSE) +
      ggplot2::labs(
        title    = sprintf("Profile %d  (K=%d)", p, dat$settings$n_components[p]),
        subtitle = sprintf(
          "Mahalanobis target: %g  |  achieved median: %.3f",
          dat$settings$dist_mahalanobis[p],
          {
            D  <- dat$achieved_mahalanobis[[p]]
            dv <- D[upper.tri(D)]
            if (length(dv) == 0) 0 else median(dv)
          }
        ),
        x = x_lab, y = y_lab
      ) +
      .mp_theme()
  })
}

# 5. Achieved vs target proportions (mixing and feature-group)
.mp_plot_props <- function(dat) {
  P <- dat$settings$P

  build_df <- function(achieved_list, target_list, kind) {
    do.call(rbind, lapply(seq_len(P), function(p) {
      K  <- length(achieved_list[[p]])
      rbind(
        data.frame(Profile  = sprintf("Profile %d", p),
                   Category = factor(seq_len(K)),
                   Kind     = "Achieved",
                   Prop     = achieved_list[[p]],
                   Type     = kind),
        data.frame(Profile  = sprintf("Profile %d", p),
                   Category = factor(seq_len(K)),
                   Kind     = "Target",
                   Prop     = target_list[[p]],
                   Type     = kind)
      )
    }))
  }

  prop_df <- rbind(
    build_df(dat$achieved_mixing,
             dat$settings$mixing_proportions,
             "Mixing proportions"),
    build_df(dat$achieved_feature_group_props,
             dat$settings$feature_group_proportions,
             "Feature-group proportions")
  )

  K_max  <- max(dat$settings$n_components, dat$settings$n_feature_patterns)
  all_lv <- as.character(seq_len(K_max))
  pal    <- stats::setNames(.mp_group_colours(K_max), all_lv)

  ggplot2::ggplot(
    prop_df,
    ggplot2::aes(.data$Category, .data$Prop,
                 fill = .data$Category, alpha = .data$Kind)
  ) +
    ggplot2::geom_col(position = ggplot2::position_dodge(0.7), width = 0.6) +
    ggplot2::scale_fill_manual(values = pal, guide = "none") +
    ggplot2::scale_alpha_manual(
      values = c(Achieved = 1.0, Target = 0.28), name = NULL
    ) +
    ggplot2::scale_y_continuous(
      labels = scales::percent_format(accuracy = 1), limits = c(0, 1)
    ) +
    ggplot2::facet_grid(Type ~ Profile) +
    ggplot2::labs(
      title    = "Achieved vs target proportions",
      subtitle = "Solid bar = achieved.  Faded bar = requested target.  They should nearly overlap.",
      x = NULL, y = "Proportion"
    ) +
    .mp_theme()
}

# 6. Pairwise Mahalanobis distance matrices (one tile plot per profile)
.mp_plot_mahal <- function(dat) {
  P <- dat$settings$P

  mah_df <- do.call(rbind, lapply(seq_len(P), function(p) {
    D   <- dat$achieved_mahalanobis[[p]]
    tgt <- dat$settings$dist_mahalanobis[p]
    K   <- nrow(D)
    g   <- expand.grid(k1 = seq_len(K), k2 = seq_len(K))
    data.frame(
      Profile = sprintf("Profile %d  (target = %g)", p, tgt),
      k1      = factor(g$k1),
      k2      = factor(g$k2),
      Dist    = as.vector(D)
    )
  }))

  max_d <- max(mah_df$Dist)

  ggplot2::ggplot(mah_df,
                  ggplot2::aes(.data$k1, .data$k2, fill = .data$Dist)) +
    ggplot2::geom_tile(colour = "white", linewidth = 0.8) +
    ggplot2::geom_text(
      ggplot2::aes(label = sprintf("%.2f", .data$Dist)),
      size = 3.8, colour = "white", fontface = "bold"
    ) +
    ggplot2::scale_fill_gradientn(
      colours = c("#313695", "#4575b4", "#abd9e9",
                  "#fee090", "#f46d43", "#a50026"),
      limits  = c(0, max_d),
      name    = "Distance"
    ) +
    ggplot2::facet_wrap(~Profile) +
    ggplot2::coord_equal() +
    ggplot2::scale_x_discrete(expand = c(0, 0)) +
    ggplot2::scale_y_discrete(expand = c(0, 0)) +
    ggplot2::labs(
      title    = "Pairwise Mahalanobis distances between component means",
      subtitle = paste0(
        "Diagonal = 0 (same component).  Off-diagonal = separation between components.\n",
        "For K=2: target is met exactly.  For K>2: target is the MEDIAN of all off-diagonal values."
      ),
      x = "Component", y = "Component"
    ) +
    .mp_theme()
}

# 7. Component mean profiles across features
# Returns a LIST of P ggplot objects
.mp_plot_mu <- function(dat) {
  P     <- dat$settings$P
  K_max <- max(dat$settings$n_components)
  pal   <- stats::setNames(.mp_comp_colours(K_max), as.character(seq_len(K_max)))

  lapply(seq_len(P), function(p) {
    mu  <- dat$mu[[p]]
    s_p <- dat$s[[p]]
    ord <- order(s_p)
    K   <- nrow(mu)
    M   <- ncol(mu)

    mu_df <- do.call(rbind, lapply(seq_len(K), function(k) {
      data.frame(
        Feature   = seq_len(M),
        MeanValue = mu[k, ord],
        Component = factor(k),
        Group     = factor(s_p[ord])
      )
    }))

    ref_comp <- levels(mu_df$Component)[1]
    g_breaks <- which(
      diff(as.integer(mu_df$Group[mu_df$Component == ref_comp])) != 0
    ) + 0.5

    ggplot2::ggplot(
      mu_df,
      ggplot2::aes(.data$Feature, .data$MeanValue,
                   colour = .data$Component, group = .data$Component)
    ) +
      ggplot2::geom_line(alpha = 0.85, linewidth = 0.3) +
      ggplot2::geom_vline(xintercept = g_breaks,
                          linetype = "dashed", colour = "grey55", linewidth = 0.4) +
      ggplot2::scale_colour_manual(values = pal, name = "Component", drop = FALSE) +
      ggplot2::labs(
        title = sprintf("Profile %d -- component means  (K=%d)",
                        p, dat$settings$n_components[p]),
        x = "Feature (sorted by group)", y = "Component mean"
      ) +
      .mp_theme()
  })
}

# ---- build catalogue of all plots -------------------------

# Returns a named list; PCA and mu entries are sub-lists of ggplots.
.mp_build_all <- function(dat) {
  list(
    # heatmap                = .mp_plot_heatmap(dat),
    feature_partitions     = .mp_plot_feature_parts(dat),
    observation_partitions = .mp_plot_obs_parts(dat),
    pca                    = .mp_plot_pca(dat),
    proportions            = .mp_plot_props(dat),
    mahalanobis            = .mp_plot_mahal(dat),
    component_means        = .mp_plot_mu(dat)
  )
}

# Resolve `which` argument to a character vector of plot names
.mp_resolve_which <- function(which_arg) {
  plot_names <- c(
    # "heatmap",
    "feature_partitions", "observation_partitions",
    "pca", "proportions", "mahalanobis", "component_means"
  )
  if (identical(which_arg, "all")) return(plot_names)
  if (is.numeric(which_arg)) {
    idx <- as.integer(which_arg)
    bad <- idx[idx < 1 | idx > length(plot_names)]
    if (length(bad))
      # stop("Plot indices out of range [1, 7]: ", paste(bad, collapse = ", "),
      stop("Plot indices out of range [1, 6]: ", paste(bad, collapse = ", "),
           call. = FALSE)
    return(plot_names[idx])
  }
  if (is.character(which_arg)) {
    bad <- setdiff(which_arg, plot_names)
    if (length(bad))
      stop("Unknown plot name(s): ", paste(bad, collapse = ", "),
           "\nValid names: ", paste(plot_names, collapse = ", "),
           call. = FALSE)
    return(which_arg)
  }
  # stop("`which` must be \"all\", an integer vector 1-7, or a character vector of plot names.",
  stop("`which` must be \"all\", an integer vector 1-6, or a character vector of plot names.",
       call. = FALSE)
}

# ---- interactive rendering (used by plot.MPObject) ---------

.mp_print_entry <- function(entry, name) {
  if (inherits(entry, "gg")) {
    print(entry)
    return(invisible(NULL))
  }

  if (is.list(entry) && all(vapply(entry, inherits, logical(1), "gg"))) {
    n   <- length(entry)
    ttl <- switch(name,
                  pca             = "PCA of X  (noise features excluded)",
                  component_means = "Component mean structure",
                  name)
    subttl <- if (name == "component_means")
      paste0(
        "Each line = one component's mean across all M features, sorted by feature group.\n",
        "Lines that diverge inside a group indicate that this group drives component separation. ",
        "Dashed vertical lines = feature-group boundaries."
      )
    else NULL

    plots_grob <- gridExtra::arrangeGrob(grobs = entry, ncol = min(n, 2))

    if (!is.null(subttl)) {
      header_grob <- gridExtra::arrangeGrob(
        grid::textGrob(ttl, x = 0.02, hjust = 0,
                       gp = grid::gpar(fontface = "bold", fontsize = 13)),
        grid::textGrob(subttl, x = 0.02, hjust = 0,
                       gp = grid::gpar(fontsize = 9, lineheight = 1.15, col = "grey40")),
        ncol    = 1,
        heights = grid::unit(c(0.7, 1.5), "cm")
      )
      gridExtra::grid.arrange(
        header_grob, plots_grob,
        ncol    = 1,
        heights = grid::unit(c(2.5, 1), c("cm", "null"))
      )
    } else {
      gridExtra::grid.arrange(
        grid::textGrob(ttl, gp = grid::gpar(fontface = "bold", fontsize = 13)),
        plots_grob,
        ncol    = 1,
        heights = grid::unit(c(0.8, 1), c("cm", "null"))
      )
    }
    return(invisible(NULL))
  }

  warning("Could not render plot '", name, "'.")
}

# ---- grob conversion (single ggplot or list -> one grob) ---

# Used by the landscape renderer for single-panel plot entries.
.mp_entry_to_grob <- function(entry, name) {
  if (inherits(entry, "gg")) {
    return(ggplot2::ggplotGrob(entry))
  }
  if (is.list(entry) && all(vapply(entry, inherits, logical(1), "gg"))) {
    n   <- length(entry)
    ttl <- switch(name,
                  pca             = "PCA of X  (noise features excluded)",
                  component_means = "Component mean structure",
                  name)
    return(gridExtra::arrangeGrob(
      grid::textGrob(ttl, x = 0.02, hjust = 0,
                     gp = grid::gpar(fontface = "bold", fontsize = 12)),
      gridExtra::arrangeGrob(grobs = entry, ncol = min(n, 2)),
      ncol    = 1,
      heights = grid::unit(c(0.8, 1), c("cm", "null"))
    ))
  }
  grid::nullGrob()
}

# ---- margined page draw ------------------------------------

# Draws `grob` onto a new PDF page inside a 1-inch margin on all sides.
.mp_draw_margined <- function(grob, page_w, page_h, margin = 1) {
  grid::grid.newpage()
  grid::pushViewport(grid::viewport(
    x      = grid::unit(margin, "inches"),
    y      = grid::unit(margin, "inches"),
    width  = grid::unit(page_w - 2 * margin, "inches"),
    height = grid::unit(page_h - 2 * margin, "inches"),
    just   = c("left", "bottom")
  ))
  grid::grid.draw(grob)
  grid::popViewport()
}

# ---- pagination helper (adaptive layout) -------------------

# Splits a list of ggplots into pages of `per_page` each.
# Returns a list of grobs ready for .mp_draw_margined().
.mp_paginate_plots <- function(plot_list, per_page, layout_ncol,
                               title, subtitle = NULL) {
  n     <- length(plot_list)
  n_pgs <- ceiling(n / per_page)

  lapply(seq_len(n_pgs), function(i) {
    idx   <- seq((i - 1L) * per_page + 1L, min(i * per_page, n))
    grobs <- plot_list[idx]

    while (length(grobs) < per_page)
      grobs <- c(grobs, list(grid::nullGrob()))

    pg_title <- if (n_pgs > 1L)
      sprintf("%s  (%d / %d)", title, i, n_pgs)
    else
      title

    plots_grob <- gridExtra::arrangeGrob(grobs = grobs, ncol = layout_ncol)

    if (!is.null(subtitle)) {
      header <- gridExtra::arrangeGrob(
        grid::textGrob(pg_title, x = 0.02, hjust = 0,
                       gp = grid::gpar(fontface = "bold", fontsize = 12)),
        grid::textGrob(subtitle, x = 0.02, hjust = 0,
                       gp = grid::gpar(fontsize = 9, lineheight = 1.1,
                                       col = "grey40")),
        ncol    = 1,
        heights = grid::unit(c(0.7, 1.5), "cm")
      )
      gridExtra::arrangeGrob(header, plots_grob,
                             ncol    = 1,
                             heights = grid::unit(c(2.5, 1), c("cm", "null")))
    } else {
      gridExtra::arrangeGrob(
        grid::textGrob(pg_title, x = 0.02, hjust = 0,
                       gp = grid::gpar(fontface = "bold", fontsize = 12)),
        plots_grob,
        ncol    = 1,
        heights = grid::unit(c(0.8, 1), c("cm", "null"))
      )
    }
  })
}

# ---- summary table grob ------------------------------------

# Page 1: bold title + one-line meta + per-profile tableGrob.
.mp_summary_table_grob <- function(dat) {
  s <- dat$settings
  P <- s$P

  rows <- lapply(seq_len(P), function(p) {
    D   <- dat$achieved_mahalanobis[[p]]
    dv  <- D[upper.tri(D)]
    mah <- if (length(dv) == 0) "n/a (K=1)"
            else sprintf("%.3f / %.1f", median(dv), s$dist_mahalanobis[p])
    ari <- if (p == 1) "reference"
            else sprintf("%.3f / %.3f",
                         dat$achieved_ari_features[1, p],
                         .mp_scalar_target_ari(dat, p))
    mix_str  <- paste(round(s$mixing_proportions[[p]], 2),        collapse = ", ")
    feat_str <- paste(round(s$feature_group_proportions[[p]], 2), collapse = ", ")
    data.frame(
      "Profile"                        = sprintf("P%d", p),
      "K"                              = s$n_components[p],
      "Mixing proportions"             = mix_str,
      "L"                              = s$n_feature_patterns[p],
      "Feature group proportions"      = feat_str,
      "Mahalanobis\n(achieved/target)" = mah,
      "ARI\n(achieved/target)"         = ari,
      "Cov"                            = s$covariance_spec$type,
      check.names      = FALSE,
      stringsAsFactors = FALSE
    )
  })
  df <- do.call(rbind, rows)

  title_grob <- grid::textGrob(
    "genMPGMM -- Generated dataset summary",
    x = 0, hjust = 0,
    gp = grid::gpar(fontface = "bold", fontsize = 14)
  )

  noise_str <- if (s$add_noise)
    sprintf("Additive noise: TRUE (sd = %g)", s$noise_sd)
  else
    "Additive noise: FALSE"

  meta <- sprintf(
    "M = %d features  x  N = %d observations  |  P = %d profiles  |  Noise features: %d (%.0f %%)  |  %s",
    s$M, s$N, P,
    length(dat$noise_feature_indices),
    100 * s$noise_feature_fraction,
    noise_str
  )
  meta_grob <- grid::textGrob(
    meta, x = 0, hjust = 0,
    gp = grid::gpar(fontsize = 10, col = "grey35")
  )

  row_fills <- rep_len(c("white", "#f0f0f0"), P)
  tbl_grob <- gridExtra::tableGrob(
    df, rows = NULL,
    theme = gridExtra::ttheme_default(
      base_size = 10,
      core    = list(bg_params = list(fill = row_fills, col = "grey80"),
                     fg_params = list(hjust = 0, x = 0.05)),
      colhead = list(bg_params = list(fill = "white", col = "grey80"),
                     fg_params = list(col = "black", fontface = "bold",
                                      hjust = 0, x = 0.05))
    )
  )
  # Stretch table to fill full available width (8 columns, widths sum to 1).
  tbl_grob$widths <- grid::unit(
    c(0.07, 0.04, 0.20, 0.04, 0.20, 0.17, 0.17, 0.11), "npc"
  )

  gridExtra::arrangeGrob(
    title_grob,
    meta_grob,
    tbl_grob,
    ncol    = 1,
    heights = grid::unit(c(0.9, 0.6, 1, 1), c("cm", "cm", "null", "null"))
  )
}

# ---- landscape renderer ------------------------------------

# A4 landscape (11.69 x 8.27 in):
#   Page 1        : summary table
#   Pages per plot: one page each for scalar plot entries
#   Pages +       : PCA -- 2 profiles per page, side by side
#   Pages +       : component means -- 1 profile per page
.mp_render_landscape <- function(plots, dat, selected, page_w, page_h) {
  mu_subtitle <- paste0(
    "Each line = one component's mean across all M features, sorted by feature group.\n",
    "Lines that diverge inside a group indicate that this group drives component separation.  ",
    "Dashed vertical lines = feature-group boundaries."
  )

  .mp_draw_margined(.mp_summary_table_grob(dat), page_w, page_h)

  for (nm in selected) {
    if (nm == "pca") {
      for (pg in .mp_paginate_plots(plots$pca, per_page = 2L, layout_ncol = 2L,
                                    title = "PCA of X  (noise features excluded)"))
        .mp_draw_margined(pg, page_w, page_h)

    } else if (nm == "component_means") {
      for (pg in .mp_paginate_plots(plots$component_means, per_page = 1L,
                                    layout_ncol = 1L,
                                    title    = "Component mean structure",
                                    subtitle = mu_subtitle))
        .mp_draw_margined(pg, page_w, page_h)

    } else {
      .mp_draw_margined(.mp_entry_to_grob(plots[[nm]], nm), page_w, page_h)
    }
  }

  invisible(NULL)
}

# ============================================================
# Public: plot.MPObject
# ============================================================

#' Plot a multi-profile GMM object
#'
#' Displays up to seven diagnostic plots for an object of class
#' \code{"MPObject"}.  Use \code{which} to select a subset.
#'
#' @section Plots available:
#' \describe{
#'   \item{1 / "heatmap"}{Data matrix \code{X}, rows sorted by profile-1 feature
#'     group, columns by profile-1 component.  Reveals block structure.}
#'   \item{2 / "feature_partitions"}{One coloured bar per profile showing which
#'     feature belongs to which group.  ARI between profiles is annotated.}
#'   \item{3 / "observation_partitions"}{One coloured bar per profile showing
#'     the component assignment of each observation.}
#'   \item{4 / "pca"}{PCA scatter of observations coloured by component
#'     assignment (one panel per profile).}
#'   \item{5 / "proportions"}{Achieved vs requested mixing and feature-group
#'     proportions for every profile.}
#'   \item{6 / "mahalanobis"}{Tile matrix of pairwise Mahalanobis distances
#'     between component means for each profile.}
#'   \item{7 / "component_means"}{Component mean profiles across features
#'     for each profile (one panel per profile).}
#' }
#'
#' @param x An object of class \code{"MPObject"}.
#' @param which Plots to display.  \code{"all"} (default), an integer vector
#'   \code{1:7}, or a character vector of plot names (see Details).
#' @param ask If \code{TRUE} (default when session is interactive), pause
#'   between plots.
#' @param ... Currently unused.
#'
#' @return Invisibly returns a named list of the built \code{ggplot} objects.
#'
#' @examples
#' \dontrun{
#' dat <- genMPGMM(
#'   n_feature_patterns = c(2, 2), n_components = c(2, 2),
#'   feature_group_proportions = list(c(0.5, 0.5), c(0.5, 0.5)),
#'   mixing_proportions = list(c(0.5, 0.5), c(0.5, 0.5)),
#'   dist_mahalanobis = 3, target_ari = c(1, 0.3),
#'   M = 60, N = 80, covariance_spec = list(type = "diagonal"),
#'   noise_feature_fraction = 0, seed = 1
#' )
#' plot(dat)                        # all plots, interactive
#' plot(dat, which = c(1, 4, 6))    # heatmap, PCA, Mahalanobis only
#' }
#'
#' @export
plot.MPObject <- function(x, which = "all", ask = interactive(), ...) {
  .mp_check_deps()
  selected <- .mp_resolve_which(which)
  plots    <- .mp_build_all(x)

  if (ask && length(selected) > 1) {
    oask <- grDevices::devAskNewPage(TRUE)
    on.exit(grDevices::devAskNewPage(oask))
  }

  for (nm in selected) {
    .mp_print_entry(plots[[nm]], nm)
  }

  invisible(plots[selected])
}

# ============================================================
# Public: report_MPObject
# ============================================================

#' Save a diagnostic PDF report for a multi-profile GMM object
#'
#' Writes an A4 landscape PDF whose layout adapts automatically to any number
#' of profiles (P) and components (K).  A summary table is followed by one
#' page per plot section; PCA panels and component-mean plots are paginated so
#' individual panels remain readable even for large P.
#'
#' Page sequence (use \code{which} to include a subset):
#' \enumerate{
#'   \item Summary table -- one row per profile (always included)
#'   \item Heatmap of data matrix \code{X}
#'   \item Feature partitions per profile
#'   \item Observation (component) partitions per profile
#'   \item Achieved vs target proportions
#'   \item Pairwise Mahalanobis distances
#'   \item PCA -- 2 profiles per page, side by side (paginated)
#'   \item Component means -- 1 profile per page (paginated)
#' }
#'
#' @param x An object of class \code{"MPObject"}.
#' @param file Path for the output PDF.  Defaults to \code{"mpgmm_report.pdf"}
#'   in the current working directory.
#' @param which Plots to include.  \code{"all"} (default), an integer vector
#'   \code{1:7}, or a character vector of plot names.
#'   See \code{\link{plot.MPObject}} for the full list.
#' @param open If \code{TRUE} (default when session is interactive), attempt
#'   to open the PDF after saving using the system viewer.
#' @param ... Currently unused.
#'
#' @return Invisibly returns the path to the saved PDF.
#'
#' @examples
#' \dontrun{
#' dat <- genMPGMM(
#'   n_feature_patterns = c(2, 2), n_components = c(2, 2),
#'   feature_group_proportions = list(c(0.5, 0.5), c(0.5, 0.5)),
#'   mixing_proportions = list(c(0.5, 0.5), c(0.5, 0.5)),
#'   dist_mahalanobis = 3, target_ari = c(1, 0.3),
#'   M = 60, N = 80, covariance_spec = list(type = "diagonal"),
#'   noise_feature_fraction = 0, seed = 1
#' )
#'
#' # Full report (landscape A4, all plots)
#' report_MPObject(dat)
#'
#' # Selected plots only
#' report_MPObject(dat, which = c(1, 4, 6), file = "report_partial.pdf")
#' }
#'
#' @export
report_MPObject <- function(x,
                            file  = "mpgmm_report.pdf",
                            which = "all",
                            open  = interactive(),
                            ...) {
  .mp_check_deps()
  selected <- .mp_resolve_which(which)
  plots    <- .mp_build_all(x)
  file     <- normalizePath(file, mustWork = FALSE)

  grDevices::pdf(file, width = 11.69, height = 8.27, onefile = TRUE)
  tryCatch(
    .mp_render_landscape(plots, x, selected, 11.69, 8.27),
    finally = grDevices::dev.off()
  )

  message("Report saved to:\n  ", file)
  if (open)
    tryCatch(
      utils::browseURL(paste0("file:///", gsub("\\\\", "/", file))),
      error = function(e) NULL
    )

  invisible(file)
}
