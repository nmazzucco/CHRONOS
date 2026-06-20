################################################################################
# CHRONOS.R
#
# Modelling Neolithic production and circulation of obsidian in the Central
# Mediterranean.
#
# This script reproduces the analyses documented in CHRONOS_report.html:
#   1. read and clean obsidian technological/source data;
#   2. calculate production-contribution values and production-score ranks;
#   3. evaluate rank structure in Brainerd-Robinson dissimilarity space;
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
  "units"
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
  "1" = "#F9C04E",  # low production involvement / consumer
  "2" = "#6F9FE9",  # intermediate involvement
  "3" = "#7CAE7A",  # high production involvement / producer
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
# 3. BRAINERD_ROBINSON SIMILARITY FOR PERCENTAGE COMPOSITION.
# ==============================================================================

br_similarity <- function(mat_percent) {

  mat_percent <- as.matrix(mat_percent)
  d <- as.matrix(dist(mat_percent, method = "manhattan"))
  br <- 1 - (d / 200)
  br[br < 0] <- 0
  diag(br) <- 1
  return(br)
}

row_rescale_to_100 <- function(x) {
  x <- as.data.frame(x)
  rs <- rowSums(x, na.rm = TRUE)
  out <- sweep(x, 1, rs, "/") * 100
  out[is.na(out)] <- 0
  return(out)
}

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
    directed = TRUE,
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
    scale_size_manual(values = c("1" = 2.0, "2" = 2.8, "3" = 3.6, "4" = 4.6)) +
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
# 4d. Filter networks by source (Lipari, Palmarola, Monte Arci)
# ------------------------------------------------------------------------------

