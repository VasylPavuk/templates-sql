-- objects overview
select	ov.[object_id], ov.[Type_Desc], ov.[Name], ov.Parent, ov.create_date, ov.modify_date, ov.[Rows], ov.ReservedPages, ov.UsedPages, RezervedSize = ov.ReservedPages/128, [Definition] = convert(xml, '<?query '+ov.[Definition]+'?>')
from
	(
		select	o.[object_id], o.[Type_Desc], [Name] = concat(SCHEMA_NAME(o.schema_id), '.', o.[Name]), Parent = po.Name, o.create_date, o.modify_date, x.[Rows], x.ReservedPages, x.UsedPages, d.[Definition]
		from	sys.objects o with (nolock)
				left join sys.objects po with (nolock) on o.parent_object_id = po.[object_id]
				left join sys.sql_modules d with (nolock) on o.[object_id] = d.[object_id]
				left join
                (
                    select  ps.[object_id],
                            [Rows]          = sum(case when ps.index_id < 2 then ps.row_count else 0 end),
                            ReservedPages   = sum(ps.reserved_page_count),
		                    UsedPages       = sum(ps.used_page_count)
                    from    sys.dm_db_partition_stats ps
                    group by ps.[object_id]
                ) x on o.[object_id] = x.[object_id]
	) ov
where   1 = 1
        --and ov.Definition like '%[[]Comment%'
        and ov.[Rows] > 0
order by ReservedPages desc, ov.[Rows] desc, ov.[Type_Desc], ov.[Name];
GO
-- objects & indexes sizes
set nocount on;
select  schemaName = sc.[name], tableName = t.[name], i.index_id, IndexName = i.[name], i.[type_desc],  ps.[Rows], ps.ReservedSizeMb, ps.UsedSizeMb, FreeSize = ps.ReservedSizeMb - ps.UsedSizeMb,
		ps.in_row_data_page_count, ps.in_row_used_page_count, ps.in_row_reserved_page_count,
		ps.lob_used_page_count,ps.lob_reserved_page_count,
		ps.row_overflow_used_page_count, ps.row_overflow_reserved_page_count
from    sys.indexes i
        inner join sys.objects t on i.object_id = t.object_id
        inner join sys.schemas sc on t.schema_id = sc.schema_id
        inner join
        (
            select  ps.object_id, ps.index_id,
                    [Rows] = sum(ps.row_count),
                    ReservedSizeMb = sum(ps.reserved_page_count)/128.0,
                    UsedSizeMb    = sum(ps.used_page_count) / 128.0,
					sum(in_row_data_page_count) in_row_data_page_count,
					sum(in_row_used_page_count) in_row_used_page_count,
					sum(in_row_reserved_page_count) in_row_reserved_page_count,
					sum(lob_used_page_count) lob_used_page_count,
					sum(lob_reserved_page_count) lob_reserved_page_count,
					sum(row_overflow_used_page_count) row_overflow_used_page_count,
					sum(row_overflow_reserved_page_count) row_overflow_reserved_page_count
            from    sys.dm_db_partition_stats ps
            group by ps.object_id, ps.index_id
        ) ps on i.object_id = ps.object_id and i.index_id = ps.index_id
where	sc.[name] not in ('sys')
order by ps.ReservedSizeMb desc, sc.[name], t.[name], i.index_id;
