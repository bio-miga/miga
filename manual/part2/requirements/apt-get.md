# Installing requirements using `apt-get`

## Live notebook

If you prefer to see code in action, the full installation process
with apt-get is available as a
[Notebook in Google Colab](https://colab.research.google.com/gist/lmrodriguezr/78f2f48eadce96bc2dd526fd194fb00a/miga_1-2_apt_installation.ipynb).

## Packages

Run:

```bash
sudo apt-get update
sudo apt-get install \
  ruby ruby-sqlite3 r-base sqlite3 python \
  libcurl4-openssl-dev zlib1g zlib1g-dev \
  ncbi-blast+ hmmer bedtools idba prodigal \
  mcl barrnap diamond-aligner trnascan-se
```

## Additional Software

Some of the software required by MiGA is not available in aptitude, but
you can install it in your 64bit Linux machine using:

```bash
## FaQCs
curl -Lso FaQCs \
  "https://github.com/LANL-Bioinformatics/FaQCs/releases/download/2.10/FaQCs_linux_x86_64"
sudo install FaQCs /usr/bin/ && rm FaQCs

## Falco
curl -Lso falco.tar.gz \
  "https://github.com/smithlabcode/falco/releases/download/v0.2.4/falco-0.2.4.tar.gz"
tar zxf falco.tar.gz
( cd falco-0.2.4 \
    && ./configure CXXFLAGS="-O3 -Wall" \
    && make && sudo make install
) > /dev/null
rm -rf falco-0.2.4

## Fastp
curl -Lso fastp "http://opengene.org/fastp/fastp"
sudo install fastp /usr/bin/ && rm fastp

# FastANI
curl -Lso fastani-Linux64-v1.33.zip \
  "https://github.com/ParBLiSS/FastANI/releases/download/v1.33/fastani-Linux64-v1.33.zip"
unzip fastani-Linux64-v1.33.zip fastANI > /dev/null && rm fastani-Linux64-v1.33.zip
sudo install fastANI /usr/bin/ && rm fastANI
```

## MyTaxa utils

If you want to activate the [MyTaxa](../part5/workflow.md#mytaxa) and
[MyTaxa Scan](../part5/workflow.md#mytaxa-scan) steps, follow the instructions
to install the [MyTaxa Utils](mytaxa.md).