filter_network_by_source <- function(g, nodes, source_col, source_label, source_node_name) {
  
  gu <- as_undirected(g, mode = "collapse")
  
  nodes_for_filter <- nodes %>%
    mutate(
      source_value = .data[[source_col]],
      is_selected_source_node = Rank == 4 & sites == source_node_name,
      is_other_source_node = Rank == 4 & sites != source_node_name
    )
  
  # Keep:
  # - the selected source node;
  # - archaeological sites with confirmed presence of the source;
  # - archaeological sites with unknown source attribution;
  # Remove:
  # - sites with explicit absence of the source;
  # - other raw-material source nodes.
  eligible_nodes <- nodes_for_filter %>%
    filter(
      !is_other_source_node,
      is_selected_source_node |
        is.na(source_value) |
        source_value != 0
    ) %>%
    pull(sites)
  
  subgraph <- induced_subgraph(
    gu,
    vids = V(gu)[name %in% eligible_nodes]
  )
  
  if (vcount(subgraph) == 0) {
    warning(paste("No nodes retained for source:", source_label))
    return(subgraph)
  }
  
  # Keep only components connected to at least one confirmed source-presence node
  # or to the selected source node itself.
  vertex_names <- V(subgraph)$name
  
  vertex_source_values <- nodes_for_filter$source_value[
    match(vertex_names, nodes_for_filter$sites)
  ]
  
  vertex_is_selected_source <- nodes_for_filter$is_selected_source_node[
    match(vertex_names, nodes_for_filter$sites)
  ]
  
  comp <- components(subgraph)
  
  components_to_keep <- unique(comp$membership[
    vertex_source_values == 1 | vertex_is_selected_source
  ])
  
  final_subgraph <- induced_subgraph(
    subgraph,
    vids = V(subgraph)[comp$membership %in% components_to_keep]
  )
  
  graph_attr(final_subgraph, "source_filter") <- source_label
  
  return(final_subgraph)
}

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
  # They are NOT used for clustering or rank assignment.
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
  # and debris/scarti. This preserves production intensity.
  
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
  # 5.3 Brainerd-Robinson matrix on PN contribution values
  # ---------------------------------------------------------------------------
  # This follows your original code:
  # ((2 - vegan::vegdist(..., method = "manhattan")) / 2)
  
  obs_br_PN <- ((2 - as.matrix(vegan::vegdist(
    obs_mat2,
    method = "manhattan"
  ))) / 2)
  
  write.csv(
    obs_br_PN,
    file.path(output_folder, paste0("obs_br_PN_", interval_label, ".csv")),
    row.names = TRUE
  )
  
  br_dissimilarity <- 1 - obs_br_PN
  
  if (any(is.na(br_dissimilarity))) {
    stop("Dissimilarity matrix contains NA values. Check the PN matrix.")
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
  # This produces reproducible and archaeologically interpretable classes of
  # production involvement while avoiding clustering solutions dominated by
  # extreme outliers.
  
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
  # 5.6 Attach production-score ranks to the site table
  # ---------------------------------------------------------------------------
  
  obs_ranked <- obs_data %>%
    left_join(cluster_assignment, by = "sites")
  
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
  # 5.7 Brainerd-Robinson diagnostic evaluation of production-score ranks
  # ---------------------------------------------------------------------------
  # The Brainerd-Robinson-style dissimilarity matrix is not used to assign ranks.
  # It is retained only as a diagnostic tool to evaluate whether the
  # production-score ranks correspond to differences in multivariate
  # technological space.
  
  br_dist <- as.dist(br_dissimilarity)
  
  # ---------------------------------------------------------------------------
  # 5.7a PERMANOVA-style test of rank differences in BR dissimilarity space
  # ---------------------------------------------------------------------------
  # This exploratory test evaluates whether production-score ranks correspond
  # to significant differences in multivariate technological profiles.
  
  adonis_data <- data.frame(
    Rank = factor(obs_ranked$Rank)
  )
  
  adonis_result <- vegan::adonis2(
    br_dist ~ Rank,
    data = adonis_data,
    permutations = 999
  )
  
  adonis_table <- as.data.frame(adonis_result)
  
  write.csv(
    adonis_table,
    file.path(output_folder, paste0("adonis_BR_dissimilarity_by_rank_", interval_label, ".csv")),
    row.names = TRUE
  )
  
  cat("\nPERMANOVA-style test of BR dissimilarity by rank:\n")
  print(adonis_result)
  
  # ---------------------------------------------------------------------------
  # 5.7b PCoA visualisation of Brainerd-Robinson dissimilarity space
  # ---------------------------------------------------------------------------
  
  pcoa_result <- cmdscale(
    br_dist,
    k = 2,
    eig = TRUE,
    add = TRUE
  )
  
  pcoa_plot_data <- data.frame(
    sites = rownames(obs_mat2),
    PCoA1 = pcoa_result$points[, 1],
    PCoA2 = pcoa_result$points[, 2],
    Rank = factor(obs_ranked$Rank),
    Production_score = obs_ranked$Production_score,
    stringsAsFactors = FALSE
  )
  
  write.csv(
    pcoa_plot_data,
    file.path(output_folder, paste0("pcoa_BR_by_production_rank_", interval_label, ".csv")),
    row.names = FALSE
  )
  
  # Plot only labels for Rank 2 and Rank 3 sites
  # Rank 1 sites are shown as background points without labels.
  pcoa_plot_data <- pcoa_plot_data %>%
    mutate(
      Rank = factor(Rank, levels = c("1", "2", "3"))
    )
  
  # Short labels for Rank 2 and Rank 3 sites
  site_code_lookup <- data.frame(
    sites = c(
      "Sant'Anna di Oria",
      "La Marmotta",
      "Sa Punta",
      "Cuccuru is Arrius",
      "Colle Santo Stefano",
      "Rio Saboccu",
      "Umbro Bova Marina",
      "Catignano",
      "Renaghju",
      "Fornace Cappuccini",
      "La Scola",
      "Cala Giovanna",
      "Piana di Curinga",
      "Le Secche",
      "Strette"
    ),
    site_code = c(
      "SAO",
      "LM",
      "SP",
      "CIA",
      "CSS",
      "RS",
      "UBM",
      "CAT",
      "REN",
      "FC",
      "LS",
      "CG",
      "PC",
      "LSE",
      "STR"
    ),
    stringsAsFactors = FALSE
  )
  
  pcoa_plot_data <- pcoa_plot_data %>%
    left_join(site_code_lookup, by = "sites") %>%
    mutate(
      label_code = ifelse(Rank %in% c("2", "3"), site_code, NA)
    )
  
  write.csv(
    site_code_lookup,
    file.path(output_folder, paste0("pcoa_site_code_lookup_", interval_label, ".csv")),
    row.names = FALSE
  )
  
  pcoa_plot <- ggplot(
    pcoa_plot_data,
    aes(
      x = PCoA1,
      y = PCoA2
    )
  ) +
    geom_point(
      aes(
        fill = Rank,
        size = Production_score
      ),
      shape = 21,
      colour = "grey35",
      alpha = 0.85,
      stroke = 0.35
    ) +
    ggrepel::geom_text_repel(
      data = pcoa_plot_data %>% filter(Rank %in% c("2", "3")),
      aes(
        label = label_code,
        colour = Rank
      ),
      size = 3.0,
      box.padding = 0.45,
      point.padding = 0.45,
      min.segment.length = 0,
      segment.size = 0.25,
      segment.alpha = 0.5,
      max.overlaps = Inf,
      show.legend = FALSE
    ) +
    scale_fill_manual(
      values = rank_palette[c("1", "2", "3")],
      name = "Production rank"
    ) +
    scale_colour_manual(
      values = rank_palette[c("1", "2", "3")],
      guide = "none"
    ) +
    scale_size_continuous(
      name = "Production score",
      range = c(1.8, 7)
    ) +
    guides(
      fill = guide_legend(
        override.aes = list(size = 4, colour = "grey35")
      )
    ) +
    theme_minimal() +
    labs(
      title = "Production-score ranks in Brainerd-Robinson dissimilarity space",
      x = "PCoA axis 1",
      y = "PCoA axis 2"
    ) +
    theme(
      plot.background = element_rect(fill = "white", colour = NA),
      panel.background = element_rect(fill = "white", colour = NA),
      legend.position = "right"
    )
  
  ggsave(
    file.path(output_folder, paste0("PCoA_BR_by_production_rank_", interval_label, ".png")),
    pcoa_plot,
    width = 7.6,
    height = 5.8,
    units = "in",
    dpi = 300,
    bg = "white"
  )
  
  return(obs_ranked)
}

# ==============================================================================
# 6. BUILD NETWORKS FOR ONE INTERVAL
# ==============================================================================

