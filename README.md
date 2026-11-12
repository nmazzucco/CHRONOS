# CHRONOS

**CHRONOS – The Obsidian Route in the Central Mediterranean: DiaCHRONic Pathways and Cultural ConnectiOnS**

This repository contains the data, R workflow and derived outputs supporting the study **“Modelling Obsidian Production and Circulation across the Central Mediterranean, 6100–4900 cal BCE.”**

The analysis compares 74 archaeological contexts using technological counts, chronology, provenance and location. It then explores how alternative assumptions about technological involvement, source access and distance affect potential obsidian-circulation networks.

> **Important interpretative point:** the three archaeological ranks are operational levels of **documented technological involvement**. They are not fixed functional categories. Likewise, network edges and distance thresholds are modelling constructs, not demonstrated prehistoric journeys or exchange routes.

## Start here

For a complete reproduction from the repository root:

~~~r
source("CHRONOS.R")
~~~

or:

~~~bash
Rscript CHRONOS.R
~~~

The script reads the files in <code>RAWDATA/</code> and <code>MAP/</code>, regenerates the analytical tables and network panels in <code>OUTPUTS/</code>, and assembles publication Figures 3–8 in <code>OUTPUTS/Figures/</code>.

## Repository structure

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
│   └── map_shp.prj
└── OUTPUTS/
    ├── Obsidian_network_6100_5500/
    ├── Obsidian_network_5500_4900/
    ├── Figures/
    └── global analytical tables and figures
~~~

