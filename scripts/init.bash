#!/bin/bash
set -e

#=======[ Functions ]
function ask_user {
   local question=$1
   local default=$2
   echo $question >&2
   echo -n "  [$default] > " >&2
   read user_answer
   user_answer=${user_answer:-$default}
   echo -n "$user_answer"
}

function check_req {
   local bin=$1
   local default=$(dirname "$(which "$bin")")
   user_answer=$(ask_user "Where can I find $2 ($3)? $4" "$default")
   if [[ -x "$user_answer/$bin" ]] ; then
      echo "export PATH=$user_answer:\$PATH" >> "$HOME/.miga_rc"
   else
      echo "Cannot find $2 at '$user_answer/$bin'. Aborting..." >&2
      exit 1
   fi
}

#=======[ Main ]
MIGA_STARTUP="no"
MIGA=$(cd "$(dirname "$0")/.."; pwd)
echo "
===[ Welcome to MiGA, the Microbial Genome Atlas ]===

I'm the initialization script, and I'll sniff around your computer to
make sure you have all the requirements for MiGA Daemons.
" >&2

if [[ "$(ask_user "Would you like to see all the requirements before starting? (yes / no)" "no")" == "yes" ]] ; then
   echo "" >&2
   cat "$MIGA/utils/requirements.txt" >&2
   echo "" >&2
fi

if [[ -e "$HOME/.miga_rc" ]] ; then
   case "$(ask_user "I found a previous configuration. Do you want to load the defaults within? (yes / no / cancel)" "yes")" in
      yes)
	 source "$HOME/.miga_rc"
	 if [[ "$MIGA_CONFIG_DATE" == "" ]] ; then
	    echo "  Loaded incomplete configuration" >&2
	 else
	    echo "  Loaded configuration from $MIGA_CONFIG_DATE" >&2
	 fi
	 ;;
      no)
	 rm "$HOME/.miga_rc"
	 ;;
      cancel)
	 exit 0
	 ;;
      *)
	 echo "Cannot understand your answer, please use 'yes', 'no', or 'cancel'. Aborting..." >&2
	 exit 1
   esac
fi

echo "#!/bin/bash
# MiGA made this on $(date)
" > "$HOME/.miga_rc"

# Check Software requirements
MIGA_STARTUP=$(ask_user "Is there a script I need to load at startup? (no / path to the script to load)" "$MIGA_STARTUP")
if [[ "$MIGA_STARTUP" != "no" ]] ; then
   echo "MIGA_STARTUP='$MIGA_STARTUP'
source \"\$MIGA_STARTUP\"
" >> "$HOME/.miga_rc";
   source "$MIGA_STARTUP";
fi
echo "
Looking for Software requirements:" >&2
reqs=$(tail -n+3 "$MIGA/utils/requirements.txt" | perl -pe 's/\t+/\t/g')
IFS_BU=$IFS
IFS=$'\n'
for ln in $reqs ; do
   rname=$(echo "$ln" | awk -F'\t' '{print $1}')
   rtest=$(echo "$ln" | awk -F'\t' '{print $2}')
   rwebs=$(echo "$ln" | awk -F'\t' '{print $3}')
   rhint=$(echo "$ln" | awk -F'\t' '{print $4}')
   check_req "$rtest" "$rname" "$rwebs" "$rhint"
done
IFS=$IFS_BU

# Configure daemon
echo "
Default daemon configuration:" >&2
dtype=$(ask_user "Please select the type of daemon you want to setup (bash / qsub / msub)", "bash")
case "$dtype" in
   bash)
      dlatency=$(ask_user "For how long should I sleep? (# in seconds)" "30")
      dmaxjobs=$(ask_user "How many jobs can I launch at once?" "6")
      dppn=$(ask_user "How many CPUs can I use per job?" "2")
      echo "Setting up internal daemon defaults, if you don't understand this just leave default values:" >&2
      dcmd=$(ask_user "How should I launch tasks? Use %1\$s for script path, %2\$s for variables, %3\$d for CPUs, and %4\$s for log file." "%2\$s '%1\$s' &> '%4\$s'")
      dvar=$(ask_user "How should I pass variables? Use %1\$s for keys and %2\$s for values." "%1\$s=%2\$s")
      dsep=$(ask_user "What should I use to separate variables?" " ")
      dalive=$(ask_user "How can I know that a process is still alive? Use %1\$s for PID, output should be 1 for running and 0 for non-running." "ps -p '%1\$s'|tail -n+2|wc -l|awk '{print \$1}'")
      ;;
   [qm]sub)
      dqueue=$(ask_user "What's the name of the queue I should use?" "")
      dlatency=$(ask_user "How long should I sleep? (# in seconds)" "150")
      dmaxjobs=$(ask_user "How many jobs can I launch at once?" "300")
      dppn=$(ask_user "How many CPUs can I use per job?" "4")
      echo "Setting up internal daemon defaults, if you don't understand this just leave default values:" >&2
      dcmd=$(ask_user "How should I launch tasks? Use %1\$s for script path, %2\$s for variables, and %3\$d for CPUs, and %3\$d for log file." "$dtype -q '$dqueue' -v '%2\$s' -l nodes=1:ppn=%3\$d %1\$s -j oe -o '%4\$s'")
      dvar=$(ask_user "How should I pass variables? Use %1\$s for keys and %2\$s for values." "%1\$s=%2\$s")
      dsep=$(ask_user "What should I use to separate variables?" ",")
      if [[ "$dtype" == "qsub" ]] ; then
	 dalive=$(ask_user "How can I know that a process is still alive? Use %1\$s for job id, output should be 1 for running and 0 for non-running." "checkjob '%1\$s'|grep '^State:'|perl -pe 's/.*: //'|grep 'Running\\|Idle\\|Blocked\\|Starting'|tail -n1|wc -l|awk '{print \$1}'")
      else
	 dalive=$(ask_user "How can I know that a process is still alive? Use %1\$s for job id, output should be 1 for running and 0 for non-running." "qstat -f '%1\$s'|grep ' job_state ='|perl -pe 's/.*= //'|grep '[^C]'|tail -n1|wc -l|awk '{print $1}'")
      fi
      ;;
   *)
esac
echo "{
   \"created\": \"$(date "+%Y-%m-%d %H:%M:%S %z")\",
   \"updated\": \"$(date "+%Y-%m-%d %H:%M:%S %z")\",
   \"type\"   : \"$dtype\",
   \"cmd\"    : \"$dcmd\",
   \"var\"    : \"$dvar\",
   \"varsep\" : \"$dsep\",
   \"alive\"  : \"$dalive\",
   \"latency\": $dlatency,
   \"maxjobs\": $dmaxjobs,
   \"ppn\"    : $dppn
}" > $HOME/.miga_daemon.json

# Confirm configuration
echo "
MIGA_CONFIG_DATE='$(date)'
" >> "$HOME/.miga_rc"

