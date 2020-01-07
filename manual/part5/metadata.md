# Metadata

## All objects

All metadata objects support the following fields:

| Field        | Supported values                  | Description
| ------------:|:---------------------------------:|:-------------------
| created*     | [Date](../glossary.md#miga-dates) | Date of creation
| updated*     | [Date](../glossary.md#miga-dates) | Date of last update

**\*** Mandatory

## Projects

The following metadata fields are recognized by different interfaces for
**Projects**:

| Field        | Supported values | Description
| ------------:|:----------------:|:------------------------------------
| datasets*    | Array of String  | List of datasets in the project
| comments     | String           | Free-form comments
| description  | String           | Free-form description
| name*        | [Name](../glossary.md#miga-names) | Name‡
| type*        | String           | [Type](../part2/types.md#project-types)
| plugins      | Array of String  | For internal control of plugins
| ref_project  | Path             | Project with reference taxonomy
| db_proj_dir  | Path             | Directory containing database projects
| tax_pvalue   | Float [0,1]      | Max p-value to transfer taxonomy (def: 0.05)
| aai_p        | String           | Value of aai.rb -p° on AAI (def: blast+)
| haai_p       | String           | Value of aai.rb -p° on hAAI (def: blast+)
| ani_p        | String           | Value of ani.rb -p° on ANI (def: blast+)
| max_try      | Integer          | Max number of task attempts (def: 10)
| aai_save_rbm | Boolean          | Should RBMs be saved for OGS analysis?
| ogs_identity | Float [0,100]    | Min RBM identity for OGS (def: 80)
| clean_ogs    | Boolean          | If false, keeps ABC (clades only)
| run_clades   | Boolean          | Should clades be estimated from distances?
| gsp_ani      | Float [0,100]    | ANI limit to propose gsp clades (def: 90)
| gsp_aai      | Float [0,100]    | AAI limit to propose gsp clades (def: 95)
| gsp_metric   | String           | Metric to propose clades: `ani` (def), `aai`
| ess_coll     | String           | Collection of essential genes to use+

**\*** Mandatory

**‡** By default the base name of the project path

**°** By default: `blast+`. Other supported values: `blast`, `blat`,
`diamond` (except for ANI), and `fastani` (only for ANI), `no` (only for hAAI).
If using `diamond` and/or `fastani`, the corresponding software must be
installed

**+** One of: `dupont_2012` (default), or `lee_2019`

## Datasets

The following metadata fields are recognized by different interfaces for
**Datasets**:

| Field        | Supported values | Description
| ------------:|:----------------:|:----------------------------------
| type*        | String           | [Type](../part2/types.md#dataset-types)
| ref          | Boolean          | [Reference](../part2/types.md#reference)
| run_`step`   | Boolean          | Forces running or not `step`
| inactive     | Boolean          | If auto-processing should stop
| tax          | MiGA::Taxonomy   | Taxonomy of the dataset
| quality      | String           | Description of genome quality
| db_project   | Path             | Project to use as database
| dprotologue  | String           | Taxonumber in the Digital Protologue DB
| ncbi_tax_id  | String           | Linking ID(s)‡ for NCBI Taxonomy
| ncbi_nuccore | String           | Linking ID(s)‡ for NCBI Nucleotide
| ncbi_asm     | String           | Linking ID(s)‡ for NCBI Assembly
| ebi_embl     | String           | Linking ID(s)‡ for EBI EMBL
| ebi_ena      | String           | Linking ID(s)‡ for EBI ENA
| web_assembly | String           | URL to download assembly
| web_assembly_gz | String        | URL to download gzipped assembly
| see_also     | String           | Link(s)‡ in the format text:url
| is_type      | Boolean          | If it is type material
| is_ref_type  | Boolean          | If it is reference material°
| type_rel     | String           | Relationship to type material
| metadata_only | Boolean         | Dataset with metadata but without input data
| _step        | String           | For internal control of processing
| \_try_`step` | Integer          | For internal control of processing
| ~~user~~     | String           | Deprecated

**\*** Mandatory

**‡** Multiple values can be provided separated by commas or colons

**°** This is not a valid type, but it represents the closest available dataset
to material that is unavailable and unlikely to ever become available.
See also [Federhen, 2015, NAR](https://doi.org/10.1093/nar/gku1127)

