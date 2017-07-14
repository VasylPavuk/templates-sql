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

delete  l
from    ##Logs l
where   l.LogDate < convert(date, dateadd(dd, -3, getdate()));

select  [Date]=convert(date, l.LogDate), [Hour]=datepart(hour, l.LogDate), Qnt = count(*)
from    ##Logs l
where   l.[Text] like 'AppDomain%is marked for unload due to memory pressure.'
group by convert(date, l.LogDate), datepart(hour, l.LogDate)
order by convert(date, l.LogDate), datepart(hour, l.LogDate)