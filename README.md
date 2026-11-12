# CHRONOS

**CHRONOS – The Obsidian Route in the Central Mediterranean: DiaCHRONic Pathways and Cultural ConnectiOnS**

This repository contains the reproducible analytical workflow supporting the study **“Modelling Obsidian Production and Circulation across the Central Mediterranean, 6100–4900 cal BCE.”** The workflow harmonises technological, chronological, provenance and spatial data for 74 archaeological contexts and explores how different assumptions about technological involvement, source access and distance affect potential obsidian-circulation networks.

The analysis is exploratory. Site ranks are operational levels of **documented technological involvement**, not fixed functional categories, and network edges are modelling outcomes rather than demonstrated prehistoric journeys or exchange routes.

## Repository contents

~~~text
CHRONOS/
├── CHRONOS.R
├── CHRONOS_report.html
├── README.md
├── RAWDATA/
│   ├── obs_data_corr.xlsx
│   ├── obs_data_corr_6100_5500.xlsx
│   └── obs_data_corr_5500_4900.xlsx
├── MAP/
│   ├── map_shp.shp
│   ├── map_shp.dbf
│   ├── map_shp.shx
│   ├── map_shp.prj
│   └── map_shp.qmd
└── OUTPUTS/
    ├── Obsidian_network_6100_5500/
    ├── Obsidian_network_5500_4900/
    ├── Figures/
    └── global tables and figures
~~~

