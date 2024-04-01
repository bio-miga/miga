#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES
set -e
SCRIPT="aai_distances"
# shellcheck source=scripts/miga.bash
. "$MIGA/scripts/miga.bash" || exit 1
DIR="$PROJECT/data/09.distances/02.aai"

# Initialize
miga_start_project_step "$DIR"

# Extract values
function foreach_database_aai {
  local SQL="SELECT seq1, seq2, aai, sd, n, omega from aai;"
  local k=0
  while [[ -n ${DS[$k]} ]] ; do
    echo "$SQL" | sqlite3 "$DIR/${DS[$k]}.db" | tr "\\|" "\\t"
    let k=$k+1
  done
}

function aai_tsv {
  DS=($(miga ls -P "$PROJECT" --ref --no-multi --active))
  echo "a b value sd n omega" | tr " " "\\t"
  if [[ ${#DS[@]} -gt 40000 ]] ; then
    # Use comparisons in strictly one direction only for huge projects
    # (assuming the distances are truly bidirectional!)
    foreach_database_aai | awk -F"\t" '$1 >= $2'
  else
    foreach_database_aai
  fi
}

rm -f "miga-project.txt"
aai_tsv | tee >(wc -l | awk '{print $1-1}' > "miga-project.txt.lno") \
  | gzip -9c > "miga-project.txt.gz"
LNO=$(cat "miga-project.txt.lno")
rm "miga-project.txt.lno"

# R-ify
cat <<R | R --vanilla
file <- gzfile("miga-project.txt.gz")
text <- readLines(file, n = $LNO + 1, ok = FALSE)
list <- strsplit(text[-1], "\t", fixed = TRUE)
a <- sapply(list, function(x) x[1])
b <- sapply(list, function(x) x[2])
d <- sapply(list, function(x) 1 - (as.numeric(x[3]) / 100))
save(a, b, d, file = "miga-project.rda")

non_self <- a != b
if(sum(non_self) > 0) {
  h <- hist((1 - d[non_self]) * 100, breaks = 100, plot = FALSE)
  len <- length(h[["breaks"]])
  write.table(
    cbind(h[["breaks"]][-len], h[["breaks"]][-1], h[["counts"]]),
    file = "miga-project.hist", quote = FALSE, sep = "\t",
    col.names = FALSE, row.names = FALSE
  )
}
R

# Finalize
miga_end_project_step "$DIR"