- **CHRONOS.R**: complete executable analysis.
- **RAWDATA/**: full and chronological input workbooks.
- **MAP/**: geographical background used for maps.
- **OUTPUTS/**: generated analytical tables, edge lists, maps, diagnostics and publication figures.
- **CHRONOS_report.html**: readable explanation of the workflow and the principal results.

## Software requirements

The workflow requires R and these packages:

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

RStudio is optional. The script also works from a terminal and detects the repository root automatically when <code>CHRONOS.R</code> is stored either in the root or in a <code>SCRIPTS/</code> subfolder.

## Input data and missing values

The principal technological variables are:

- <code>blade</code>
- <code>flake</code>
- <code>core</code>
- <code>by.products.waste</code>

The analytical denominator excludes technologically indeterminate pieces.

The workflow deliberately distinguishes **absence** from **unknown information**:

- technological count 0 = documented absence;
- technological count NA = unknown/unavailable; the script stops before ranking if such a value would enter the analysis;
- provenance 1 = source documented;
- provenance 0 = source documented as absent;
- provenance NA = unknown/not analysed.

This prevents missing information from being silently interpreted as archaeological absence.

## Analytical workflow

### 1. Contribution-based production score

For each technological category, each site is expressed as its percentage contribution to the total documented amount of that category across the 74-site dataset.

~~~text
Production_score =
  blade.PN +
  flake.PN +
  core.PN +
  by.products.waste.PN
~~~

These are **not within-site percentages**. The purpose is to retain both technological composition and the documented quantitative scale of obsidian working.

### 2. Operational ranks

The score distribution is divided using the 80th and 90th percentiles:

| Rank | Criterion | Operational meaning |
|---|---|---|
| 1 | below 80th percentile | lower documented technological involvement |
| 2 | 80th–90th percentile | intermediate documented technological involvement |
| 3 | upper decile | highest documented technological involvement |
| 4 | geological source node | Monte Arci, Lipari or Palmarola |

The percentile thresholds are reproducible analytical cut-offs, not archaeological boundaries, and they are defined before the network analysis.

For the current analytical run:

| Result | Value |
|---|---:|
| Rank 1 sites | 59 |
| Rank 2 sites | 7 |
| Rank 3 sites | 8 |
| Rank 2 minimum score | 4.074466 |
| Rank 3 minimum score | 12.775919 |

### 3. Manhattan diagnostic

Pairwise Manhattan dissimilarities are calculated on the same category-wise contribution matrix used for the score.

PERMANOVA and PCoA are therefore **descriptive diagnostics of the rank structure in contribution space**, not independent validation of the classification.

Current output names use <code>Manhattan</code>; obsolete <code>BR</code>-named files from earlier workflow versions have been removed from the repository.

### 4. Sensitivity to assemblage magnitude

Two complementary tests are used.

**Square-root sensitivity ranking.** Technological counts are square-root transformed before repeating the same category-wise scaling, score calculation and percentile ranking. This reduces the leverage of very large assemblages while still retaining quantitative differences.

**Composition-only diagnostic.** Within-site relative frequencies are converted to a Manhattan distance matrix and compared with the primary contribution-based distance structure using a Spearman Mantel test. This removes assemblage magnitude completely and therefore asks a different question: whether sites have similar internal technological compositions regardless of assemblage scale.

Current results:

| Sensitivity result | Value |
|---|---:|
| Spearman primary vs square-root scores | 0.987310 |
| Exact rank agreement | 97.3% |
| Rank 3 Jaccard overlap | 0.7778 |
| Rank 2+3 Jaccard overlap | 1.000 |
| Mantel r, primary vs composition-only | 0.163444 |
| Mantel p | 0.008 |

Only **La Scola** and **Renaghju** exchange Rank 2/Rank 3 positions under the square-root transformation, while membership in the combined upper two ranks is unchanged.

The weak Mantel correspondence does **not** mean that the primary ranking is unstable. It shows that a composition-only analysis deliberately removes the quantitative information retained by the primary contribution-based approach.

### 5. Chronological network models

Ranks are calculated once on the complete 74-site dataset and then joined to the chronological subsets:

- **6100–5500 cal BCE:** 33 archaeological sites + 3 source nodes = 36 network nodes.
- **5500–4900 cal BCE:** 41 archaeological sites + 3 source nodes = 44 network nodes.

The current quality-control files contain no unmatched archaeological sites.

The three network rules are:

| Rule | Permitted rank connections |
|---|---|
| A | 4–3, 3–2, 3–1, 2–1 |
| B | 4–3, 4–2, 3–2, 3–1, 2–1 |
| C | 4–3, 3–2, 2–1 |

Each rule is evaluated from **100 to 650 km in 50-km increments** using centre-to-centre geographical distances after projection to EPSG:3035.

Distance thresholds are modelling parameters. They do not directly represent prehistoric journeys and do not explicitly model coastlines, topography, currents, winds or social boundaries.

### 6. Principal connectivity results

The first distance at which all nodes belong to a single connected component is:

| Interval | Rule A | Rule B | Rule C |
|---|---:|---:|---:|
| 6100–5500 cal BCE | 550 km | 550 km | 650 km |
| 5500–4900 cal BCE | 450 km | 450 km | 450 km |

Rule A is used as the preferred parsimonious interpretative scenario because it reaches broad connectivity without adding the direct source-to-Rank 2 links permitted under Rule B. This preference is a modelling choice, not proof that prehistoric circulation followed Rule A.

With the square-root sensitivity ranking, the Rule A thresholds remain **550 km** and **450 km** respectively. In the earlier interval, Rule C changes from 650 km to 550 km; this is why the manuscript describes the robustness specifically in relation to the principal Rule A result.

### 7. Source-confirmed networks

Source-filtered models retain only sites where a particular obsidian source is explicitly documented. Ranks remain based on the **total obsidian assemblage**, because provenance and technological category cannot generally be linked at artefact level in the available evidence.

Current Rule A source-filtered results:

| Interval | Source | Nodes | Edges | Fully connected? |
|---|---|---:|---:|---|
| 6100–5500 | Monte Arci/Sardegna | 7 | 9 | yes |
| 6100–5500 | Lipari | 16 | 25 | yes |
| 6100–5500 | Palmarola | 16 | 30 | yes |
| 5500–4900 | Monte Arci/Sardegna | 13 | 26 | no: 2 components, 1 isolate |
| 5500–4900 | Lipari | 27 | 109 | yes |
| 5500–4900 | Palmarola | 16 | 59 | yes |

Rule B is available as a fallback only when the Rule A source-filtered graph is empty, lacks edges, lacks the source node, or leaves the source isolated. The current source-filtered models do not require that fallback.

## Quality-control checks

Before using a new analytical run, check:

1. <code>unmatched_sites_no_rank_6100_5500.csv</code> and <code>unmatched_sites_no_rank_5500_4900.csv</code> contain only their header.
2. <code>rank_summary_all_sites.csv</code> gives 59 / 7 / 8 sites in Ranks 1 / 2 / 3.
3. <code>sensitivity_summary_all_sites.csv</code> reproduces the sensitivity values above.
4. <code>first_connected_network_by_rule_&lt;interval&gt;.csv</code> reproduces the primary connectivity thresholds.
5. <code>first_connected_rank_sensitivity_sqrt_&lt;interval&gt;.csv</code> reproduces the square-root sensitivity thresholds.
6. <code>source_confirmed_rule_selection_log_&lt;interval&gt;.csv</code> records the source-filtered rule choice and any fallback.
7. RAWDATA and OUTPUTS are regenerated and uploaded together after any correction to the input workbooks.

## Principal outputs

### Global files in <code>OUTPUTS/</code>

| File | Contents |
|---|---|
| <code>production_contribution_PN_all_sites.csv</code> | category-wise contribution values |
| <code>manhattan_dissimilarity_PN_all_sites.csv</code> | primary Manhattan distance matrix |
| <code>production_score_all_sites.csv</code> | contribution-based production scores |
| <code>production_score_rank_thresholds_all_sites.csv</code> | 80th/90th percentile cut-offs |
| <code>site_production_score_ranking_all_sites.csv</code> | primary score and rank |
| <code>sensitivity_rank_comparison_all_sites.csv</code> | primary vs square-root score/rank for every site |
| <code>sensitivity_summary_all_sites.csv</code> | sensitivity statistics |
| <code>composition_only_manhattan_dissimilarity_all_sites.csv</code> | composition-only distance matrix |
| <code>ranked_sites_all_sites.csv</code> | cleaned full dataset with primary and square-root ranks |
| <code>rank_summary_all_sites.csv</code> | rank counts |
| <code>adonis_Manhattan_dissimilarity_by_rank_all_sites.csv</code> | PERMANOVA diagnostic |
| <code>pcoa_Manhattan_by_production_rank_all_sites.csv</code> | PCoA coordinates |
| <code>PCoA_Manhattan_by_production_rank_all_sites.png</code> | PCoA plot |
| <code>pcoa_site_code_lookup_all_sites.csv</code> | PCoA label lookup |
| <code>Figure1_site_number_lookup.csv</code> | Figure 1 site-number lookup |
| <code>Figure1_site_number_lookup.txt</code> | manuscript-ready numbered site list |
| <code>all_sites_numbered_black_white_map.png</code> | Figure 1 site-location map |
| <code>all_sites_numbered_map_lookup.csv</code> | Figure 1 lookup table |

### Interval folders

Each <code>OUTPUTS/Obsidian_network_&lt;interval&gt;/</code> folder contains:

- the ranked chronological dataset and rank-join QC file;
- Rules A–C edge lists and maps for every 50-km threshold from 100 to 650 km;
- global metrics and centrality tables;
- Friedman and pairwise Wilcoxon rule comparisons;
- first-connected thresholds;
- the selected backbone;
- source-confirmed vertices, edges, metrics and rule-selection logs;
- the complete square-root network-sensitivity grid and first-connected thresholds.

## Manuscript figures

- **Figure 1**: <code>OUTPUTS/all_sites_numbered_black_white_map.png</code>
- **Figure 2**: conceptual connection-rule schematic prepared outside the R workflow
- **Figures 3–8**: automatically assembled by <code>CHRONOS.R</code> in <code>OUTPUTS/Figures/</code> as PNG and LZW-compressed TIFF

Figure mapping:

| Figure | Content |
|---|---|
| 3 | rule-set comparison; earlier interval left, later interval right |
| 4 | earlier networks; Rules A/B/C at 300 km above and 550 km below |
| 5 | later networks; Rules A/B/C at 300 km above and 450 km below |
| 6 | Lipari source-confirmed networks |
| 7 | Palmarola source-confirmed networks |
| 8 | Monte Arci/Sardegna source-confirmed networks |

## HTML report

A more readable explanation of the workflow and key results is provided in <code>CHRONOS_report.html</code>.

GitHub Pages:

https://nmazzucco.github.io/CHRONOS/CHRONOS_report.html

The report is static: running the R script regenerates analytical outputs but does not automatically rewrite the HTML. If the analysis changes, update the R script, RAWDATA, OUTPUTS, README and HTML report together.

## Transparency and reproducibility

The repository makes the R workflow, analytical pipelines, input datasets and derived outputs openly available so that the classification, sensitivity tests and network models can be independently inspected, reproduced and extended.

For a publication archive, preserve the exact Git commit and the R/package environment used for the final run.

## Citation

Mazzucco N, et al. *Modelling Obsidian Production and Circulation across the Central Mediterranean, 6100–4900 cal BCE*. CHRONOS analytical repository: https://github.com/nmazzucco/CHRONOS

## Author

Niccolò Mazzucco  
University of Pisa  
GitHub: @nmazzucco
