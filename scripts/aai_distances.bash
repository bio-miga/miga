#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES
set -e
SCRIPT="aai_distances"
# shellcheck source=scripts/miga.bash
. "$MIGA/scripts/miga.bash" || exit 1
DIR="$PROJECT/data/09.distances/02.aai"

# Initialize
miga_start_project_step "$DIR"

echo -n "" > miga-project.log
DS=$(miga ls -P "$PROJECT" --ref --no-multi --active)

# Extract values
rm -f miga-project.txt
(
  echo "metric a b value sd n omega" | tr " " "\\t"
  for i in $DS ; do
    echo "SELECT CASE WHEN omega!=0 THEN 'AAI' ELSE 'hAAI_AAI' END," \
      " seq1, seq2, aai, sd, n, omega from aai;" \
      | sqlite3 "$DIR/$i.db" | tr "\\|" "\\t"
    echo "$i" >> miga-project.log
  done
) | gzip -9c > miga-project.txt.gz

# R-ify
echo "
aai <- read.table(gzfile('miga-project.txt.gz'), sep='\\t', h=T, as.is=TRUE);
save(aai, file='miga-project.Rdata');
if(sum(aai[,'a'] != aai[,'b']) > 0){
  h <- hist(aai[aai[,'a'] != aai[,'b'], 'value'], breaks=100, plot=FALSE);
  write.table(
    cbind(h[['breaks']][-length(h[['breaks']])],
      h[['breaks']][-1], h[['counts']]),
    file='miga-project.hist', quote=FALSE, sep='\\t',
    col.names=FALSE, row.names=FALSE);
}
" | R --vanilla

# Finalize
miga_end_project_step "$DIR"
