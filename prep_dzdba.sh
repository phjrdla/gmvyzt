#!/usr/bin/ksh

[[ -z $ORACLE_SID ]] && { print "ORACLE_SID must be defined, exit."; exit; }

print "ORACLE_SID is $ORACLE_SID"

typeset -l lowerORACLE_SID=$ORACLE_SID

cnxsys='/ as sysdba'
cnxdzdba="dzdba/Qmx0225_$lowerORACLE_SID"

sqlplus -s  $cnxsys <<!
grant select on v_\$event_name to dzdba
/
connect $cnxdzdba 
create synonym v_\$event_name for sys.v_\$event_name
/
exit
!

