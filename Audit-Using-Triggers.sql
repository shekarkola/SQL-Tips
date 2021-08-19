IF(OBJECT_ID ('audit_log')) IS NULL
BEGIN ---- Central Audit Storage 
	create table audit_log 
	(recid int identity (1,1),
	 ref_table varchar (200),
	 ref_column varchar (200),
	 ref_value varchar (200),
	 created_on datetime2(2) default GETDATE()
	);

	create nonclustered index nci_audit_table on audit_log (ref_table, ref_column, created_on);
END 
go

/*--------------------------------------------------------------------------------------------------------------------------------
 Author:		Shekar Kola
 Create date: 2021-08-19
 Description: Storing audit information into central repository, 
				following approach might not be optimal for the tables that are heavily involved in UPDATE Transactions  

Notes:	Before executing trigger creation, consider following 
			1. Change the trigger name as needed 
			2. Each INSERT statement in trigger body carries a column name from source table, change the values accordingly 
			3. When new column added in table, trigger must be altered to include the new column 
			4. Trigger need to be crated on required table separately, by mentioning requried columns from the table in trigger body 

		TRY_CONVERT used since all audit information stores in single destination table (audit_log), which stores all data types in single column as NVARCHAR, 
		when converstion not possible NULL values will be loaded without failing the trigger. 
------------------------------------------------------------------------------------------------------------------------------------*/ 
CREATE or ALTER TRIGGER tr_audit_updates_TableName
   ON  TableName
   AFTER UPDATE
AS 
BEGIN

	SET NOCOUNT ON;

	insert into audit_log (ref_table, ref_column, ref_value) select 'TableName', 'name', TRY_CONVERT(nvarchar(4000), i.name) from inserted as i;
	insert into audit_log (ref_table, ref_column, ref_value) select 'TableName', 'email', TRY_CONVERT(nvarchar(4000), i.email) from inserted as i;
	insert into audit_log (ref_table, ref_column, ref_value) select 'TableName', 'dob', TRY_CONVERT(nvarchar(4000), i.dob) from inserted as i;
END
GO



--- Read audit data 
select * from audit_log where ref_table = 'TableName';