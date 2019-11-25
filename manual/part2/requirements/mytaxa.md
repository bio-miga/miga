# Installing the MyTaxa utils

**The MyTaxa utilities are optional**, but without them the
[MyTaxa](../../part5/workflow.md#mytaxa) and
[MyTaxa scan](../../part5/workflow.md#mytaxa-scan) analyses are disabled.
Note that MyTaxa requires about **15Gb** of disk available to store the
database.

We will install the necessary software in `$HOME/apps`. You can change this
directory if you prefer:

```bash
[[ -d $HOME/apps/bin ]] || mkdir -p $HOME/apps/bin
cd $HOME/apps
echo 'export PATH=$HOME/apps/bin:$PATH' >> ~/.miga_modules
```

## MyTaxa

```bash
curl -L \
  https://github.com/luo-chengwei/MyTaxa/archive/master.tar.gz | tar zx
cd MyTaxa-master
make
python2 utils/download_db.py
curl -O \
  http://enve-omics.ce.gatech.edu/data/public_mytaxa/AllGenomes.faa.dmnd
echo 'export PATH='$PWD':$PATH' >> ~/.miga_modules
cd ..
```

## Krona

If you followed the instructions for [conda](conda.md), you already have Krona.
If you still need to install Krona, simply execute:

```bash
curl -L \
  https://github.com/marbl/Krona/archive/master.tar.gz | tar zx
( cd Krona-master/KronaTools && ./install.pl --prefix ../.. )
```

