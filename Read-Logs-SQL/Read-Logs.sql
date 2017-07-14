USE [Administration];
GO
IF object_id('dbo.ReadLogs', 'p') IS NOT NULL DROP PROCEDURE dbo.ReadLogs;
GO
CREATE PROCEDURE dbo.ReadLogs
(
	@DiveHistory int = 1
)AS
BEGIN
	-- exec master.dbo.sp_enumerrorlogs
	if object_id('tempdb..##Logs', 'u') is not null drop table ##Logs;
	create table ##Logs
	(
		LogDate     datetime,
		ProcessInfo varchar(128),
		[Text]      varchar(max)
	);

	insert into ##Logs
	exec [master].[dbo].sp_readerrorlog @p1=0, @p2=1, @p3=null, @p4=null;

	-- remove older logs
	delete  l
	from    ##Logs l
	where   l.LogDate < convert(date, dateadd(dd, -@DiveHistory, getdate()));

	/**************************************************
		remove ignored messages
	**************************************************/
	delete  l
	from    ##Logs l
	where   l.[Text] like 'Starting up database%';

	delete  l
	from    ##Logs l
	where   l.[Text] like 'SQL Trace stopped%' or l.[Text] like 'SQL Trace ID % was started by login%';

	delete  l
	from    ##Logs l
	where   l.[Text] like 'Setting database option%';

	delete  l
	from    ##Logs l
	where   l.[Text] like 'BACKUP DATABASE successfully processed%';

	delete  l
	from    ##Logs l
	where   l.[Text] like 'Database backed up.%';

	delete  l
	from    ##Logs l
	where   l.[Text] like 'Log was backed up%';

	delete  l
	from    ##Logs l
	where   l.[Text] like 'This instance of SQL Server has been using a process ID of%';

	-- show the memory pressure related messages
	select  [DateTime]=convert(varchar(8), l.LogDate, 112)+' '+convert(varchar(5),l.LogDate,114), Quantity=count(*), 'AppDomain%is marked for unload due to memory pressure.'
	from    ##Logs l
	where   l.[Text] like 'AppDomain%is marked for unload due to memory pressure.'
	group by convert(varchar(5),l.LogDate,114), convert(varchar(8), l.LogDate, 112)
	order by convert(varchar(8), l.LogDate, 112), convert(varchar(5),l.LogDate,114);

	delete  l
	from    ##Logs l
	where   l.[Text] like 'AppDomain%is marked for unload due to memory pressure.';
	-- show other messages
	select  *
	from    ##Logs
	order by LogDate;
END
GO
exec [Administration].[dbo].[ReadLogs] @DiveHistory = 14