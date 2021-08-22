--------------------------------------------------------------------------------------------------------------------------------------
-- Author: SHEKAR KOLA
-- Created On: 2019-09-30
-- Modified On: 2019-11-04

-- Execute the following statements at DR Site SQL Server 
-- Same database must be restored at selected secondary server with "NORECOVERY" or "STANDBY" option 
-- Make sure @BackupCopyDirectory directory exists 
-- Change database context to user database that need to be a Primary of Log Shipping, or change the parameter @DBName manully
-- Verify COPY SCHEDULE and RESTORE SCHEDULE 
--------------------------------------------------------------------------------------------------------------------------------------


--Following can be changed to assign custom values into variable ------------------------------------------------------------------------------------------------------------

Declare @SecondaryServer varchar(128);
Declare @PrimaryServer varchar(128);
Declare @DBName nvarchar(128);
Declare @BackupDirectory nvarchar(300);
Declare @BackupCopyDirectory nvarchar(300);
Declare @CopyJobName nvarchar (128);
Declare @CopyScheduleName nvarchar (128);
Declare @RestoreJobName nvarchar (128);
Declare @RestoreScheduleName nvarchar (128);

-- Log Shipping Config Options **********************************************************************************************************
SELECT	@SecondaryServer      = 'SQL-LS-SECONDARY01';
SELECT	@PrimaryServer        = 'SQL-LS-PRIMARY01'  --- Include AG Lestener name, if there is any custom port it must be specified with comma (,) after the hostname
SELECT	@DBName               = 'DBName'; 
SELECT	@BackupDirectory      = '\\SharedHost\SharedFolder\' + @DBName;
SELECT	@BackupCopyDirectory  = 'C:\LogShipping\' + @DBName; 	-- Where the Log Shipping should copy the Backups from main-backup location
SELECT	@CopyJobName          = 'LS_Copy_'+@DBName;
SELECT	@CopyScheduleName     = 'CopyJobSchedule_'+@DBName;
SELECT	@RestoreJobName       = 'LS_Restore_'+@DBName;
SELECT	@RestoreScheduleName  = 'RestoreJobSchedule' + @DBName;
-- Log Shipping Config Options end **********************************************************************************************************

IF EXISTS (select 1 from msdb.dbo.log_shipping_secondary_databases where secondary_database = @DBName)
	BEGIN
		Print 'The Database ['+ @DBName + '] Already exists in LS Configuration!'
	END
