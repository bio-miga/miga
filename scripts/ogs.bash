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

echo -n "" > miga-project.log
DS=$(miga list_datasets -P "$PROJECT" --ref --no-multi)

# Extract RBMs
[[ -d miga-project.rbm ]] || mkdir miga-project.rbm
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

# Estimate OGs
ogs.mcl.rb -o miga-project.ogs -d miga-project.rbm -t "$CORES"
ogs.stats.rb -o miga-project.ogs -j miga-project.stats

# Clean RBMs
rm -rf miga-project.rbm

# Finalize
miga date > "miga-project.done"
miga add_result -P "$PROJECT" -r "$SCRIPT"
