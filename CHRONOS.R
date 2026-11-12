################################################################################
# CHRONOS.R
#
# Modelling Neolithic production and circulation of obsidian in the Central
# Mediterranean.
#
# This script reproduces the analyses documented in CHRONOS_report.html:
#   1. read and clean obsidian technological/source data;
#   2. calculate production-contribution values and production-score ranks;
#   3. evaluate rank structure in Manhattan dissimilarity space;
#   4. build rule-distance network models for two chronological intervals;
#   5. export figures, edge lists, centrality tables, and source-confirmed
#      network summaries.
#
# Repository layout expected by this script:
#
#   CHRONOS/
#   |-- CHRONOS.R              # or SCRIPTS/CHRONOS.R
#   |-- RAWDATA/
#   |-- MAP/
#   |-- OUTPUTS/
#   |-- README.md
#   `-- CHRONOS_report.html
#
# Author: Niccolo Mazzucco, University of Pisa
################################################################################

# ==============================================================================
# 0. PACKAGES
# ============================================================================== 

# The script stops with an explicit message if one or more packages are missing.
# This is preferable to installing packages automatically inside a reproducible
# analysis script.

required_packages <- c(
  "openxlsx",
  "dplyr",
  "tidyr",
  "ggplot2",
  "igraph",
  "sf",
  "ggrepel",
  "ggspatial",
  "vegan",
  "units",
  "magick"
)

missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]

if (length(missing_packages) > 0) {
  stop(
    paste0(
      "The following R packages are required but not installed: ",
      paste(missing_packages, collapse = ", "),
      "\nInstall them with:\ninstall.packages(c(",
      paste(sprintf('"%s"', missing_packages), collapse = ", "),
      "))"
    ),
    call. = FALSE
  )
}

library(openxlsx)
library(dplyr)
library(tidyr)
library(ggplot2)
library(igraph)
library(sf)
library(ggrepel)
library(ggspatial)

# ==============================================================================
# 1. PATHS AND GENERAL SETTINGS
# ============================================================================== 

# GitHub-ready path handling:
# The project root is detected automatically. The script works when CHRONOS.R is
# placed either in the repository root or in a SCRIPTS/ folder.

get_script_directory <- function() {
  command_args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", command_args, value = TRUE)
  
  if (length(file_arg) > 0) {
    return(dirname(normalizePath(sub("^--file=", "", file_arg[1]))))
  }
  
  if (requireNamespace("rstudioapi", quietly = TRUE)) {
    active_file <- tryCatch(rstudioapi::getActiveDocumentContext()$path, error = function(e) "")
    if (!is.null(active_file) && nzchar(active_file)) {
      return(dirname(normalizePath(active_file)))
    }
  }
  
  return(normalizePath(getwd()))
}

find_project_root <- function(start_dir) {
  candidates <- unique(normalizePath(c(start_dir, dirname(start_dir)), mustWork = FALSE))
  
  for (candidate in candidates) {
    if (dir.exists(file.path(candidate, "RAWDATA")) && dir.exists(file.path(candidate, "MAP"))) {
      return(candidate)
    }
  }
  
  stop(
    paste0(
      "Project root not found. Run the script from the CHRONOS repository root, ",
      "or place it in CHRONOS/SCRIPTS/. Expected folders: RAWDATA/ and MAP/."
    ),
    call. = FALSE
  )
}

script_dir <- get_script_directory()
chronos_base <- find_project_root(script_dir)

rawdata_folder <- file.path(chronos_base, "RAWDATA")
map_folder     <- file.path(chronos_base, "MAP")
output_folder  <- file.path(chronos_base, "OUTPUTS")

if (!dir.exists(output_folder)) dir.create(output_folder, recursive = TRUE)

map_file <- file.path(map_folder, "map_shp.shp")

# Input files in RAWDATA/
input_all        <- file.path(rawdata_folder, "obs_data_corr.xlsx")
input_6100_5500  <- file.path(rawdata_folder, "obs_data_corr_6100_5500.xlsx")
input_5500_4900  <- file.path(rawdata_folder, "obs_data_corr_5500_4900.xlsx")

