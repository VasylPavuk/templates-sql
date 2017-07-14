-- query for database sizes
select  ServerName = @@servername, DatabaseName = d.name, DatabaseFileName = mf.name, mf.physical_name, FileType = mf.type_desc,
        Size = convert(bigint, vfs.size_on_disk_bytes)-- size in GigaBytes
from    sys.dm_io_virtual_file_stats(default, default) vfs
        inner join master.sys.databases d on vfs.database_id = d.database_id
        inner join sys.master_files mf on vfs.database_id = mf.database_id and vfs.file_id = mf.file_id
where
        d.name not in ('tempdb', 'model')
order by ServerName, DatabaseName, DatabaseFileName;
go
select  DatabasesCount  = count(distinct d.name),
        [DataSize(GB)]  = round(sum(case when mf.type_desc = 'ROWS' then vfs.size_on_disk_bytes else 0 end)/1024/1024/1024.0,1),
        [LogSize(GB)]   = round(sum(case when mf.type_desc = 'LOG' then vfs.size_on_disk_bytes else 0 end)/1024/1024/1024.0,1)
from    sys.dm_io_virtual_file_stats(default, default) vfs
        inner join master.sys.databases d on vfs.database_id = d.database_id
        inner join sys.master_files mf on vfs.database_id = mf.database_id and vfs.file_id = mf.file_id
where
        d.name not in ('tempdb', 'model')
go
select  d.Name, df.physical_name, dfs.size_on_disk_bytes, lf.physical_name, lfs.size_on_disk_bytes, TotalSizeBytes=dfs.size_on_disk_bytes+lfs.size_on_disk_bytes
from    sys.databases d
        inner join sys.master_files df on d.database_id=df.database_id and df.type=0
        inner join sys.master_files lf on d.database_id=lf.database_id and lf.type=1
        inner join sys.dm_io_virtual_file_stats(default, default) dfs on df.database_id = dfs.database_id and df.file_id = dfs.file_id
        inner join sys.dm_io_virtual_file_stats(default, default) lfs on lf.database_id = lfs.database_id and lf.file_id = lfs.file_id
order by dfs.size_on_disk_bytes+lfs.size_on_disk_bytes desc;