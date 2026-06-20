CHRONOS is a reproducible R workflow for modelling the production, ranking, and circulation of obsidian in the Central Mediterranean during the Neolithic. The repository contains the input data structure, map files, analytical script, generated outputs, and an illustrated HTML report prepared for publication.
The workflow combines technological quantification, production-score ranking, Brainerd–Robinson similarity/dissimilarity analysis, network modelling, distance-threshold sensitivity testing, source-filtered obsidian circulation networks, and publication-ready cartographic outputs.

---

Repository structure
```text
CHRONOS/
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
    └── global output tables and figures
```

---

Project aims:
CHRONOS was developed to explore how obsidian production and circulation changed across two chronological intervals:
6100–5500 cal BC
5500–4900 cal BC
The workflow addresses four main questions:
How can archaeological sites be ranked according to their involvement in obsidian production and transformation?
How do different connection rules and distance thresholds affect the structure of reconstructed exchange networks?
Which network models provide the most parsimonious explanation for regional obsidian circulation?
How do source-specific networks differ for Sardinian / Monte Arci, Lipari, and Palmarola obsidian?

---

Main analytical workflow
The R script performs the following steps.
1. Data loading and cleaning
The script reads the main obsidian dataset and two chronological subsets from the `RAWDATA/` folder. Site names, coordinates, technological variables, total artefact counts, and source-attribution columns are standardised.
Expected technological variables are:
```r
blade
flake
core
by.products.waste
```
Expected source columns are:
```r
Sardegna
Lipari
Palmarola
```

2. Production-score ranking
For each technological category, the script calculates the percentage contribution of each site to the total amount of that category in the complete dataset.
The production score is calculated as:
```text
Production_score =
blade.PN + flake.PN + core.PN + by.products.waste.PN
```

Sites are then assigned to three production ranks:
Rank	Interpretation	Criterion
Rank 1	Low production involvement / consumer sites	Below the 80th percentile
Rank 2	Intermediate production involvement	Between the 80th and 90th percentiles
Rank 3	High production involvement / producer sites	At or above the 90th percentile
Rank 4	Raw-material source nodes	Manually added source locations
The three raw-material source nodes added by the script are:
Monte Arci
Lipari
Palmarola

3. Brainerd–Robinson diagnostic analysis
The workflow calculates a Brainerd–Robinson-style similarity and dissimilarity matrix on production-contribution values. These matrices are used as diagnostic tools, not for assigning ranks.
The diagnostic stage includes:
Brainerd–Robinson similarity matrix
Brainerd–Robinson dissimilarity matrix
PERMANOVA-style test of differences among production ranks
PCoA visualisation of technological dissimilarity space
4. Chronological splitting
After ranks are calculated on the full dataset, they are attached to the two chronological subsets:
`obs_data_corr_6100_5500.xlsx`
`obs_data_corr_5500_4900.xlsx`
This ensures that site rank is defined consistently across both chronological phases.

5. Network model construction
For each chronological interval, the script builds directed networks using combinations of rule sets and distance thresholds.
The three rule sets are:
Rule set	Allowed connections	Interpretation
Rule A	`4-3`, `3-2`, `3-1`, `2-1`	Parsimonious hierarchical model excluding direct source-to-intermediate links
Rule B	`4-3`, `4-2`, `3-2`, `3-1`, `2-1`	Less restrictive model allowing direct source-to-intermediate links
Rule C	`4-3`, `3-2`, `2-1`	Strict stepped hierarchical model
Distance thresholds are tested from 100 km to 650 km, in 50 km increments.
For each model, the script exports:
edge lists
network maps
global metrics
centrality measures
rule-distance sensitivity summaries

6. Model comparison
The script evaluates how each rule set behaves across distance thresholds using:
number of edges
number of components
number of isolates
largest component size
first fully connected model for each rule set
Friedman tests for repeated comparison across distance thresholds
pairwise Wilcoxon signed-rank tests as post-hoc comparisons

7. Source-confirmed networks
The workflow extracts source-specific confirmed networks for:
Sardegna / Monte Arci
Lipari
Palmarola
Rule A is used as the preferred backbone because it is more parsimonious. If Rule A produces an uninformative source-confirmed graph, the script falls back to Rule B. The fallback decision is recorded in the output tables.

8. Publication map
The script also generates a numbered black-and-white map of all sites, together with a lookup table linking map IDs to site names and coordinates.
---

Main outputs
The script writes outputs to the `OUTPUTS/` folder and to the two chronological subfolders:
```text
OUTPUTS/Obsidian_network_6100_5500/
OUTPUTS/Obsidian_network_5500_4900/
```


Key global output tables

File	Description
`production_contribution_PN_all_sites.csv`	Production-contribution matrix for all sites

`obs_br_PN_all_sites.csv`	Brainerd–Robinson similarity matrix

`production_score_all_sites.csv`	Production score for each site

`production_score_rank_thresholds_all_sites.csv`	Thresholds used to define Rank 2 and Rank 3