run_network_models <- function(ranked_sites, output_folder, interval_label) {
  
  nodes <- add_rank4_sources(ranked_sites)
  
  # ---------------------------------------------------------------------------
  # 6.1 Define rule sets and distance thresholds
  # ---------------------------------------------------------------------------
  # Rule set A excludes direct links from raw-material sources to intermediate
  # nodes. Rule set B allows this additional 4-2 connection.
  #
  # The aim is to identify, for each rule set, the minimum distance threshold
  # at which all nodes become part of a single connected component.
  
  rule_sets <- list(
    Rule_A = c("4-3", "3-2", "3-1", "2-1"),
    Rule_B = c("4-3", "4-2", "3-2", "3-1", "2-1"),
    Rule_C = c("4-3", "3-2", "2-1")
  )
  
  distance_thresholds <- seq(100, 650, by = 50)
  
  networks <- list()
  all_metrics <- data.frame()
  all_centrality <- data.frame()
  
  # ---------------------------------------------------------------------------
  # 6.2 Build all networks in the rule-distance grid
  # ---------------------------------------------------------------------------
  
  for (rule_name in names(rule_sets)) {
    
    current_rules <- rule_sets[[rule_name]]
    
    for (current_distance in distance_thresholds) {
      
      network_name <- paste0(
        rule_name,
        "_",
        current_distance,
        "km"
      )
      
      g <- build_network(
        nodes = nodes,
        allowed_connections = current_rules,
        max_distance_km = current_distance,
        network_name = network_name
      )
      
      networks[[network_name]] <- g
      
      # Store graph attributes
      graph_attr(networks[[network_name]], "rule_set") <- rule_name
      graph_attr(networks[[network_name]], "distance_km") <- current_distance
      graph_attr(networks[[network_name]], "allowed_connections") <- paste(current_rules, collapse = ", ")
      
      # Export edge list
      write.csv(
        as_data_frame(g, what = "edges"),
        file.path(output_folder, paste0(network_name, "_edges_", interval_label, ".csv")),
        row.names = FALSE
      )
      
      # Plot map
      plot_network_map(
        g,
        nodes,
        paste0(
          interval_label,
          ": ",
          rule_name,
          ", ",
          paste(current_rules, collapse = " / "),
          ", ",
          current_distance,
          " km"
        ),
        file.path(output_folder, paste0(network_name, "_map_", interval_label, ".png"))
      )
      
      # Metrics
      m <- summarise_network(g, network_name)
      m$Rule_set <- rule_name
      m$Distance_km <- current_distance
      m$Allowed_connections <- paste(current_rules, collapse = ", ")
      
      all_metrics <- bind_rows(all_metrics, m)
      
      # Centrality
      ctab <- centrality_table(g, network_name)
      ctab$Rule_set <- rule_name
      ctab$Distance_km <- current_distance
      ctab$Allowed_connections <- paste(current_rules, collapse = ", ")
      
      all_centrality <- bind_rows(all_centrality, ctab)
    }
  }
  
  # ---------------------------------------------------------------------------
  # 6.3 Plot rule-set comparison across distance thresholds
  # ---------------------------------------------------------------------------
  
  metrics_plot_data <- all_metrics %>%
    select(
      Rule_set,
      Distance_km,
      Edges,
      Components,
      Isolates,
      Largest_Component_Size
    ) %>%
    pivot_longer(
      cols = -c(Rule_set, Distance_km),
      names_to = "Metric",
      values_to = "Value"
    ) %>%
    mutate(
      Metric = factor(
        Metric,
        levels = c(
          "Edges",
          "Components",
          "Isolates",
          "Largest_Component_Size"
        ),
        labels = c(
          "Edges",
          "Components",
          "Isolates",
          "Largest component size"
        )
      ),
      Rule_set_label = dplyr::recode(
        Rule_set,
        "Rule_A" = "Rule A",
        "Rule_B" = "Rule B",
        "Rule_C" = "Rule C"
      )
    )
  
  rule_comparison_plot <- ggplot(
    metrics_plot_data,
    aes(
      x = Distance_km,
      y = Value,
      colour = Rule_set_label,
      linetype = Rule_set_label,
      shape = Rule_set_label,
      group = Rule_set_label
    )
  ) +
    geom_line(
      linewidth = 0.75,
      position = position_dodge(width = 8)
    ) +
    geom_point(
      size = 2.1,
      position = position_dodge(width = 8)
    ) +
    facet_wrap(~ Metric, scales = "free_y", ncol = 2) +
    theme_minimal() +
    labs(
      title = paste0("Comparison of rule sets across distance thresholds, ", interval_label),
      x = "Distance threshold (km)",
      y = "Metric value",
      colour = "Rule set",
      linetype = "Rule set",
      shape = "Rule set"
    ) +
    theme(
      plot.background = element_rect(fill = "white", colour = NA),
      panel.background = element_rect(fill = "white", colour = NA),
      strip.text = element_text(size = 11),
      axis.title = element_text(size = 10),
      axis.text = element_text(size = 9),
      legend.position = "bottom"
    )
    
  ggsave(
    file.path(output_folder, paste0("rule_set_metric_comparison_", interval_label, ".png")),
    rule_comparison_plot,
    width = 6.8,
    height = 5.5,
    units = "in",
    dpi = 300,
    bg = "white"
  )
  
  # ---------------------------------------------------------------------------
  # 6.4 Export full sensitivity table
  # ---------------------------------------------------------------------------
  
  all_metrics <- all_metrics %>%
    arrange(Rule_set, Distance_km)
  
  write.csv(
    all_metrics,
    file.path(output_folder, paste0("global_metrics_rule_distance_sweep_", interval_label, ".csv")),
    row.names = FALSE
  )
  
  write.csv(
    all_centrality,
    file.path(output_folder, paste0("centrality_rule_distance_sweep_", interval_label, ".csv")),
    row.names = FALSE
  )
  
  # ---------------------------------------------------------------------------
  # 6.5 Statistical comparison among Rule A, Rule B, and Rule C
  # ---------------------------------------------------------------------------
  # Rule sets are compared across the same sequence of distance thresholds.
  # Because each rule set is evaluated at the same distance thresholds, distance
  # is treated as a blocking factor. Friedman tests are used as non-parametric
  # repeated-measures tests. Pairwise Wilcoxon signed-rank tests are then used
  # as post-hoc comparisons.
  
  metrics_to_test <- c(
    "Edges",
    "Components",
    "Isolates",
    "Largest_Component_Size"
  )
  
  friedman_results <- data.frame()
  pairwise_results <- data.frame()
  
  for (metric_name in metrics_to_test) {
    
    test_data <- all_metrics %>%
      select(Rule_set, Distance_km, all_of(metric_name)) %>%
      filter(!is.na(.data[[metric_name]]))
    
    # Keep only distances where all rule sets have values
    complete_distances <- test_data %>%
      group_by(Distance_km) %>%
      summarise(
        n_rules = n_distinct(Rule_set),
        .groups = "drop"
      ) %>%
      filter(n_rules == length(rule_sets)) %>%
      pull(Distance_km)
    
    test_data <- test_data %>%
      filter(Distance_km %in% complete_distances)
    
    if (
      length(unique(test_data$Rule_set)) >= 3 &&
      length(unique(test_data$Distance_km)) >= 2
    ) {
      
      friedman_formula <- as.formula(
        paste(metric_name, "~ Rule_set | Distance_km")
      )
      
      friedman_test <- friedman.test(
        formula = friedman_formula,
        data = test_data
      )
      
      friedman_results <- bind_rows(
        friedman_results,
        data.frame(
          Metric = metric_name,
          Friedman_chi_squared = unname(friedman_test$statistic),
          Df = unname(friedman_test$parameter),
          P_value = friedman_test$p.value,
          stringsAsFactors = FALSE
        )
      )
      
      pairwise_test <- pairwise.wilcox.test(
        x = test_data[[metric_name]],
        g = test_data$Rule_set,
        paired = TRUE,
        p.adjust.method = "BH"
      )
      
      pairwise_df <- as.data.frame(as.table(pairwise_test$p.value)) %>%
        filter(!is.na(Freq)) %>%
        rename(
          Rule_1 = Var1,
          Rule_2 = Var2,
          Adjusted_P_value = Freq
        ) %>%
        mutate(
          Metric = metric_name
        ) %>%
        select(Metric, Rule_1, Rule_2, Adjusted_P_value)
      
      pairwise_results <- bind_rows(
        pairwise_results,
        pairwise_df
      )
    }
  }
  
  friedman_results <- friedman_results %>%
    mutate(
      P_adjusted_BH = p.adjust(P_value, method = "BH")
    )
  
  write.csv(
    friedman_results,
    file.path(output_folder, paste0("friedman_rule_comparison_", interval_label, ".csv")),
    row.names = FALSE
  )
  
  write.csv(
    pairwise_results,
    file.path(output_folder, paste0("pairwise_rule_comparison_", interval_label, ".csv")),
    row.names = FALSE
  )
  
  # ---------------------------------------------------------------------------
  # 6.6 Identify the first connected network for each rule set
  # ---------------------------------------------------------------------------
  
  first_connected_by_rule <- all_metrics %>%
    filter(Connected_All_Sites) %>%
    group_by(Rule_set) %>%
    slice_min(order_by = Distance_km, n = 1, with_ties = FALSE) %>%
    ungroup() %>%
    arrange(Rule_set)
  
  write.csv(
    first_connected_by_rule,
    file.path(output_folder, paste0("first_connected_network_by_rule_", interval_label, ".csv")),
    row.names = FALSE
  )
  
  cat("\nMinimum connected network by rule set, ", interval_label, ":\n", sep = "")
  print(first_connected_by_rule %>% select(Rule_set, Distance_km, Network, Nodes, Edges, Components, Connected_All_Sites))
  
  # ---------------------------------------------------------------------------
  # 6.7 Select one backbone network for downstream source-filtered analyses
  # ---------------------------------------------------------------------------
  # Preference rule:
  # 1. Use the least-distance connected Rule C model if available.
  # 2. If Rule C never connects all sites, use the least-distance connected Rule A model.
  # 3. If Rule A never connects all sites, use the least-distance connected Rule B model.
  # 4. If none connects all sites, retain the largest-distance Rule B model.
  
  backbone_preference <- c(
    "Rule_A",
    "Rule_B",
    "Rule_C"
  )
  
  selected_network_name <- NA_character_
  
  for (preferred_rule in backbone_preference) {
    
    candidate <- first_connected_by_rule %>%
      filter(Rule_set == preferred_rule)
    
    if (nrow(candidate) > 0) {
      selected_network_name <- candidate %>%
        slice_min(order_by = Distance_km, n = 1, with_ties = FALSE) %>%
        pull(Network)
      
      break
    }
  }
  
  if (is.na(selected_network_name)) {
    
    selected_network_name <- paste0(
      "Rule_B_",
      max(distance_thresholds),
      "km"
    )
    
    warning(
      paste0(
        "No rule-distance combination connects all sites. ",
        selected_network_name,
        " is retained as the least restrictive backbone available."
      )
    )
  }
  
  selected_network <- networks[[selected_network_name]]
  
  selected_backbone_info <- all_metrics %>%
    filter(Network == selected_network_name) %>%
    select(
      Network,
      Rule_set,
      Distance_km,
      Nodes,
      Edges,
      Components,
      Connected_All_Sites
    )
  
  write.csv(
    selected_backbone_info,
    file.path(output_folder, paste0("selected_backbone_network_", interval_label, ".csv")),
    row.names = FALSE
  )
  
  print(selected_backbone_info)

 # ---------------------------------------------------------------------------
 # 6.8 Select the best-connected parsimonious backbone: Rule A
 # ---------------------------------------------------------------------------
 # Rule A excludes direct source-to-intermediate links.
 # It is used as the main backbone for source-filtered/regional networks because
 # it reaches the same connectivity threshold as Rule B while making fewer
 # assumptions.
  
  rule_a_connected <- first_connected_by_rule %>%
    filter(Rule_set == "Rule_A")
  
  if (nrow(rule_a_connected) > 0) {
    
    selected_rule_a_network_name <- rule_a_connected %>%
      pull(Network)
    
  } else {
    
    selected_rule_a_network_name <- paste0(
      "Rule_A_",
      max(distance_thresholds),
      "km"
    )
    
    warning(
      paste0(
        "Rule_A does not connect all sites. ",
        selected_rule_a_network_name,
        " is retained as the most restrictive available source-filter backbone."
      )
    )
  }
  
  selected_rule_a_network <- networks[[selected_rule_a_network_name]]
  
  write.csv(
    data.frame(
      Selected_rule_a_source_filter_backbone = selected_rule_a_network_name
    ),
    file.path(output_folder, paste0("selected_rule_a_source_filter_backbone_", interval_label, ".csv")),
    row.names = FALSE
  )
  
  # ---------------------------------------------------------------------------
  # 6.9 Centrality by rank
  # ---------------------------------------------------------------------------
  
  centrality_rank_summary <- all_centrality %>%
    group_by(Network, Rule_set, Distance_km, Rank) %>%
    summarise(
      mean_degree = mean(Degree, na.rm = TRUE),
      mean_betweenness = mean(Betweenness, na.rm = TRUE),
      mean_closeness = mean(Closeness, na.rm = TRUE),
      mean_harmonic = mean(Harmonic, na.rm = TRUE),
      mean_eigenvector = mean(Eigenvector, na.rm = TRUE),
      .groups = "drop"
    )
  
  write.csv(
    centrality_rank_summary,
    file.path(output_folder, paste0("centrality_by_rank_rule_distance_sweep_", interval_label, ".csv")),
    row.names = FALSE
  )
  
  degree_plot <- ggplot(
    all_centrality,
    aes(x = factor(Rank), y = Degree, fill = factor(Rank), colour = factor(Rank))
  ) +
    geom_boxplot(alpha = 0.75, outlier.size = 1) +
    facet_grid(Rule_set ~ Distance_km, scales = "free_y") +
    scale_fill_manual(values = rank_palette[c("1", "2", "3", "4")]) +
    scale_colour_manual(values = rank_palette[c("1", "2", "3", "4")]) +
    theme_minimal() +
    labs(
      title = paste0("Degree centrality by rank across rule-distance models, ", interval_label),
      x = "Rank",
      y = "Degree centrality",
      fill = "Rank",
      colour = "Rank"
    ) +
    theme(
      plot.background = element_rect(fill = "white", colour = NA),
      panel.background = element_rect(fill = "white", colour = NA),
      axis.text.x = element_text(angle = 0)
    )
  
  ggsave(
    file.path(output_folder, paste0("degree_by_rank_rule_distance_sweep_", interval_label, ".png")),
    degree_plot,
    width = 6.8,
    height = 9.8,
    units = "in",
    dpi = 300,
    bg = "white"
  )
  
  # ---------------------------------------------------------------------------
  # 6.10 Source-filtered networks with Rule A primary and Rule B fallback
  # ---------------------------------------------------------------------------
  # Source-filtered networks are extracted primarily from the best-connected
  # Rule A backbone, because Rule A is the preferred parsimonious model.
  #
  # Sites with unknown source attribution are excluded.
  # Sites with explicit absence of the selected source are excluded.
  # Other raw-material source nodes are excluded.
  #
  # If Rule A produces an uninformative source-confirmed network for a given
  # source, the script falls back to Rule B. This can occur when the confirmed
  # source network lacks Rank 3 nodes and Rule A cannot connect the Rank 4
  # source node to Rank 2 or Rank 1 sites.
  #
  # Fallback criteria:
  # 1. the source-confirmed graph has no vertices;
  # 2. the source-confirmed graph has no edges;
  # 3. the selected source node is isolated.
  #
  # For each source, the rule actually used is recorded in the output metrics.
  
  # ---------------------------------------------------------------------------
  # 6.10.1 Select Rule A backbone
  # ---------------------------------------------------------------------------
  
  rule_a_connected <- first_connected_by_rule %>%
    filter(Rule_set == "Rule_A")
  
  if (nrow(rule_a_connected) > 0) {
    selected_rule_a_network_name <- rule_a_connected %>%
      slice_min(order_by = Distance_km, n = 1, with_ties = FALSE) %>%
      pull(Network)
  } else {
    selected_rule_a_network_name <- paste0(
      "Rule_A_",
      max(distance_thresholds),
      "km"
    )
    
    warning(
      paste0(
        "Rule_A does not connect all entries. ",
        selected_rule_a_network_name,
        " is retained as the most restrictive available Rule A backbone."
      )
    )
  }
  
  rule_a_backbone <- networks[[selected_rule_a_network_name]]
  
  # ---------------------------------------------------------------------------
  # 6.10.2 Select Rule B fallback backbone
  # ---------------------------------------------------------------------------
  
  rule_b_connected <- first_connected_by_rule %>%
    filter(Rule_set == "Rule_B")
  
  if (nrow(rule_b_connected) > 0) {
    selected_rule_b_network_name <- rule_b_connected %>%
      slice_min(order_by = Distance_km, n = 1, with_ties = FALSE) %>%
      pull(Network)
  } else {
    selected_rule_b_network_name <- paste0(
      "Rule_B_",
      max(distance_thresholds),
      "km"
    )
    
    warning(
      paste0(
        "Rule_B does not connect all entries. ",
        selected_rule_b_network_name,
        " is retained as the fallback Rule B backbone."
      )
    )
  }
  
  rule_b_backbone <- networks[[selected_rule_b_network_name]]
  
  # ---------------------------------------------------------------------------
  # 6.10.3 Helper function: check whether source-confirmed graph is informative
  # ---------------------------------------------------------------------------
  
  is_informative_source_graph <- function(g_source, source_node_name) {
    
    if (is.null(g_source)) return(FALSE)
    if (vcount(g_source) == 0) return(FALSE)
    if (ecount(g_source) == 0) return(FALSE)
    if (!source_node_name %in% V(g_source)$name) return(FALSE)
    
    gu_source <- as_undirected(g_source, mode = "collapse")
    
    source_degree <- degree(
      gu_source,
      v = V(gu_source)[name == source_node_name],
      mode = "all"
    )
    
    if (length(source_degree) == 0) return(FALSE)
    if (source_degree == 0) return(FALSE)
    
    return(TRUE)
  }
  
  # ---------------------------------------------------------------------------
  # 6.10.4 Helper function: filter network by confirmed source presence only
  # ---------------------------------------------------------------------------
  
  filter_network_by_confirmed_source <- function(
    g,
    nodes,
    source_col,
    source_label,
    source_node_name
  ) {
    
    # Retain only:
    # - selected source node;
    # - archaeological sites where source_col == 1.
    #
    # Exclude:
    # - source_col == 0;
    # - source_col == NA;
    # - other source nodes.
    
    confirmed_site_names <- nodes %>%
      st_drop_geometry() %>%
      filter(
        sites == source_node_name |
          (!sites %in% c("Monte Arci", "Lipari", "Palmarola") &
             !is.na(.data[[source_col]]) &
             .data[[source_col]] == 1)
      ) %>%
      pull(sites)
    
    confirmed_site_names <- intersect(
      confirmed_site_names,
      V(g)$name
    )
    
    if (length(confirmed_site_names) == 0) {
      return(make_empty_graph(directed = is_directed(g)))
    }
    
    g_source <- induced_subgraph(
      g,
      vids = V(g)[name %in% confirmed_site_names]
    )
    
    graph_attr(g_source, "source_filter") <- source_label
    graph_attr(g_source, "source_filter_type") <- "confirmed_only"
    graph_attr(g_source, "source_node") <- source_node_name
    
    return(g_source)
  }
  
  # ---------------------------------------------------------------------------
  # 6.10.5 Source metadata
  # ---------------------------------------------------------------------------
  
  source_info <- data.frame(
    source_name = c("Sardegna", "Lipari", "Palmarola"),
    source_col = c("Sardegna", "Lipari", "Palmarola"),
    source_label = c("Monte Arci / Sardegna", "Lipari", "Palmarola"),
    source_node_name = c("Monte Arci", "Lipari", "Palmarola"),
    stringsAsFactors = FALSE
  )
  
  source_subgraphs <- list()
  source_selection_log <- data.frame()
  
  # ---------------------------------------------------------------------------
  # 6.10.6 Build source-confirmed networks
  # ---------------------------------------------------------------------------
  
  for (i in seq_len(nrow(source_info))) {
    
    source_name <- source_info$source_name[i]
    source_col <- source_info$source_col[i]
    source_label <- source_info$source_label[i]
    source_node_name <- source_info$source_node_name[i]
    
    # Try Rule A first
    subgraph_a <- filter_network_by_confirmed_source(
      rule_a_backbone,
      nodes,
      source_col,
      source_label,
      source_node_name
    )
    
    use_rule_a <- is_informative_source_graph(
      subgraph_a,
      source_node_name
    )
    
    if (use_rule_a) {
      
      current_subgraph <- subgraph_a
      source_filter_backbone_name <- selected_rule_a_network_name
      source_filter_rule_set <- "Rule_A"
      fallback_used <- FALSE
      fallback_reason <- NA_character_
      
    } else {
      
      # Fall back to Rule B
      subgraph_b <- filter_network_by_confirmed_source(
        rule_b_backbone,
        nodes,
        source_col,
        source_label,
        source_node_name
      )
      
      current_subgraph <- subgraph_b
      source_filter_backbone_name <- selected_rule_b_network_name
      source_filter_rule_set <- "Rule_B"
      fallback_used <- TRUE
      
      if (vcount(subgraph_a) == 0) {
        fallback_reason <- "Rule A produced an empty source-confirmed graph"
      } else if (ecount(subgraph_a) == 0) {
        fallback_reason <- "Rule A produced a source-confirmed graph with no edges"
      } else if (!source_node_name %in% V(subgraph_a)$name) {
        fallback_reason <- "Source node absent from Rule A source-confirmed graph"
      } else {
        gu_a <- as_undirected(subgraph_a, mode = "collapse")
        source_degree_a <- degree(
          gu_a,
          v = V(gu_a)[name == source_node_name],
          mode = "all"
        )
        
        if (length(source_degree_a) == 0 || source_degree_a == 0) {
          fallback_reason <- "Source node isolated under Rule A"
        } else {
          fallback_reason <- "Rule A source-confirmed graph considered uninformative"
        }
      }
    }
    
    graph_attr(current_subgraph, "source_filter") <- source_label
    graph_attr(current_subgraph, "source_filter_type") <- "confirmed_only"
    graph_attr(current_subgraph, "source_filter_backbone") <- source_filter_backbone_name
    graph_attr(current_subgraph, "source_filter_rule_set") <- source_filter_rule_set
    graph_attr(current_subgraph, "fallback_used") <- fallback_used
    graph_attr(current_subgraph, "fallback_reason") <- fallback_reason
    
    source_subgraphs[[source_name]] <- current_subgraph
    
    current_nodes <- nodes %>%
      filter(sites %in% V(current_subgraph)$name)
    
    confirmed_site_count <- current_nodes %>%
      st_drop_geometry() %>%
      filter(
        !sites %in% c("Monte Arci", "Lipari", "Palmarola")
      ) %>%
      nrow()
    
    source_selection_log <- bind_rows(
      source_selection_log,
      data.frame(
        Source = source_name,
        Source_label = source_label,
        Source_node = source_node_name,
        Filter_type = "confirmed_only",
        Backbone_network = source_filter_backbone_name,
        Backbone_rule_set = source_filter_rule_set,
        Fallback_used = fallback_used,
        Fallback_reason = fallback_reason,
        Confirmed_sites = confirmed_site_count,
        Vertices = vcount(current_subgraph),
        Edges = ecount(current_subgraph),
        stringsAsFactors = FALSE
      )
    )
    
    # Export edge list
    write.csv(
      as_data_frame(current_subgraph, what = "edges"),
      file.path(
        output_folder,
        paste0(source_name, "_source_confirmed_edges_", interval_label, ".csv")
      ),
      row.names = FALSE
    )
    
    # Export vertex list
    write.csv(
      as_data_frame(current_subgraph, what = "vertices"),
      file.path(
        output_folder,
        paste0(source_name, "_source_confirmed_vertices_", interval_label, ".csv")
      ),
      row.names = FALSE
    )
    
    # Plot source-confirmed network on map
    plot_network_map(
      current_subgraph,
      current_nodes,
      paste0(
        interval_label,
        ": ",
        source_label,
        " source-confirmed network on map; backbone = ",
        source_filter_backbone_name,
        "; rule = ",
        source_filter_rule_set
      ),
      file.path(
        output_folder,
        paste0(source_name, "_source_confirmed_map_", interval_label, ".png")
      )
    )
    
    # Plot source-confirmed graph alone
    plot_network_graph_only(
      current_subgraph,
      paste0(
        interval_label,
        ": ",
        source_label,
        " source-confirmed graph; backbone = ",
        source_filter_backbone_name,
        "; rule = ",
        source_filter_rule_set
      ),
      file.path(
        output_folder,
        paste0(source_name, "_source_confirmed_graph_only_", interval_label, ".png")
      )
    )
  }
  
  # ---------------------------------------------------------------------------
  # 6.10.7 Export source-confirmed rule-selection log
  # ---------------------------------------------------------------------------
  
  write.csv(
    source_selection_log,
    file.path(output_folder, paste0("source_confirmed_rule_selection_log_", interval_label, ".csv")),
    row.names = FALSE
  )
  
  # ---------------------------------------------------------------------------
  # 6.10.8 Export source-confirmed metrics
  # ---------------------------------------------------------------------------
  
  source_metrics <- bind_rows(
    lapply(names(source_subgraphs), function(source_name) {
      
      current_subgraph <- source_subgraphs[[source_name]]
      
      m <- summarise_network(
        current_subgraph,
        source_info$source_label[source_info$source_name == source_name]
      )
      
      m$Source <- source_name
      m$Source_label <- source_info$source_label[source_info$source_name == source_name]
      m$Filter_type <- "confirmed_only"
      m$Backbone_network <- graph_attr(current_subgraph, "source_filter_backbone")
      m$Backbone_rule_set <- graph_attr(current_subgraph, "source_filter_rule_set")
      m$Fallback_used <- graph_attr(current_subgraph, "fallback_used")
      m$Fallback_reason <- graph_attr(current_subgraph, "fallback_reason")
      
      return(m)
    })
  )
  
  write.csv(
    source_metrics,
    file.path(output_folder, paste0("source_confirmed_metrics_", interval_label, ".csv")),
    row.names = FALSE
  )
}

