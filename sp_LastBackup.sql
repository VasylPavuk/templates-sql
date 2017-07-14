use [master]
go
if object_id('sp_LastBackup', 'p') is not null drop procedure sp_LastBackup;
go
create procedure sp_LastBackup
(
    @DatabaseName sysname = null,
    @DaysPastLimit  int     = null
)
as
begin
    set dateformat dmy;
    select  [DatabaseName]      = t1.[Name],
            [DatabaseState]     = t1.state_desc,
            [RecoveryModel]     = t1.recovery_model_desc,
            t1.create_date,
            [LastBackUpTaken]   = coalesce(convert(varchar(128), T2.backup_finish_date, 120),'Not Yet Taken'),
            [CurrentTime]       = getdate(),
            [TimePast]          = isnull(convert(varchar(12), datediff(dd, T2.backup_finish_date, getdate()))+ ' ' + convert(varchar(12), getdate()-T2.backup_finish_date, 114), 'NA'),
            [UserName]          = coalesce(convert(varchar(128), T2.user_name, 101),'NA'),
            t2.backup_size, t2.compressed_backup_size,
            [Type] =    case t2.[type]
                            when 'D' then 'Full'
                            when 'I' then 'Differential'
                            when 'L' then 'Log'
                            else t2.[type]
                        end,
            bm.physical_device_name
    from    sys.databases t1
            left outer join 
            (
                -- msdb.dbo.backupset
                select  *,
                        Rate = row_number()over(partition by [database_name], [type] order by backup_finish_date desc)
                from    msdb.dbo.backupset
                -- where   [type] = 'D'
            ) t2 ON t2.database_name = t1.name and t2.Rate = 1
            left outer join msdb.dbo.backupmediafamily bm on t2.media_set_id = bm.media_set_id
    where   t1.Name not in ('tempdb', 'model')
            and t1.[State] = 0
            and t1.Name = coalesce(@DatabaseName, t1.Name)
            and ((datediff(dd, T2.backup_finish_date, getdate()) >= @DaysPastLimit or T2.backup_finish_date is null) or @DaysPastLimit is null)
    order by T1.Name, [LastBackUpTaken];
end;
go
