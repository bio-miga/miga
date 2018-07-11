# Metadata

The following metadata fields are recognized by different interfaces:

| Field      | Object  | Supported values | Description
| ----------:|:-------:|:----------------:|:------------------------------------
| ref_project| Project | Path to Project  | Project with reference taxonomy
| tax_pvalue | Project | Float [0,1]      | Maximum p-value to transfer taxonomy
| aai_p      | Project | String           | Value of -p for aai.rb\*\* on AAI
| haai_p     | Project | String           | Value of -p for aai.rb\*\* on hAAI
| ani_p      | Project | String           | Value of -p for ani.rb\*\* on ANI
| max_try    | Project | Integer          | Max number of times a task is attempted
| run_`step` | Dataset | Boolean          | Forces running or not `step`
| inactive   | Dataset | Boolean          | Indicates if auto-processing should stop
| tax        | Dataset | MiGA::Taxonomy   | Taxonomy of the dataset
| quality    | Dataset | String           | Description of genome quality
| dprotologue  | Dataset | String         | Taxonumber in the Digital Protologue Database
| ncbi_tax_id  | Dataset | String         | Linking ID(s)* for NCBI Taxonomy
| ncbi_nuccore | Dataset | String         | Linking ID(s)* for NCBI Nucleotide
| ncbi_asm     | Dataset | String         | Linking ID(s)* for NCBI Assembly
| ebi_embl     | Dataset | String         | Linking ID(s)* for EBI EMBL
| ebi_ena      | Dataset | String         | Linking ID(s)* for EBI ENA
| see_also     | Dataset | String         | Link(s)* in the format text:url
| is_type      | Dataset | Boolean        | Indicates if it is type material
| _step        | Dataset | String         | For internal control of processing
| \_try_`step` | Dataset | Integer        | For internal control of processing
| ~~user~~     | Dataset | String         | Deprecated

\* Multiple IDs can be provided separated by commas or colons.

\*\* By default: blast+. Other supported values: blast, blat, diamond (except
for ANI), and fastani (only for ANI). If using diamond and/or fastani, the
corresponding software must be installed.