# ==============================================================================
# 7. RUN PRODUCTION RANKING ON FULL DATASET, THEN SPLIT BY CHRONOLOGY
# ==============================================================================

# ------------------------------------------------------------------------------
# 7.1 Calculate technological ranks on the full dataset
# ------------------------------------------------------------------------------
# Everything below this line executes the complete workflow.
# Source the function sections above if you want to run individual steps only.

ranked_all <- run_production_ranking(
  input_file = input_all,
  output_folder = output_folder,
  interval_label = "all_sites"
)

# ------------------------------------------------------------------------------
# 7.2 Load the two chronological datasets
# ------------------------------------------------------------------------------

data_6100_5500 <- read_obsidian_file(input_6100_5500)
data_5500_4900 <- read_obsidian_file(input_5500_4900)

data_6100_5500 <- clean_obsidian_table(data_6100_5500)
data_5500_4900 <- clean_obsidian_table(data_5500_4900)

# ------------------------------------------------------------------------------
# 7.3 Attach the full-dataset ranks to the chronological datasets
# ------------------------------------------------------------------------------

standardise_site_name <- function(x) {
  x <- as.character(x)
  x <- gsub("\u00A0", " ", x)
  x <- gsub("[[:space:]]+", " ", x)
  x <- trimws(x)
  x <- iconv(x, from = "", to = "ASCII//TRANSLIT")
  x <- tolower(x)
  return(x)
}

