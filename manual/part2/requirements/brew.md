# Installing requirements using Homebrew or Linuxbrew

You can use [Homebrew](https://brew.sh/) to install most of the software
required by MiGA.
If you don't have Homebrew, execute (and follow the instructions):

```bash
/usr/bin/ruby -e "$(curl -fsSL \
      https://raw.githubusercontent.com/Homebrew/install/master/install)"
```

Next, make sure you have the brewsci/science and brewsci/bio taps:

```bash
brew tap brewsci/science
brew tap brewsci/bio
```

## Essentials

Now that you have Homebrew and the science tap, execute:

```bash
# General-purpose software
brew install r sqlite3 python
brew cask install java
# Bioinformatics software
brew install blast hmmer bedtools \
      prodigal idba mcl barrnap fastqc solexaqa \
      diamond fastani
brew install jonchang/biology/scythe
# Pending: Scythe in science (contacting authors)
# See: https://github.com/brewsci/homebrew-bio/issues/23
# See also: https://github.com/vsbuffalo/scythe/pull/20
```

## R packages

The full list of R packages are automatically installed by MiGA. However, we
will install one package here to make sure everything is properly initialized.

```bash
R
install.packages('enveomics.R', repos = 'http://cran.rstudio.com/')
q('no')
```

## MyTaxa utils

If you want to activate the [MyTaxa](../part5/workflow.md#mytaxa) and
[MyTaxa Scan](../part5/workflow.md#mytaxa-scan) steps, follow the instructions
to install the [MyTaxa Utils](mytaxa.md).

