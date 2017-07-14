-- Capture deadlocks via system_health event session
select  eventTime = d.n.value('@timestamp', 'datetime'),
        crc = checksum(convert(nvarchar(max), x.deadlockEvent)),
        deadlockGrapth = x.deadlockEvent.query('//event/data/value/deadlock')
        --, x.[file_name], x.file_offset
from
    (
        select  deadlockEvent = convert(xml, event_data), [file_name], file_offset
        from    sys.fn_xe_file_target_read_file ('system_health*.xel', default, default, default) xef
        where   xef.[object_name] = 'xml_deadlock_report'
    ) x
    cross apply x.deadlockEvent.nodes('//event') d(n)
order by eventTime
/*
    select  *
    from    administration.Performance.Deadlocks
*/
