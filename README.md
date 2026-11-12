# CHRONOS

CHRONOS is an R workflow for modelling documented involvement in Neolithic obsidian production and potential circulation networks in the Central Mediterranean. It compares the intervals **6100–5500 cal BCE** and **5500–4900 cal BCE**.

The repository contains one analytical entry-point script, [`CHRONOS.R`](CHRONOS.R), the input datasets and map files, generated tables and individual figure panels, and an illustrated HTML report.

## Start here

- **Run the analyses:** follow [Reproducing the analyses](#reproducing-the-analyses).
- **Find a manuscript figure:** use the [figure-to-code mapping](#manuscript-figures-and-their-generating-code), including the panel order for Figures 3–8.
- **Browse the illustrated workflow:** [open the CHRONOS HTML report](https://nmazzucco.github.io/CHRONOS/CHRONOS_report.html).
- **Find an output table:** use the [output catalogue below](#output-table-catalogue) or the [catalogue in the HTML report](https://nmazzucco.github.io/CHRONOS/CHRONOS_report.html#tables).

The HTML report explains the workflow step by step, displays the analytical figures, provides interpretative commentary, and identifies the output files. It is a companion to the executable script. Its section numbers describe analytical stages and are not the manuscript's figure numbers.

## Repository structure

```text
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
    ├── PCoA_BR_by_production_rank_all_sites.png
    ├── all_sites_numbered_black_white_map.png
    └── global output tables
```

## Reproducing the analyses

### 1. Download the complete repository

Clone the repository or download and extract its ZIP archive. Keep `CHRONOS.R`, `RAWDATA/`, and `MAP/` together in the repository root. The R script alone is not sufficient because it reads the three input workbooks and the map shapefile.

| Input | Role |
|---|---|
| [`RAWDATA/obs_data_corr.xlsx`](RAWDATA/obs_data_corr.xlsx) | Complete technological dataset used to calculate production scores and ranks |
| [`RAWDATA/obs_data_corr_6100_5500.xlsx`](RAWDATA/obs_data_corr_6100_5500.xlsx) | Earlier chronological dataset, including coordinates and source-attribution fields |
| [`RAWDATA/obs_data_corr_5500_4900.xlsx`](RAWDATA/obs_data_corr_5500_4900.xlsx) | Later chronological dataset, including coordinates and source-attribution fields |
| [`MAP/map_shp.shp`](MAP/map_shp.shp), with `.dbf`, `.shx`, and `.prj` companions | Background map used in the geographical figures |

Keep the shapefile components together. `MAP/map_shp.qmd` is accompanying map metadata; it is not an analysis script or a required Quarto workflow.

### 2. Install the R packages

The analysis requires R and the following packages. RStudio is optional.

```r
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
  "units"
))
```

The script checks for these packages before starting and reports any that are missing. Installation of spatial packages can require platform-specific system dependencies; follow the installation instructions for `sf` and `units` if their installation fails.

### 3. Run the complete workflow

Set the working directory to the repository root, where `CHRONOS.R` is located. In R or RStudio, run:

```r
source("CHRONOS.R")
```

Alternatively, from a terminal in the repository root:

```bash
Rscript CHRONOS.R
```

Run the whole script so that input cleaning, ranking, chronological matching, network construction, and plotting use the same inputs. The script creates the output directories automatically and writes regenerated results to the same filenames.

The executable sequence is:

| Stage | Relevant part of `CHRONOS.R` | Result |
|---|---|---|
| Full-dataset ranking and diagnostics | Section 5, called by Section 7.1 | Contribution values, production scores, percentile ranks, PERMANOVA results, and PCoA |
| Attach ranks to chronological records | Sections 7.2–7.5 | Two chronological datasets with the full-dataset ranks attached, plus unmatched-site lists |
| Build and compare rule-distance networks | Sections 6.1–6.6, called by Section 7.6 | Complete rule-distance grid, maps, edge lists, metrics, and statistical comparisons |
| Select backbones and build source-filtered networks | Sections 6.7–6.10, called by Section 7.6 | Selected models, source maps and graphs, source metrics, and selection logs |
| Draw the numbered site-location map | Section 8 | Site map and number-to-site lookup table |

### 4. Check that the run is ready to interpret

For each interval, inspect `OUTPUTS/Obsidian_network_<interval>/unmatched_sites_no_rank_<interval>.csv`. Both files should contain a header and **no unmatched site records**. The console also prints the number of unmatched sites.

Ranks are transferred by matching normalised site names. Normalisation handles whitespace, accents, and case, but not spelling differences. An unmatched site has no assigned rank and cannot receive links under the rank-based connection rules. The current script warns and continues, so resolve any unmatched records in the input workbooks and rerun before interpreting the networks.

Also check that the same archaeological context has consistent coordinates and technological counts across the complete and chronological inputs. Use the freshly generated CSV files to verify numbers quoted in the manuscript.

The script sets `set.seed(123)`. To record the R and package versions used for a run, execute the following in R after the analysis finishes:

```r
writeLines(capture.output(sessionInfo()), "OUTPUTS/sessionInfo.txt")
```

This version record is produced by the command above; it is not automatically written by `CHRONOS.R`.

## Manuscript figures and their generating code

**`CHRONOS.R` generates the analytical panels used for Figures 1 and 3–8.** The table below identifies the code sections, exact output-name patterns, and manuscript panel order. Figure 2 is a conceptual schematic prepared outside the R workflow.

The current repository script exports **individual PNG panels**. Combining them into the final multi-panel publication figures is a separate preparation step; the public script does not currently write files named `Figure_3.tiff` through `Figure_8.tiff`. Arrange the regenerated panels as specified below.

In this table:

- `<interval>` means `6100_5500` or `5500_4900`.
- Interval-specific files are in `OUTPUTS/Obsidian_network_<interval>/`.
- `<rule>` means `A`, `B`, or `C`.

| Manuscript figure | Generating code in `CHRONOS.R` | Output files and arrangement |
|---|---|---|
| **Figure 1 — Site locations** | Section 8, `plot_all_sites_numbered_map()` | [`OUTPUTS/all_sites_numbered_black_white_map.png`](OUTPUTS/all_sites_numbered_black_white_map.png). Site numbers are identified in [`OUTPUTS/all_sites_numbered_map_lookup.csv`](OUTPUTS/all_sites_numbered_map_lookup.csv). |
| **Figure 2 — Connection rules** | Schematic prepared outside R; the model rules are implemented as `rule_sets` in Section 6.1 | Conceptual illustration of the permitted rank connections under Rules A–C. No Figure 2 image is exported by the script. See the [rule definitions below](#network-rules-and-threshold-selection). |
| **Figure 3 — Rule-set comparison** | Section 6.3, `rule_comparison_plot` within `run_network_models()` | `rule_set_metric_comparison_6100_5500.png` on the **left** and `rule_set_metric_comparison_5500_4900.png` on the **right**, each from its interval folder. |
| **Figure 4 — Earlier network configurations** | Section 6.2, `build_network()` and `plot_network_map()` | Earlier interval folder. **Top row:** `Rule_<rule>_300km_map_6100_5500.png`. **Bottom row:** `Rule_<rule>_550km_map_6100_5500.png`. Rules **A, B, C** run left to right in each row. |
| **Figure 5 — Later network configurations** | Section 6.2, `build_network()` and `plot_network_map()` | Later interval folder. **Top row:** `Rule_<rule>_300km_map_5500_4900.png`. **Bottom row:** `Rule_<rule>_450km_map_5500_4900.png`. Rules **A, B, C** run left to right in each row. |
| **Figure 6 — Lipari** | Section 6.10.6, `plot_network_map()` and `plot_network_graph_only()` | `Lipari_source_confirmed_map_<interval>.png` and `Lipari_source_confirmed_graph_only_<interval>.png`. **Earlier interval on top, later below; geographical map on the left, graph-only layout on the right.** |
| **Figure 7 — Palmarola** | Section 6.10.6, the same plotting functions | `Palmarola_source_confirmed_map_<interval>.png` and `Palmarola_source_confirmed_graph_only_<interval>.png`. Same panel arrangement as Figure 6. |
| **Figure 8 — Monte Arci/Sardinia** | Section 6.10.6, the same plotting functions | `Sardegna_source_confirmed_map_<interval>.png` and `Sardegna_source_confirmed_graph_only_<interval>.png`. Same panel arrangement as Figure 6. The internal source name and filename prefix are **`Sardegna`**. |

For Figures 3–5, panel letters follow the order left to right, then top to bottom where applicable. For Figures 6–8, A is the earlier map, B the earlier graph-only layout, C the later map, and D the later graph-only layout.

The thresholds illustrated in Figures 4 and 5 are selected views from the full sensitivity grid. For the source-filtered Figures 6–8, obtain the actual selected rule and distance threshold from `source_confirmed_rule_selection_log_<interval>.csv` and `source_confirmed_metrics_<interval>.csv` for that run. Report those parameters in the figure captions; they are selected from the input-dependent network results.

### Additional diagnostic figures

| Output | Generating code | Purpose |
|---|---|---|
| [`OUTPUTS/PCoA_BR_by_production_rank_all_sites.png`](OUTPUTS/PCoA_BR_by_production_rank_all_sites.png) | Section 5.7b | PCoA diagnostic of production ranks; this is not the conceptual Figure 2 |
| `degree_by_rank_rule_distance_sweep_<interval>.png` | Section 6.9 | Degree centrality by rank across the rule-distance grid |
| `Rule_<rule>_<distance>km_map_<interval>.png` | Section 6.2 | All tested geographical networks, including configurations not selected for the manuscript panels |

The rule-comparison and network panels used for Figures 3–8 are exported at 6.8 × 5.5 inches and 300 dpi. Figure 1 is exported at 8.5 × 6.2 inches; the additional PCoA plot uses 7.6 × 5.8 inches, also at 300 dpi. Re-run the analytical workflow after changing inputs before assembling publication figures, so that panels and tables correspond to the same run.

## Analytical definitions

### Production-score ranks

The four technological variables are `blade`, `flake`, `core`, and `by.products.waste`. For each category, the script calculates each site's percentage contribution to the category total across the complete dataset. These contribution values are not percentages within each site's assemblage and are not rescaled by row.

```text
Production_score =
  blade.PN + flake.PN + core.PN + by.products.waste.PN
```

| Rank | Operational interpretation | Criterion |
|---|---|---|
| 1 | Lower documented production involvement | Score below the 80th-percentile threshold |
| 2 | Intermediate documented production involvement | Score at or above the 80th percentile and below the 90th percentile |
| 3 | Higher documented production involvement | Score at or above the 90th percentile |
| 4 | Geological source location | Manually added Monte Arci, Lipari, and Palmarola source nodes |

Ranks are calculated once for the full dataset and then attached to the chronological records. Rank assignment uses the production score and percentile thresholds, not an unsupervised clustering procedure.

### Manhattan dissimilarity diagnostics

The active diagnostic calculation uses `vegan::vegdist(..., method = "manhattan")` on the production-contribution matrix. The script's intermediate transformation yields **Manhattan distance divided by two** for the PERMANOVA and PCoA. Existing object and output names containing `BR` are retained in the code and filenames.

These diagnostics describe the rank groups in the same contribution space from which their scores were calculated; they do not provide independent validation of the classification. See [HTML report, Step 3](https://nmazzucco.github.io/CHRONOS/CHRONOS_report.html#step3) for the illustrated diagnostic.

### Network rules and threshold selection

| Rule | Permitted rank connections | Model distinction |
|---|---|---|
| A | `4-3`, `3-2`, `3-1`, `2-1` | Direct source connections restricted to Rank 3, with additional non-consecutive site connections |
| B | `4-3`, `4-2`, `3-2`, `3-1`, `2-1` | Also permits direct source-to-Rank 2 connections |
| C | `4-3`, `3-2`, `2-1` | Permits only consecutive-rank connections |

For each interval, the script evaluates the **complete grid from 100 to 650 km in 50 km steps**. Distances are calculated between site/source coordinates after projection to EPSG:3035. Edges require both an allowed rank pair and a distance within the selected threshold. Connectivity and centrality are evaluated on undirected, unweighted representations of the graphs.

After evaluating the grid, the script identifies the **lowest tested threshold achieving full connectivity for each rule**. Full connectivity means that all sites and source nodes in that general network belong to one connected component. This selection does not stop the sensitivity-grid calculations at the first connected threshold.

For the general backbone, the executable preference is Rule A, then B, then C among rules that achieve full connectivity. If none does, the maximum-distance Rule B graph is retained as a fallback. The selected model is recorded in `selected_backbone_network_<interval>.csv`.

### Source-confirmed networks

Source columns are `Sardegna` (Monte Arci), `Lipari`, and `Palmarola`: `1` means documented presence, `0` absence, and a blank/`NA` unknown or not analysed.

Source filtering uses a separately selected Rule A backbone: its first fully connected configuration, or its maximum tested threshold if Rule A never achieves full connectivity. The script retains the selected source and sites with an explicit presence value of `1`, excluding other source nodes and sites with absent or unknown attribution. Ranks remain those calculated from the total obsidian assemblages.

If that filtered Rule A graph is uninformative—empty, without edges, or with an isolated selected source—the workflow uses a Rule B fallback, selected at Rule B's first fully connected threshold or its maximum tested threshold if none is connected. Full connectivity is **not imposed again after source filtering**. The parameters and any fallback are recorded in `source_confirmed_rule_selection_log_<interval>.csv` and `source_confirmed_metrics_<interval>.csv`; the backbone name includes the distance threshold.

## Output table catalogue

### Global outputs in `OUTPUTS/`

| File | Contents |
|---|---|
| `production_contribution_PN_all_sites.csv` | Category-wise contribution matrix |
| `obs_br_PN_all_sites.csv` | Legacy-named intermediate matrix, calculated as `1 - Manhattan_distance / 2` |
| `production_score_all_sites.csv` | Production score for every site |
| `production_score_rank_thresholds_all_sites.csv` | 80th- and 90th-percentile score thresholds |
| `site_production_score_ranking_all_sites.csv` | Score and rank assignment |
| `ranked_sites_all_sites.csv` | Full cleaned technological dataset with scores and ranks |
| `rank_summary_all_sites.csv` | Number of sites in each rank |
| `adonis_BR_dissimilarity_by_rank_all_sites.csv` | PERMANOVA-style diagnostic results |
| `pcoa_BR_by_production_rank_all_sites.csv` | PCoA coordinates |
| `pcoa_site_code_lookup_all_sites.csv` | Abbreviations used in the PCoA labels |
| `all_sites_numbered_map_lookup.csv` | Figure 1 number-to-site and coordinate lookup |

### Chronological outputs in `OUTPUTS/Obsidian_network_<interval>/`

| File | Contents |
|---|---|
| `ranked_sites_<interval>.csv` | Chronological records with full-dataset scores and ranks |
| `unmatched_sites_no_rank_<interval>.csv` | Records that failed the rank lookup; verify that this contains no site rows |
| `Rule_<rule>_<distance>km_edges_<interval>.csv` | Edge list for a rule-distance configuration |
| `global_metrics_rule_distance_sweep_<interval>.csv` | Nodes, edges, components, isolates, largest-component size, and connectedness for the full grid |
| `centrality_rule_distance_sweep_<interval>.csv` | Site-level centralities for the grid |
| `centrality_by_rank_rule_distance_sweep_<interval>.csv` | Centrality summaries by rank |
| `friedman_rule_comparison_<interval>.csv` | Blocked comparisons among the three rule sets |
| `pairwise_rule_comparison_<interval>.csv` | Pairwise Wilcoxon comparisons with adjusted p-values |
| `first_connected_network_by_rule_<interval>.csv` | Lowest fully connected threshold for each rule that reaches connectivity |
| `selected_backbone_network_<interval>.csv` | Selected general backbone and its metrics |
| `selected_rule_a_source_filter_backbone_<interval>.csv` | Rule A backbone selected for source filtering |
| `source_confirmed_rule_selection_log_<interval>.csv` | Selected rule, backbone name (including its threshold), and fallback decision by source |
| `source_confirmed_metrics_<interval>.csv` | Metrics and selected model parameters for each source-filtered graph |
| `<source>_source_confirmed_edges_<interval>.csv` | Source-filtered edge list |
| `<source>_source_confirmed_vertices_<interval>.csv` | Retained source-filtered vertices and their attributes |

Here `<source>` is `Lipari`, `Palmarola`, or `Sardegna`. The [HTML table catalogue](https://nmazzucco.github.io/CHRONOS/CHRONOS_report.html#tables) lists the output filenames and explains their contents.

## Using the HTML report

Open [the online report](https://nmazzucco.github.io/CHRONOS/CHRONOS_report.html), or open [`CHRONOS_report.html`](CHRONOS_report.html) locally in a browser. For local viewing, keep `OUTPUTS/` beside the HTML file because its images use relative paths.

Useful report sections are:

- [Input data](https://nmazzucco.github.io/CHRONOS/CHRONOS_report.html#step1)
- [Production scores and ranks](https://nmazzucco.github.io/CHRONOS/CHRONOS_report.html#step2)
- [Manhattan-dissimilarity diagnostic](https://nmazzucco.github.io/CHRONOS/CHRONOS_report.html#step3)
- [Rule-distance networks](https://nmazzucco.github.io/CHRONOS/CHRONOS_report.html#step4)
- [Source-filtered networks](https://nmazzucco.github.io/CHRONOS/CHRONOS_report.html#step5)
- [Site-location map](https://nmazzucco.github.io/CHRONOS/CHRONOS_report.html#step6)
- [Output table catalogue](https://nmazzucco.github.io/CHRONOS/CHRONOS_report.html#tables)
- [Reproduction instructions](https://nmazzucco.github.io/CHRONOS/CHRONOS_report.html#reproducibility)

The report is a static explanatory document. Re-running `CHRONOS.R` regenerates the referenced analytical outputs but does **not** rewrite the report's numerical commentary. After an input or analysis revision, update that commentary, manuscript values, and figure captions against the same regenerated CSV tables and upload the corresponding outputs together.

## Reproducibility notes

The repository includes the analytical script, input datasets, map files, generated tables and figures, the illustrated HTML report, and this README. Preserve the repository revision and the R/package version record used for a reported analysis.

Recommended additional files before final publication:

```text
LICENSE
CITATION.cff
.gitignore
```

## Licence

Data, figures, documentation, and report are under Creative Commons Attribution 4.0 International (CC BY 4.0).

Suggested wording:

```text
Code in this repository is released under the MIT Licence.
Data, figures, documentation, and the HTML report are released under Creative Commons Attribution 4.0 International (CC BY 4.0), unless otherwise stated.
```

## Suggested citation

```text
Mazzucco, N. CHRONOS: Reproducible workflow for modelling Neolithic obsidian production and circulation in the Central Mediterranean. GitHub repository.
```

## Author

Niccolò Mazzucco  
University of Pisa  
GitHub: `@nmazzucco`
