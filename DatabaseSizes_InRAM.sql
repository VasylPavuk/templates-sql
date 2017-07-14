select  x.database_id, d.Name, x.MemoryUsed_MB, x.FreeSpace
from
    (
        select  bd.database_id,
                MemoryUsed_MB   = round(sum(convert(float, 1))/128.0, 3),
                FreeSpace       = round(sum(convert(float, bd.free_space_in_bytes))/1024/1024, 3)
        from    sys.dm_os_buffer_descriptors bd
        group by bd.database_id
    ) x
    left join sys.databases d on x.database_id = d.database_id
order by MemoryUsed_MB desc;
go
select  bd.page_type, MemoryUsed_MB = round(sum(convert(float, 1))/128.0, 3)
from    sys.dm_os_buffer_descriptors bd
group by bd.page_type
order by 2 desc;