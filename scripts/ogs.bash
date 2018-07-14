#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES
set -e
SCRIPT="ogs"
echo "MiGA: $MIGA"
echo "Project: $PROJECT"
# shellcheck source=scripts/miga.bash
source "$MIGA/scripts/miga.bash" || exit 1
cd "$PROJECT/data/10.clades/03.ogs"

# Initialize
miga date > "miga-project.start"

DS=$(miga list_datasets -P "$PROJECT" --ref --no-multi)
if [[ ! -s miga-project.ogs ]] ; then
  # Extract RBMs
  [[ -d miga-project.rbm ]] || mkdir miga-project.rbm
  echo -n "" > miga-project.log
  for i in $DS ; do
    for j in $DS ; do
      file="miga-project.rbm/$i-$j.rbm"
      [[ -s $file ]] && continue
      echo "SELECT id1,id2,id,0,0,0,0,0,0,0,evalue,bitscore from rbm" \
        "where seq1='$i' and seq2='$j' ;" \
        | sqlite3 "../../09.distances/02.aai/$i.db" | tr "\\|" "\\t" \
        > "$file"
      [[ -s "$file" ]] || rm "$file"
    done
    echo "$i" >> miga-project.log
  done

  # Estimate OGs and Clean RBMs
  ogs.mcl.rb -o miga-project.ogs -d miga-project.rbm -t "$CORES"
  [[ $(miga about -P "$PROJECT" -m clean_ogs) == "false" ]] \
    || rm -rf miga-project.rbm
fi

# Calculate Statistics
ogs.stats.rb -o miga-project.ogs -j miga-project.stats
ogs.core-pan.rb -o miga-project.ogs -s miga-project.core-pan.tsv -t "$CORES"
Rscript "$MIGA/utils/core-pan-plot.R" \
  miga-project.core-pan.tsv miga-project.core-pan.pdf

# Finalize
miga date > "miga-project.done"
miga add_result -P "$PROJECT" -r "$SCRIPT" -f
