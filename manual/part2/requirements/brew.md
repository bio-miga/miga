# Live notebook

If you prefer to see code in action, the full installation process
with homebrew is available as a
[Notebook in Google Collab](https://colab.research.google.com/drive/1Wv4uZwLGuzc5RiAT8NkgJ6B_IKAeM0KU).

# Installing requirements using Homebrew

You can use [Homebrew](https://brew.sh/) to install most of the software
required by MiGA.
If you don't have Homebrew, execute (and follow the instructions):

```bash
/bin/bash -c "$(curl -fsSL \
  https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
```

Next, make sure you have the brewsci/bio tap:

```bash
brew tap brewsci/bio
```

## Essentials

Now that you have Homebrew and the science tap, execute:

```bash
# General-purpose software
brew install r sqlite3 python
# Bioinformatics software
brew install blast hmmer bedtools \
      prodigal idba mcl barrnap fastqc solexaqa \
      diamond fastani
brew install jonchang/biology/scythe
# Pending: Scythe in science (contacting authors)
# See: https://github.com/brewsci/homebrew-bio/issues/23
# See also: https://github.com/vsbuffalo/scythe/pull/20
```

## A recent Ruby

It's possible you already have a recent version of ruby (2.3+).
To check which version you have, simply run: `ruby -v`.
If your version of Ruby is older than 2.3, you can install a recent
version using:

```bash
brew install libyaml rbenv
rbenv install 2.7.1
rbenv global 2.7.1
```

We also recommend installing the `sqlite3` gem beforehand using the brew
libraries, to avoid headaches down the road:

```bash
gem install sqlite3 -- --with-sqlite3-dir="$(brew --prefix sqlite3)"
```

## R packages

The full list of R packages is automatically installed by MiGA. However, we
will install one package here to make sure everything is properly initialized.

```bash
Rscript -e "install.packages('ape', repos = 'http://cran.rstudio.com/')"
```

## MyTaxa utils

If you want to activate the [MyTaxa](../part5/workflow.md#mytaxa) and
[MyTaxa Scan](../part5/workflow.md#mytaxa-scan) steps, follow the instructions
to install the [MyTaxa Utils](mytaxa.md).

