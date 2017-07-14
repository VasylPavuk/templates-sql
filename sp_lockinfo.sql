use [master]
go
if object_id('[dbo].[sp_lockinfo]', 'p') is not null drop procedure dbo.sp_lockinfo;
go
create procedure [dbo].[sp_lockinfo]
as
begin
    set nocount on;
    with BlockQueue ([session_id], [block_path], [lck]) as
    (				--	base part
	    select	s.[session_id], [block_path] = convert(varchar(max), s.[session_id]), lck = '!'
	    from	sys.dm_exec_sessions s with (nolock)
	    where
			    exists (select * from sys.dm_exec_requests c with (nolock) where c.[blocking_session_id] = s.[session_id] )and
			    not exists(select * from sys.dm_exec_requests c with (nolock) where c.[session_id] = s.[session_id] and c.[blocking_session_id] != 0)
			
	    union all	--	recursive part
	
	    select	r.[session_id], [Path] = q.[block_path] + '\' + convert(varchar(max),r.[session_id]), lck = ''
	    from	sys.dm_exec_requests r with (nolock)
			    inner join BlockQueue q on r.[blocking_session_id] = q.[session_id]
    )
    select	q.[session_id], q.[block_path],
            Duration = left(convert(time,getdate()-coalesce(r.start_time, s.last_request_end_time, s.last_request_start_time)), 12),
            DatabaseName = d.[name], s.[host_name], s.host_process_id,
            r.[command],
		    [status]        = coalesce(r.[status], s.[status]),
            [cpu_time]      = coalesce(r.[cpu_time], s.[cpu_time]),
            [reads]         = coalesce(r.[reads], s.[reads]),
            logical_reads   = coalesce(r.logical_reads, s.logical_reads),
            [writes] = coalesce(r.[writes], s.[writes]),
		    isolation_level =
		    case s.transaction_isolation_level
                when 0 then 'unspecified'
                when 1 then 'read uncommitted'
                when 2 then 'read committed'
                when 3 then 'repeatable'
                when 4 then 'serializable'
                when 5 then 'snapshot'
            end,
            r.[wait_resource],
            wait_class = 
            case
                when r.wait_type is null then 'cpu'
                when r.wait_type like 'lck_%' then 'lock'
                when r.wait_type like '%pageiolatch%' then 'i/o'
                when r.wait_type like '%pagelatch%' then 'buffer/tempdb'
                when r.wait_type like '%latch%' then 'memory'
                else r.wait_type
            end,
            r.wait_type,
            s.[program_name],
            [Statement] =
                substring
                (
                    t.[text],
                    coalesce(r.statement_start_offset,0)/2+1,
                    coalesce(r.statement_end_offset, 0)/2+1
                ),
            t.[Text]
    from	BlockQueue q
		    inner join sys.dm_exec_sessions s with (nolock) on q.[session_id] = s.[session_id]
            inner join sys.dm_exec_connections c on q.session_id = c.session_id and c.parent_connection_id is null
		    left join sys.dm_exec_requests r with (nolock) on q.[session_id] = r.[session_id]
		    left join sys.databases d with (nolock) on r.[database_id] = d.[database_id]
            outer apply sys.dm_exec_sql_text(coalesce(r.[sql_handle], c.most_recent_sql_handle)) t
    order by q.[block_path];
end
go
exec [dbo].[sp_lockinfo]