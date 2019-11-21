set echo on
set timing on
alter database drop logfile group &&1;
alter database add logfile group &&1 ('+REDO', '+FRA') size &2;
@q_rlf_det
exit