rank_lookup <- ranked_all %>%
  mutate(site_key = standardise_site_name(sites)) %>%
  select(
    site_key,
    sites_ranked_all = sites,
    Cluster_raw,
    Rank,
    Production_score
  )

ranked_6100_5500 <- data_6100_5500 %>%
  mutate(site_key = standardise_site_name(sites)) %>%
  left_join(rank_lookup, by = "site_key")

ranked_5500_4900 <- data_5500_4900 %>%
  mutate(site_key = standardise_site_name(sites)) %>%
  left_join(rank_lookup, by = "site_key")

# ------------------------------------------------------------------------------
# 7.4 Check for unmatched sites
# ------------------------------------------------------------------------------

unmatched_6100_5500 <- ranked_6100_5500 %>%
  filter(is.na(Rank)) %>%
  select(sites)

unmatched_5500_4900 <- ranked_5500_4900 %>%
  filter(is.na(Rank)) %>%
  select(sites)

write.csv(
  unmatched_6100_5500,
  file.path(output_6100_5500, "unmatched_sites_no_rank_6100_5500.csv"),
  row.names = FALSE
)

write.csv(
  unmatched_5500_4900,
  file.path(output_5500_4900, "unmatched_sites_no_rank_5500_4900.csv"),
  row.names = FALSE
)

