#!/bin/bash

#
#
# Used to run pt-osc to alter many-many tables in a selected database.
#    -f with -t > 1  is quite important because in case of failure of pt-osc xargs will be aborted but some of "just started" pt-osc can continue running
# 
#  sample calls:
#  ./universal-alter.sh -d serpbook -r '.*' -a 'add column z int'
#  ./universal-alter.sh -d serpbook -r '.*' -a 'drop column z' -t 5
# 

db=
regexp=
alter=
threads=

opt=

fail_immediately=

work_folder="/tmp/.universal-alter/"
file_with_tables="$work_folder/tables"

c_threads_default=1


# ------------------------------------------------------------------------------------
function log(){
   echo "[$(date +%Y%m%d-%H%M%S)]$1" "$2"
}


function info(){
   log "[info]" "$1"
}


function error(){
   log "[error]" "$1"
}


# ------------------------------------------------------------------------------------
function usage(){
cat << EOF
   -d        used to pass database
   -r        used to pass regexp to check tables   
   -t        amount of threads running in parallel (1 by default)
   -o        the rest of options to be passed to pt-osc
   -a        alter statement w/o 'alter table'
   -f        fail immediately

   -h        display help
EOF

}



# ------------------------------------------------------------------------------------
function get_options(){
   while getopts r:t:a:o:d:hf option; do
      case $option in        
         d) db="$OPTARG";;
         r) regexp="$OPTARG";;
         t) threads="$OPTARG";;
         a) alter="$OPTARG";;
         o) opt="$OPTARG";;
         f) fail_immediately=" || exit 255";;
         h) usage; exit 0;;
      esac
   done
}



# ------------------------------------------------------------------------------------
function check_options(){
   info "checking parameters..."

   local rc=0
   if [ -z "$db" ]; then
      rc=1
      error "use --database|-d to pass database name"
   else
      mysql -BN $db -e 'select 1' >/dev/null 2>&1
      if [ $? -ne 0 ]; then
         rc=2
         error "Cannot connect to database $db"
      fi
   fi

   if [ -z "$regexp" ]; then
      rc=3
      error "Use --regexp|-r to pass regexp"
   fi

   if [ -z "$alter" ]; then
      rc=3
      error "Use --alter|-a to pass alter statement"
   fi

   if [ -z "$threads" ]; then
      threads=$c_threads_default
      info "Amount of threads will be set to default $threads"
   fi

   return $rc
}




# ------------------------------------------------------------------------------------
function init(){
   mkdir -p $work_folder
   mysql -BN $db -e 'show tables' | grep -E "$regexp" > $file_with_tables
}




# ------------------------------------------------------------------------------------
function confirmation(){
cat << EOF
   db:                  $db
   regexp:              $regexp
   threads:             $threads
   alter:               $alter
   fail immediately:    $([ -z "$fail_immediately" ] && echo "No" || echo "Yes")

   tables:     $(cat $file_with_tables | tr '\n' ' ')
EOF
   read -p "Would you like to proceed? (Yy/):" answer
   if [ "$answer" == "Y" ] || [ "$answer" == "y" ]; then
      return 0
   fi

   return 1
}



# ------------------------------------------------------------------------------------
function run_alter(){
   cat $file_with_tables  | xargs -i -t -P $threads bash -c "echo 'altering table {}'; pt-online-schema-change $opt --execute --alter '$alter' D=$db,t={} $fail_immediately"

   return $?
}



# -------------------------------- MAIN -----------------------------------------------
info "starting..."
get_options "$@" || exit $?


check_options || exit $?


init || exit $?


confirmation || exit $?


run_alter || exit $?


info "Completed. OK!"
exit 0