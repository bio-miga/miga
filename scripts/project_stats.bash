#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES
set -e
SCRIPT="project_stats"
# shellcheck source=scripts/miga.bash
. "$MIGA/scripts/miga.bash" || exit 1
DIR="$PROJECT/data/90.stats"
[[ -d "$DIR" ]] || mkdir -p "$DIR"
cd "$DIR"

# Initialize
miga date > "miga-project.start"

# Execute doctor
echo "# Doctor"
miga doctor -P "$PROJECT" -t "$CORES" -v

# Index taxonomy
echo "# Index taxonomy"
miga tax_index -P "$PROJECT" -i "miga-project.taxonomy.json" --ref --active

# Index metadata
echo "# Index metadata"
ruby -I "$MIGA/lib" \
  "$MIGA/utils/index_metadata.rb" "$PROJECT" "miga-project.metadata.db"

# Finalize
miga date > "miga-project.done"
miga add_result -P "$PROJECT" -r "$SCRIPT" -f
