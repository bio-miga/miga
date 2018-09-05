# Metadata

All metadata objects support the following fields:

| Field        | Supported values                  | Description
| ------------:|:---------------------------------:|:-------------------
| created*     | [Date](../glossary.md#miga-dates) | Date of creation
| updated*     | [Date](../glossary.md#miga-dates) | Date of last update

\* Mandatory

## Projects

The following metadata fields are recognized by different interfaces for
**Projects**:

| Field        | Supported values | Description
| ------------:|:----------------:|:------------------------------------
| datasets*    | Array of String  | List of datasets in the project
| comments     | String           | Free-form comments
| description  | String           | Free-form description
| name*        | [Name](../glossary.md#miga-names) | Name<sup>1</sup>
| type*        | String           | [Type](../part2/types.md#project-types)
| plugins      | Array of String  | For internal control of plugins
| ref_project  | Path to Project  | Project with reference taxonomy
| tax_pvalue   | Float [0,1]      | Maximum p-value to transfer taxonomy
| aai_p        | String           | Value of -p for aai.rb<sup>2</sup> on AAI
| haai_p       | String           | Value of -p for aai.rb<sup>2</sup> on hAAI
| ani_p        | String           | Value of -p for ani.rb<sup>2</sup> on ANI
| max_try      | Integer          | Max number of times a task is attempted
| clean_ogs    | Boolean          | If false, keeps ABC (clades only)

\* Mandatory

<sup>1</sup> By default the base name of the project path

<sup>2</sup> By default: blast+. Other supported values: blast, blat, diamond
(except for ANI), and fastani (only for ANI). If using diamond and/or fastani,
the corresponding software must be installed.

## Datasets

The following metadata fields are recognized by different interfaces for
**Datasets**:

| Field        | Supported values | Description
| ------------:|:----------------:|:----------------------------------
| type*        | String           | [Type](../part2/types.md#dataset-types)
| ref          | Boolean          | If it is a reference dataset
| run_`step`   | Boolean          | Forces running or not `step`
| inactive     | Boolean          | If auto-processing should stop
| tax          | MiGA::Taxonomy   | Taxonomy of the dataset
| quality      | String           | Description of genome quality
| dprotologue  | String           | Taxonumber in the Digital Protologue DB
| ncbi_tax_id  | String           | Linking IDs<sup>1</sup> for NCBI Taxonomy
| ncbi_nuccore | String           | Linking IDs<sup>1</sup> for NCBI Nucleotide
| ncbi_asm     | String           | Linking IDs<sup>1</sup> for NCBI Assembly
| ebi_embl     | String           | Linking IDs<sup>1</sup> for EBI EMBL
| ebi_ena      | String           | Linking IDs<sup>1</sup> for EBI ENA
| web_assembly | String           | URL to download assembly
| web_assembly_gz | String        | URL to download gzipped assembly
| see_also     | String           | Links<sup>1</sup> in the format text:url
| is_type      | Boolean          | If it is type material
| is_ref_type  | Boolean          | If it is reference material<sup>2</sup>
| _step        | String           | For internal control of processing
| \_try_`step` | Integer          | For internal control of processing
| ~~user~~     | String           | Deprecated

\* Mandatory

<sup>1</sup> Multiple values can be provided separated by commas or colons.

<sup>2</sup> This is not a valid type, but it represents the closest available
dataset to material that is unavailable and unlikely to ever become available.
See also [Federhen, 2015, NAR](https://doi.org/10.1093/nar/gku1127).

