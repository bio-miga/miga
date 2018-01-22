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

\* Multiple IDs can be provided separated by commas.
