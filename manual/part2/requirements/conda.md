# Installing requirements using Conda

You can use [conda](https://conda.io/) to install most of the Software required
by MiGA.
If you don't have Conda, you can follow the
[Installation instructions](https://conda.io/projects/conda/en/latest/user-guide/install/index.html).

## Essentials

Now that you have Conda, activate it. If you want to create a separate clean
environment (optional) you can simply execute:

```bash
conda create -n miga
conda activate miga
```

Next, install the requirements:

```bash
conda install -y ruby r-base sqlite
conda install -y -c bioconda \
  blast hmmer bedtools prodigal idba mcl barrnap \
  fastqc solexaqa diamond krona fastani
conda install -y -c faircloth-lab scythe
```

Finally, conda's Ruby [is broken](https://github.com/ContinuumIO/anaconda-issues/issues/9863),
so we'll apply a quick patch to allow native gem installations:

```bash
cd $(gem environment gemdir)
cd ../../$(basename $PWD)/$(gem environment platform | perl -pe 's/.*://')
mv rbconfig.rb rbconfig.rb.bu
perl -pe 's/\/\S*?\/_build_env\/bin\///g' rbconfig.rb.bu > rbconfig.rb
```

## R packages

The full list of R packages are automatically installed by MiGA. However, we
will install one package here to make sure everything is properly initialized.

```bash
R
install.packages('enveomics.R', repos = 'http://cran.rstudio.com/')
q()
```

## MyTaxa utils

If you want to activate the [MyTaxa](../part5/workflow.md#mytaxa) and
[MyTaxa Scan](../part5/workflow.md#mytaxa-scan) steps, follow the instructions
to install the [MyTaxa Utils](mytaxa.md).