- **CHRONOS.R** is the single executable analytical workflow.
- **RAWDATA/** contains the complete and chronological input datasets.
- **MAP/** contains the shapefile used for geographical figures.
- **OUTPUTS/** contains generated tables and figures. Re-run the script after any change to the inputs and replace these outputs together so that all files correspond to the same analytical run.
- **CHRONOS_report.html** is a static explanatory companion to the script and outputs.

## Reproducing the analysis

### Requirements

R and the following packages are required:

~~~r
install.packages(c(
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
))
~~~

RStudio is optional.

### Run the complete workflow

From the repository root:

~~~r
source("CHRONOS.R")
~~~

or from a terminal:

~~~bash
Rscript CHRONOS.R
~~~

The script detects the project root automatically when it is placed either in the repository root or in a **SCRIPTS/** subfolder. It creates output folders when necessary.

## Input datasets

| Input | Role |
|---|---|
| **RAWDATA/obs_data_corr.xlsx** | Complete technological dataset used to calculate contribution values, production scores, operational ranks and sensitivity diagnostics |
| **RAWDATA/obs_data_corr_6100_5500.xlsx** | Earlier chronological subset used for network modelling |
| **RAWDATA/obs_data_corr_5500_4900.xlsx** | Later chronological subset used for network modelling |
| **MAP/map_shp.shp** and sidecars | Background geography for maps |

The principal technological variables are **blade**, **flake**, **core**, and **by.products.waste**. The analytical denominator excludes technologically indeterminate pieces.

### Missing information and genuine absence

The workflow distinguishes documented absence from unavailable information.

- For the technological variables, **0 means documented absence**. Missing/unresolved counts must remain **NA** and the script stops before ranking if such values are present.
- For source columns (**Sardegna**, **Lipari**, **Palmarola**), **1 means documented presence**, **0 documented absence**, and **NA unknown/not analysed**.
- Source-confirmed networks retain only sites with explicit source presence (= 1).

This prevents unpublished or unresolved information from being silently converted into archaeological absence.

## Analytical workflow

### 1. Contribution-based production score

For each technological category, each site is expressed as its percentage contribution to the total amount of that category across the complete dataset:

~~~text
Production_score =
  blade.PN + flake.PN + core.PN + by.products.waste.PN
~~~

These are **not within-site percentages**. The contribution-based formulation intentionally retains both technological composition and the documented quantitative scale of obsidian working.

### 2. Operational technological ranks

Sites are assigned to three analytical ranks from the complete production-score distribution:

| Rank | Criterion | Interpretation |
|---|---|---|
| 1 | below 80th percentile | lower documented technological involvement |
| 2 | 80th–90th percentile | intermediate documented technological involvement |
| 3 | upper decile | highest documented technological involvement |
| 4 | geological source node | Monte Arci, Lipari or Palmarola |

The 90th percentile isolates the small upper tail of sites making the greatest contributions to the documented technological corpus; the 80th percentile defines an intermediate group immediately below it. These are reproducible analytical cut-offs, defined independently of subsequent network results, not archaeological boundaries.

Ranks are calculated once from the complete dataset and then joined to the two chronological subsets.

### 3. Manhattan dissimilarity diagnostic

The script calculates pairwise Manhattan dissimilarities directly on the same category-wise contribution matrix used for the production score. PERMANOVA and PCoA are therefore descriptive diagnostics of the rank structure in contribution space, not independent validation of the classification.

Current output names use **Manhattan**, replacing the legacy **BR** naming used in earlier repository versions.

### 4. Sensitivity to assemblage magnitude

Two complementary checks assess the effect of assemblage size.

**Square-root sensitivity ranking.** Raw technological counts are square-root transformed before the same contribution scaling, score calculation and percentile rank assignment. This reduces the leverage of very large assemblages while preserving quantitative differences.

**Composition-only diagnostic.** Within-site relative frequencies are converted to a Manhattan distance matrix and compared with the primary contribution-based distance matrix using a Spearman Mantel test. This intentionally removes assemblage magnitude and therefore addresses a different question: similarity in internal technological composition irrespective of quantitative scale.

For the analytical run reported in the manuscript, the square-root ranking strongly reproduced the primary classification (**Spearman ρ = 0.987; 97.3% exact rank agreement**). Only La Scola and Renaghju exchanged Rank 2/Rank 3 positions, while membership of the combined upper two ranks was unchanged. The composition-only structure corresponded only weakly with the primary contribution structure (**Mantel r = 0.163, p = 0.008**), showing that purely proportional standardisation removes information retained by the contribution-based approach.

The complete rule-distance grid is also rerun with the square-root ranks. Under preferred Rule A, the first full-connectivity threshold remains **550 km for 6100–5500 cal BCE** and **450 km for 5500–4900 cal BCE**. Thus reducing the influence of the largest assemblages does not alter the principal Rule A spatial result.

### 5. Rule-distance network models

The three rule sets are:

| Rule | Permitted rank connections |
|---|---|
| A | 4–3, 3–2, 3–1, 2–1 |
| B | 4–3, 4–2, 3–2, 3–1, 2–1 |
| C | 4–3, 3–2, 2–1 |

The script evaluates every rule from **100 to 650 km in 50 km increments**. Distances are centre-to-centre geographical distances after transformation to EPSG:3035.

Distance thresholds are **modelling parameters applied to individual potential links**. They are not direct measures of prehistoric journeys and do not incorporate coastlines, topography, currents, winds or social boundaries.

For each rule the script records the first threshold at which all nodes belong to one connected component. Rule A is retained as the preferred parsimonious interpretative scenario when connected because it achieves connectivity without introducing the additional direct source-to-Rank 2 links allowed by Rule B. Network performance is not treated as independent proof that prehistoric circulation followed that structure.

### 6. Source-confirmed networks

Source-filtered networks retain the selected source and only sites where that source is explicitly documented. Ranks remain based on the total obsidian assemblage and therefore should not be interpreted as source-specific technological classifications.

Rule A is attempted first. A Rule B fallback is used only when the Rule A source-filtered graph is empty, has no edges, lacks the source node or leaves the source isolated. The selected rule and fallback decision are exported for each source and interval.

## Quality-control checks

Before interpreting a run:

1. Confirm that **unmatched_sites_no_rank_6100_5500.csv** and **unmatched_sites_no_rank_5500_4900.csv** contain no site records. The current script stops if rank matching fails.
2. Verify that the input workbooks and generated outputs come from the same revision.
3. Check the first-connected thresholds in **first_connected_network_by_rule_<interval>.csv**.
4. Check source-specific model selection in **source_confirmed_rule_selection_log_<interval>.csv**.
5. Use **sensitivity_summary_all_sites.csv** and the two **first_connected_rank_sensitivity_sqrt_<interval>.csv** files to reproduce the robustness statements reported in the manuscript.

## Main outputs

### Global outputs in OUTPUTS/

| File | Contents |
|---|---|
| **production_contribution_PN_all_sites.csv** | Category-wise site contributions |
| **manhattan_dissimilarity_PN_all_sites.csv** | Pairwise Manhattan dissimilarity matrix on contribution values |
| **production_score_all_sites.csv** | Contribution-based production score |
| **production_score_rank_thresholds_all_sites.csv** | 80th/90th percentile thresholds |
| **site_production_score_ranking_all_sites.csv** | Primary score and rank |
| **sensitivity_rank_comparison_all_sites.csv** | Primary versus square-root score/rank for every site |
| **sensitivity_summary_all_sites.csv** | Spearman, rank agreement, Jaccard overlap and Mantel statistics |
| **composition_only_manhattan_dissimilarity_all_sites.csv** | Composition-only distance matrix |
| **ranked_sites_all_sites.csv** | Cleaned site table with primary and square-root ranks |
| **rank_summary_all_sites.csv** | Number of sites by primary rank |
| **adonis_Manhattan_dissimilarity_by_rank_all_sites.csv** | PERMANOVA-style descriptive diagnostic |
| **pcoa_Manhattan_by_production_rank_all_sites.csv** | PCoA coordinates |
| **PCoA_Manhattan_by_production_rank_all_sites.png** | PCoA diagnostic plot |
| **pcoa_site_code_lookup_all_sites.csv** | Site labels used in the PCoA |
| **all_sites_numbered_black_white_map.png** | Figure 1 site-location map |
| **all_sites_numbered_map_lookup.csv** | Figure 1 site-number lookup |

### Interval-specific outputs

Files are written to **OUTPUTS/Obsidian_network_<interval>/**.

| File/pattern | Contents |
|---|---|
| **ranked_sites_<interval>.csv** | Chronological records with full-dataset ranks |
| **unmatched_sites_no_rank_<interval>.csv** | Rank-join QC |
| **Rule_<rule>_<distance>km_edges_<interval>.csv** | Edge list for each rule-distance model |
| **Rule_<rule>_<distance>km_map_<interval>.png** | Geographical network panel |
| **global_metrics_rule_distance_sweep_<interval>.csv** | Global metrics for the complete grid |
| **centrality_rule_distance_sweep_<interval>.csv** | Node centralities |
| **centrality_by_rank_rule_distance_sweep_<interval>.csv** | Centrality summaries by rank |
| **friedman_rule_comparison_<interval>.csv** | Friedman comparisons across rule sets |
| **pairwise_rule_comparison_<interval>.csv** | Pairwise Wilcoxon comparisons |
| **first_connected_network_by_rule_<interval>.csv** | First full-connectivity threshold by rule |
| **selected_backbone_network_<interval>.csv** | Selected general backbone |
| **selected_rule_a_source_filter_backbone_<interval>.csv** | Rule A backbone used for source filtering |
| **source_confirmed_rule_selection_log_<interval>.csv** | Source-filter rule/fallback log |
| **source_confirmed_metrics_<interval>.csv** | Source-filtered metrics |
| **<source>_source_confirmed_edges_<interval>.csv** | Source-filtered edges |
| **<source>_source_confirmed_vertices_<interval>.csv** | Source-filtered vertices |
| **network_rank_sensitivity_sqrt_<interval>.csv** | Complete rule-distance grid using square-root ranks |
| **first_connected_rank_sensitivity_sqrt_<interval>.csv** | First full-connectivity threshold by rule under square-root ranks |

Here **<source>** is **Lipari**, **Palmarola**, or **Sardegna** (the internal filename used for Monte Arci).

## Manuscript figures

**Figure 1** is generated as **OUTPUTS/all_sites_numbered_black_white_map.png**.

**Figure 2** is the conceptual schematic of rank-based connection rules and is prepared outside the R workflow.

The current script automatically assembles the publication composites for **Figures 3–8** in **OUTPUTS/Figures/**, exporting both PNG and LZW-compressed TIFF versions:

- Figure 3: rule-set comparison, earlier interval left and later interval right.
- Figure 4: earlier general networks; Rules A/B/C at 300 km above and 550 km below.
- Figure 5: later general networks; Rules A/B/C at 300 km above and 450 km below.
- Figure 6: Lipari source-confirmed networks, earlier above and later below; map left, graph-only view right.
- Figure 7: Palmarola, same arrangement.
- Figure 8: Monte Arci/Sardegna, same arrangement.

The individual panels remain available in the interval-specific output folders.

## HTML report

Open **CHRONOS_report.html** locally or through GitHub Pages:

https://nmazzucco.github.io/CHRONOS/CHRONOS_report.html

The report explains the analytical logic and expected outputs. It is intentionally static: running **CHRONOS.R** regenerates the analytical files but does not rewrite the report. If the analysis changes, update the script, outputs, README and HTML report together.

## Transparency and reproducibility

The repository makes the R workflow, analytical pipelines, input datasets and derived outputs openly available so that the classification, sensitivity tests and network models can be independently reproduced, inspected and extended.

When archiving a final analytical release, also preserve the exact R/package environment (for example, the output of **sessionInfo()**) and the repository commit used for the publication.

## Citation

Mazzucco N, et al. *Modelling Obsidian Production and Circulation across the Central Mediterranean, 6100–4900 cal BCE*. Associated CHRONOS analytical repository: https://github.com/nmazzucco/CHRONOS

## Author

Niccolò Mazzucco  
University of Pisa  
GitHub: @nmazzucco
