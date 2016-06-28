#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES
set -e
echo "MiGA: $MIGA"
echo "Project: $PROJECT"
source "$MIGA/scripts/miga.bash" || exit 1
cd "$PROJECT/data/09.distances/01.haai"

# Initialize
date "+%Y-%m-%d %H:%M:%S %z" > "miga-project.start"

echo -n "" > miga-project.log
DS=$(miga list_datasets -P "$PROJECT" --ref --no-multi)

# Extract values
echo "metric a b value sd n omega" | tr " " "\\t" >miga-project.txt
for i in $DS ; do
   echo "SELECT 'hAAI', seq1, seq2, aai, sd, n, omega from aai ;" \
      | sqlite3 "$i.db" | tr "\\|" "\\t" >>miga-project.txt
   echo "$i" >> miga-project.log
done

# R-ify
if true ; then
  echo "
  haai <- read.table('miga-project.txt', sep='\\t', h=T);
  save(haai, file='miga-project.Rdata');"
  if [[ $(cat miga-project.txt | wc -l) -gt 1 ]] ; then
    echo "
    h <- hist(haai[,'value'], breaks=100, plot=FALSE);
    write.table(
      cbind(h[['breaks']][-length(h[['breaks']])],
        h[['breaks']][-1],h[['counts']]),
      file='miga-project.hist', quote=FALSE, sep='\\t',
      col.names=FALSE, row.names=FALSE);
    "
  fi
fi | R --vanilla

# Gzip
gzip -9 -f miga-project.txt

# Finalize
date "+%Y-%m-%d %H:%M:%S %z" > "miga-project.done"
miga add_result -P "$PROJECT" -r haai_distances

