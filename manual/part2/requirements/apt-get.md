# Installing requirements using `apt-get`

## Live notebook

If you prefer to see code in action, the full installation process
with apt-get is available as a
[Notebook in Google Colab](https://colab.research.google.com/gist/lmrodriguezr/78f2f48eadce96bc2dd526fd194fb00a).

## Packages

Run:

```bash
sudo apt-get update
sudo apt-get install \
  ruby ruby-sqlite3 r-base sqlite3 libcurl4-openssl-dev zlib1g zlib1g-dev pigz \
  ncbi-blast+ hmmer bedtools idba prodigal mcl barrnap diamond-aligner \
  fastp fastani trnascan-se seqtk
```

## Additional Software

Some of the software required by MiGA is not available in aptitude, but
you can install it in your 64bit Linux machine using:

```bash
## FaQCs
wget -O FaQCs \
  "https://github.com/LANL-Bioinformatics/FaQCs/releases/download/2.10/FaQCs_linux_x86_64"
sudo install FaQCs /usr/bin/ && rm FaQCs

## Falco
wget -O falco.tar.gz \
  "https://github.com/smithlabcode/falco/releases/download/v1.2.1/falco-1.2.1.tar.gz"
tar zxf falco.tar.gz
( cd falco-1.2.1 \
    && ./configure CXXFLAGS="-O3 -Wall" \
    && make && sudo make install
) > /dev/null
rm -rf falco-1.2.1 falco.tar.gz
```

# JAVA VM

If you want support for RDP classifications, you'll need any working Java VM.
For example, you could install Temurin as follows:

```bash
wget -O - https://packages.adoptium.net/artifactory/api/gpg/key/public \
  | sudo apt-key add -
echo "deb https://packages.adoptium.net/artifactory/deb \
  $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" \
  | sudo tee /etc/apt/sources.list.d/adoptium.list
sudo apt-get update
sudo apt-get install temurin-21-jdk
```

## MyTaxa utils

If you want to activate the [MyTaxa](../part5/workflow.md#mytaxa) and
[MyTaxa Scan](../part5/workflow.md#mytaxa-scan) steps, follow the instructions
to install the [MyTaxa Utils](mytaxa.md).

