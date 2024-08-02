use master;
go
if Object_ID('sp_who4', 'p') is not null drop procedure sp_who4;
go
CREATE procedure sp_who4
    -- Pavuk.V 2021-08-25
(
    @session_id int = null
)
 as
begin
    set nocount on;
    select  s.session_id, [status] = coalesce(r.[status], s.[status]), r.command, [database_name] = d.[name], r.blocking_session_id, blocking_path = convert(varchar(1024), ''), r.start_time,
	    duration = convert(time, getdate()-r.start_time, 114),
            r.cpu_time, r.reads, r.writes, r.logical_reads, r.granted_query_memory, r.wait_time, r.last_wait_type, r.wait_resource,
            s.[host_name], s.host_process_id, s.[program_name], s.login_name, --ObjectName=object_name(t.objectid, t.[dbid]),
            s.transaction_isolation_level,
            r.statement_start_offset, r.statement_end_offset,
            r.[sql_handle],
            objectName = convert(sysname, null),
            [statement] = convert(nvarchar(max), null)
    into    #who
    from    sys.dm_exec_sessions s
            left join sys.dm_exec_requests r on r.session_id = s.session_id
            left join sys.databases d on r.database_id = d.database_id
            -- outer apply sys.dm_exec_sql_text(r.[sql_handle]) t
    where   s.session_id != @@spid and s.[status] not in('sleeping', 'dormant') and s.session_id = coalesce(@session_id, s.session_id);

    alter table #who add constraint PK__#who primary key clustered (session_id);

    declare @start int, @end int;
    update  w
    set     @start =
                case
                    when w.statement_start_offset is null then 1
                    when w.statement_start_offset = -1 then 1
                    else w.statement_start_offset / 2 + 1
                end,
            @end =
                case
                    when w.statement_end_offset is null then len([t].[text])
                    when w.statement_end_offset = -1 then len([t].[text])
                    else w.statement_end_offset/2 - @start + 2
                end,
            [statement] = substring(t.[text], @start, @end),
            objectName = object_name([t].[objectid], [t].[dbid])
    from    #who w
            outer apply sys.dm_exec_sql_text(w.[sql_handle]) t;

    if exists(select * from #who where blocking_session_id > 0)
        begin
            insert  into #who
            select  s.session_id, [status] = s.[status], command = null, [database_name] = null, blocking_session_id= 0, blocking_path = convert(varchar(1024), ''), start_time = s.last_request_start_time, duration = convert(time, getdate()-s.last_request_
start_time, 114),
                    cpu_time = null, reads = null, writes = null, logical_reads = null, granted_query_memory = null, wait_time = null, last_wait_type = null, wait_resource = null,
                    s.[host_name], s.host_process_id, s.[program_name], s.login_name, --ObjectName=object_name(t.objectid, t.[dbid]),
                    s.transaction_isolation_level,
                    statement_start_offset = null, statement_end_offset = null,
                    [sql_handle] = null,
                    objectName = convert(sysname, null),
                    [statement] = convert(nvarchar(max), ib.event_info)
            from    sys.dm_exec_sessions s
                    outer apply sys.dm_exec_input_buffer (s.session_id, null) ib
            where   exists ( select  1 from #who w where w.blocking_session_id = [s].session_id )
                    and not exists ( select 1 from #who w where w.session_id = [s].session_id);
        
            declare @blk table(session_id int, block_path varchar(1024));
            begin try
                with BlockQueue ([session_id], [block_path]) as
                (				--	base part
	                select	s.[session_id], [block_path] = convert(varchar(max), s.[session_id])
	                from	#who s with (nolock)
	                where
			                exists (select * from #who c with (nolock) where c.[blocking_session_id] = s.[session_id] )and
			                not exists(select * from #who c with (nolock) where c.[session_id] = s.[session_id] and c.[blocking_session_id] != 0)
			
	                union all	--	recursive part
	
	                select	r.[session_id], [Path] = q.[block_path] + '\' + convert(varchar(max),r.[session_id])
	                from	#who r with (nolock)
			                inner join BlockQueue q on r.[blocking_session_id] = q.[session_id]	--	сесія, якою блокується запит r
                )
                insert into @blk(session_id, block_path)
                select  session_id, block_path
                from    BlockQueue;
            end try
            begin catch
                -- recursion is over 100; let's emphasize blocking-root nodes only
                insert into @blk(session_id, block_path)
	            select	s.[session_id], [block_path] = '!'
	            from	#who s with (nolock)
	            where
			            exists (select * from #who c with (nolock) where c.[blocking_session_id] = s.[session_id] )and
			            not exists(select * from #who c with (nolock) where c.[session_id] = s.[session_id] and c.[blocking_session_id] != 0)
            end catch

            update  w
            set     blocking_path = bq.block_path
            from    #who w
                    inner join @blk bq on w.session_id = bq.session_id;
        end
        else
        begin
            alter table #who drop column blocking_path;
            alter table #who drop column blocking_session_id;
        end

    alter table #who drop column [sql_handle];
    alter table #who drop column [statement_start_offset];
    alter table #who drop column [statement_end_offset];
    alter table #who alter column transaction_isolation_level varchar(32);
    update  w
    set     transaction_isolation_level =
		        case transaction_isolation_level
                    when 0 then 'unspecified'
                    when 1 then 'read uncommitted'
                    when 2 then 'read committed'
                    when 3 then 'repeatable'
                    when 4 then 'serializable'
                    when 5 then 'snapshot'
                end
    from    #who w;

    select  w.*
    from    #who w;

    set lock_timeout 5;
    begin try
        select  w.session_id, qsx.query_plan--, qp.node_id, qp.row_count, qp.estimate_row_count, qp.physical_operator_name
        from    #who w
                cross apply sys.dm_exec_query_statistics_xml(w.session_id) qsx
                --inner join sys.dm_exec_query_profiles qp on w.session_id = qp.session_id
        order by w.session_id asc--, qp.node_id asc;
    end try
    begin catch
        select 'Lock timeout to get the additional information' as [Message]
    end catch
    set lock_timeout -1;

    drop table if exists #who;
end
