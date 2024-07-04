#!/bin/bash

TERRAFORM_HISTORY=$HOME/.terraform_history
export IFS=

# STATE holds what we are printing
# 0: normal line
# 1: helm_release resource
# 2: helm_release.metadata block
# 3: helm_release.values value block
# 4: helm_release.value_old value block
# 5: helm_release.value_new value block
STATE=0

strip_color() {
  echo "$1" | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2};?)?)?[mGK]//g"
}

parse_terraform_output() {
  cat | while read line; do
    echo -e "$line" >> $raw_output
    [ "$STATE" -eq 0 ] && parse_normal "$line" && continue
    [ "$STATE" -eq 1 ] && parse_helm_release "$line" && continue
    [ "$STATE" -eq 2 ] && parse_helm_release_metadata "$line" && continue
    [ "$STATE" -eq 3 ] && parse_helm_release_values "$line" && continue
    [ "$STATE" -eq 4 ] && parse_helm_release_values_old "$line" && continue
    [ "$STATE" -eq 5 ] && parse_helm_release_values_new "$line" && continue
  done
}

parse_normal() {
  line="$1"
  uncolor=$(strip_color "$line")
  if [[ "$uncolor" =~ ^\ +\#\ ([^\ ]+\.)?helm_release\.[^\ ]+\ (will|must)\ be ]]; then
    STATE=1
  fi
  echo -e "$line"
}

parse_helm_release() {
  line="$1"
  uncolor=$(strip_color "$line")
  if [[ "$uncolor" =~ ^\ {4}\}$ ]]; then
    STATE=0
  elif [[ "$uncolor" =~ ^\ {6}.\ metadata ]]; then
    if ! [[ "$uncolor" =~ ^\ {6}.\ metadata.+(known\ after\ apply) ]]; then
      STATE=2
    fi
  elif [[ "$uncolor" =~ ^\ {6}.\ values ]]; then
    STATE=3
  fi
  echo -e "$line"
}

parse_helm_release_metadata() {
  line="$1"
  uncolor=$(strip_color "$line")
  if [[ "$uncolor" =~ ^\ {8}\] ]]; then
    STATE=1
    echo -e "            (omitted)"
    echo -e "$line"
  fi
}

parse_helm_release_values() {
  line="$1"
  uncolor=$(strip_color "$line")
  if [[ "$uncolor" =~ ^\ {10}-\ \<\<-EOT$ ]]; then
    STATE=4
    export HELM_OLD_VALUES=$(mktemp)
  elif [[ "$uncolor" =~ ^\ {10}\+\ \<\<-EOT$ ]]; then
    STATE=5
    export HELM_NEW_VALUES=$(mktemp)
  elif [[ "$uncolor" =~ ^\ {8}\]$ ]]; then
    STATE=1
    # test for file existence
    [ -f $HELM_OLD_VALUES ] || HELM_OLD_VALUES=$(mktemp)
    [ -f $HELM_NEW_VALUES ] || HELM_NEW_VALUES=$(mktemp)
    diff -u -U 10 --color=always $HELM_OLD_VALUES $HELM_NEW_VALUES | while read diffline; do
      echo -e "            $diffline"
    done
    # rm -f $HELM_OLD_VALUES $HELM_NEW_VALUES
    echo -e "$line"
  fi
}

parse_helm_release_values_old() {
  line="$1"
  uncolor=$(strip_color "$line")
  if [[ "$uncolor" =~ ^\ {12}EOT,$ ]]; then
    STATE=3
  else
    echo "$line" >> $HELM_OLD_VALUES
  fi
}

parse_helm_release_values_new() {
  line="$1"
  uncolor=$(strip_color "$line")
  if [[ "$uncolor" =~ ^\ {12}EOT,$ ]]; then
    STATE=3
  else
    echo "$line" >> $HELM_NEW_VALUES
  fi
}

run_dir=$TERRAFORM_HISTORY/$(date +%Y-%m-%d-%H-%M-%S)
mkdir -p $run_dir
start_time=$(date +%s)
echo $start_time > $run_dir/start_time
echo -e "\e[0;30mStart time: $start_time\e[0m"
echo -e "\e[1;33mterraform $@\e[0m"
echo -e "\e[1;33mterraform $@\e[0m" > $run_dir/command
raw_output=$run_dir/raw
error_output=$run_dir/stderr
/usr/bin/terraform "$@" 2>$error_output | parse_terraform_output | tee $run_dir/stdout
end_time=$(date +%s)
echo $end_time > $run_dir/end_time
echo -e "\e[0;30mEnd time: $end_time\e[0m"
echo -e "\e[0;30mExecution time: $(($end_time - $start_time)) seconds\e[0m"
cat $error_output 1>&2

# clean
ls -1 $TERRAFORM_HISTORY | sort | head -n -150 | while read old_run; do
  [ -z "$TERRAFORM_HISTORY" ] && echo "NO TERRAFORM_HISTORY" && exit -1
  rm -r $TERRAFORM_HISTORY/$old_run
done
