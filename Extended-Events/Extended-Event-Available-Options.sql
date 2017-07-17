--Find the event name allows to look at wait statistics
SELECT  xo.*, '|', xp.*
FROM    sys.dm_xe_objects xo
        INNER JOIN sys.dm_xe_packages xp  ON xp.[guid] = xo.[package_guid]
--WHERE xo.[object_type] = 'event' AND xo.name LIKE '%wait%'
ORDER BY xo.[object_type], xp.[name];
GO
--Find the columns that are  available to track for the wait_info event
SELECT  *
FROM    sys.dm_xe_object_columns
WHERE   [object_name] = 'wait_info';
GO
--Find the additional columns that can be tracked
SELECT  xo.*, '|', xp.*
FROM    sys.dm_xe_objects xo
        INNER JOIN sys.dm_xe_packages xp ON xp.[guid] = xo.[package_guid]
WHERE   xo.[object_type] = 'action'
ORDER BY xp.[name];
GO