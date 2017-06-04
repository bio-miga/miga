# Requirements

MiGA has a relatively long list of requirements, but most of them are easy to
install. Find your system below and follow the instructions.

## For Linux users with `apt-get`

### Essentials

If you have `apt-get`, execute:

```bash
# General-purpose software
sudo apt-get install ruby r-base sqlite3 python
# Bioinformatics software
sudo apt-get install ncbi-blast+ hmmer bedtools \
      prodigal idba mcl barrnap scythe fastqc
```

### SolexaQA++

Next, you'll need to install SolexaQA++. If you have a 64-bits Linux:

```bash
curl -L -o SolexaQA++_v3.1.7.1.zip "https://downloads.sourceforge.net/project/solexaqa/src/SolexaQA%2B%2B_v3.1.7.1.zip"
unzip -p SolexaQA++_v3.1.7.1.zip Linux_x64/SolexaQA++ > SolexaQA++
sudo install SolexaQA++ /usr/bin/
```

If you have 32-bits Linux, you can build SolexaQA++ from source:

```bash
sudo apt-get install libboost-dev libboost-filesystem-dev \
      libboost-regex-dev libboost-iostreams-dev
curl -L -o SolexaQA++_v3.1.7.1.zip "https://downloads.sourceforge.net/project/solexaqa/src/SolexaQA%2B%2B_v3.1.7.1.zip"
unzip SolexaQA++_v3.1.7.1.zip 'source/*'
cd source && make
sudo install source/SolexaQA++ /usr/bin/
```

### MyTaxa utils

**The MyTaxa utilities are optional**, but without them the `MyTaxa` and
`MyTaxa scan` analyses are disabled. Note that MyTaxa requires about 15Gb of
disk available to store the database.

We will install the necessary software in `$HOME/apps`. You can change this
directory if you prefer:

```bash
[[ -d $HOME/apps/bin ]] || mkdir -p $HOME/apps/bin
cd $HOME/apps

# Install Diamond
curl -L http://github.com/bbuchfink/diamond/releases/download/v0.9.4/diamond-linux64.tar.gz | tar zx
mv diamond diamond-sse2 bin/

# Install MyTaxa
curl -L https://github.com/luo-chengwei/MyTaxa/archive/master.tar.gz | tar zx
cd MyTaxa-master
make
python utils/download_db.py
curl -O http://enve-omics.ce.gatech.edu/data/public_mytaxa/AllGenomes.faa.dmnd
cd ../bin

# Install Krona
curl -L https://github.com/marbl/Krona/archive/master.tar.gz | tar zx
cd bin
for i in ../Krona-master/KronaTools/scripts/*.pl ; do
  ln -sf "$i" "$(basename $i .pl)"
done
cd ..
```

## For MacOS users (or other users with Homebrew)

If you have MacOS, we'll use Homebrew to install most of the software. If
you don't have Homebrew, execute (and follow the instructions):

```bash
/usr/bin/ruby -e "$(curl -fsSL \
      https://raw.githubusercontent.com/Homebrew/install/master/install)"
```

Next, make sure you have the science tap:

```bash
brew tap homebrew/science
```

### Essentials

Now that you have Homebrew and the science tap, execute:

```bash
# General-purpose software
brew install r sqlite3 python
# Bioinformatics software
brew install blast hmmer bedtools \
      prodigal idba mcl barrnap fastqc
brew install jonchang/biology/scythe
# Missing: SolexaQA++ (in pull request review)
```

### MyTaxa utils
**The MyTaxa utilities are optional**, but without them the `MyTaxa` and
`MyTaxa scan` analyses are disabled. Note that MyTaxa requires about 15Gb of
disk available to store the database.

We will install the necessary software in `$HOME/apps`. You can change this
directory if you prefer:

```bash
[[ -d $HOME/apps/bin ]] || mkdir -p $HOME/apps/bin
cd $HOME/apps

# Install Diamond (using Homebrew)
brew install diamond

# Install MyTaxa
curl -L https://github.com/luo-chengwei/MyTaxa/archive/master.tar.gz | tar zx
cd MyTaxa-master
make
python utils/download_db.py
curl -O http://enve-omics.ce.gatech.edu/data/public_mytaxa/AllGenomes.faa.dmnd

# Install Krona
curl -L -o Krona.tar.gz https://github.com/marbl/Krona/archive/master.tar.gz
tar zxf Krona.tar.gz
cd bin
for i in ../Krona-master/KronaTools/scripts/*.pl ; do
  ln -sf "$i" "$(basename $i .pl)"
done
cd ..
```

## For any other users

### Essentials

If you don't have either apt-get nor Homebrew, here's the list of requirements
and URLs with installation instructions:

* **Python**: https://www.python.org/.
* **R**: http://www.r-project.org/.
* **SQLite3**: https://www.sqlite.org/.
* **NCBI BLAST+**: ftp://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/LATEST.
* **HMMer**: http://hmmer.janelia.org/software. Required version: 3.0+.
* **Bedtools**: http://bedtools.readthedocs.org/en/latest/.
* **Prodigal**: http://prodigal.ornl.gov.
* **IDBA**: http://i.cs.hku.hk/~alse/hkubrg/projects/idba. Required flavor:
  IDBA-UD.
* **MCL**: http://micans.org/mcl/.
* **Barrnap**: http://www.vicbioinformatics.com/software.barrnap.shtml.
* **Scythe**: https://github.com/vsbuffalo/scythe. Required version: 0.991+.
* **FastQC**: http://www.bioinformatics.babraham.ac.uk/projects/fastqc.
* **SolexaQA++**: http://solexaqa.sourceforge.net. Required version: v3.1.3+.

### MyTaxa utils

**The MyTaxa utilities are optional**, but without them the `MyTaxa` and
`MyTaxa scan` analyses are disabled. Note that MyTaxa requires about 15Gb of
disk available to store the database.

To install **Diamond**, we provide below the method for 64-bits Linux. If you
have a different system please checkout https://github.com/bbuchfink/diamond
instead.

We will install the necessary software in `$HOME/apps`. You can change this
directory if you prefer:

```bash
[[ -d $HOME/apps/bin ]] || mkdir -p $HOME/apps/bin
cd $HOME/apps

# Install Diamond (for 64-bits Linux)
curl -L http://github.com/bbuchfink/diamond/releases/download/v0.9.4/diamond-linux64.tar.gz | tar zx
mv diamond diamond-sse2 bin/

# Install MyTaxa
curl -L https://github.com/luo-chengwei/MyTaxa/archive/master.tar.gz | tar zx
cd MyTaxa-master
make
python utils/download_db.py
curl -O http://enve-omics.ce.gatech.edu/data/public_mytaxa/AllGenomes.faa.dmnd
cd ..

# Install Krona
curl -L https://github.com/marbl/Krona/archive/master.tar.gz | tar zx
cd bin
for i in ../Krona-master/KronaTools/scripts/*.pl ; do
  ln -sf "$i" "$(basename $i .pl)"
done
cd ..
```