# Output folders in OUTPUTS/
output_6100_5500 <- file.path(output_folder, "Obsidian_network_6100_5500")
output_5500_4900 <- file.path(output_folder, "Obsidian_network_5500_4900")

if (!dir.exists(output_6100_5500)) dir.create(output_6100_5500, recursive = TRUE)
if (!dir.exists(output_5500_4900)) dir.create(output_5500_4900, recursive = TRUE)

# Check required input files early, before running the analysis.
required_input_files <- c(input_all, input_6100_5500, input_5500_4900)
missing_input_files <- required_input_files[!file.exists(required_input_files)]

if (length(missing_input_files) > 0) {
  stop(
    paste0("Missing input file(s):\n", paste(missing_input_files, collapse = "\n")),
    call. = FALSE
  )
}

if (!file.exists(map_file)) {
  warning(paste("Map shapefile not found:", map_file))
}

# ------------------------------------------------------------------------------
# 1a. Technological variables
# ------------------------------------------------------------------------------

tech_vars <- c("blade", "flake", "core", "by.products.waste")

# ------------------------------------------------------------------------------
# 1b. Colour settings used consistently in all maps and graphs
# ------------------------------------------------------------------------------

rank_palette <- c(
  "1" = "#F9C04E",  # low documented technological involvement
  "2" = "#6F9FE9",  # intermediate documented technological involvement
  "3" = "#7CAE7A",  # high documented technological involvement
  "4" = "#D95F3F"   # raw-material source
)

rank_shapes <- c(
  "1" = 21,
  "2" = 22,
  "3" = 24,
  "4" = 23
)

map_land_fill <- "lightyellow"
map_land_border <- "grey60"

# ------------------------------------------------------------------------------
# 1c. Obsidian source columns
# ------------------------------------------------------------------------------

source_columns <- c("Sardegna", "Lipari", "Palmarola")

set.seed(123)

# ==============================================================================
# 2. SMALL UTILITY FUNCTIONS
# ==============================================================================

# ------------------------------------------------------------------------------
# 2a. Read data
# ------------------------------------------------------------------------------

