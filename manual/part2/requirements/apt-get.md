# Installing requirements using `apt-get`

## Essentials

If you have `apt-get`, execute:

```bash
# General-purpose software
sudo apt-get update
sudo apt-get install ruby ruby-sqlite3 r-base sqlite3 python \
  libcurl4-openssl-dev
# Bioinformatics software
sudo apt-get install ncbi-blast+ hmmer bedtools idba \
  prodigal mcl barrnap scythe fastqc diamond-aligner
sudo ln -s $(which diamond-aligner) /usr/bin/diamond
```

## IDBA

Some indexes may still have an old version of IDBA that didn't build the
IDBA-UD flavor (you'll need at least v1.1.3-2).
Check first if you have it:

```bash
idba_ud
```

If you don't, you can get it by adding the Ubuntu Universe source to APT:
```bash
echo 'deb http://us.archive.ubuntu.com/ubuntu/ cosmic universe' \
  | sudo tee /etc/apt/sources.list.d/ubuntu-universe.list
sudo apt-get update
sudo apt-get install idba
```

Or install it directly from the DEB package:

```bash
wget http://ftp.br.debian.org/debian/pool/main/i/idba/idba_1.1.3-3_amd64.deb
sudo apt-get install ./idba_1.1.3-3_amd64.deb
```

## SolexaQA++

Next, you'll need to install SolexaQA++. If you have a 64-bits Linux:

```bash
curl -L -o SolexaQA++_v3.1.7.1.zip \
  "https://downloads.sourceforge.net/project/solexaqa/src/SolexaQA%2B%2B_v3.1.7.1.zip"
unzip -p SolexaQA++_v3.1.7.1.zip Linux_x64/SolexaQA++ > SolexaQA++
sudo install SolexaQA++ /usr/bin/
```

If you have 32-bits Linux, you can build SolexaQA++ from source:

```bash
sudo apt-get install libboost-dev libboost-filesystem-dev \
      libboost-regex-dev libboost-iostreams-dev
curl -L -o SolexaQA++_v3.1.7.1.zip \
  "https://downloads.sourceforge.net/project/solexaqa/src/SolexaQA%2B%2B_v3.1.7.1.zip"
unzip SolexaQA++_v3.1.7.1.zip 'source/*'
cd source && make
sudo install source/SolexaQA++ /usr/bin/
```

## FastANI

FastANI is optional, but it may be required to search certain databases.
It can be used instead of BLAST ANI to speed up indexing.
If you have a 64-bits Linux:

```bash
curl -L -o fastani-Linux64-v1.1.zip \
  "https://github.com/ParBLiSS/FastANI/releases/download/v1.1/fastani-Linux64-v1.1.zip"
unzip fastani-Linux64-v1.1.zip fastANI
sudo install fastANI /usr/bin/
```

If you have a 32-bits Linux, you can build it from source following the
[FastANI installation](https://github.com/ParBLiSS/FastANI/blob/master/INSTALL.txt).

## R packages

The full list of R packages are automatically installed by MiGA. However, we
will install one package here to make sure everything is properly initialized.

```bash
R
install.packages('ape', repos = 'http://cran.rstudio.com/')
q()
```

## MyTaxa utils

If you want to activate the [MyTaxa](../part5/workflow.md#mytaxa) and
[MyTaxa Scan](../part5/workflow.md#mytaxa-scan) steps, follow the instructions
to install the [MyTaxa Utils](mytaxa.md).

