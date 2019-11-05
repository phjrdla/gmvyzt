#!/usr/bin/ksh
# This scripts performs all the steps necessary for an RMAN database duplication using a backup
# Main steps are 
#   cleanup,
#   generation of auxiliary instance init parameter file
#   generation of rman database duplication script
#   Auxliliary instance startup
#   Database duplication
#   Post duplication actions

this_script=$0
pgm=$(basename $0)
pgm=${pgm%%.*}

# Error handling
set -e
set -u

DEBUG=''
#DEBUG=echo
[[ ! -z $DEBUG  ]] && set -x
#trap "print $this_script aborted" INT TERM EXIT

# process number, to name files uniquely 
pid=$$

# For temporay files
TMPDIR='/tmp'
[[ ! -d $TMPDIR ]] && { print "Directory $TMPDIR not found, exit." | tee -a $err; exit; }

# log and error files
log=$TMPDIR/${pgm}_$pid.log
err=$TMPDIR/${pgm}_$pid.err

# Mailing lists
mailx_it_database_list='briensph@gmail.com'
mailx_it_database_team_list='Philippe.Briens@fluxys.com'

# Constants
BACKUP_MODE='B'
ACTIVE_MODE='A'

#################################################################################################################
# Parameters handling
#################################################################################################################
typeset -u SOURCE_SID=''
typeset -l lowerSOURCE_SID=''
typeset -u DEST_SID=''
typeset -l lowerDEST_SID=''
typeset -u RMAN_SID=''
typeset -u ADM_SID=''
typeset -u DUPLICATE_MODE=$BACKUP_MODE
typeset -u UNTIL_TIME=''
typeset -u SHOW_PROGRESS=''
BACKUP_LOCATION_ROOT="/DD2500/backup/"

while getopts 'hm:s:d:r:a:b:u:p' OPTION
do
  case "$OPTION" in
    s)
      SOURCE_SID=$OPTARG
      lowerSOURCE_SID=$OPTARG
      ;;
    m)
      DUPLICATE_MODE=$OPTARG
      ;;
    d)
      DEST_SID=$OPTARG
      lowerDEST_SID=$OPTARG
      ;;
    r)
      RMAN_SID=$OPTARG
      ;;
    a)
      ADM_SID=$OPTARG
      ;;
    b)
      BACKUP_LOCATION_ROOT=$OPTARG
      ;;
    u)
      UNTIL_TIME=$OPTARG
      ;;
    p)
      SHOW_PROGRESS='Y'
      ;;
    h)
      print "script usage: $(basename $0) [-h] [-m duplicate_mode (Backup/Active)] [-s source_db] [-d dest_db] [-r RMAN_catalog_db] [-a DZDBA_db] [-b backup_location_root ]" | tee -a $log
      print "Exemple :  $(basename $0) -s BELDEV -d BELQUA -m a -u 'SYSDATE-1'" | tee -a $log
      print "Exemple :  $(basename $0) -s BELDEV -d BELQUA -b /DD2500/backup" | tee -a $log
      print "Exemple :  $(basename $0) -s BELDEV -d BELQUA -r EMPRD" | tee -a $log
      print "Exemple :  $(basename $0) -s BELDEV -d BELQUA -a EMPRD" | tee -a $log
      print "Exemple :  $(basename $0) -s BELDEV -d BELQUA -r EMPRD -a EMPRD" | tee -a $log
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"

print "DUPLICATE_MODE is $DUPLICATE_MODE" | tee -a $log
print "SOURCE_SID is $SOURCE_SID" | tee -a $log
print "lowerSOURCE_SID is $lowerSOURCE_SID" | tee -a $log
print "DEST_SID is $DEST_SID" | tee -a $log
print "RMAN_SID is $RMAN_SID" | tee -a $log
print "ADM_SID is $ADM_SID" | tee -a $log
print "BACKUP_LOCATION_ROOT is $BACKUP_LOCATION_ROOT" | tee -a $log

