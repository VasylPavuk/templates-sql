use master;
go
if Object_ID('sp_who4', 'p') is not null drop procedure sp_who4;
go
create procedure sp_who4
    -- Pavuk.V 05.10.2012
(
    @spid int = null
)
 as
begin
    set nocount on;
    declare @who table
    (
        session_id              int,
        [status]                nvarchar(30),
        command                 nvarchar(32),
        DatabaseName            sysname null,
        blocking_session_id     int,
        blocking_path           varchar(1024),
        start_time              datetime,
        duration                varchar(16),
        cpu_time                int,
        reads                   bigint,
        writes                  bigint,
        logical_reads           bigint,
        granted_query_memory    int,
        wait_time               int,
        last_wait_type          nvarchar(60),
        wait_resource           nvarchar(256),
        [host_name]             nvarchar(128),
        host_process_id         int,
        [program_name]          nvarchar(128),
        login_name              nvarchar(128),
        ObjectName              nvarchar(128),
        isolation_level         varchar(16),
        [statement]             nvarchar(max),
        [text]                  nvarchar(max)
    )
    insert into @who
    select  s.session_id, [status]=coalesce(r.[status], s.[status]), r.command, DatabaseName=d.name, r.blocking_session_id, blocking_path='', r.start_time, duration = convert(varchar(16), getdate()-r.start_time, 114),
            r.cpu_time, r.reads, r.writes, r.logical_reads, r.granted_query_memory, r.wait_time, r.last_wait_type, r.wait_resource,
            s.[host_name], s.host_process_id, s.[program_name], s.login_name, ObjectName=object_name(t.objectid, t.[dbid]),
            isolation_level =
		        case s.transaction_isolation_level
                    when 0 then 'unspecified'
                    when 1 then 'read uncommitted'
                    when 2 then 'read committed'
                    when 3 then 'repeatable'
                    when 4 then 'serializable'
                    when 5 then 'snapshot'
                end,
            [statement] = substring
                (
                    t.[text],
                    case when coalesce(r.statement_start_offset,0) = 0 then 1 else statement_start_offset/2 + 1 end,
                    case when coalesce(r.statement_end_offset,-1) in (0,-1) then len(text) else statement_end_offset/2 end - case when coalesce(r.statement_start_offset,0) = 0 then 1 else statement_start_offset/2 + 1 end+1
                ),
                t.[text]
    from    sys.dm_exec_sessions s
            left join sys.dm_exec_requests r on r.session_id = s.session_id
            left join sys.databases d on r.database_id = d.database_id
            outer apply sys.dm_exec_sql_text(r.[sql_handle]) t
    where   s.session_id!= @@spid and s.[status] not in('sleeping', 'dormant');

    if exists(select 1 from @who where blocking_session_id != 0)
    begin
        declare @blk table(session_id int, block_path varchar(1024));
        with BlockQueue ([session_id], [block_path]) as
        (				--	базова частина
	        select	s.[session_id], [block_path] = convert(varchar(max), s.[session_id])
	        from	sys.dm_exec_sessions s with (nolock)
	        where	--	є запити, які блокуються сесією s
			        exists (select * from sys.dm_exec_requests c with (nolock) where c.[blocking_session_id] = s.[session_id] )and
			        --	нема запитів, які блокують сесію s
			        not exists(select * from sys.dm_exec_requests c with (nolock) where c.[session_id] = s.[session_id] and c.[blocking_session_id] != 0)
			
	        union all	--	рекурсивна частина
	
	        select	r.[session_id], [Path] = q.[block_path] + '\' + convert(varchar(max),r.[session_id])
	        from	sys.dm_exec_requests r with (nolock)
			        inner join BlockQueue q on r.[blocking_session_id] = q.[session_id]	--	сесія, якою блокується запит r
        )
        insert into @blk(session_id, block_path)
        select  session_id, block_path
        from    BlockQueue;

        update  w
        set     blocking_path = bq.block_path
        from    @who w
                inner join @blk bq on w.session_id = bq.session_id;
    end;
	begin try
		declare @startTag nvarchar(max) = '<?query '+char(13)+char(10)+char(13)+char(10);
		select  session_id,[status],command,DatabaseName,blocking_session_id,blocking_path,start_time,duration,cpu_time,reads,writes,logical_reads,granted_query_memory,
				wait_time,last_wait_type,wait_resource,[host_name],host_process_id,[program_name],login_name,ObjectName,isolation_level,
				[statement] = convert(xml, @startTag + [statement] + '?>'),[text] = convert(xml, @startTag+[text]+'?>')
		from    @who
		order by blocking_path, start_time, session_id;
	end try
	begin catch
		select  session_id,[status],command,DatabaseName,blocking_session_id,blocking_path,start_time,duration,cpu_time,reads,writes,logical_reads,granted_query_memory,
				wait_time,last_wait_type,wait_resource,[host_name],host_process_id,[program_name],login_name,ObjectName,isolation_level,
				[statement] = [statement], [text]
		from    @who
		order by blocking_path, start_time, session_id;
	end catch
end
