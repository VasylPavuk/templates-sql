--------------------------------------------- init session ---------------------------------------------
/*
create event session BlockingTransactions on server
add event sqlserver.locks_lock_timeouts(action (sqlserver.sql_text, sqlserver.tsql_stack)),
add event sqlserver.locks_lock_waits(action(sqlserver.sql_text, sqlserver.tsql_stack))
add target package0.ring_buffer with(max_dispatch_latency = 30 seconds);
go
alter event session BlockingTransactions on server state = start;
go
*/
--------------------------------------------- report ---------------------------------------------
with BlockingTransactions as
(
    select  SessionXML = convert(xml, target_data)
    from    sys.dm_xe_session_targets st
            inner join sys.dm_xe_sessions s on s.address = st.event_session_address
    where   name = 'BlockingTransactions'
)
select  event_timestamp = block.value('@timestamp', 'datetime'),
        event_name      = block.value('@name', 'nvarchar(128)'),
        event_count     = block.value('(data/value)[1]', 'nvarchar(128)'),
        increment       = block.value('(data/value)[1]', 'nvarchar(128)'),
        lock_type = mv.map_value,
        sql_text = block.value('(action/value)[1]', 'nvarchar(max)'),
        tsql_stack = block.value('(action/value)[2]', 'nvarchar(255)')
from    BlockingTransactions b
        cross apply SessionXML.nodes('//RingBufferTarget/event') t (block)
        inner join sys.dm_xe_map_values mv on block.value('(data/value)[3]', 'nvarchar(128)') = mv.map_key and name = 'lock_mode'
where   block.value('@name', 'nvarchar(128)') = 'locks_lock_waits'
union all
select  event_timestamp = block.value('@timestamp', 'datetime'),
        event_name      = block.value('@name', 'nvarchar(128)'),
        event_count     = block.value('(data/value)[1]', 'nvarchar(128)'),
        null,
        lock_type = mv.map_value,
        sql_text = block.value('(action/value)[1]', 'nvarchar(max)'),
        tsql_stack = block.value('(action/value)[2]', 'nvarchar(255)')
from    BlockingTransactions b
        cross apply SessionXML.nodes('//RingBufferTarget/event') t (block)
        inner join sys.dm_xe_map_values mv on block.value('(data/value)[3]', 'nvarchar(128)') = mv.map_key and name = 'lock_mode'
where   block.value('@name', 'nvarchar(128)') = 'locks_lock_timeouts'
