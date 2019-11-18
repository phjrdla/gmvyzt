-- Create Table with same structure as ALL_TABLES from Oracle Dictionary
set timing on
set echo off
set lines 200
set pages 100
set serveroutput on

column hostname format a12 trunc
column instance_name format a12 trunc

spool san_test.out;
select host_name, instance_name
  from v$instance;

drop table my_objects;

create table my_objects
as
select rownum id, a.*
  from all_objects a
 where 1=0;
alter table my_objects nologging;

select count(1) from  my_objects;

-- to compute difference between timestamps
create or replace function timestamp_diff(a timestamp, b timestamp) return number is
begin
  return extract (day    from (a-b))*24*60*60 +
         extract (hour   from (a-b))*60*60+
         extract (minute from (a-b))*60+
         extract (second from (a-b));
end;
/

select count(1) from  all_objects;

-- Create table my_objects from all_objects
-- insert l_rows rows
declare
    l_cnt  number;
    l_rows number := 10000000;
    object_name all_objects.object_name%type;
    object_type all_objects.object_type%type;
    random_row  my_objects.id%type;
    random_reads  number;
    tstamp_start timestamp;
    tstamp_end timestamp;
    diff number;
begin
    -- Copy ALL_OBJECTS
    insert /*+ append */
    into my_objects
    select rownum, a.*
      from all_objects a;
    l_cnt := sql%rowcount;
    commit;

    -- Insert rows
    dbms_output.put_line('---------------------------------------------------------------------------------------------------');
    dbms_output.put_line(to_char(l_rows)||' sequential inserts');
    execute immediate 'select systimestamp from dual' into tstamp_start;
    dbms_output.put_line('timestamp start is '||to_char(tstamp_start,'DD-MON-YY HH24:MI:SS.FF'));
    while (l_cnt < l_rows)
    loop
        insert /*+ APPEND */ into my_objects
        select rownum+l_cnt,
               OWNER, OBJECT_NAME, SUBOBJECT_NAME,
               OBJECT_ID, DATA_OBJECT_ID,
               OBJECT_TYPE, CREATED, LAST_DDL_TIME,
               TIMESTAMP, STATUS, TEMPORARY,
               GENERATED, SECONDARY,
               NAMESPACE, EDITION_NAME, SHARING,
               EDITIONABLE, ORACLE_MAINTAINED, APPLICATION,
               DEFAULT_COLLATION, DUPLICATED, SHARDED,
               CREATED_APPID, CREATED_VSNID, MODIFIED_APPID, MODIFIED_VSNID
          from my_objects
         where rownum <= l_rows-l_cnt;
        l_cnt := l_cnt + sql%rowcount;
        commit;
    end loop;
    execute immediate 'select systimestamp from dual' into tstamp_end;
    dbms_output.put_line('timestamp end is '||to_char(tstamp_end,'DD-MON-YY HH24:MI:SS.FF'));
    execute immediate 'select timestamp_diff( :1, :2) from dual' into diff using  tstamp_end, tstamp_start;
    dbms_output.put_line('duration in sec is '||to_char(ceil(diff)));
    dbms_output.put_line('inserts/sec are '||to_char( ceil(l_rows/diff) ) );

-- Create primary key
    dbms_output.put_line('---------------------------------------------------------------------------------------------------');
    dbms_output.put_line('Create primary key on '||to_char(l_rows)||' records');
    execute immediate 'select systimestamp from dual' into tstamp_start;
    dbms_output.put_line('timestamp start is '||to_char(tstamp_start,'DD-MON-YY HH24:MI:SS.FF'));
    execute immediate 'alter table my_objects add constraint my_objects_pk primary key(id)';
    execute immediate 'select systimestamp from dual' into tstamp_end;
    dbms_output.put_line('timestamp end is '||to_char(tstamp_end,'DD-MON-YY HH24:MI:SS.FF'));
    execute immediate 'select timestamp_diff( :1, :2) from dual' into diff using  tstamp_end, tstamp_start;
    dbms_output.put_line('duration in sec is '||to_char(ceil(diff)));

-- create a seed for repeatability
   dbms_random.seed ( l_rows );

   random_reads :=  l_rows/10;

-- Read randomly 10% of all rows
   dbms_output.put_line('---------------------------------------------------------------------------------------------------');
   dbms_output.put_line(to_char(random_reads)||' random reads');
   execute immediate 'select systimestamp from dual' into tstamp_start;
   dbms_output.put_line('timestamp start is '||to_char(tstamp_start,'DD-MON-YY HH24:MI:SS.FF'));
   for i in 1..random_reads
   loop
     random_row := floor(DBMS_RANDOM.value(low => 1, high => l_rows));
     execute immediate 'select object_type,object_name from my_objects where id = :1' into object_type, object_name using random_row;
     -- dbms_output.put_line('row '||to_char(random_row)||' object_name '||object_name);
   end loop;
   execute immediate 'select systimestamp from dual' into tstamp_end;
   dbms_output.put_line('timestamp end is '||to_char(tstamp_end,'DD-MON-YY HH24:MI:SS.FF'));
   execute immediate 'select timestamp_diff( :1, :2) from dual' into diff using  tstamp_end, tstamp_start;
   dbms_output.put_line('duration in sec is '||to_char(ceil(diff)));
   dbms_output.put_line('reads/sec are '||to_char( ceil(random_reads/diff) ) );

-- Delete all rows + commit
   dbms_output.put_line('---------------------------------------------------------------------------------------------------');
   dbms_output.put_line('delete of all '||to_char(l_rows)||' rows');
   execute immediate 'select systimestamp from dual' into tstamp_start;
   dbms_output.put_line('timestamp start is '||to_char(tstamp_start,'DD-MON-YY HH24:MI:SS.FF'));
   execute immediate 'delete from my_objects';
   execute immediate 'commit';
   execute immediate 'select systimestamp from dual' into tstamp_end;
   dbms_output.put_line('timestamp end is '||to_char(tstamp_end,'DD-MON-YY HH24:MI:SS.FF'));
   execute immediate 'select timestamp_diff( :1, :2) from dual' into diff using  tstamp_end, tstamp_start;
   dbms_output.put_line('duration in sec is '||to_char(ceil(diff)));
   dbms_output.put_line('deletes/sec are '||to_char( ceil(l_rows/diff) ) );
   
end;
/

spool off
