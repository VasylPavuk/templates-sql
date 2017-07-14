use [ww-unicomny]
go
--select  cd.*, d.name
--from    [sys].[change_tracking_databases] cd
--        inner join sys.databases d on cd.database_id = d.database_id
go
declare @sync_last_received_anchor int = 0
select  ct.*, '|', sl.*
from    changetable(changes dbo.STOCK_Lot, @sync_last_received_anchor) ct
        left join STOCK_Lot sl on ct.id_int = sl.id_int;

declare @sync_new_received_anchor int = change_tracking_current_version();
select @sync_new_received_anchor;