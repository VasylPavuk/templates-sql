USE master
GO
if exists(select * from [master].sys.server_triggers where name = 'ddl_trig_database_create')
    drop trigger [ddl_trig_database_create] ON ALL SERVER;
go
CREATE TRIGGER [ddl_trig_database_create]
    ON ALL SERVER
    AFTER CREATE_DATABASE
AS
BEGIN
    declare @eventData nvarchar(max) = (select convert(nvarchar(max), EVENTDATA()));

    declare
        @subject	nvarchar(255) = 'Database created at server [' + @@servername + ']',
        @recipients varchar(128)  = 'Pavuk.Vasya@gmail.com';

        exec msdb.dbo.sp_send_dbmail @recipients = @recipients,	@subject=@subject, @body = @eventData;
END
GO