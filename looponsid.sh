#!/usr/bin/ksh

[[ ! -f $ORACLE_HOME/dbs/save ]] && mkdir -p $ORACLE_HOME/dbs/save

sids=$(ps -ef | grep pmon | grep -v grep | grep -v ASM | sed 's/^.*pmon_//' | grep -v /)

for sid in $sids
do
  pfile="init$sid.ora"
# print $pfile

  spfile="+DATA/$sid/spfile$sid.ora"
# print $spfile

#  [[ -s $ORACLE_HOME/dbs/$pfile ]] && mv $ORACLE_HOME/dbs/$pfile $ORACLE_HOME/dbs/save/${pfile}_$$
#  cat <<! > $ORACLE_HOME/dbs/$pfile
#SPFILE='$spfile'
#!

# print "srvctl modify database -db $sid -spfile '$spfile'"

  srvctl config database -db $sid
done
