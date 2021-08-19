 /*---------------------------------------------------------------------------------------------------------
		Creating XE Events to Audit All UPDATE actions in selected database, 
	before creatign XE event, change the databas name at [sqlserver].[database_name]
 ---------------------------------------------------------------------------------------------------------*/

CREATE EVENT SESSION [audit_updates] ON SERVER 
--ADD EVENT sqlserver.rpc_completed(
--    ACTION(sqlserver.client_app_name,sqlserver.database_id,sqlserver.database_name,sqlserver.sql_text,sqlserver.username)
--    WHERE ([sqlserver].[database_name]=N'DBA' 
--			AND [sqlserver].[like_i_sql_unicode_string]([sqlserver].[sql_text],N'%UPDATE %'))),
ADD EVENT sqlserver.sql_batch_completed(
    ACTION(sqlserver.client_app_name,sqlserver.database_id,sqlserver.database_name,sqlserver.sql_text,sqlserver.username)
    WHERE ([sqlserver].[database_name]=N'DBA' 
			AND [sqlserver].[like_i_sql_unicode_string]([sqlserver].[sql_text],N'%UPDATE %')))
ADD TARGET package0.event_file(SET filename=N'audit_updates',max_file_size=(10),max_rollover_files=(5))
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=OFF,STARTUP_STATE=OFF)
GO

 ALTER EVENT SESSION [audit_updates] on SERVER 
 STATE = START 
 go

 

 ---------------------------------------------------------------------------------------------------------
 --	To Read XE Events Audit Data (where clause applied to read last 7 days audit events)
 ---------------------------------------------------------------------------------------------------------
IF (OBJECT_ID ('tempdb..#temp') ) is not null 
	BEGIN 
		Drop table #temp;
	END

 select CONVERT(xml, event_data) event_data 
 into #temp
 from sys.fn_xe_file_target_read_file(N'audit_updates*.xel', NULL, NULL, NULL);


SELECT 
  timestamp		= event_data.value(N'(event/@timestamp)[1]', N'datetime'),
  sql_text		= event_data.value(N'(event/action[@name="sql_text"]/value)[1]', N'nvarchar(max)'),
  spid			= event_data.value(N'(event/action[@name="session_id"]/value)[1]', N'int'),
  logical_reads	= event_data.value(N'(event/data[@name="logical_reads"]/value)[1]', N'int'),
  username		= event_data.value(N'(event/action[@name="username"]/value)[1]', N'nvarchar(500)'),
  client_appname = event_data.value(N'(event/action[@name="client_app_name"]/value)[1]', N'nvarchar(500)')
FROM #temp
where event_data.value(N'(event/@timestamp)[1]', N'datetime') >= GETDATE() -7
go