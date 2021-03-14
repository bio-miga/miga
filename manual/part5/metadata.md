# Metadata

## All objects

All metadata objects support the following fields:

| Field        | Supported values                  | Description
| ------------:|:---------------------------------:|:-------------------
| created*     | [Date](../glossary.md#miga-dates) | Date of creation
| updated*     | [Date](../glossary.md#miga-dates) | Date of last update

> **\*** Mandatory

## Projects

The following metadata fields are recognized by different interfaces for
**Projects**:

### Project Features

Metadata with additional information and features about the project:

| Field        | Supported values | Description
| ------------:|:----------------:|:------------------------------------
| comments     | String           | Free-form comments
| description  | String           | Free-form description
| name*        | [Name](../glossary.md#miga-names) | Name‡

> **\*** Mandatory


### Project System Metadata

Metadata entries automatically set by MiGA:

| Field        | Supported values | Description
| ------------:|:----------------:|:------------------------------------
| datasets*    | Array of String  | List of datasets in the project
| type*        | String           | [Type](../part2/types.md#project-types)

> **\*** Mandatory
> 
> **‡** By default the base name of the project path


### Project Flags

Metadata entries that trigger specific behaviors in MiGA:

| Field        | Supported values | Description
| ------------:|:----------------:|:------------------------------------
| ref_project  | Path             | Project with reference taxonomy
| db_proj_dir  | Path             | Directory containing database projects<sup>1</sup>
| tax_pvalue   | Float [0,1]      | Max p-value to transfer taxonomy (def: 0.05)
| haai_p       | String           | hAAI engine<sup>2</sup> (def: fastaai)
| aai_p        | String           | AAI engine<sup>2</sup> (def: diamond)
| ani_p        | String           | ANI engine<sup>2</sup> (def: fastani)
| max_try      | Integer          | Max number of task attempts (def: 10)
| aai_save_rbm | Boolean          | Should RBMs be saved for OGS analysis?
| ogs_identity | Float [0,100]    | Min RBM identity for OGS (def: 80)
| clean_ogs    | Boolean          | If false, keeps ABC (clades only)
| run_clades   | Boolean          | Should clades be estimated from distances?
| gsp_ani      | Float [0,100]    | ANI limit to propose gsp clades (def: 95)
| gsp_aai      | Float [0,100]    | AAI limit to propose gsp clades (def: 90)
| gsp_metric   | String           | Metric to propose clades: `ani` (def), `aai`
| ess_coll     | String           | Collection of essential genes to use<sup>3</sup>
| min_qual     | Float (or 'no')  | Min. genome quality (or no filter; def: 25)
| distances_checkpoint | Integer  | Comparisons before storing data (def: 10)

> **<sup>1</sup>** This is the relative location of the databases used by
> [db_project](#dataset-flags). If not set, it is assumed to be the parent
> folder of the current project.
>
> **<sup>2</sup>** Supported values: `blast`, `blat`, `diamond`
> (only for hAAI and AAI), `fastani` (only for ANI), `no` (only for hAAI),
> and `fastaai` (only for hAAI).
>
> **<sup>3</sup>** One of: `dupont_2012` (default), or `lee_2019`


### Project Hooks

Additionally, hooks can be defined for projects as arrays of arrays containing
the action name and the arguments (if any). For example, one can define:

```
on_processing_ready: [
  ['run_cmd', 'date > {{project}}/ALL_DONE.txt'],
  ['run_cmd', 'sendmail ...']
]
```

or

```
on_add_dataset: [
  ['run_cmd', 'echo {{object}} > {{project}}/LATEST_DATASET.txt']
]
```

Supported events:
- `on_create()`: When created
- `on_load()`: When loaded
- `on_save()`: When saved
- `on_add_dataset(object)`: When a dataset is added, with name `object`
- `on_unlink_dataset(object)`: When dataset with name `object` is unlinked
- `on_result_ready(object)`: When any result is ready, with key `object`
- `on_result_ready_{result}()`: When `result` is ready
- `on_processing_ready()`: When processing is complete

Supported hooks:
- `run_lambda(lambda, args...)`
- `run_cmd(cmd)`


## Datasets

The following metadata fields are recognized by different interfaces for
**Datasets**:

### Dataset Features

Metadata with additional information and features about the dataset:

| Field        | Supported values | Description
| ------------:|:----------------:|:----------------------------------
| tax          | MiGA::Taxonomy   | Taxonomy of the dataset
| quality      | String           | Description of genome quality
| dprotologue  | String           | Taxonumber in the Digital Protologue DB
| ncbi_tax_id  | String           | Linking ID(s)<sup>1</sup> for NCBI Taxonomy
| ncbi_nuccore | String           | Linking ID(s)<sup>1</sup> for NCBI Nucleotide
| ncbi_asm     | String           | Linking ID(s)<sup>1</sup> for NCBI Assembly
| ebi_embl     | String           | Linking ID(s)<sup>1</sup> for EBI EMBL
| ebi_ena      | String           | Linking ID(s)<sup>1</sup> for EBI ENA
| web_assembly | String           | URL to download assembly
| web_assembly_gz | String        | URL to download gzipped assembly
| see_also     | String           | Link(s)<sup>1</sup> in the format text:url
| is_type      | Boolean          | If it is type material
| is_ref_type  | Boolean          | If it is reference material<sup>2</sup>
| type_rel     | String           | Relationship to type material
| suspect      | Array(String)    | Flags indicating a suspect dataset

> **<sup>1</sup>** Multiple values can be provided separated by commas or colons
> 
> **<sup>2</sup>** This is not a valid type, but it represents the closest
> available dataset to material that is unavailable and unlikely to ever become
> available. See also [Federhen, 2015, NAR](https://doi.org/10.1093/nar/gku1127)


### Dataset System Metadata

Metadata entries automatically set by MiGA:

| Field        | Supported values | Description
| ------------:|:----------------:|:----------------------------------
| type*        | String           | [Type](../part2/types.md#dataset-types)
| ref          | Boolean          | [Reference](../part2/types.md#reference)
| inactive     | Boolean          | If auto-processing should stop
| metadata_only | Boolean         | Dataset with metadata but without input data
| status       | String           | Proc. status: complete, incomplete, inactive
| _step        | String           | For internal control of processing
| \_try_`step` | Integer          | For internal control of processing
| ~~user~~     | String           | Deprecated

> **\*** Mandatory


### Dataset Flags

Metadata entries that trigger specific behaviors in MiGA:

| Field        | Supported values | Description
| ------------:|:----------------:|:----------------------------------
| run_`step`   | Boolean          | Forces running or not `step`
| db_project   | Path             | Project to use as database
| dist_req     | Array of String  | Run distances against these datasets*

> **\*** When searching best-matching datasets, include these datasets even if
> they are not visited using the medoid tree


### Dataset Hooks

Additionally, hooks can be defined for datasets as arrays of arrays containing
the action name and the arguments. See above ([project hooks](#project-hooks))
for examples.

Supported events:
- `on_load()`: When loaded
- `on_save()`: When saved
- `on_remove()`: When removed
- `on_inactivate()`: When inactivated
- `on_activate()`: When activated
- `on_result_ready(object)`: When any result is ready, with key `object`
- `on_result_ready_{result}()`: When `result` is ready
- `on_preprocessing_ready()`: When preprocessing is complete

Supported hooks:
- `run_lambda(lambda, args...)`
- `clear_run_counts()`
- `run_cmd(cmd)`