read_obsidian_file <- function(input_file) {
  
  file_ext <- tolower(tools::file_ext(input_file))
  
  if (file_ext %in% c("xlsx", "xlsm")) {
    
    raw_data <- openxlsx::read.xlsx(
      input_file,
      sheet = 1,
      colNames = TRUE,
      rowNames = FALSE,
      detectDates = FALSE
    )
    
  } else if (file_ext == "csv") {
    
    raw_data <- read.csv(
      input_file,
      header = TRUE,
      sep = ";",
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
    
    if (ncol(raw_data) == 1) {
      raw_data <- read.csv(
        input_file,
        header = TRUE,
        sep = ",",
        stringsAsFactors = FALSE,
        check.names = FALSE
      )
    }
    
    if (ncol(raw_data) == 1) {
      raw_data <- read.csv(
        input_file,
        header = TRUE,
        sep = "\t",
        stringsAsFactors = FALSE,
        check.names = FALSE
      )
    }
    
  } else {
    stop(paste("Unsupported file type:", input_file))
  }
  
  names(raw_data) <- make.names(names(raw_data), unique = TRUE)
  
  return(raw_data)
}

# ------------------------------------------------------------------------------
# 2b. Clean data
# ------------------------------------------------------------------------------

clean_obsidian_table <- function(x) {
  x <- as.data.frame(x)
  
  # Standardise site-name column
  if ("sites" %in% names(x)) {
    x$sites <- x$sites
  } else if ("Sites" %in% names(x)) {
    names(x)[names(x) == "Sites"] <- "sites"
  } else if ("site" %in% names(x)) {
    names(x)[names(x) == "site"] <- "sites"
  } else if ("Site" %in% names(x)) {
    names(x)[names(x) == "Site"] <- "sites"
  } else {
    x$sites <- rownames(x)
  }
  
  x$sites <- trimws(as.character(x$sites))
  x$Long  <- as.numeric(gsub(",", ".", as.character(x$Long)))
  x$Lat   <- as.numeric(gsub(",", ".", as.character(x$Lat)))

  for (v in tech_vars) {
    if (!v %in% names(x)) stop(paste("Missing technological variable:", v))
    x[[v]] <- as.numeric(gsub(",", ".", as.character(x[[v]])))
  }

  if (!"tot.no.ind" %in% names(x)) stop("Missing column: tot.no.ind")
  x$tot.no.ind <- as.numeric(gsub(",", ".", as.character(x$tot.no.ind)))

  # Missing technological information must not be silently treated as a genuine
  # archaeological absence. A value of 0 means documented absence; NA means that
  # the count is unknown/not available and cannot enter the ranking analysis.
  missing_tech <- x %>%
    filter(if_any(all_of(tech_vars), is.na))

  if (nrow(missing_tech) > 0) {
    stop(
      paste0(
        "Missing technological counts detected for: ",
        paste(unique(missing_tech$sites), collapse = ", "),
        ". Use 0 only for documented absence; unresolved/unpublished counts must remain NA and be resolved or excluded before ranking."
      ),
      call. = FALSE
    )
  }

  # Source columns, when present, are converted to numeric presence/absence.
  # 1 = source present; 0 = source absent; NA = unknown/not analysed.
  for (cc in intersect(source_columns, names(x))) {
    x[[cc]] <- as.numeric(gsub(",", ".", as.character(x[[cc]])))
  }

  x <- x %>%
    filter(!is.na(sites), sites != "") %>%
    filter(!is.na(Long), !is.na(Lat)) %>%
    filter(!is.na(tot.no.ind), tot.no.ind > 0)

  return(x)
}

# ==============================================================================
# 3. NETWORK NODE UTILITIES
# ==============================================================================

# ------------------------------------------------------------------------------
# 3a. Manually add original sources.
# ------------------------------------------------------------------------------

add_rank4_sources <- function(site_table) {
  raw_materials <- data.frame(
    sites = c("Monte Arci", "Lipari", "Palmarola"),
    Long = c(8.74500, 14.95544, 12.85806),
    Lat = c(39.77778, 38.46728, 40.93694),
    Rank = c(4, 4, 4),
    Sardegna = c(1, NA, NA),
    Lipari = c(NA, 1, NA),
    Palmarola = c(NA, NA, 1),
    stringsAsFactors = FALSE
  )

  missing_source_cols <- setdiff(source_columns, names(site_table))
  for (cc in missing_source_cols) site_table[[cc]] <- NA

  keep_cols <- c("sites", "Long", "Lat", "Rank", source_columns)
  site_table2 <- site_table[, keep_cols]
  out <- bind_rows(site_table2, raw_materials)
  out$sites <- trimws(as.character(out$sites))
  rownames(out) <- out$sites
  return(out)
}

# ==============================================================================
# 4. CREATE EDGES AND NETWORKS
# ==============================================================================

create_edges_by_distance_and_rank <- function(nodes, allowed_connections, max_distance_km) {
  # This version uses centre-to-centre distances, not overlapping buffers.
  # Therefore max_distance_km is the actual maximum distance between sites.

  nodes_sf <- st_as_sf(nodes, coords = c("Long", "Lat"), crs = 4326, remove = FALSE)
  nodes_sf <- st_transform(nodes_sf, 3035)  # ETRS89 / LAEA Europe, suitable for broad European distances.

  dist_matrix <- units::drop_units(st_distance(nodes_sf, nodes_sf)) / 1000

  edges <- data.frame(from = character(0), to = character(0), stringsAsFactors = FALSE)

  for (i in seq_len(nrow(nodes))) {
    for (j in seq_len(nrow(nodes))) {
      if (i != j && dist_matrix[i, j] <= max_distance_km) {
        connection_ij <- paste0(nodes$Rank[i], "-", nodes$Rank[j])

        if (connection_ij %in% allowed_connections) {
          edges <- rbind(
            edges,
            data.frame(
              from = nodes$sites[i],
              to = nodes$sites[j],
              stringsAsFactors = FALSE
            )
          )
        }
      }
    }
  }

  edges <- distinct(edges)
  return(edges)
}

# ------------------------------------------------------------------------------
# 4a. Build Networks.
# ------------------------------------------------------------------------------

build_network <- function(nodes, allowed_connections, max_distance_km, network_name) {
  edges <- create_edges_by_distance_and_rank(nodes, allowed_connections, max_distance_km)

  g <- graph_from_data_frame(
    d = edges,
    directed = FALSE,
    vertices = nodes
  )

  E(g)$distance_rule_km <- max_distance_km
  graph_attr(g, "network_name") <- network_name
  graph_attr(g, "allowed_connections") <- paste(allowed_connections, collapse = ", ")

  return(g)
}

summarise_network <- function(g, network_name) {
  
  g_und <- igraph::as.undirected(g, mode = "collapse")
  
  comps <- igraph::components(g_und)
  
  n_vertices <- igraph::vcount(g_und)
  n_edges <- igraph::ecount(g_und)
  n_components <- comps$no
  n_isolates <- sum(igraph::degree(g_und) == 0)
  largest_component_size <- max(comps$csize)
  
  data.frame(
    Network = network_name,
    Nodes = n_vertices,
    Edges = n_edges,
    Components = n_components,
    Isolates = n_isolates,
    Largest_Component_Size = largest_component_size,
    Connected_All_Sites = n_components == 1,
    stringsAsFactors = FALSE
  )
}

centrality_table <- function(g, network_name) {
  gu <- as_undirected(g, mode = "collapse")

  # Standard closeness is difficult to interpret in disconnected graphs and may
  # return NaN for isolates. Harmonic centrality is included because it is safer
  # for disconnected archaeological networks.
  closeness_value <- closeness(gu, normalized = TRUE)
  harmonic_value <- harmonic_centrality(gu, normalized = TRUE)

  data.frame(
    sites = V(gu)$name,
    Network = network_name,
    Rank = V(gu)$Rank,
    Degree = degree(gu, mode = "all"),
    Betweenness = betweenness(gu, directed = FALSE, normalized = TRUE),
    Closeness = closeness_value,
    Harmonic = harmonic_value,
    Eigenvector = eigen_centrality(gu, directed = FALSE)$vector,
    stringsAsFactors = FALSE
  )
}

# ------------------------------------------------------------------------------
# 4b. Plot Networks Maps.
# ------------------------------------------------------------------------------

plot_network_map <- function(g, nodes, title, output_file) {
  
  edges <- as_data_frame(g, what = "edges")
  
  if (file.exists(map_file)) {
    map_shp <- st_read(map_file, quiet = TRUE)
  } else {
    map_shp <- NULL
  }
  
  nodes_sf <- st_as_sf(nodes, coords = c("Long", "Lat"), crs = 4326, remove = FALSE)
  node_xy <- cbind(nodes, st_coordinates(nodes_sf))
  
  node_xy$Rank <- factor(node_xy$Rank, levels = c(1, 2, 3, 4))
  
  if (nrow(edges) > 0) {
    edge_xy <- edges %>%
      left_join(node_xy %>% select(sites, X, Y), by = c("from" = "sites")) %>%
      rename(X_from = X, Y_from = Y) %>%
      left_join(node_xy %>% select(sites, X, Y), by = c("to" = "sites")) %>%
      rename(X_to = X, Y_to = Y)
  } else {
    edge_xy <- data.frame()
  }
  
  p <- ggplot()
  
  if (!is.null(map_shp)) {
    p <- p +
      geom_sf(
        data = map_shp,
        fill = map_land_fill,
        colour = map_land_border,
        linewidth = 0.2
      )
  }
  
  if (nrow(edge_xy) > 0) {
    p <- p +
      geom_segment(
        data = edge_xy,
        aes(x = X_from, y = Y_from, xend = X_to, yend = Y_to),
        linewidth = 0.25,
        alpha = 0.45,
        colour = "grey35"
      )
  }
  
  p <- p +
    geom_point(
      data = node_xy,
      aes(
        x = X,
        y = Y,
        fill = Rank,
        colour = Rank,
        shape = Rank,
        size = Rank
      ),
      alpha = 0.9,
      stroke = 0.35
    ) +
    scale_fill_manual(values = rank_palette) +
    scale_colour_manual(values = rank_palette) +
    scale_shape_manual(values = rank_shapes) +
    scale_size_manual(
      values = c(
        "1" = 2.0,
        "2" = 2.8,
        "3" = 3.6,
        "4" = 4.6
      )
    ) +
    coord_sf() +
    theme_minimal() +
    labs(
      title = title,
      x = "Longitude",
      y = "Latitude",
      fill = "Rank",
      colour = "Rank",
      shape = "Rank",
      size = "Rank"
    ) +
    theme(
      plot.background = element_rect(fill = "white", colour = NA),
      panel.background = element_rect(fill = "white", colour = NA),
      legend.position = "right",
      
      plot.title = element_text(
        size = 9,
        face = "plain",
        margin = margin(
          l = 45,
          b = 6
        )
      )
    )
  
  ggsave(
    output_file,
    p,
    width = 6.8,
    height = 5.5,
    units = "in",
    dpi = 300,
    bg = "white"
  )
  
  return(p)
}

# ------------------------------------------------------------------------------
# 4c. Plot Networks Graphs.
# ------------------------------------------------------------------------------

plot_network_graph_only <- function(g, title, output_file) {
  
  if (vcount(g) == 0) {
    warning(paste("Graph has no vertices:", title))
    return(NULL)
  }
  
  gu <- as_undirected(g, mode = "collapse")
  
  layout_matrix <- layout_with_fr(gu)
  
  node_df <- data.frame(
    sites = V(gu)$name,
    X = layout_matrix[, 1],
    Y = layout_matrix[, 2],
    Rank = factor(V(gu)$Rank, levels = c(1, 2, 3, 4)),
    stringsAsFactors = FALSE
  )
  
  edges <- as_data_frame(gu, what = "edges")
  
  if (nrow(edges) > 0) {
    edge_df <- edges %>%
      left_join(node_df %>% select(sites, X, Y), by = c("from" = "sites")) %>%
      rename(X_from = X, Y_from = Y) %>%
      left_join(node_df %>% select(sites, X, Y), by = c("to" = "sites")) %>%
      rename(X_to = X, Y_to = Y)
  } else {
    edge_df <- data.frame()
  }
  
  p <- ggplot()
  
  if (nrow(edge_df) > 0) {
    p <- p +
      geom_segment(
        data = edge_df,
        aes(x = X_from, y = Y_from, xend = X_to, yend = Y_to),
        linewidth = 0.35,
        alpha = 0.55,
        colour = "grey35"
      )
  }
  
  p <- p +
    geom_point(
      data = node_df,
      aes(x = X, y = Y, fill = Rank, colour = Rank, shape = Rank, size = Rank),
      alpha = 0.95,
      stroke = 0.45
    ) +
    geom_text(
      data = node_df,
      aes(x = X, y = Y, label = sites),
      size = 2.2,
      vjust = -0.8,
      check_overlap = TRUE
    ) +
    scale_fill_manual(values = rank_palette) +
    scale_colour_manual(values = rank_palette) +
    scale_shape_manual(values = rank_shapes) +
    scale_size_manual(values = c("1" = 2.2, "2" = 3.0, "3" = 3.8, "4" = 4.8)) +
    theme_minimal() +
    labs(
      title = title,
      x = NULL,
      y = NULL,
      fill = "Rank",
      colour = "Rank",
      shape = "Rank",
      size = "Rank"
    ) +
    theme(
      axis.text = element_blank(),
      axis.ticks = element_blank(),
      panel.grid = element_blank(),
      plot.background = element_rect(fill = "white", colour = NA),
      panel.background = element_rect(fill = "white", colour = NA),
      legend.position = "right"
    )
  
  ggsave(
    output_file,
    p,
    width = 6.8,
    height = 5.5,
    units = "in",
    dpi = 300,
    bg = "white"
  )
  
  return(p)
}

# ------------------------------------------------------------------------------
# 4d. Source filtering
# ------------------------------------------------------------------------------
# Source-filtered networks are implemented in Section 6.10 using confirmed
# provenance only (source == 1). Unknown provenance (NA) is kept distinct from
# documented absence (0) and is excluded from source-confirmed networks.

# ==============================================================================
# 5. PRODUCTION RANKING ON THE FULL TECHNOLOGICAL DATASET
# ==============================================================================

run_production_ranking <- function(input_file, output_folder, interval_label) {
  
  raw_data <- read_obsidian_file(input_file)
  obs_data <- clean_obsidian_table(raw_data)
  
  # ---------------------------------------------------------------------------
  # 5.1 Percentages within each site assemblage
  # ---------------------------------------------------------------------------
  # These values describe the internal technological composition of each site.
  # They are NOT used for the primary production-score rank assignment.
  # They are used only after classification for ANOVA, Tukey tests, and boxplots.
  
  obs_data_per <- obs_data[, tech_vars] / obs_data$tot.no.ind * 100
  obs_data_per[is.na(obs_data_per)] <- 0
  rownames(obs_data_per) <- obs_data$sites
  
  # ---------------------------------------------------------------------------
  # 5.2 Production-contribution percentages
  # ---------------------------------------------------------------------------
  # Each technological class is normalised by the total amount of that class
  # across the whole dataset.
  #
  # IMPORTANT:
  # These .PN values are NOT row-rescaled.
  # They measure the contribution of each site to total blades, flakes, cores,
  # and by-products/waste. This preserves the documented quantitative scale of involvement.
  
  categories <- tech_vars
  
  for (cat in categories) {
    total_cat <- sum(obs_data[[cat]], na.rm = TRUE)
    
    if (total_cat == 0) {
      obs_data[[paste0(cat, ".PN")]] <- 0
    } else {
      obs_data[[paste0(cat, ".PN")]] <- (obs_data[[cat]] / total_cat) * 100
    }
  }
  
  pn_vars <- paste0(categories, ".PN")
  
  obs_mat2 <- as.matrix(obs_data[, pn_vars])
  rownames(obs_mat2) <- obs_data$sites
  
  write.csv(
    obs_mat2,
    file.path(output_folder, paste0("production_contribution_PN_", interval_label, ".csv")),
    row.names = TRUE
  )
  
  # ---------------------------------------------------------------------------
  # 5.3 Manhattan dissimilarity on production-contribution values
  # ---------------------------------------------------------------------------
  # Pairwise Manhattan distances are calculated directly on the same PN matrix
  # used to derive the production score. This analysis is therefore descriptive
  # and is NOT an independent validation of the production-score ranking.
  
  manhattan_dist <- vegan::vegdist(
    obs_mat2,
    method = "manhattan"
  )
  
  manhattan_matrix <- as.matrix(manhattan_dist)
  
  write.csv(
    manhattan_matrix,
    file.path(output_folder, paste0("manhattan_dissimilarity_PN_", interval_label, ".csv")),
    row.names = TRUE
  )
  
  if (any(is.na(manhattan_matrix))) {
    stop("Manhattan dissimilarity matrix contains NA values. Check the PN matrix.")
  }
  
  # ---------------------------------------------------------------------------
  # 5.4 Production-involvement score and rank assignment
  # ---------------------------------------------------------------------------
  # The final site classification is based on an explicit production-involvement
  # score rather than on unsupervised clustering.
  #
  # The production score is calculated as the row sum of the production-
  # contribution matrix:
  #
  # Production_score = blade.PN + flake.PN + core.PN + by.products.waste.PN
  #
  # Each .PN variable expresses the percentage contribution of a site to the
  # total amount of that technological category in the full dataset.
  # The resulting score therefore estimates the overall quantitative involvement
  # of each site in obsidian production/transformation.
  
  production_score <- rowSums(obs_mat2, na.rm = TRUE)
  
  production_score_table <- data.frame(
    sites = rownames(obs_mat2),
    Production_score = production_score,
    stringsAsFactors = FALSE
  )
  
  write.csv(
    production_score_table,
    file.path(output_folder, paste0("production_score_", interval_label, ".csv")),
    row.names = FALSE
  )
  
  # ---------------------------------------------------------------------------
  # 5.5 Rank thresholds
  # ---------------------------------------------------------------------------
  # Sites are assigned to three analytical ranks according to their position in
  # the production-score distribution:
  #
  # Rank 3 = upper 10% of sites by production score
  # Rank 2 = sites between the 80th and 90th percentiles
  # Rank 1 = all remaining sites
  #
  # This produces reproducible operational classes of documented technological
  # involvement. The percentile boundaries are analytical cut-offs rather than
  # independently established archaeological divisions.
  
  threshold_rank3 <- quantile(
    production_score_table$Production_score,
    probs = 0.90,
    na.rm = TRUE,
    names = FALSE
  )
  
  threshold_rank2 <- quantile(
    production_score_table$Production_score,
    probs = 0.80,
    na.rm = TRUE,
    names = FALSE
  )
  
  threshold_table <- data.frame(
    Threshold = c("Rank_2_minimum", "Rank_3_minimum"),
    Percentile = c(80, 90),
    Production_score = c(threshold_rank2, threshold_rank3),
    stringsAsFactors = FALSE
  )
  
  write.csv(
    threshold_table,
    file.path(output_folder, paste0("production_score_rank_thresholds_", interval_label, ".csv")),
    row.names = FALSE
  )
  
  cluster_assignment <- production_score_table %>%
    mutate(
      Rank = case_when(
        Production_score >= threshold_rank3 ~ 3,
        Production_score >= threshold_rank2 ~ 2,
        TRUE ~ 1
      ),
      Cluster_raw = Rank
    )
  
  write.csv(
    cluster_assignment,
    file.path(output_folder, paste0("site_production_score_ranking_", interval_label, ".csv")),
    row.names = FALSE
  )
  
  # ---------------------------------------------------------------------------
  # 5.6 Sensitivity analysis of assemblage-magnitude effects
  # ---------------------------------------------------------------------------
  # The primary classification intentionally retains assemblage magnitude because
  # the scale of documented obsidian working is part of the archaeological question.
  # A pure within-site relative-frequency transformation would remove that dimension
  # entirely and, because the four percentages sum to 100, cannot be passed through
  # the same additive production-score procedure. Two complementary diagnostics are
  # therefore used here:
  #
  # (a) square-root sensitivity ranking: raw technological counts are square-root
  #     transformed before the same category-wise contribution scaling and percentile
  #     ranking. This reduces the leverage of very large assemblages without removing
  #     quantitative information;
  # (b) composition-only distance diagnostic: within-site percentages are compared
  #     with the primary PN Manhattan distance structure using a Mantel correlation.
  #     This asks whether pairwise technological relationships remain similar after
  #     assemblage magnitude is removed, but it is not used to assign functional ranks.
  
  sqrt_counts <- sqrt(as.matrix(obs_data[, categories]))
  colnames(sqrt_counts) <- categories
  rownames(sqrt_counts) <- obs_data$sites
  
  sqrt_col_totals <- colSums(sqrt_counts, na.rm = TRUE)
  if (any(sqrt_col_totals == 0)) {
    stop("A square-root transformed technological category has a zero total.")
  }
  
  sqrt_contribution <- sweep(sqrt_counts, 2, sqrt_col_totals, "/") * 100
  sqrt_score <- rowSums(sqrt_contribution, na.rm = TRUE)
  sqrt_threshold_rank2 <- unname(quantile(sqrt_score, probs = 0.80, na.rm = TRUE))
  sqrt_threshold_rank3 <- unname(quantile(sqrt_score, probs = 0.90, na.rm = TRUE))
  
  sqrt_rank <- ifelse(
    sqrt_score >= sqrt_threshold_rank3, 3,
    ifelse(sqrt_score >= sqrt_threshold_rank2, 2, 1)
  )
  
  sensitivity_rank_table <- data.frame(
    sites = obs_data$sites,
    Production_score_primary = production_score,
    Rank_primary = cluster_assignment$Rank,
    Production_score_sqrt_sensitivity = sqrt_score,
    Rank_sqrt_sensitivity = sqrt_rank,
    Rank_agreement = cluster_assignment$Rank == sqrt_rank,
    stringsAsFactors = FALSE
  )
  
  write.csv(
    sensitivity_rank_table,
    file.path(output_folder, paste0("sensitivity_rank_comparison_", interval_label, ".csv")),
    row.names = FALSE
  )
  
  rank3_primary <- sensitivity_rank_table$sites[sensitivity_rank_table$Rank_primary == 3]
  rank3_sqrt <- sensitivity_rank_table$sites[sensitivity_rank_table$Rank_sqrt_sensitivity == 3]
  rank2plus_primary <- sensitivity_rank_table$sites[sensitivity_rank_table$Rank_primary >= 2]
  rank2plus_sqrt <- sensitivity_rank_table$sites[sensitivity_rank_table$Rank_sqrt_sensitivity >= 2]
  
  jaccard_index <- function(a, b) {
    u <- union(a, b)
    if (length(u) == 0) return(NA_real_)
    length(intersect(a, b)) / length(u)
  }
  
  composition_dist <- vegan::vegdist(
    as.matrix(obs_data_per),
    method = "manhattan"
  ) / 200
  
  mantel_composition <- vegan::mantel(
    manhattan_dist,
    composition_dist,
    method = "spearman",
    permutations = 999
  )
  
  sensitivity_summary <- data.frame(
    Metric = c(
      "Spearman_primary_vs_sqrt_scores",
      "Exact_rank_agreement",
      "Rank3_Jaccard_overlap",
      "Rank2plus_Jaccard_overlap",
      "Mantel_r_primary_vs_composition_distances",
      "Mantel_p_primary_vs_composition_distances"
    ),
    Value = c(
      suppressWarnings(cor(production_score, sqrt_score, method = "spearman")),
      mean(sensitivity_rank_table$Rank_agreement),
      jaccard_index(rank3_primary, rank3_sqrt),
      jaccard_index(rank2plus_primary, rank2plus_sqrt),
      unname(mantel_composition$statistic),
      mantel_composition$signif
    ),
    stringsAsFactors = FALSE
  )
  
  write.csv(
    sensitivity_summary,
    file.path(output_folder, paste0("sensitivity_summary_", interval_label, ".csv")),
    row.names = FALSE
  )
  
  write.csv(
    as.matrix(composition_dist),
    file.path(output_folder, paste0("composition_only_manhattan_dissimilarity_", interval_label, ".csv")),
    row.names = TRUE
  )
  
  cat("\nSensitivity analysis (primary vs square-root-transformed counts):\n")
  print(sensitivity_summary)
  cat("\nSites changing rank under square-root sensitivity analysis:\n")
  print(sensitivity_rank_table %>% filter(!Rank_agreement))
  
  # ---------------------------------------------------------------------------
  # 5.7 Attach production-score ranks to the site table
  # ---------------------------------------------------------------------------
  
  obs_ranked <- obs_data %>%
    left_join(cluster_assignment, by = "sites") %>%
    left_join(
      sensitivity_rank_table %>%
        select(sites, Production_score_sqrt_sensitivity, Rank_sqrt_sensitivity),
      by = "sites"
    )
  
  # Keep compatibility columns for the rest of the script
  obs_ranked$Cluster <- obs_ranked$Rank
  obs_ranked$Cluster_raw <- obs_ranked$Cluster_raw
  
  write.csv(
    obs_ranked,
    file.path(output_folder, paste0("ranked_sites_", interval_label, ".csv")),
    row.names = FALSE
  )
  
  rank_summary <- obs_ranked %>%
    count(Rank, name = "n_sites") %>%
    arrange(Rank)
  
  write.csv(
    rank_summary,
    file.path(output_folder, paste0("rank_summary_", interval_label, ".csv")),
    row.names = FALSE
  )
  
  cat("\nProduction-score rank summary:\n")
  print(rank_summary)
  
  # ---------------------------------------------------------------------------
  # 5.8 Descriptive Manhattan diagnostic of production-score ranks
  # ---------------------------------------------------------------------------
  # The Manhattan dissimilarity matrix is derived from the same PN contribution
  # matrix as the production score. It is therefore a descriptive diagnostic,
  # not an independent validation of the classification.
  
  diagnostic_dist <- manhattan_dist
  
  # ---------------------------------------------------------------------------
  # 5.8a PERMANOVA-style description of rank differences in Manhattan space
  # ---------------------------------------------------------------------------
  # This exploratory test evaluates whether production-score ranks correspond
  # to significant differences in multivariate technological profiles.
  
  adonis_data <- data.frame(