# Mandatory parameters
[[ $DUPLICATE_MODE != $BACKUP_MODE && $DUPLICATE_MODE != $ACTIVE_MODE ]] && { print "Allowed values for DUPLICATE_MODE are $BACKUP_MODE or $ACTIVE_MODE"; exit; }
[[ -z $SOURCE_SID ]] && { print "SOURCE_SID is mandatory, exit."; exit; }
[[ -z $DEST_SID ]] && { print "DEST_SID is mandatory, exit."; exit; }

#################################################################################################################
# Function to clean ASM files
V_CLONE_DB=$DEST_SID
V_DATA_DISKGROUP=DATA
V_ARCHIVE_DISKGROUP=FRA
V_REDO_DISKGROUP=REDO

function remove_db
{
print "function remove_db invoked ..."
#export GRID_HOME=/u01/app/18.0.0/grid
GRID_HOME=/u01/app/18.0.0/grid
ORACLE_SID=+ASM
LD_LIBRARY_PATH=$GRID_HOME/lib
PATH=/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:$GRID_HOME/bin
echo asmcmd --privilege sysdba ls +$V_DATA_DISKGROUP/$V_CLONE_DB
$GRID_HOME/bin/asmcmd --privilege sysdba ls +$V_DATA_DISKGROUP/$V_CLONE_DB
echo asmcmd --privilege sysdba ls +$V_ARCHIVE_DISKGROUP/$V_CLONE_DB
$GRID_HOME/bin/asmcmd --privilege sysdba ls +$V_ARCHIVE_DISKGROUP/$V_CLONE_DB
echo asmcmd --privilege sysdba ls +$V_REDO_DISKGROUP/$V_CLONE_DB
$GRID_HOME/bin/asmcmd --privilege sysdba ls +$V_REDO_DISKGROUP/$V_CLONE_DB

echo asmcmd --privilege sysdba rm -fr +$V_DATA_DISKGROUP/$V_CLONE_DB/DATAFILE
$GRID_HOME/bin/asmcmd --privilege sysdba rm -fr +$V_DATA_DISKGROUP/$V_CLONE_DB/DATAFILE
echo asmcmd --privilege sysdba rm -fr +$V_DATA_DISKGROUP/$V_CLONE_DB/TEMPFILE
$GRID_HOME/bin/asmcmd --privilege sysdba rm -fr +$V_DATA_DISKGROUP/$V_CLONE_DB/TEMPFILE
echo asmcmd --privilege sysdba rm -fr +$V_DATA_DISKGROUP/$V_CLONE_DB/PASSWORD
$GRID_HOME/bin/asmcmd --privilege sysdba rm -fr +$V_DATA_DISKGROUP/$V_CLONE_DB/PASSWORD
echo asmcmd --privilege sysdba rm -fr +$V_DATA_DISKGROUP/$V_CLONE_DB/PARAMETERFILE
$GRID_HOME/bin/asmcmd --privilege sysdba rm -fr +$V_DATA_DISKGROUP/$V_CLONE_DB/PARAMETERFILE
echo asmcmd --privilege sysdba rm -fr +$V_DATA_DISKGROUP/$V_CLONE_DB/ONLINELOG
$GRID_HOME/bin/asmcmd --privilege sysdba rm -fr +$V_DATA_DISKGROUP/$V_CLONE_DB/ONLINELOG
echo asmcmd --privilege sysdba rm -fr +$V_DATA_DISKGROUP/$V_CLONE_DB/CONTROLFILE
$GRID_HOME/bin/asmcmd --privilege sysdba rm -fr +$V_DATA_DISKGROUP/$V_CLONE_DB/CONTROLFILE

echo asmcmd --privilege sysdba rm -fr +$V_ARCHIVE_DISKGROUP/$V_CLONE_DB/ONLINELOG
$GRID_HOME/bin/asmcmd --privilege sysdba rm -fr +$V_ARCHIVE_DISKGROUP/$V_CLONE_DB/ONLINELOG
echo asmcmd --privilege sysdba rm -fr +$V_ARCHIVE_DISKGROUP/$V_CLONE_DB/CONTROLFILE
$GRID_HOME/bin/asmcmd --privilege sysdba rm -fr +$V_ARCHIVE_DISKGROUP/$V_CLONE_DB/CONTROLFILE

echo asmcmd --privilege sysdba rm -fr +$V_REDO_DISKGROUP/$V_CLONE_DB/ONLINELOG
$GRID_HOME/bin/asmcmd --privilege sysdba rm -fr +$V_REDO_DISKGROUP/$V_CLONE_DB/ONLINELOG
echo asmcmd --privilege sysdba rm -fr +$V_REDO_DISKGROUP/$V_CLONE_DB/CONTROLFILE
$GRID_HOME/bin/asmcmd --privilege sysdba rm -fr +$V_REDO_DISKGROUP/$V_CLONE_DB/CONTROLFILE
}
#################################################################################################################