cat("\nUnmatched 6100-5500 sites:", nrow(unmatched_6100_5500), "\n")
cat("Unmatched 5500-4900 sites:", nrow(unmatched_5500_4900), "\n")

if (nrow(unmatched_6100_5500) > 0) {
  warning("Some 6100-5500 sites did not receive a rank. Check unmatched_sites_no_rank_6100_5500.csv")
}

if (nrow(unmatched_5500_4900) > 0) {
  warning("Some 5500-4900 sites did not receive a rank. Check unmatched_sites_no_rank_5500_4900.csv")
}

# ------------------------------------------------------------------------------
# 7.5 Export ranked chronological datasets
# ------------------------------------------------------------------------------

write.csv(
  ranked_6100_5500,
  file.path(output_6100_5500, "ranked_sites_6100_5500.csv"),
  row.names = FALSE
)

write.csv(
  ranked_5500_4900,
  file.path(output_5500_4900, "ranked_sites_5500_4900.csv"),
  row.names = FALSE
)

# ------------------------------------------------------------------------------
# 7.6 Build networks separately for the two already-ranked intervals
# ------------------------------------------------------------------------------

networks_6100_5500 <- run_network_models(
  ranked_sites = ranked_6100_5500,
  output_folder = output_6100_5500,
  interval_label = "6100_5500"
)