ELSE
BEGIN
	DECLARE @LS_Secondary__CopyJobId	AS uniqueidentifier 
	DECLARE @LS_Secondary__RestoreJobId	AS uniqueidentifier 
	DECLARE @LS_Secondary__SecondaryId	AS uniqueidentifier 
	DECLARE @LS_Add_RetCode	As int 

	BEGIN
		EXEC @LS_Add_RetCode = master.dbo.sp_add_log_shipping_secondary_primary 
		 @primary_server = @PrimaryServer
		,@primary_database = @DBName 
		,@backup_source_directory = @BackupDirectory
		,@backup_destination_directory = @BackupCopyDirectory
		,@copy_job_name = @CopyJobName
		,@restore_job_name = @RestoreJobName
		,@file_retention_period = 4320 
		,@overwrite = 1 
		,@copy_job_id = @LS_Secondary__CopyJobId OUTPUT 
		,@restore_job_id = @LS_Secondary__RestoreJobId OUTPUT 
		,@secondary_id = @LS_Secondary__SecondaryId OUTPUT 

		IF (@@ERROR = 0 AND @LS_Add_RetCode = 0) 

		DECLARE @LS_SecondaryCopyJobScheduleUID	As uniqueidentifier 
		DECLARE @LS_SecondaryCopyJobScheduleID	AS int 


		--Copy Schedule---------------------------------------------------------------------------------------------------

		IF exists (Select 1 from msdb.dbo.sysschedules where name = @CopyScheduleName)
			BEGIN
				SET @LS_SecondaryCopyJobScheduleID = (Select schedule_id from msdb.dbo.sysschedules where name = @CopyScheduleName);
				
				EXEC msdb.dbo.sp_attach_schedule 
					 @job_id = @LS_Secondary__CopyJobId 
					,@schedule_id = @LS_SecondaryCopyJobScheduleID  
			END
		IF not exists (Select 1 from msdb.dbo.sysschedules where name = @CopyScheduleName)
			BEGIN
			EXEC msdb.dbo.sp_add_schedule 
				 @schedule_name = @CopyScheduleName
				,@enabled = 1 
				,@freq_type = 4 
				,@freq_interval = 1 
				,@freq_subday_type = 4 -- 1 = Occures Once, 4 = Occures by Minute, 8 = Occures by Hour
				,@freq_subday_interval = 33 
				,@freq_recurrence_factor = 0 
				,@active_start_date = 20190929 
				,@active_end_date = 99991231 
				,@active_start_time = 000500 
				,@active_end_time = 235900 
				,@schedule_uid = @LS_SecondaryCopyJobScheduleUID OUTPUT 
				,@schedule_id = @LS_SecondaryCopyJobScheduleID OUTPUT;

				EXEC msdb.dbo.sp_attach_schedule 
					 @job_id = @LS_Secondary__CopyJobId 
					,@schedule_id = @LS_SecondaryCopyJobScheduleID  
			END


		--Copy Schedule end ---------------------------------------------------------------------------------------------------


		--Restore Schedule-----------------------------------------------------------------------------------------------------

		DECLARE @LS_SecondaryRestoreJobScheduleUID	As uniqueidentifier 
		DECLARE @LS_SecondaryRestoreJobScheduleID	AS int 

		IF exists (Select 1 from msdb.dbo.sysschedules where name = @RestoreScheduleName)
			BEGIN
				SET @LS_SecondaryCopyJobScheduleID = (Select top 1 schedule_id from msdb.dbo.sysschedules where name = @RestoreScheduleName order by schedule_id desc);
					
				EXEC msdb.dbo.sp_attach_schedule 
					 @job_id = @LS_Secondary__RestoreJobId 
					,@schedule_id = @LS_SecondaryRestoreJobScheduleID  
			END

		IF not exists (Select 1 from msdb.dbo.sysschedules where name = @RestoreScheduleName)
			BEGIN

			EXEC msdb.dbo.sp_add_schedule 
					 @schedule_name = @RestoreScheduleName
					,@enabled = 1 
					,@freq_type = 4    -- 1=Once, 4=Daily, 8=Weekly, 16=Monthly, 32=Monthly(relative freq_interal), 64=SQLAgent stats
					,@freq_interval = 1 
					,@freq_subday_type = 8 -- 1 = Occures Once, 4 = Occures by Minute, 8 = Occures by Hour
					,@freq_subday_interval = 2 
					,@freq_recurrence_factor = 0 
					,@active_start_date = 20191001
					,@active_end_date = 99991231 
					,@active_start_time = 0 
					,@active_end_time = 235900 
					,@schedule_uid = @LS_SecondaryRestoreJobScheduleUID OUTPUT 
					,@schedule_id = @LS_SecondaryRestoreJobScheduleID OUTPUT;

					EXEC msdb.dbo.sp_attach_schedule 
					 @job_id = @LS_Secondary__RestoreJobId 
					,@schedule_id = @LS_SecondaryRestoreJobScheduleID 
			END


		--Restore Schedule End ---------------------------------------------------------------------------------------------------

		DECLARE @LS_Add_RetCode2	As int 

		IF (@@ERROR = 0 AND @LS_Add_RetCode = 0) 
		BEGIN 

			EXEC @LS_Add_RetCode2 = master.dbo.sp_add_log_shipping_secondary_database 
				 @secondary_database = @DBName
				,@primary_server = @PrimaryServer
				,@primary_database = @DBName
				,@restore_delay = 10 
				,@restore_mode = 0   --- 0 = NORECOVERY, 1 = STANDBY
				,@disconnect_users	= 1 
				,@restore_threshold = 120   
				,@threshold_alert_enabled = 1 
				,@history_retention_period	= 10080 
				,@overwrite = 1 
		END 


		IF (@@error = 0 AND @LS_Add_RetCode = 0) 
		BEGIN 

		EXEC msdb.dbo.sp_update_job 
				 @job_id = @LS_Secondary__CopyJobId 
				,@enabled = 1 

		EXEC msdb.dbo.sp_update_job 
				@job_id = @LS_Secondary__RestoreJobId 
				,@enabled = 0 
		END

	END
END 
go