#################################################################################################################
# Setup environment for duplication to be done locally
#################################################################################################################
# Backup location
if [[ $DUPLICATE_MODE == $BACKUP_MODE ]]
then
  backup_location="$BACKUP_LOCATION_ROOT/$SOURCE_SID"
  print "backup_location is $backup_location" | tee -a $log
[[ ! -d $backup_location ]] && { print "Backup location $backup_location not found, exit." | tee -a $err; exit; }
fi

#################################################################################################################
# Preparing duplication
#################################################################################################################
# Script connects directly to destination/auxiliary instance to avoid to have to setup static registration
#################################################################################################################

#Local tnsnames.ora with new databases
#export TNS_ADMIN=/u01/app/oracle/dup/network/admin

export ORACLE_SID=$DEST_SID
ORAENV_ASK=NO
. oraenv
env | grep ORA | sort

sleep 5

# set parameters for auxiliary instance init.ora file
#db_name=$DEST_SID
# Case when DEST_SID is like db_name_STBY, resulting DEST_SID length is often > 8
source_db_name=${SOURCE_SID%_*}
dest_db_name=${DEST_SID%_*}
typeset -l lowersourcedb_name=$source_db_name
typeset -l lowerdestdb_name=$dest_db_name

db_name=$dest_db_name
# Oracle db_name must be <= 8
(( ${#db_name} > 8 )) && { print "db_name length is > 8, exit."; exit; }
db_unique_name=$DEST_SID
compatible=18.7.0
audit_file_dest="$ORACLE_BASE/admin/$DEST_SID/adump"
diagnostic_dest="$ORACLE_BASE/diag/rdbms/$lowerdestdb_name/$DEST_SID/trace"
core_dump_dest="$ORACLE_BASE/diag/rdbms/$lowerdestdb_name/$DEST_SID/cdump"
db_create_file_dest='+DATA'
db_create_online_log_dest_1='+REDO'
db_recovery_file_dest='+FRA'
db_recovery_file_dest_size=20G
remote_login_passwordfile='EXCLUSIVE'
# Control files
control_file_1='control01.ctl'
control_file_2='control02.ctl'
control_file_dir_1="$db_create_file_dest/$DEST_SID/CONTROLFILE"
control_file_dir_2="$db_recovery_file_dest/$DEST_SID/CONTROLFILE"
ctl_file_1="$control_file_dir_1/$control_file_1"
ctl_file_2="$control_file_dir_2/$control_file_2"
control_files="'$ctl_file_1','$ctl_file_2'"

# sysdba password file
passwordfile="$ORACLE_HOME/dbs/orapw${DEST_SID}"
asmpasswordfile="$db_create_file_dest/$DEST_SID/orapw${DEST_SID}"

# spfile & pfile
spfile="$ORACLE_HOME/dbs/spfile${DEST_SID}.ora"
tmppfile="$TMPDIR/init${DEST_SID}_${pid}.ora"
asmspfile="$db_create_file_dest/$DEST_SID/spfile${DEST_SID}"
newpfile="$ORACLE_HOME/dbs/init${DEST_SID}.ora"

#################################################################################################################
# PasswordState gpg setup
OEM_HOST=flbeoraoem01
GLOB_SECFILE=/u01/app/oracle/scripts/security/reslist_$OEM_HOST.txt.gpg

DEST_SECFILE=/u01/app/oracle/scripts/security/reslist_${HOSTNAME}.txt.gpg
[[ ! -s $DEST_SECFILE ]] && { print "GPG $DEST_SECFILE not found, exit." | tee -a $err; exit; }

# Get SYS info for source & destination
sys_usr=SYS

# Find host for $SOURCE_SID with tnsping. Only for active duplication.
if [[ $DUPLICATE_MODE == $ACTIVE_MODE ]]
then
  sshcmd="gpg -qd $GLOB_SECFILE | grep -i \"$SOURCE_SID:$sys_usr:\" | cut -d \":\" -f3"
  source_sid_pwd=$(ssh oracle@$OEM_HOST $sshcmd)
  # 2019/10/28 :  comme en ce moment passwordstate est souvent en retard, j'applique la convention ....
  [[ -z $source_sid_pwd ]]  && { source_sid_pwd="Qmx0225_${lowersourcedb_name}"; print "source_sid_pwd according to convention : $source_sid_pwd"; }
  [[ -z $source_sid_pwd ]]  && { print "$sys_usr password for $SOURCE_SID not found, exit." | tee -a $err; exit; }
fi

dest_sid_pwd=$(gpg -qd $DEST_SECFILE | grep -i "$DEST_SID:$sys_usr:" | cut -d ":" -f3)
#dest_sid_pwd=${source_sid_pwd}
# 2019/10/21 :  comme en ce moment passwordstate est souvent en retard, j'applique la convention ....
[[ -z $dest_sid_pwd ]]  && { dest_sid_pwd="Qmx0225_${lowerdestdb_name}"; print "dest_sid_pwd according to convention : $dest_sid_pwd"; }

[[ -z $dest_sid_pwd ]]  && { print "$sys_usr password for $DEST_SID not found, exit." | tee -a $err; exit; }
[[ ! -z $DEBUG ]] && print "dest_sid_pwd is $dest_sid_pwd"  | tee -a $log
#################################################################################################################

# connection string
#dest_cnxsys="sys/$dest_sid_pwd@$DEST_SID as sysdba"
dest_cnxsys="sys/$dest_sid_pwd as sysdba"

# Abort instance $DEST_SID if found
(( instanceUp = $(ps -ef | grep "pmon_$DEST_SID\$" | grep -v grep | wc -l ) ))
if (( instanceUp == 1 ))
then
  print "\nAbout to abort instance $DEST_SID" | tee -a $log
  if [[ $DEBUG  == '' ]]
  then
    $ORACLE_HOME/bin/sqlplus -s $dest_cnxsys <<! | tee -a $log
whenever sqlerror exit sql.sqlcode;
shutdown abort
exit
!
    (( rc = $? ))
    (( rc != 0 )) && { print "Error while aborting instance $DEST_SID, exit." | tee -a $err; exit; }
  fi
fi

#################################################################################################################
# Cleanup
# ASM files are removed.
#################################################################################################################
print '\nASM cleanup' | tee -a $log
print "ORACLE_SID is $ORACLE_SID"
#remove_db
ssh grid@flbeoradgqua01 "/home/grid/dup/rmasm4db.sh $ORACLE_SID"

sleep 5

print '\nPassword & pfiles cleanup' | tee -a $log
[[ -f $passwordfile ]] && $DEBUG rm -v $passwordfile | tee -a $log
[[ -f $newpfile ]] && $DEBUG rm -v $newpfile | tee -a $log
[[ -f $spfile ]] && $DEBUG rm -v $spfile | tee -a $log

# Create minimal auxiliary instance init.ora file
init_ora_file="$TMPDIR/init_${DEST_SID}_4_dup_${pid}.ora"
cat <<! > $init_ora_file
db_name=$db_name
db_unique_name=$db_unique_name
compatible=$compatible
control_files=$control_files
remote_login_passwordfile='EXCLUSIVE'
db_create_file_dest='$db_create_file_dest'
db_recovery_file_dest='$db_recovery_file_dest'
db_recovery_file_dest_size='$db_recovery_file_dest_size'
db_create_online_log_dest_1='+REDO'
db_create_online_log_dest_2='+FRA'
!
[[ ! -s $init_ora_file ]] && { print "Auxiliary instance $DEST_SID $init_ora_file not created, exit." | tee -a $err; exit; }
print "\nAuxiliary instance $DEST_SID $init_ora_file" | tee -a $log
cat $init_ora_file | tee -a $log

# Create RMAN command file
rman_cmd_file="$TMPDIR/duplicate_${SOURCE_SID}_2_${DEST_SID}_${pid}.rman"
rman_log_file="$TMPDIR/duplicate_${SOURCE_SID}_2_${DEST_SID}_${pid}.log"

#################################################################################################################
# Duplicate from backup
#################################################################################################################
if [[ $DUPLICATE_MODE == $BACKUP_MODE ]]
then
  dest_cnxsys="sys/$dest_sid_pwd as sysdba"
  cat <<! > $rman_cmd_file
connect auxiliary sys/$dest_sid_pwd
run{
allocate auxiliary channel aux1 type disk;
allocate auxiliary channel aux2 type disk;
allocate auxiliary channel aux3 type disk;
allocate auxiliary channel aux4 type disk;
allocate auxiliary channel aux5 type disk;
allocate auxiliary channel aux6 type disk;
allocate auxiliary channel aux7 type disk;
allocate auxiliary channel aux8 type disk;
DUPLICATE DATABASE '$SOURCE_SID' TO '$DEST_SID'
!

  if [[ ! -z $UNTIL_TIME ]] 
  then
    print "Setting up rman command file for $UNTIL_TIME" | tee -a $log
    cat <<! >> $rman_cmd_file
UNTIL TIME "$UNTIL_TIME"
!
  fi

  cat <<! >> $rman_cmd_file
backup location '$backup_location'
spfile
PARAMETER_VALUE_CONVERT
  '$SOURCE_SID','$DEST_SID'
NOFILENAMECHECK;
}
!
fi

#################################################################################################################
# Duplicate ACTIVE
#################################################################################################################
if [[ $DUPLICATE_MODE == $ACTIVE_MODE ]]
then
  dest_cnxsys="sys/$source_sid_pwd as sysdba"
  cat <<! > $rman_cmd_file
connect target sys/$source_sid_pwd@$SOURCE_SID
connect auxiliary sys/$source_sid_pwd
run{
allocate channel prm1 type disk;
allocate channel prm2 type disk;
allocate auxiliary channel aux1 type disk;
allocate auxiliary channel aux2 type disk;
allocate auxiliary channel aux3 type disk;
allocate auxiliary channel aux4 type disk;
DUPLICATE TARGET DATABASE TO '$db_name'
FROM ACTIVE DATABASE
!

  cat <<! >> $rman_cmd_file
SPFILE
  PARAMETER_VALUE_CONVERT
    '$SOURCE_SID','$DEST_SID','$lowersourcedb_name','$lowerdestdb_name'
  SET DB_UNIQUE_NAME='$DEST_SID'
USING COMPRESSED BACKUPSET SECTION SIZE 2G
NOFILENAMECHECK;
}
!
fi

[[ ! -s $rman_cmd_file ]] && { print "RMAN command file $rman_cmd_file  not created, exit." | tee -a $err; exit; }
print "\nRMAN command file $rman_cmd_file" | tee -a $log
cat $rman_cmd_file

# Summary
if [[ ! -z $DEBUG ]]
then
  print "\nSummary"
  print "SOURCE_SID is $SOURCE_SID"
  print "DEST_SID is $DEST_SID"
  print "db_name is $db_name"
  print "audit_file_dest is $audit_file_dest"
  print "passwordfile is $passwordfile"
  #print "asmpasswordfile is $asmpasswordfile"
  print "spfile is $spfile"
  print "tmppfile is $tmppfile"
  print "asmspfile is $asmspfile"
  print "newpfile is $newpfile"
  print "audit_file_dest is $audit_file_dest"
  print "diagnostic_dest is $diagnostic_dest"
  print "core_dump_dest is $core_dump_dest"
  print "ctl_file_1 is $ctl_file_1"
  print "ctl_file_2 is $ctl_file_2"
  print "control_files is $control_files"
  print "db_create_file_dest is $db_create_file_dest"
  print "db_recovery_file_dest is $db_recovery_file_dest"
  print "db_recovery_file_dest_size is $db_recovery_file_dest_size"
  print "init_ora_file is $init_ora_file"
  print "rman_cmd_file is $rman_cmd_file"
fi

# Create mandatory directory
[[ ! -d $audit_file_dest ]] &&  mkdir -pv $audit_file_dest | tee -a $log
[[ ! -d $audit_file_dest ]] && { print "Audit directory $audit_file_dest not found, exit." | tee -a $err; exit; }
[[ ! -d $diagnostic_dest ]] &&  mkdir -pv $diagnostic_dest | tee -a $log
[[ ! -d $diagnostic_dest ]] && { print "Diagnostic directory $diagnostic_dest not found, exit." | tee -a $err; exit; }
[[ ! -d $core_dump_dest ]] &&  mkdir -pv $core_dump_dest | tee -a $log
[[ ! -d $core_dump_dest ]] && { print "Core dump directory $core_dump_dest not found, exit." | tee -a $err; exit; }

# Create password file
[[ $DUPLICATE_MODE == $BACKUP_MODE ]] && $DEBUG $ORACLE_HOME/bin/orapwd file=$passwordfile password=$dest_sid_pwd entries=10  force=y | tee -a $log
# For active duplication SYS password must be identical for source & destination
[[ $DUPLICATE_MODE == $ACTIVE_MODE ]] && $DEBUG $ORACLE_HOME/bin/orapwd file=$passwordfile password=$source_sid_pwd entries=10  force=y | tee -a $log

[[ ! -s $passwordfile ]] && { print "Oracle password file $passwordfile empty or not found, exit." | tee -a $err; exit; }
print "Oracle password file $passwordfile created" | tee -a $log
[[ ! -z $DEBUG ]] && ls -l $passwordfile

#################################################################################################################
# Starting duplication
#################################################################################################################

env | sort
sleep 5

if [[ -z $DEBUG ]]
then
  print "\nStartup auxiliary instance $DEST_SID" | tee -a $log
# Start auxiliary instance
  $ORACLE_HOME/bin/sqlplus -s $dest_cnxsys <<! | tee -a $log
whenever sqlerror exit sql.sqlcode;
startup nomount pfile='$init_ora_file';
exit
!
  (( rc = $? ))
  (( rc != 0 )) && { print "Error while starting auxiliary instance $DEST_SID, exit." | tee -a $err; exit; }
fi

sleep 2

# Duplicate database with rman
print "\nAbout to duplicate ...." | tee -a $log
# To be able to compute duplication duration when done
start=$SECONDS
$DEBUG $ORACLE_HOME/bin/rman cmdfile $rman_cmd_file log $rman_log_file 

############################
# Scan rman log for errors
############################
(( rman_err_cnt = $( grep 'RMAN-' $rman_log_file | wc -l) ))
(( ora_err_cnt = $( grep 'ORA-' $rman_log_file | wc -l) ))
if (( rman_err_cnt > 0 || ora_err_cnt > 0 )) 
then
  print "RMAN error count is $rman_err_cnt" | tee -a $err
  grep 'RMAN-' $rman_log_file | tee -a $err
  print "Oracle error count is $ora_err_cnt" | tee -a $err
  grep 'ORA-' $rman_log_file | tee -a $err
  print  "\n$DEST_SID duplication has error(s), investigate, exit." | tee -a $err
  failure_msg="Failure for $DEST_SID duplication"
  mailx -s "$failure_msg" $mailx_it_database_list < $err
  mailx -s "$failure_msg" $mailx_it_database_team_list < $err
  exit
else
  success_msg="Succesfull duplication for $DEST_SID"
  print "\n$success_msg\n" | tee -a $log
  date -ud "@$((SECONDS-start))" "+Elapsed Time: %H:%M:%S.%N" | tee -a $log
  mailx -s "$success_msg" $mailx_it_database_list < $log
  mailx -s "$success_msg" $mailx_it_database_team_list < $log
fi

#################################################################################################################
# Duplication is done
#################################################################################################################

#################################################################################################################
# Store duplicated database spfile on ASM
#################################################################################################################
print "\nPut $DEST_SID spfile on ASM" | tee -a $log
# Create a temp pfile from current spfile
print "About to create temp pfile $tmppfile" | tee -a $log
$ORACLE_HOME/bin/sqlplus -s $dest_cnxsys <<! | tee -a $log
whenever sqlerror exit sql.sqlcode;
create pfile='$tmppfile' from spfile;
exit
!
(( rc = $? ))
(( rc != 0 )) && { print "Error while creating pfile $tmppfile from spfile, exit." | tee -a $err; exit; }
[[ ! -s $tmppfile ]] && { print "Temporary pfile $tmppfile empty of not found, exit." | tee -a $err; exit; }

# Put spfile on ASM
print "About to create ASM pfile $asmspfile" | tee -a $log
$ORACLE_HOME/bin/sqlplus -s $dest_cnxsys <<! | tee -a $log
whenever sqlerror exit sql.sqlcode;
create spfile='$asmspfile' from pfile='$tmppfile';
exit
!
(( rc = $? ))
(( rc != 0 )) && { print "Error while creating ASM spfile $asmspfile from pfile $tmppfile from spfile, exit." | tee -a $err; exit; }

# move spfile & pfile from $ORACLE_HOME/dbs out of the way
[[ -s $spfile ]] && mv -v $spfile ${spfile}_${pid} | tee -a $log
[[ -s $newpfile ]] && mv -v $newpfile ${newpfile}_${pid} | tee -a $log

# Create init pfile pointing to ASM spfile
cat <<! > $newpfile
spfile='$asmspfile'
!
[[ ! -s $newpfile ]] && { print "ASM spfile pointing pfile $newpfile empty or not found, exit." | tee -a $err; exit; }

#################################################################################################################
# Store duplicated database password on ASM
#################################################################################################################
#$DEBUG $ORACLE_HOME/bin/orapwd input_file=$passwordfile file=$asmpasswordfile asm=y

# Mount db with ASM pfile
$ORACLE_HOME/bin/sqlplus -s $dest_cnxsys <<! | tee -a $log
whenever sqlerror exit sql.sqlcode;
shutdown abort
startup pfile='$newpfile'
alter user sys identified by $dest_sid_pwd;
alter user system identified by $dest_sid_pwd;
alter user dzdba identified by $dest_sid_pwd;
shutdown immediate
exit
!
(( rc = $? ))
(( rc != 0 )) && { print "Error while starting instance $DEST_SID with ASM spfile pointing pfile $newpfile, exit." | tee -a $err; exit; }

srvctl add database -db $DEST_SID -spfile $asmspfile -oraclehome $ORACLE_HOME -dbname $db_name
srvctl config database -db $DEST_SID 
srvctl start database -db $DEST_SID 
exit 0

