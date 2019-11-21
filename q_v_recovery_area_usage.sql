set lines 200
set pages 25

column name format a60 trunc
column space_limit       format 999,999,999,999
column space_used        format 999,999,999,999
column SPACE_RECLAIMABLE format 999,999,999,999

SELECT * 
  FROM V$RECOVERY_AREA_USAGE
/

