#!/usr/bin/ksh
this_script=$0
pid=$$

cat <<!
$this_script lists indexes with depths > 2.
Rebuild for these indexes is optional
!

[[ $# = 0 ]] && { print "Usage: $(basename $0) [-h] -d dbname [-l Level] [-r (rebuild) Y/N]"; exit; }

(( BLEVEL = 2 ))
typeset -u REBUILD='N'

while getopts "h:?d:o:l:?r:?" OPTION
do
  case "$OPTION" in
    d)
      typeset -u DBNAME=$OPTARG
      typeset -l lowerDBNAME=$DBNAME
      ;;
    l)
      BLEVEL=$OPTARG
      ;;
    r)
      REBUILD=$OPTARG
      ;;
    h)
      print "Usage: $(basename $0) [-h] -d dbname [-l Level] [-r rebuuild]"
      print "Exemple :  $(basename $0) -d BELREG -l 2 -r Y" 
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"

print "DBNAME is $DBNAME"
print "BLEVEL is $BLEVEL"
print "REBUILD is $REBUILD"

(( BLEVEL <= 1 )) && { print "Level must be > 1, exit."; exit; }

cnx="dzdba/Qmx0225_$lowerDBNAME@$DBNAME"

[[ -z $ORACLE_HOME ]] && { print "ORACLE_HOME is not defined, exit."; exit; }

candidates="/tmp/candidates_${DBNAME}_$pid.lst"
$ORACLE_HOME/bin/sqlplus -S $cnx <<!
set pages 100
set lines 110
set timing off
set trimspool on
column owner          format a20 trunc
column index_owner    format a20 trunc
column index_name     format a20 trunc
column blevel         format 99999
column degree         format a6
column partition_name format a30 trunc
column num_rows       format 999,999,999

spool $candidates
ttitle "$DBNAME - Ordinary indexes candidates for a rebuild - depth > $BLEVEL"
clear breaks
break on owner skip 1
select owner
      ,index_name
      ,num_rows
      ,blevel
      ,degree
  from all_indexes
 where owner in ( select username
                    from dba_users
                   where user_id > 100 )
   and blevel > $BLEVEL
   and index_name not in ( select distinct index_name 
                            from all_ind_partitions )
order by owner, index_name
/
ttitle "$DBNAME - Partionned indexes candidates for a rebuild - depth > $BLEVEL"
clear breaks
break on index_owner skip 1 on index_name skip 1
select aip.index_owner
      ,aip.index_name
      ,aip.partition_name 
      ,aip.num_rows
      ,aip.blevel
      ,ai.degree
  from all_ind_partitions aip
      ,all_indexes ai
 where  aip.index_owner in ( select username
                               from dba_users
                              where user_id > 100 )
  and aip.blevel > $BLEVEL
  and aip.index_owner = ai.owner
  and aip.index_name = ai.index_name
order by aip.index_owner, aip.partition_name, aip.index_name
/
spool off
!

print "\nIndexes health report"
ls -l $candidates

cmdfile="/tmp/sql_$pid.cmd"
cmdlog="/tmp/sql_$pid.log"

print "\nRebuilds script is $cmdfile"
$ORACLE_HOME/bin/sqlplus -S $cnx <<!
set pages 0
set lines 100
set feedback off
set heading off
set trimspool on
set termout off
set echo off
spool $cmdfile
select 'alter index '||owner||'.'||INDEX_NAME||' REBUILD ONLINE PARALLEL '||DEGREE||';'
  from all_indexes
 where owner in ( select username
                    from dba_users
                   where user_id > 100 )
   and blevel > $BLEVEL
   and index_name not in ( select distinct index_name 
                            from all_ind_partitions )
order by owner, index_name
/
select 'alter index '||aip.index_owner||'.'||aip.INDEX_NAME||' REBUILD PARTITION '||aip.PARTITION_NAME||' ONLINE PARALLEL '||ai.DEGREE||';'
  from all_ind_partitions aip
      ,all_indexes ai
 where  aip.index_owner in ( select username
                               from dba_users
                              where user_id > 100 )
  and aip.blevel > $BLEVEL
  and aip.index_owner = ai.owner
  and aip.index_name = ai.index_name
order by aip.index_owner, aip.index_name, aip.partition_name
/
spool off
!

[[ $REBUILD != 'Y' ]] && { print "\nRebuilds script is NOT run, exit."; exit; }

print "\nRebuilds are performed"

$ORACLE_HOME/bin/sqlplus -S $cnx <<!
set timing on
set termout on
set echo on
spool $cmdlog
@$cmdfile
spool off
!

[[ -f $cmdfile ]] && rm -f $cmdfile
