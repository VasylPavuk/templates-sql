-- Event sessions & files
select  [session].[name] as sessionName, [target].name as targetName, pack.[name] as packageName, [session].max_dispatch_latency, [session].max_memory, [session].startup_state, xs.total_buffer_size, xs.dropped_buffer_count, xs.create_time
from    sys.server_event_session_targets [target]
        inner join sys.server_event_sessions [session] on [target].event_session_id = [session].event_session_id
        inner join sys.dm_xe_objects obj on [target].name = obj.[name]
        inner join sys.dm_xe_packages pack on [target].module = pack.module_guid and pack.guid = obj.package_guid
        left join sys.dm_xe_sessions xs on [session].[name] = xs.[name]
order by sessionName;
go
-- Event files & options (for active session)
select  [session].[name] as sessionName, [target].name as targetName, pack.[name] as packageName,
        [session].max_dispatch_latency, [session].max_memory, [session].startup_state,
        xs.total_buffer_size, xs.dropped_buffer_count, xs.create_time,
        col.[name], col.[description], fld.[value]
from    sys.server_event_session_targets [target]
        inner join sys.server_event_sessions [session] on [target].event_session_id = [session].event_session_id
        inner join sys.dm_xe_objects obj on [target].name = obj.[name]
        inner join sys.dm_xe_packages pack on [target].module = pack.module_guid and pack.guid = obj.package_guid
        inner join sys.dm_xe_sessions xs on [session].[name] = xs.[name]
        inner join sys.dm_xe_object_columns col on [target].[name] = col.[object_name]
        inner join sys.server_event_session_fields fld on [target].event_session_id = fld.event_session_id and [target].target_id = fld.[object_id] and col.[name] = fld.[name]
order by sessionName;
go
-- Capture deadlocks via system_health event session
select  eventTime = d.n.value('@timestamp', 'datetime'),
        crc = checksum(convert(nvarchar(max), x.deadlockEvent)),
        deadlockGrapth = x.deadlockEvent.query('//event/data/value/deadlock')
        --, x.[file_name], x.file_offset
from
    (
        select  deadlockEvent = convert(xml, event_data), [file_name], file_offset
        from    sys.fn_xe_file_target_read_file('system_health*.xel', default, default, default) xef
        where   xef.[object_name] = 'xml_deadlock_report'
    ) x
    cross apply x.deadlockEvent.nodes('//event') d(n)
order by eventTime
