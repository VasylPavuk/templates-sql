set nocount on;
select  c.session_id, c.connect_time, connect_duration = replace(convert(varchar(24), getdate()-c.connect_time, 121), '1900-01-', ''), c.net_transport, c.auth_scheme,
        c.client_net_address, c.client_tcp_port,
        s.host_name, s.program_name, s.host_process_id, s.client_interface_name, s.login_name, s.status,
        s.cpu_time, s.memory_usage, s.reads, s.writes, s.logical_reads,
        s.total_elapsed_time, s.[language],
        transaction_isolation_level =
            case s.transaction_isolation_level
                when 0 then 'unspecified'
                when 1 then 'read uncomitted'
                when 2 then 'read committed'
                when 3 then 'repeatable'
                when 4 then 'serializable'
                when 5 then 'snapshot'
            end
from    sys.dm_exec_connections c
        inner join sys.dm_exec_sessions s on c.session_id = s.session_id
where
        c.parent_connection_id is null
order by s.host_name, c.session_id;