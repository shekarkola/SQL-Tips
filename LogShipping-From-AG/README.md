# LogShipping from Availability Groups

Following are the steps to configure Log Shipping (LS) from AlwaysOn Availability Group (AG) to Stand-alone instance, by following approach when AG failover to secondary replica in a group there is no interruption to the Log Shipping as all secondary’s in LS communicate with primary on AG Listener, the configuration doesn't inlcude Monitor Server, However that can be done later using separate script file.

### Pre-Requisites 
1. Set Database Recovery Model to FULL (if not already) `ALTER DATABASE [DBNema] SET RECOVERY FULL;`
2. Take FULL and LOG Backups from Primary SQL-Instance of LS 
3. Restore WITH NORECOVERY or STANDBY option at Secondary SQL-Instance of LS
4. Stop LOG Backup Jobs at Primary Replica (If there is any exists)


### Log Shipping Configuration 
  1. Use the `LSPrimary-Configure-Without-Monitor.sql` to execute on Primary Instance of LS, following varilable values must be changed, and it shold be executed in all AG Replicas
   ```sql
SELECT @PrimaryServer      = 'SQL-LS-PRIMARY01'
SELECT @SecondaryServer    = 'SQL-LS-SECONDARY01'; -- Change it as needed 
SELECT @DBName             = 'DBName';  
SELECT @BackupDirectory    = '\\SharedHost\SharedFolder\' + @DBName; ----  This is the Backup shared location 
SELECT @BackupJobName      = 'LS_Backup_'+@DBName; 
SELECT @BackupScheduleName = 'LS_Backup_Sch_Databases'; -- This is centralized schedule for group of databases
```
  2. Verify LS Backup Jobs and Schedule in **Primary** Replicas of AG
  3. Use the `LSSecondary-Configure-Without-Monitor.sql` to execute on **Secondary** Instance of LS, following varilable values must be changed before executing script
 ```sql
SELECT	@SecondaryServer      = 'SQL-LS-SECONDARY01';
SELECT	@PrimaryServer        = 'SQL-LS-PRIMARY01'  --- Include AG Lestener name, if there is any custom port it must be specified with comma (,) after the hostname
SELECT	@DBName               = 'DBName'; 
SELECT	@BackupDirectory      = '\\SharedHost\SharedFolder\' + @DBName;
SELECT	@BackupCopyDirectory  = 'C:\LogShipping\' + @DBName; 	-- Where the Log Shipping should copy the Backups from main-backup location
SELECT	@CopyJobName          = 'LS_Copy_'+@DBName;
SELECT	@CopyScheduleName     = 'CopyJobSchedule_'+@DBName;
SELECT	@RestoreJobName       = 'LS_Restore_'+@DBName;
SELECT	@RestoreScheduleName  = 'RestoreJobSchedule' + @DBName;
```
  4. Verify LS Backup Jobs and Schedule in **Secondary** SQL-Instance of LS
  5. Run SQL Jobs in following order 
        
        LS-Backup Job     at **Primary** (In which replica of AG the backups preferred)
        
        LS-Copy Job       at **Secondary** SQL-Instance of LS
        
        LS-Restore Job    at **Secondary** SQL-Instance of LS
        
        
