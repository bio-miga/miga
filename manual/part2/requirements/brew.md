# Installing requirements using Homebrew or Linuxbrew

You can use [Homebrew](https://brew.sh/) to install most of the software
required by MiGA.
If you don't have Homebrew, execute (and follow the instructions):

```bash
/usr/bin/ruby -e "$(curl -fsSL \
      https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
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
rbenv
# Install a recent ruby
rbenv install 2.6.6
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

And make sure to restart your session (close and re-open the terminal).

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

