-- based on https://www.brentozar.com/archive/2015/12/tracking-tempdb-growth-using-extended-events/

/*
CREATE EVENT SESSION [PublicToilet] ON SERVER
ADD EVENT [sqlserver].[database_file_size_change] (
    ACTION ( [sqlserver].[session_id], [sqlserver].[database_id],
    [sqlserver].[client_hostname], [sqlserver].[sql_text] )
    WHERE ( [database_id] = ( 2 )
            AND [session_id] > ( 50 ) ) ),
ADD EVENT [sqlserver].[databases_log_file_used_size_changed] (
    --ACTION ( [sqlserver].[session_id], [sqlserver].[database_id], [sqlserver].[client_hostname], [sqlserver].[sql_text] )
	ACTION ( [sqlserver].[client_app_name],[sqlserver].[database_id],[sqlserver].[plan_handle],[sqlserver].[query_plan_hash],[sqlserver].[session_id],[sqlserver].[tsql_frame])
    WHERE ( [database_id] = ( 2 )
            AND [session_id] > ( 50 ) ) )
ADD TARGET [package0].[asynchronous_file_target] (  SET filename = N'c:\temp\publictoilet.xel' ,
                                                    metadatafile = N'c:\temp\publictoilet.xem' ,
                                                    max_file_size = ( 10 ) ,
                                                    max_rollover_files = 10 )
WITH (  MAX_MEMORY = 4096 KB ,
        EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS ,
        MAX_DISPATCH_LATENCY = 1 SECONDS ,
        MAX_EVENT_SIZE = 0 KB ,
        MEMORY_PARTITION_MODE = NONE ,
        TRACK_CAUSALITY = ON ,
        STARTUP_STATE = ON );
GO
ALTER EVENT SESSION [PublicToilet] ON SERVER STATE = START;
GO
ALTER EVENT SESSION [PublicToilet] ON SERVER STATE = STOP;
GO
DROP EVENT SESSION [PublicToilet] ON SERVER;
GO
*/
SELECT	y.line, y.offsetStart, y.offsetEnd, y.client_app_name, object_name(st.objectid, st.[dbid]) [object_name], db_name(st.[dbid]) [database_name], y.size_change_in_kb, y.[count],
		substring(st.[text], y.offsetStart/2+1, case when y.offsetEnd = -1 then len(st.[text]) else (y.offsetEnd-y.offsetStart)/2+1 end) [statement], st.[text],
		qp.query_plan, y.event_data
FROM
	(
		SELECT	x.event_data,
				convert(varbinary(128), N'0x'+x.event_data.value('(/event/action[@name="plan_handle"]/value)[1]', 'varchar(max)'),1) plan_handle,
				convert(varbinary(128),x.event_data.value('(/event/action[@name="tsql_frame"]/value/frame/@handle)[1]', 'varchar(max)'),1) tsql_frame,
								x.event_data.value('(/event/action[@name="tsql_frame"]/value/frame/@line)[1]', 'int') line,
				x.event_data.value('(/event/action[@name="tsql_frame"]/value/frame/@offsetStart)[1]', 'int') offsetStart,
				x.event_data.value('(/event/action[@name="tsql_frame"]/value/frame/@offsetEnd)[1]', 'int') offsetEnd,
				x.event_data.value('(/event/action[@name="client_app_name"]/value)[1]', 'nvarchar(500)') client_app_name,
				x.event_data.value('(/event/data[@name="size_change_kb"]/value)[1]', 'bigint') size_change_in_kb,
				x.event_data.value('(/event/data[@name="count"]/value)[1]', 'bigint') [count]
		FROM
			(
				SELECT  top 100 convert(xml, event_data) event_data
				FROM    [sys].[fn_xe_file_target_read_file]('c:\temp\publictoilet*.xel', NULL, NULL, NULL) [evts]
			) x
	) y
	cross apply sys.dm_exec_query_plan(y.[plan_handle]) qp
	outer apply sys.dm_exec_sql_text(y.[plan_handle]) as st
order by [count] desc