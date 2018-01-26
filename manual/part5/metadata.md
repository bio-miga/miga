# Metadata

The following metadata fields are recognized by different interfaces:

| Field      | Object  | Supported values | Description
| ----------:|:-------:|:----------------:|:------------------------------------
| ref_project| Project | Path to Project  | Project with reference taxonomy
| tax_pvalue | Project | Float [0,1]      | Maximum p-value to transfer taxonomy
| tax        | Dataset | MiGA::Taxonomy   | Taxonomy of the dataset
| run_`step` | Dataset | Boolean          | Forces running or not `step`
| quality    | Dataset | String           | Description of genome quality
| ncbi_tax_id  | Dataset | String         | Linking ID(s)* for NCBI Taxonomy
| ncbi_nuccore | Dataset | String         | Linking ID(s)* for NCBI Nucleotide
| user       | Dataset | String           | Deprecated
| aai_p      | Project | String           | Value of -p for aai.rb\*\* on AAI
| haai_p     | Project | String           | Value of -p for aai.rb\*\* on hAAI
| ani_p      | Project | String           | Value of -p for ani.rb\*\*\* on ANI
| see_also   | Dataset | String           | Link(s)* in the format text:url

\* Multiple IDs can be provided separated by commas or colons.
\*\* By default: blast+. Other supported values: blast, blat, diamond.
\*\*\* By default: blast+. Other supported values: blast, blat.

