Declare @SecondaryServer varchar(128);
Declare @PrimaryServer varchar(128);
Declare @DBName nvarchar(128);
Declare @BackupDirectory nvarchar(300);
Declare @BackupJobName nvarchar (128);
Declare @BackupScheduleName nvarchar (128);

-- Log Shipping Config Options **********************************************************************************************************

SELECT @PrimaryServer      = 'SQL-LS-PRIMARY01'
SELECT @SecondaryServer    = 'SQL-LS-SECONDARY01'; -- Change it as needed 
SELECT @DBName             = 'DBName';  
SELECT @BackupDirectory    = '\\SharedHost\SharedFolder\' + @DBName; ----  This is the Backup shared location 
SELECT @BackupJobName      = 'LS_Backup_'+@DBName; 
SELECT @BackupScheduleName = 'LS_Backup_Sch_Databases'; -- This is centralized schedule for group of databases

-- Log Shipping Config Options end **********************************************************************************************************


IF (@DBName = 'master' or @DBName = 'TempDB' or @DBName = 'model') 
	or exists (select * from msdb.dbo.log_shipping_primary_databases where primary_database = @DBName)

	begin
		Print ('Change the DB Context to User Database that need to be part of LS and make sure the database is not already part of LS')
	end
ELSE

--- Backup JOB and Logshipping -------------------------------------------------------------------------------------------------------------------
BEGIN
	BEGIN
		DECLARE @LS_BackupJobId	AS uniqueidentifier 
		DECLARE @LS_PrimaryId	AS uniqueidentifier 
		DECLARE @SP_Add_RetCode	As int 

		EXEC @SP_Add_RetCode = master.dbo.sp_add_log_shipping_primary_database 
				 @database = @DBName
				,@backup_directory = @BackupDirectory
				,@backup_share = @BackupDirectory
				,@backup_job_name = @BackupJobName
				,@backup_retention_period = 43200  -- 30 Days
				,@backup_compression = 1
				,@backup_threshold = 60		-- LS Monitor Alert fired if no backup happens within 60 minutes
				,@threshold_alert_enabled = 1
				,@history_retention_period = 10080 -- 7 Dyas 
				,@backup_job_id = @LS_BackupJobId OUTPUT 
				,@primary_id = @LS_PrimaryId OUTPUT 
				,@overwrite = 1 
	END

IF (@@ERROR = 0 AND @SP_Add_RetCode = 0) 

--- Backup Schedule ------------------------------------------------------------------------------------------------------------------------

		DECLARE @LS_BackUpScheduleUID	As uniqueidentifier 
		DECLARE @LS_BackUpScheduleID	AS int 
		
		IF exists (Select schedule_id from msdb.dbo.sysschedules where name = @BackupScheduleName)
			BEGIN
				SET @LS_BackUpScheduleID = (Select schedule_id from msdb.dbo.sysschedules where name = @BackupScheduleName);
			END
		IF not exists (Select schedule_id from msdb.dbo.sysschedules where name = @BackupScheduleName)
			BEGIN
			
				EXEC msdb.dbo.sp_add_schedule 
						 @schedule_name = @BackupScheduleName
						,@enabled = 1 
						,@freq_type = 4 -- 4 = Daily,  8=Weekly, 16 = Monthly, 
						,@freq_interval = 1 
						,@freq_subday_type = 4  -- 1 = Occures Once, 4 = Occures by Minute, 8 = Occures by Hour
						,@freq_subday_interval = 20 
						,@freq_recurrence_factor = 0 
						,@active_start_date = 20191001 
						,@active_end_date = 99991231 
						,@active_start_time = 014500 
						,@active_end_time = 235900 
						,@schedule_uid = @LS_BackUpScheduleUID OUTPUT 
						,@schedule_id = @LS_BackUpScheduleID OUTPUT 
			END
--- Backup Schedule End ------------------------------------------------------------------------------------------------------------------------

			EXEC msdb.dbo.sp_attach_schedule 
					@job_id = @LS_BackupJobId 
					,@schedule_id = @LS_BackUpScheduleID  
		
			EXEC msdb.dbo.sp_update_job 
					@job_id = @LS_BackupJobId 
					,@enabled = 1 

			EXEC master.dbo.sp_add_log_shipping_alert_job 

			EXEC master.dbo.sp_add_log_shipping_primary_secondary 
					 @primary_database = @DBName
					,@secondary_server = @SecondaryServer
					,@secondary_database = @DBName
					,@overwrite = 1

--Notify operator upon Backup Job Failure ---------------------------------------------------------------------------------------------------------------------------
	IF EXISTS (select enabled from msdb.dbo.sysoperators where enabled = 1 )
			BEGIN
				Declare @Operator int;
				SET @Operator = (select top 1 ID from msdb.dbo.sysoperators where enabled = 1 order by id);
				
				update msdb.dbo.sysjobs set 
						notify_level_email = 2, 
						notify_email_operator_id = @Operator 
				where job_id = @LS_BackupJobId
			END
	IF NOT EXISTS (select enabled from msdb.dbo.sysoperators where enabled = 1 )
	PRINT 'No Active Operators exists in server, create operator and enable the notification manully!'
END
go

