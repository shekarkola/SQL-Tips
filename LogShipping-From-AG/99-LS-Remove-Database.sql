--Run following on primary ----------------------------------------------------------------------------------------------
exec master.dbo.sp_delete_log_shipping_primary_secondary
@primary_database = 'DBName',
@secondary_database = 'DBName',
@secondary_server = 'LS-SQL-SECONDARY01'
GO

--Run following on secondary ----------------------------------------------------------------------------------------------
exec master.dbo.sp_delete_log_shipping_secondary_database @secondary_database = 'DBName'
go