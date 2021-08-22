USE MSDB
GO
-- Collect the existing information from PRIMARY (msdb.dbo.log_shipping_monitor_primary) to map the parameters 
-- Add the primary to the monitor
EXEC msdb.dbo.sp_processlogshippingmonitorprimary
 @mode = 1
,@primary_id = '8F35C8B0-74K7-49C5-9D73-88F620E8234E'
,@primary_server = N'SQL-LS-PRIMARY01'
,@monitor_server = N'SQL-LS-SECONDARY09' --Intended monitor server
,@monitor_server_security_mode = 1
,@primary_database = N'DBName'
,@backup_threshold = 5
,@threshold_alert = 14420
,@threshold_alert_enabled = 1
,@history_retention_period = 5760
go

-- Collect the existing information from SECONDARY (msdb.dbo.log_shipping_monitor_secondary) to map the parameters 
EXEC msdb.dbo.sp_processlogshippingmonitorsecondary
 @mode = 1
,@secondary_server = N'SQL-LS-SECONDARY01'
,@secondary_database = N'DBName'
,@secondary_id = '120B1AC3-2B4E-4D39-B669-BEAFEBEED67C'
,@primary_server = N'SQL-LS-PRIMARY01'
,@primary_database = N'DBName'
,@restore_threshold = 5
,@threshold_alert = 14421
,@threshold_alert_enabled = 1
,@history_retention_period = 5760
,@monitor_server = N'SQL-LS-SECONDARY09' --Intended monitor server
,@monitor_server_security_mode = 1
go

---------------------------------------------------------------------------------------------------------------------
-- Run following at Primary to replice new monitor server once added by above query
---------------------------------------------------------------------------------------------------------------------

UPDATE msdb.dbo.log_shipping_primary_databases
 SET monitor_server = 'SQL-LS-SECONDARY09'
, user_specified_monitor = 1
 WHERE primary_id = '8F35C8B0-74K7-49C5-9D73-88F620E8234E'
 
 ---------------------------------------------------------------------------------------------------------------------
-- Run following at Secondary to replice new monitor server once added by above query
---------------------------------------------------------------------------------------------------------------------

UPDATE msdb.dbo.log_shipping_secondary
 SET monitor_server = 'SQL-LS-SECONDARY09'
 , user_specified_monitor = 1
 WHERE secondary_id = '120B1AC3-2B4E-4D39-B669-BEAFEBEED67C' 