networks_5500_4900 <- run_network_models(
  ranked_sites = ranked_5500_4900,
  output_folder = output_5500_4900,
  interval_label = "5500_4900"
)



# ------------------------------------------------------------------------------
# 8. Black-and-white site location map
# ------------------------------------------------------------------------------

plot_all_sites_numbered_map <- function(input_file, output_folder, map_file) {
  
  # Read and clean full dataset
  raw_data <- read_obsidian_file(input_file)
  site_data <- clean_obsidian_table(raw_data)
  
  # Use first ID column if present
  if ("ID" %in% names(site_data)) {
    site_data$Map_ID <- site_data$ID
  } else if ("Id" %in% names(site_data)) {
    site_data$Map_ID <- site_data$Id
  } else if ("id" %in% names(site_data)) {
    site_data$Map_ID <- site_data$id
  } else {
    site_data$Map_ID <- seq_len(nrow(site_data))
    warning("No ID column found. Sequential map IDs were created.")
  }
  
  site_data$Map_ID <- as.character(site_data$Map_ID)
  
  # Read map
  if (!file.exists(map_file)) {
    stop(paste("Map shapefile not found:", map_file))
  }
  
  map_shp <- sf::st_read(map_file, quiet = TRUE)
  map_shp <- sf::st_make_valid(map_shp)
  
  # Transform map to WGS84 if needed
  if (is.na(sf::st_crs(map_shp))) {
    warning("Map shapefile has no CRS. Assuming EPSG:4326.")
    sf::st_crs(map_shp) <- 4326
  }
  
  map_shp <- sf::st_transform(map_shp, 4326)
  
  # Define map extent manually
  x_limits <- c(
    min(site_data$Long, na.rm = TRUE) - 0.8,
    max(site_data$Long, na.rm = TRUE) + 1.2
  )
  
  y_limits <- c(
    36.0,
    max(site_data$Lat, na.rm = TRUE) + 0.8
  )
  
  # Crop shapefile to the plotting extent  
  map_bbox <- sf::st_bbox(
    c(
      xmin = x_limits[1],
      xmax = x_limits[2],
      ymin = y_limits[1],
      ymax = y_limits[2]
    ),
    crs = sf::st_crs(4326)
  )
  
  map_crop <- suppressWarnings(sf::st_crop(map_shp, map_bbox))
  map_crop <- suppressWarnings(sf::st_collection_extract(map_crop, "POLYGON"))
  
  # Keep only polygon geometries
  map_crop <- suppressWarnings(sf::st_collection_extract(map_crop, "POLYGON"))
  
  # Create plot
  p <- ggplot() +
    geom_sf(
      data = map_crop,
      fill = "white",
      colour = "darkgrey",
      linewidth = 0.25
    ) +
    geom_point(
      data = site_data,
      aes(x = Long, y = Lat),
      shape = 21,
      fill = "deepskyblue3",
      colour = "black",
      size = 2.5,
      stroke = 0.2
    ) +
    ggrepel::geom_text_repel(
      data = site_data,
      aes(x = Long, y = Lat, label = Map_ID),
      size = 3.2,
      fontface = "bold",
      colour = "black",
      box.padding = 0.25,
      point.padding = 0.25,
      min.segment.length = 0,
      segment.size = 0.15,
      segment.colour = "grey40",
      max.overlaps = Inf
    ) +
    ggspatial::annotation_scale(
      location = "bl",
      width_hint = 0.25,
      text_cex = 0.65,
      line_width = 0.4,
      pad_x = unit(0.35, "cm"),
      pad_y = unit(0.35, "cm")
    ) +
    coord_sf(
      xlim = x_limits,
      ylim = y_limits,
      expand = FALSE,
      clip = "on"
    ) +
    theme_minimal() +
    labs(
      x = "Longitude",
      y = "Latitude"
    ) +
    theme(
      plot.background = element_rect(fill = "white", colour = NA),
      panel.background = element_rect(fill = "white", colour = NA),
      panel.border = element_rect(fill = NA, colour = "black", linewidth = 0.35),
      panel.grid.major = element_line(colour = "grey88", linewidth = 0.2),
      panel.grid.minor = element_blank(),
      axis.title = element_text(size = 9),
      axis.text = element_text(size = 8, colour = "black"),
      legend.position = "none",
      plot.margin = margin(5, 5, 5, 5)
    )
  
  # Save PNG
  ggsave(
    file.path(output_folder, "all_sites_numbered_black_white_map.png"),
    p,
    width = 8.5,
    height = 6.2,
    units = "in",
    dpi = 300,
    bg = "white"
  )

  # Export ID lookup table
  site_lookup <- site_data %>%
    select(Map_ID, sites, Long, Lat) %>%
    arrange(as.numeric(Map_ID))
  
  write.csv(
    site_lookup,
    file.path(output_folder, "all_sites_numbered_map_lookup.csv"),
    row.names = FALSE
  )
  
  return(p)
}

all_sites_numbered_map <- plot_all_sites_numbered_map(
  input_file = input_all,
  output_folder = output_folder,
  map_file = map_file
)


