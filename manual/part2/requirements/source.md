# Installing requirements from source

## Essentials

If you don't have apt-get, Homebrew, or conda, here's the list of requirements
and URLs with installation instructions:

* **Ruby**: https://www.ruby-lang.org/. Required: v2.1+, recommended: v2.3+.
* **Python**: https://www.python.org/.
* **R**: http://www.r-project.org/.
* **SQLite3**: https://www.sqlite.org/.
* **NCBI BLAST+**: ftp://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/LATEST.
* **HMMer**: http://hmmer.janelia.org/software. Required: v3.0+.
* **Bedtools**: http://bedtools.readthedocs.org/en/latest/.
* **Prodigal**: http://prodigal.ornl.gov.
* **IDBA**: http://i.cs.hku.hk/~alse/hkubrg/projects/idba. Required flavor:
  IDBA-UD.
* **MCL**: http://micans.org/mcl/.
* **Barrnap**: http://www.vicbioinformatics.com/software.barrnap.shtml.
* **Scythe**: https://github.com/vsbuffalo/scythe. Required: v0.991+.
* **FastQC**: http://www.bioinformatics.babraham.ac.uk/projects/fastqc.
* **SolexaQA++**: http://solexaqa.sourceforge.net. Required: v3.1.3+.
* **FastANI** (optional): https://github.com/ParBLiSS/FastANI. Required: v1.1+.
* **Diamond** (optional): http://ab.inf.uni-tuebingen.de/software/diamond. Required: v0.9.20+.

Diamond is optional but strongly recommended. Indexing can be performed much
faster with Diamond, searching of some databases depend on it, and it's required
by the MyTaxa utils. FastANI is also recommended, since searching some
databases depend on it.

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