`site_production_score_ranking_all_sites.csv`	Final rank assignment

`ranked_sites_all_sites.csv`	Full cleaned dataset with ranks attached

`rank_summary_all_sites.csv`	Number of sites per rank

`adonis_BR_dissimilarity_by_rank_all_sites.csv`	PERMANOVA-style test results

`pcoa_BR_by_production_rank_all_sites.csv`	PCoA coordinates for the BR diagnostic plot

`pcoa_site_code_lookup_all_sites.csv`	Short labels used in the PCoA figure

`all_sites_numbered_map_lookup.csv`	Lookup table for the numbered publication map



Key chronological output tables

For each interval, the script produces:

File type	Description
`ranked_sites_<interval>.csv`	Chronological dataset with full-dataset ranks attached

`unmatched_sites_no_rank_<interval>.csv`	Sites that could not be matched to the full-dataset rank table

`*_edges_<interval>.csv`	Edge list for each rule-distance network

`global_metrics_rule_distance_sweep_<interval>.csv`	Global metrics for all tested networks

`centrality_rule_distance_sweep_<interval>.csv`	Site-level centrality values for all networks

`friedman_rule_comparison_<interval>.csv`	Friedman test results comparing rule sets

`pairwise_rule_comparison_<interval>.csv`	Pairwise Wilcoxon post-hoc comparisons

`first_connected_network_by_rule_<interval>.csv`	First fully connected network for each rule set

`selected_backbone_network_<interval>.csv`	Selected backbone network for downstream analyses

`selected_rule_a_source_filter_backbone_<interval>.csv`	Rule A backbone selected for source-filtered networks

`centrality_by_rank_rule_distance_sweep_<interval>.csv`	Average centrality values by rank

`source_confirmed_rule_selection_log_<interval>.csv`	Rule-selection and fallback log for source-confirmed networks

`source_confirmed_metrics_<interval>.csv`	Metrics for source-confirmed networks

`<source>_source_confirmed_edges_<interval>.csv`	Source-confirmed edge list

`<source>_source_confirmed_vertices_<interval>.csv`	Source-confirmed vertex list



Key figures

The script generates several classes of figures:

Figure type	Description
`PCoA_BR_by_production_rank_all_sites.png`	Diagnostic PCoA plot of production ranks in BR dissimilarity space

`*_map_<interval>.png`	Geographic network map for each rule-distance model

`rule_set_metric_comparison_<interval>.png`	Comparison of network metrics across rule sets and distance thresholds

`degree_by_rank_rule_distance_sweep_<interval>.png`	Degree centrality by rank across all rule-distance models

`<source>_source_confirmed_map_<interval>.png`	Source-confirmed network plotted geographically

`<source>_source_confirmed_graph_only_<interval>.png`	Source-confirmed graph layout without geographic base map

`all_sites_numbered_black_white_map.png`	Publication-ready numbered site-location map



The complete illustrated discussion of figures and tables is provided in:
```text
CHRONOS_report.html
```
---

Software requirements
The workflow is written in R and uses the following packages:
```r
openxlsx
dplyr
tidyr
ggplot2
igraph
sf
ggrepel
ggspatial
vegan
units
```
Install the required packages with:
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
---

Running the workflow
The script expects the following folder structure:
```text
CHRONOS/
├── CHRONOS.R
├── RAWDATA/
├── MAP/
└── OUTPUTS/
```
The path is automatically detected from the local OneDrive folder used during development. If running the script on another machine, edit the path definition at the beginning of the R script:
```r
chronos_base <- file.path(one_drive_path, "R", "CHRONOS", "NEWCODE")
```

Then run the full R script.

All output folders are created automatically if they do not already exist.

---

Viewing the report
The main report is:
```text
CHRONOS_report.html
```
When viewed directly on GitHub, HTML files are usually shown as source code. To display the report as a webpage, enable GitHub Pages:
```text
Settings → Pages → Deploy from branch → main → /root
```

After deployment, the report can be opened as a public webpage from the GitHub Pages URL.

---
Reproducibility notes
For publication, the repository should include:
the R script used to generate the results;
the input datasets or a clearly documented procedure for obtaining them;
the shapefile components required for mapping;
all generated tables and figures;
the illustrated HTML report;
a README file explaining repository structure and usage;
a licence file;
a citation file if the repository is archived through Zenodo.

Recommended additional files:
```text
LICENSE
CITATION.cff
.gitignore
```

---
Suggested citation
If this repository is archived with Zenodo, cite the archived version using the DOI generated by Zenodo.
Suggested provisional citation format:
```text
Mazzucco, N. CHRONOS: Reproducible workflow for modelling Neolithic obsidian production and circulation in the Central Mediterranean. GitHub repository.
```

---

Author
Niccolò Mazzucco  
University of Pisa  
GitHub: `@nmazzucco`

---
Licence
Add a `LICENSE` file before publication. For open scientific code, a permissive licence such as MIT is commonly used. For data and figures, consider whether a Creative Commons licence is more appropriate.
