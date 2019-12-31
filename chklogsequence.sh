#!/usr/bin/ksh

cat <<!
Finds which are the "Last Seq Received" and the "Last Seq Applied"
Should be identical
!

typeset -u srvname
if (( $# == 1 ))
then
  srvname=$1
else
  while [[ -z "$srvname" ]]
  do
    read srvname?"Enter database unique name(q to quit) :"
    [[ $srvname = 'Q' ]] && exit
  done
fi
typeset -l lowersrvname=$srvname

# get password for account sys for database
usrname=SYSTEM
#usrpwd=$(/home/oracle/scripts/getpwd.sh $srvname $usrname)
usrpwd="Qmx0225_$lowersrvname"
[[ $usrpwd = "" ]] && { print "No credential found for $usrname and $srvname"; exit; }
cnx="${usrname}/${usrpwd}@$srvname"

print "cnx iz $cnx"

sqlplus -S $cnx <<!
set lines 200
SELECT al.thrd "Thread", almax "Last Seq Received", lhmax "Last Seq Applied"
  FROM (select thread# thrd, MAX(sequence#) almax 
         FROM v\$archived_log 
        WHERE resetlogs_change#=(SELECT resetlogs_change#
                                   FROM v\$database) 
        GROUP BY thread#) al, 
       (SELECT thread# thrd, MAX(sequence#) lhmax
          FROM v\$log_history
         WHERE resetlogs_change#=(SELECT resetlogs_change# 
                                    FROM v\$database) 
                                   GROUP BY thread#) lh 
  WHERE al.thrd = lh.thrd
/
!


