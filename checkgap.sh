#!/usr/bin/ksh
this_script=$0

print "This is $this_script with parameter $1"

#
# Computes archivelogs gap between primary and standby instances
# Derived from V$ARCHIVED_LOG
# Warning mail if gap > 5
#

(( $# != 1 )) && { print "Usage is $this_script DB_NAME, exit."; exit; }
typeset -u DB_NAME=$1

ORAENV_ASK=NO
export ORACLE_SID=$DB_NAME
. oraenv

print "Current ORACLE_HOME is $ORACLE_HOME"

# Global security repo
OEM_HOST=flbeoraoem01
GLOB_SECFILE=/u01/app/oracle/scripts/security/reslist_$OEM_HOST.txt.gpg

# get password for user dzdba
usrname=dzdba
sshcmd="gpg -qd $GLOB_SECFILE | grep -i \"$DB_NAME:$usrname:\" | cut -d \":\" -f3"
usrpwd=$(ssh oracle@$OEM_HOST $sshcmd)
[[ $usrpwd = "" ]] && { print "No credential found for $usrname and $DB_NAME"; exit; }

# Database connection string
cnxsys="${usrname}/${usrpwd}"

# Find out about current gap
(( gap=$($ORACLE_HOME/bin/sqlplus -S $cnxsys  <<!
set pages 0
set feedback off
set heading off
set timin off
set lines 200
select LOG_ARCHIVED-LOG_APPLIED-1 "LOG_GAP" 
  from (SELECT MAX(SEQUENCE#) LOG_ARCHIVED
          FROM V\$ARCHIVED_LOG 
         WHERE DEST_ID=1 
           AND ARCHIVED='YES'),
       (SELECT MAX(SEQUENCE#) LOG_APPLIED
          FROM V\$ARCHIVED_LOG 
         WHERE DEST_ID=2 
           AND APPLIED='YES')
/
!)
))

# Message to whoever is in charge
if (( gap > 5 )) 
then
  mailx -s "$DB_NAME Data Guard gap" IT.database@fluxys.net,IT.database.team@fluxys.net  <<!
Check standby database for $DB_NAME, gap is now $gap ...
!
fi

