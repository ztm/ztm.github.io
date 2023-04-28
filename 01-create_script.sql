--=============== CREATE DATABASE ===============
USE master;
GO

IF EXISTS (	SELECT * 
						FROM master.sys.databases 
						WHERE name = 'AlarmFirst'
					)
BEGIN
	DROP DATABASE [AlarmFirst]
END;
GO 
CREATE DATABASE [AlarmFirst];
GO 

USE [AlarmFirst];
GO 

--set recovery modell to FULL
ALTER DATABASE [AlarmFirst] SET RECOVERY FULL;
GO 

--if single-user mode was set change it to multi-user
IF (SELECT user_access_desc
		FROM master.sys.databases
		WHERE name = 'AlarmFirst') = 'SINGLE_USER'
BEGIN 
	ALTER DATABASE [AlarmFirst] SET MULTI_USER WITH ROLLBACK IMMEDIATE;
END;
GO 


--=============== CREATE SCHEMAS ===============
CREATE SCHEMA [office];
GO 
CREATE SCHEMA [tech];
GO 
CREATE SCHEMA [patrol];
GO 
CREATE SCHEMA [dbadmin];
GO 


--=============== CREATE FUNCTIONS FOR CHECK CONSTRAINTS ===============
--Function to check if installerID belongs to a technican or not.
--used in check constraint on office.Customer (installerID)
CREATE OR ALTER FUNCTION [office].[chkTech] (@installerID int)
RETURNS int
AS 
BEGIN
	DECLARE @retVal int;
	
		IF 0 = (SELECT COUNT(*) FROM office.Staff WHERE isTech = 1)
			SET @retVal = -1
		ELSE 
			BEGIN 
				IF EXISTS (SELECT 1 FROM office.Staff WHERE @installerID = id AND isTech = 1) 
						 SET @retVal = 1;
				ELSE SET @retVal = -1;
			END;
	
	RETURN @retVal;
END;
GO 


--Function to check:
-- -if SIM is data-only and in use if GPRS
-- -if SIM is not-data and in use if Staff. Dispatchers share the same phone(s).
--used in check constraint on tech.Decice (firstSIM / secondSIM)
--and office.Staff (SIMid)
CREATE OR ALTER FUNCTION [tech].[chkSIM] (@simID int, @type bit)
RETURNS int
AS 
BEGIN 
	DECLARE @retVal int;
	
	IF NOT EXISTS (SELECT id FROM office.SIM WHERE isData = @type AND @simID = id)
		SET @retval = -1;
	ELSE 
		BEGIN 
			IF @type = 1
				BEGIN 
					IF EXISTS (SELECT 1 
										 FROM office.SIM 
										 WHERE @simID = id AND isData = 1 AND isIssued = 1
										)
						SET @retVal = -1
					ELSE
						SET @retVal = 1;
				END
			ELSE 
				BEGIN 
					IF EXISTS (SELECT 1
										 FROM office.SIM AS sim
										 INNER JOIN office.Staff AS stf ON stf.SIMid = sim.id
										 WHERE @simID = sim.id AND isData = 0 AND isIssued = 1 AND isDispatcher <> 1
										)
						SET @retVal = -1
					ELSE 
						SET @retVal = 1;
				END;
		END;
	
	RETURN @retVal;
END;
GO 


--=============== CREATE SEQUENCE AND TABLES ===============
CREATE SEQUENCE [office].[Counter] AS int
	START WITH 1
	INCREMENT BY 1
	NO CACHE;
GO


CREATE TABLE [office].[Customer] (
	id int NOT NULL IDENTITY(1,1)
	,deviceID int
	,cancelCode nvarchar(20) MASKED WITH (FUNCTION = 'default()') NOT NULL
	,customerName nvarchar(150) NOT NULL 
	,customerCity nvarchar(50) NOT NULL 
	,customerAddress nvarchar(150) NOT NULL 
	,customerZIP smallint NOT NULL 
	,geoData geography NOT NULL 
	,customerPhone nvarchar(30) NOT NULL 
	,customerEmail nvarchar(100) NULL 
		CONSTRAINT DF_customer_email DEFAULT 'n/a'
	,serviceFee int NOT NULL 
	,invoiceName nvarchar(150) NOT NULL 
	,invoiceCity nvarchar(50) NOT NULL 
	,invoiceAddress nvarchar(150) NOT NULL 
	,invoiceZIP nvarchar(10) NOT NULL 
	,isCompany bit NOT NULL 
		CONSTRAINT DF_customer_isCompany DEFAULT 0
	,invoiceTaxNumber nvarchar(20) NULL 
	,contractDate date NOT NULL 
		CONSTRAINT DF_customer_contractDate DEFAULT CAST(GETDATE() AS date)
	,isActive bit NOT NULL 
		CONSTRAINT DF_customer_isActive DEFAULT 1
	,isDeleted bit NOT NULL 
		CONSTRAINT DF_customer_isDeleted DEFAULT 0
	,note nvarchar(300) NULL 
		CONSTRAINT DF_customer_note DEFAULT 'n/a'
	,isDog bit NOT NULL 
		CONSTRAINT DF_customer_isDog DEFAULT 0
	,isKey bit NOT NULL 
		CONSTRAINT DF_customer_isKey DEFAULT 0
	,isCard bit NOT NULL 
		CONSTRAINT DF_customer_isCard DEFAULT 0
	,isCode bit NOT NULL 
		CONSTRAINT DF_customer_isCode DEFAULT 0
	,isRemote bit NOT NULL 
		CONSTRAINT DF_customer_isRemote DEFAULT 0
	,isGuard bit NOT NULL 
		CONSTRAINT DF_customer_isGuard DEFAULT 0
	,isSprinkler bit NOT NULL 
		CONSTRAINT DF_customer_isSprinkler DEFAULT 0
	,category nvarchar(30) NOT NULL 
	,subscriptionID int NOT NULL
	,installerID int NULL
	,patrolCount tinyint NOT NULL 
		CONSTRAINT DF_customer_patrolCount DEFAULT 0
	,lastUpdateTimeStartUTC datetime2 GENERATED ALWAYS AS ROW START HIDDEN
	,lastModification AS (lastUpdateTimeStartUTC AT TIME ZONE 'UTC'AT TIME ZONE 'Central Europe Standard Time')
	,lastUpdateTimeEndUTC datetime2 GENERATED ALWAYS AS ROW END HIDDEN
	,PERIOD FOR SYSTEM_TIME (lastUpdateTimeStartUTC, lastUpdateTimeEndUTC)
	,CONSTRAINT PK_customer_id PRIMARY KEY (id)
	,CONSTRAINT CK_customer_deviceid CHECK (deviceID IS NOT NULL OR isDeleted = 1)
	,CONSTRAINT CK_customer_serviceFee CHECK (serviceFee >= 0)
	,CONSTRAINT CK_customer_taxnum CHECK (isCompany = 0 OR invoiceTaxNumber IS NOT NULL)
	,CONSTRAINT CK_customer_contractdate CHECK (contractDate > '1990-01-01')
	,CONSTRAINT CK_customer_ZIP CHECK (customerZIP BETWEEN 1000 AND 9999)
	,CONSTRAINT CK_customer_category CHECK (category IN (N'small office', N'supermarket',
																											 N'family house', N'storage', 
																											 N'apartment', N'office building'))
	,CONSTRAINT CK_customer_installertech CHECK (installerID IS NULL OR (office.chkTech(installerID) = 1))
	,CONSTRAINT CK_customer_state CHECK ((isActive = 1 AND isDeleted = 0) OR 
																			 (isActive = 0 AND isDeleted = 0) OR 
																			 (isActive = 0 AND isDeleted = 1))
																		
)
WITH (
	SYSTEM_VERSIONING = ON 
	(
		HISTORY_TABLE = [office].[CustomerArchive]
		,DATA_CONSISTENCY_CHECK = ON
		,HISTORY_RETENTION_PERIOD = 1 YEAR
	)
);
GO 


CREATE TABLE [office].[CustomerContact] (
	id int NOT NULL IDENTITY(1,1)
	,customerID int NOT NULL 
	,priority tinyint NOT NULL 
	,name nvarchar(50) NOT NULL 
	,phone nvarchar(30) NOT NULL 
	,email nvarchar(100) NULL 
		CONSTRAINT DF_customercontact_email DEFAULT 'n/a'
	,note nvarchar(30) NULL 
		CONSTRAINT DF_customercontact_note DEFAULT 'n/a'
	,CONSTRAINT PK_customercontact_id PRIMARY KEY (id)
	,CONSTRAINT UK_customercontact_priority UNIQUE (customerID, priority)
);
GO 


CREATE TABLE [office].[SubscriptionType] (
	id int NOT NULL IDENTITY(1,1) 
	,code nvarchar(8) NOT NULL 
	,description nvarchar(50) NOT NULL 
	,price int NOT NULL 
	,validFrom date NOT NULL 
	,validUntil date NOT NULL 
		CONSTRAINT DF_subscriptiontype_validUntil DEFAULT '9999-12-31'
	,isDiscount bit 
		CONSTRAINT DF_subscriptiontype_isDiscount DEFAULT 1
	,CONSTRAINT PK_subscriptiontype_id PRIMARY KEY (id)
	,CONSTRAINT CK_subscriptiontype_price CHECK (price > 0)
	,CONSTRAINT CK_subscriptiontype_date CHECK (validFrom < validUntil)
);
GO 


CREATE TABLE [office].[Invoice] (
	id int NOT NULL IDENTITY(1,1)
	,customerID int NOT NULL 
	,invoiceNumber int NOT NULL 
		CONSTRAINT DF_invoice_invoiceNumber DEFAULT (NEXT VALUE FOR office.Counter) 
	,invoiceDate date NOT NULL 
		CONSTRAINT DF_invoice_invoiceDate DEFAULT GETDATE()
	,invoiceDueDate date NOT NULL 
		CONSTRAINT DF_invoice_invoiceDueDate DEFAULT DATEADD(dd, 9, GETDATE())
	,unitDescription nvarchar(50) NOT NULL 
	,unitPrice int NOT NULL 
	,quantity int NOT NULL 
	,description nvarchar(500) NOT NULL 
	,isViaMail bit NOT NULL 
		CONSTRAINT DF_invoice_isViaMail DEFAULT 0
	,isDeleted bit NOT NULL 
		CONSTRAINT DF_invoice_isDeleted DEFAULT 0
	,CONSTRAINT PK_invoice_id PRIMARY KEY (id)
	,CONSTRAINT UK_invoice_invoiceNumber UNIQUE (invoiceNumber)
	,CONSTRAINT CK_invoice_dates CHECK (invoiceDate < invoiceDueDate)
);
GO 


CREATE TABLE [office].[Payment] (
	id int NOT NULL IDENTITY(1,1)
	,invoiceID int NOT NULL   
	,paymentDate date NOT NULL 
		CONSTRAINT DF_payment_paymentDate DEFAULT GETDATE()
	,amount int NOT NULL 
	,status bit NULL DEFAULT NULL 
	,CONSTRAINT PK_payment_id PRIMARY KEY (id)
	,CONSTRAINT CK_payment_amount CHECK (amount > 0)
);
GO 


CREATE TABLE [office].[Staff] (
	id int NOT NULL IDENTITY(1,1)
	,staffName nvarchar(80) NOT NULL 
	,passNumber nvarchar(10) NULL 
	,salary int NOT NULL 
	,dateHired date NOT NULL 
		CONSTRAINT DF_staff_dateHired DEFAULT GETDATE()
	,terminationDate date NULL 
	,isTech bit NULL 
	,isOffice bit NULL 
	,isPatrol bit NULL 
	,isDispatcher bit NULL 
	,isActive bit NOT NULL 
		CONSTRAINT DF_staff_isActive DEFAULT 1
	,workplaceID int
	,carID int NULL 
	,SIMid int NULL 
	,CONSTRAINT PK_staff_id PRIMARY KEY (id)
	,CONSTRAINT CK_staff_passNumber CHECK (isTech = 0 OR passNumber IS NOT NULL)
	,CONSTRAINT CK_staff_sim3 CHECK (SIMid IS NULL OR tech.chkSIM(SIMid, 0) = 1)
	,CONSTRAINT CK_staff_active CHECK (isActive = 1 OR terminationDate IS NOT NULL)
	,CONSTRAINT CK_staff_quit CHECK ((isActive = 0 AND carID IS NULL AND SIMid IS null)
																		OR 
																		isActive = 1)
	,CONSTRAINT CK_staff_department CHECK (1 = (CAST(isTech AS int) + 
																							CAST(isOffice AS int) + 
																							CAST(isPatrol AS int) + 
																							CAST(isDispatcher AS int))
																				 OR isActive = 0)
	,CONSTRAINT CK_staff_workplace CHECK (1 <> CAST(isActive AS int) + CAST(workplaceID AS int))
);
GO 


CREATE TABLE [office].[Workplace] (
	id int NOT NULL IDENTITY(1,1)
	,city nvarchar(50) NOT NULL 
	,district nvarchar(10) NULL 
	,description nvarchar(50) NOT NULL 
	,code varchar(5) NOT NULL 
	,CONSTRAINT PK_workplace_id PRIMARY KEY (id)
);
GO


CREATE TABLE [office].[SIM] (
	id int NOT NULL IDENTITY(1,1)
	,SIMnumber nvarchar(30) NOT NULL 
	,phoneNumber nvarchar(30) NOT NULL 
	,dateIssued date NULL 
	,isIssued bit NOT NULL 
		CONSTRAINT DF_sim_isIssued DEFAULT 0
	,isData bit NOT NULL 
		CONSTRAINT DF_sim_isData DEFAULT 1
	,CONSTRAINT PK_sim_id PRIMARY KEY (id)
	,CONSTRAINT UK_sim_SIMnumber UNIQUE (SIMnumber)
	,CONSTRAINT UK_sim_phoneNumber UNIQUE (phoneNumber)
	,CONSTRAINT CK_sim_issue_date CHECK ((isIssued = 1 AND dateIssued IS NOT NULL)
																				OR (isIssued = 0 AND dateIssued IS NULL))
);
GO 


CREATE TABLE [tech].[CustomerSignalType] (
	id int NOT NULL IDENTITY(1,1)
	,customerID int NOT NULL  
	,zoneNumber tinyint NOT NULL 
	,code nvarchar(5) NOT NULL 
	,description nvarchar(30) NOT NULL 
	,isPatrol bit 
		CONSTRAINT DF_customersignaltype_patrol DEFAULT 1
	,CONSTRAINT PK_customersignaltype_id PRIMARY KEY (id)
	,CONSTRAINT UK_customersignaltype_zone UNIQUE (customerID, zoneNumber) 
);
GO


CREATE TABLE [tech].[DeviceType] (
	id int NOT NULL IDENTITY(1,1)
	,code char(4) NOT NULL 
	,protocol nvarchar(5) NOT NULL 
	,description nvarchar(50) NOT NULL 
	,lifeTimeCycle smallint NOT NULL 
	,TSTcode nvarchar(3) NOT NULL 
	,TSTfailedCode nvarchar(3) NOT NULL 
	,encoderType smallint NOT NULL 
	,receiver nvarchar(15) NOT NULL
	,CONSTRAINT PK_devicetype_id PRIMARY KEY (id)
);
GO 


CREATE TABLE [tech].[Device] (
	id int NOT NULL IDENTITY(1,1)
	,lineNumber smallint NOT NULL 
	,deviceNumber smallint NOT NULL 
	,serial nvarchar(10) NULL 
	,IMEI nvarchar(15) NULL
	,firstSIM int NULL 
	,secondSIM int NULL 
	,deviceTypeID int NOT NULL
	,CONSTRAINT PK_device_id PRIMARY KEY (id)
	,CONSTRAINT UK_device_linedevice_num UNIQUE (lineNumber, deviceNumber)
	,CONSTRAINT CK_device_lineNumber CHECK (lineNumber >= 0)
	,CONSTRAINT CK_device_deviceNumber CHECK (deviceNumber >= 1000)
	,CONSTRAINT CK_device_sim1 CHECK (firstSIM IS NULL OR tech.chkSIM(firstSIM, 1) = 1)
	,CONSTRAINT CK_device_sim2 CHECK (secondSIM IS NULL OR tech.chkSIM(secondSIM, 1) = 1)
);
GO 


CREATE TABLE [patrol].[Patrol] (
	id int NOT NULL IDENTITY(1,1)
	,dutyStart datetime2(0) NOT NULL 
	,dutyEnd datetime2(0) NOT NULL 
	,staffID int NOT NULL 
	,isArmed bit NOT NULL 
		CONSTRAINT DF_patrol_isArmed DEFAULT 0
	,isOnCase bit NOT NULL 
		CONSTRAINT DF_patrol_isOnCase DEFAULT 0
	,CONSTRAINT PK_patrol_id PRIMARY KEY (id)
	,CONSTRAINT CH_patrol_duty CHECK (dutyStart < dutyEnd)
);
GO 


CREATE TABLE [patrol].[Car] (
	id int NOT NULL IDENTITY(1,1)
	,licensePlate nvarchar(10) NOT NULL 
	,coveredDistance int NOT NULL 
	,carGeoData geography
	,lastInspectionDate date NOT NULL 
	,nextMOTtestKM int NOT NULL 
	,make nvarchar(20) NOT NULL 
	,model nvarchar(20) NOT NULL 
	,productionYear smallint NOT NULL 
	,CONSTRAINT PK_car_id PRIMARY KEY (id)
	,CONSTRAINT UK_car_licensePlate UNIQUE (licensePlate)
	,CONSTRAINT CK_car_values CHECK (coveredDistance > 0 
																	 AND nextMOTtestKM > 0 
																	 AND productionYear > 2015)
	,CONSTRAINT CK_car_nextMOTtest CHECK (nextMOTtestKM > coveredDistance)
);
GO 


CREATE TABLE [patrol].[ReceivedSignal] (
	id int NOT NULL IDENTITY(1,1)
	,customerID int NOT NULL 
	,zoneNumber tinyint NOT NULL 
	,timeReceived datetime2(0) NOT NULL 
		CONSTRAINT DF_receivedsignal_timeReceived DEFAULT CURRENT_TIMESTAMP
	,dispatcherID int NOT NULL 
	,timePatrolStart datetime2(0) NULL
	,timePatrolOnSpot datetime2(0) NULL
	,patrolID int NULL
	,CONSTRAINT PK_receivedsignal_id PRIMARY KEY (id)
);
GO 


--=============== ADD FK CONSTRAINTS ===============
ALTER TABLE [office].[Customer]
ADD  CONSTRAINT FK_customer_device FOREIGN KEY (deviceID) 
								REFERENCES [tech].[Device] (id)
		,CONSTRAINT FK_customer_staff FOREIGN KEY (installerID) 
								REFERENCES [office].[Staff] (id) 
		,CONSTRAINT FK_customer_subscriptiontype FOREIGN KEY (subscriptionID) 
								REFERENCES [office].[SubscriptionType](id);
GO 

ALTER TABLE [office].[CustomerContact]
ADD	 CONSTRAINT FK_customercontact_customer FOREIGN KEY (customerID)
								REFERENCES [office].[Customer] (id);
GO 

ALTER TABLE [office].[Invoice]
ADD	 CONSTRAINT FK_invoice_customer FOREIGN KEY (customerID)
								REFERENCES [office].[Customer] (id);
GO

ALTER TABLE [office].[Payment]
ADD	 CONSTRAINT FK_payment_invoice FOREIGN KEY (invoiceID)
								REFERENCES [office].[Invoice] (id);
GO

ALTER TABLE [office].[Staff]
ADD  CONSTRAINT FK_staff_workplace FOREIGN KEY (workplaceID) 
		 						REFERENCES [office].[Workplace] (id)
		,CONSTRAINT FK_staff_car FOREIGN KEY (carID) 
		 						REFERENCES [patrol].[Car] (id)
		,CONSTRAINT FK_staff_sim FOREIGN KEY (SIMid) 
								REFERENCES [office].[SIM] (id);
GO 

ALTER TABLE [patrol].[Patrol]
ADD	 CONSTRAINT FK_patrol_staff FOREIGN KEY (staffID) 
							 	REFERENCES [office].[Staff] (id);
GO 

ALTER TABLE [patrol].[ReceivedSignal]
ADD  CONSTRAINT FK_receivedsignal_customer FOREIGN KEY (customerID) 
								REFERENCES [office].[Customer] (id)
		,CONSTRAINT FK_receivedsignal_staff_dispatcher FOREIGN KEY (dispatcherID)
								REFERENCES [office].[Staff] (id)
		,CONSTRAINT FK_receivedsignal_staff_patrol FOREIGN KEY (patrolID)
								REFERENCES [office].[Staff] (id);
GO 

ALTER TABLE [tech].[CustomerSignalType]
ADD	 CONSTRAINT FK_customersignaltype_customer FOREIGN KEY (customerID)
								REFERENCES [office].[Customer] (id);
GO

ALTER TABLE [tech].[Device]
ADD  CONSTRAINT FK_device_devicetype FOREIGN KEY (deviceTypeID) 
								REFERENCES [tech].[DeviceType] (id)
		,CONSTRAINT FK_device_sim_firstsim FOREIGN KEY (firstSIM) 
		 						REFERENCES [office].[SIM] (id)
		,CONSTRAINT FK_device_sim_secondsim FOREIGN KEY (secondSIM) 
		 						REFERENCES [office].[SIM] (id);
GO 


--=============== ADD INDEXES ===============
--indexes in [office] schema
CREATE INDEX idx_customer_installerID ON [office].[Customer] (installerID);
CREATE INDEX idx_customer_subscriptionID ON [office].[Customer] (subscriptionID);
CREATE INDEX idx_customer_name ON [office].[Customer] (customerName);
CREATE SPATIAL INDEX idx_customer_geo ON [office].[Customer] (geoData);
CREATE UNIQUE INDEX idx_customer_deviceID ON [office].[Customer] (deviceID)
			 WHERE isDeleted = 0;
CREATE INDEX idx_customercontact_customerID ON [office].[CustomerContact] (customerID);
CREATE INDEX idx_invoice_customerID ON [office].[Invoice] (customerID);
CREATE INDEX idx_payment_invoiceID ON [office].[Payment] (invoiceID);
CREATE INDEX idx_payment_amount ON [office].[Payment] (amount);
CREATE INDEX idx_staff_workplaceID ON [office].[Staff] (workplaceID);
CREATE UNIQUE INDEX idx_staff_pass ON [office].[Staff] (passNumber)
			 WHERE [passNumber] IS NOT NULL;
CREATE INDEX idx_staff_carID ON [office].[Staff] (carID);
CREATE INDEX idx_staff_simID ON [office].[Staff] (SIMid);
CREATE INDEX idx_staff_staffname ON [office].[Staff] (staffName);
CREATE INDEX idx_subscriptiontype_description ON [office].[SubscriptionType] (description);
CREATE INDEX idx_subscriptiontype_price ON [office].[SubscriptionType] (price);
CREATE INDEX idx_workplace_city ON [office].[Workplace] (city);
CREATE INDEX idx_workplace_description ON [office].[Workplace] (description);
GO 

--indexes in [patrol] SCHEMA
CREATE INDEX idx_car_km ON [patrol].[Car] (coveredDistance);
CREATE INDEX idx_patrol_dutystart ON [patrol].[Patrol] (dutyStart DESC);
CREATE INDEX idx_patrol_dutyend ON [patrol].[Patrol] (dutyEnd DESC);
CREATE INDEX idx_patrol_staffID ON [patrol].[Patrol] (staffID);
CREATE INDEX idx_patrol_oncase ON [patrol].[Patrol] (isOnCase);
CREATE SPATIAL INDEX idx_patrol_cargeo ON [patrol].[Car] (carGeoData);
CREATE INDEX idx_receivedsignal_customerID ON [patrol].[ReceivedSignal] (customerID);
CREATE INDEX idx_receivedsignal_dispatcherID ON [patrol].[ReceivedSignal] (dispatcherID);
CREATE INDEX idx_receivedsignal_sigreceived ON [patrol].[ReceivedSignal] (timeReceived DESC);
GO 

--indexes in [tech] SCHEMA
CREATE INDEX idx_customersigtype_customerID ON [tech].[CustomerSignalType] (customerID);
CREATE INDEX idx_device_devicetypeID ON [tech].[Device] (deviceTypeID);
CREATE INDEX idx_device_firstSIM ON [tech].[Device] (firstSIM);
CREATE INDEX idx_device_secondSIM ON [tech].[Device] (secondSIM);
CREATE UNIQUE INDEX idx_device_serial ON [tech].[Device] (serial)
			 WHERE [serial] IS NOT NULL;
CREATE INDEX idx_devicetype_lifetime ON [tech].[DeviceType] (lifeTimeCycle);
CREATE INDEX idx_devicetype_protocol ON [tech].[DeviceType] (protocol);
GO


--=============== CREATE FUNCTIONS =============== 
--simple function to format phone numbers
CREATE OR ALTER FUNCTION tech.phoneFormat(@formatNum nvarchar(30))
RETURNS nvarchar(30)
AS
BEGIN
	RETURN (SELECT SUBSTRING(@formatNum, 0, 3) + '/' 
								 + SUBSTRING(@formatNum, 3, 3) + '-' + 
								 + SUBSTRING(@formatNum, 6, 4))
END;
GO 


--simple function to return customerID, used in many SPs
CREATE OR ALTER FUNCTION [office].[findCustomer] (@lineNumber smallint, @deviceNumber smallint)
RETURNS int
AS
BEGIN
	RETURN (SELECT office.Customer.id FROM office.Customer
				  INNER JOIN tech.Device ON tech.Device.id = office.Customer.deviceID
				  WHERE @lineNumber = lineNumber AND @deviceNumber = deviceNumber AND isDeleted = 0);
END;
GO 


--simple function with view hack to return random generated installerID, used in trigger
CREATE OR ALTER VIEW [tech].[vRandom]
AS 
	SELECT NEWID() AS [rndInst];
GO 

CREATE OR ALTER FUNCTION [tech].[randomInst] ()
RETURNS int
AS
BEGIN
	RETURN (SELECT TOP 1 office.Staff.id 
				  FROM office.Staff 
					WHERE office.Staff.isTech = 1 
					ORDER BY (SELECT rndInst FROM tech.vRandom))
END;
GO 


--calculate customer balance between given dates
CREATE OR ALTER FUNCTION [office].[customerBalance] (
		@lineNumber smallint
		,@deviceNumber smallint
		,@startDate date
		,@endDate date = NULL
)
RETURNS int
AS 
BEGIN 
	DECLARE @invoiceSum int = 0;
	DECLARE @paymentSum int = 0;
	DECLARE @retVal int;
		
	IF @endDate IS NULL SET @endDate = GETDATE();
	
	SELECT @invoiceSum = SUM(unitPrice * quantity * 1.27)
	FROM office.Invoice
	INNER JOIN office.Customer ON office.Customer.id = office.Invoice.customerID
	INNER JOIN tech.Device ON tech.Device.id = office.Customer.deviceID
	WHERE @startDate <= office.Invoice.invoiceDate AND @endDate >= office.Invoice.invoiceDate
				AND @lineNumber = lineNumber AND @deviceNumber = deviceNumber
				AND office.Customer.isDeleted = 0;
				
	SELECT @paymentSum = SUM(amount)
	FROM office.Payment
	INNER JOIN office.Invoice ON office.Invoice.id = office.Payment.invoiceID
	INNER JOIN office.Customer ON office.Customer.id = office.Invoice.customerID
	INNER JOIN tech.Device ON tech.Device.id = office.Customer.deviceID
	WHERE @startDate <= office.Payment.paymentDate AND @endDate >= office.Payment.paymentDate
				AND @lineNumber = lineNumber AND @deviceNumber = deviceNumber
				AND office.Customer.isDeleted = 0;
	
	IF @invoiceSum IS NULL AND @paymentSum IS NULL SET @retVal = NULL;
	ELSE SET @retVal = ISNULL(@paymentSum, 0) - ISNULL(@invoiceSum, 0);
	
	RETURN @retVal;
END;	
GO 


--list customers with due within the given date range
CREATE OR ALTER FUNCTION [office].[customerDue] (@startDate date, @endDate date)
RETURNS TABLE 
AS 
RETURN (
	WITH cteInvoiceTotal AS (
		SELECT customerID, SUM(unitPrice * quantity * 1.27) AS invoiceTotal
		FROM office.Invoice
		INNER JOIN office.Customer ON office.Customer.id = office.Invoice.customerID
		WHERE @startDate <= invoiceDate AND @endDate >= invoiceDate AND office.Customer.isDeleted = 0
		GROUP BY customerID
	)
	SELECT CAST(lineNumber AS varchar(2)) + '-' + CAST(deviceNumber AS varchar(5)) AS [Customer Device]
				,customerName + ' - ' + CAST(customerZIP AS varchar(4)) + ' ' + customerCity + ', ' + customerAddress AS [Billed To]
				,FORMAT(SUM(amount) - invoiceTotal, 'C0', 'hu-hu') AS [Balance]
				,CASE
					 WHEN isActive = 1 THEN N'Active'
					 ELSE N'Suspended'
				 END AS [Customer status]
				,@startDate AS [Start Date] 
				,@endDate AS [End Date]
	FROM tech.Device
	INNER JOIN office.Customer ON office.Customer.deviceID = tech.Device.id
	INNER JOIN office.Invoice ON office.Invoice.customerID = office.Customer.id
	LEFT JOIN office.Payment ON office.Payment.invoiceID = office.Invoice.id
	INNER JOIN cteInvoiceTotal ON cteInvoiceTotal.customerID = office.Invoice.customerID
	WHERE @startDate <= paymentDate AND @endDate >= paymentDate AND office.Customer.isDeleted = 0
	GROUP BY lineNumber
					,deviceNumber
					,customerName
					,customerZIP
					,customerCity
					,customerAddress
					,invoiceTotal
					,isActive
	HAVING SUM(amount) - invoiceTotal < 0
);
GO 


--find nearest patrol(s) to the alarm location
CREATE OR ALTER FUNCTION [patrol].[findNextXPatrol] (@pCount int = 1)
RETURNS TABLE 
AS
RETURN (
	WITH lastAlarmCustomer AS (
		SELECT TOP 1 geoData, timeReceived
		FROM office.Customer AS offc
		INNER JOIN tech.CustomerSignalType AS tcs ON tcs.customerID = offc.id
		INNER JOIN patrol.ReceivedSignal AS prs ON prs.customerID = offc.id
		WHERE offc.isActive = 1 AND tcs.isPatrol = 1 AND tcs.zoneNumber = prs.zoneNumber
		ORDER BY prs.timeReceived DESC
	)
	SELECT licensePlate AS [License Plate]
				,staffName AS [Patrol Name]
				,CASE 
					 WHEN isArmed = 1 THEN 'Armed'
					 ELSE 'Not Armed'
				 END AS [Patrol Armed]
				,tech.phoneFormat(phoneNumber) AS [Patrol Phone]
				,FORMAT(geoData.STDistance(carGeoData) / 1000, 'N2') + N'km' AS [Distance from Alarm] 
				,CAST(geoData.Lat AS varchar(10)) AS [Alarm location GPS LAT]
				,CAST(geoData.Long AS varchar(10)) AS [Alarm location GPS LONG]
	FROM office.Staff
	INNER JOIN patrol.Car ON patrol.Car.id = office.Staff.carID
	INNER JOIN patrol.Patrol ON patrol.Patrol.staffID = office.Staff.id
	INNER JOIN office.SIM ON office.SIM.id = office.Staff.SIMid
	INNER JOIN lastAlarmCustomer AS lac ON lac.timeReceived > dutyStart AND lac.timeReceived < dutyEnd
	WHERE isOnCase = 0
	ORDER BY geoData.STDistance(carGeoData) ASC
	OFFSET 0 ROWS FETCH NEXT @pCount ROW ONLY
);
GO


--=============== CREATE VIEWS ===============
--view to present Customer's base data
CREATE OR ALTER VIEW [tech].[vCustomerBaseData]
AS 
SELECT CAST(lineNumber AS varchar) 
					+ '-' 
					+ CAST(deviceNumber AS varchar) AS [DeviceID]
			,customerName AS [Name]
			,CAST(customerZIP AS char(4)) 
					+ ' ' 
					+ customerCity 
					+ ', '
					+ customerAddress AS [Address]
			,'LAT: ' + CAST(geoData.Lat AS varchar(10)) + ', '
				+ 'LONG: ' + CAST(geoData.Long AS varchar(10)) AS [Customer GPS Coordinates]
			,tech.phoneFormat(customerPhone) AS [Phone Number]
			,customerEmail [E-mail]
			,category AS [Category]
			,zoneNumber AS [Zone Number]
			,description AS [Zone description]
			,CASE 
			 	 WHEN office.Customer.isActive = 1 THEN N'Active'
			 	 ELSE N'Suspended'
			 END AS [Customer status]
FROM tech.Device
INNER JOIN office.Customer ON office.Customer.deviceID = tech.Device.id
INNER JOIN tech.CustomerSignalType ON tech.CustomerSignalType.customerID = office.Customer.id
WHERE isDeleted = 0;
GO 


--view to pop-up to dispatcher in case of a new alarm
CREATE OR ALTER VIEW [patrol].[vAlarm]
AS 
SELECT CAST(tech.Device.lineNumber AS varchar) 
						+ '-' 
						+ CAST(tech.Device.deviceNumber AS varchar) AS [DeviceID]
			,office.Customer.customerName AS [Name]
			,CAST(office.Customer.customerZIP AS char(4)) 
						+ ' ' 
						+ office.Customer.customerCity + ', ' 
						+ office.Customer.customerAddress AS [Address]
			,'LAT: ' + CAST(geoData.Lat AS varchar(10)) + ', '
						+ 'LONG: ' + CAST(geoData.Long AS varchar(10)) AS [Customer GPS Coordinates]
			,tech.phoneFormat(office.Customer.customerPhone) AS [Owner Phone]
			,office.Customer.category AS [Category]
			,tech.CustomerSignalType.description AS [Zone description]
			,office.CustomerContact.name AS [Contact Name]
			,tech.phoneFormat(office.CustomerContact.phone) AS [Contact Phone]
			,office.CustomerContact.note AS [Info]
			,CASE 
				 WHEN tech.CustomerSignalType.isPatrol = 0 THEN 'Just Call'
				 ELSE 'Send Patrol' 
			 END AS [Action Type]
			,office.Customer.isDog AS [Dog on property]
			,office.Customer.isKey AS [Key provided]
			,office.Customer.isCard AS [Proxy provided]
			,office.Customer.isCode AS [GateCode provided]
			,office.Customer.isRemote AS [Remote provided]
			,office.Customer.isGuard AS [Property guarded]
			,office.Customer.isSprinkler AS [FS Sprinkler]
FROM tech.Device
INNER JOIN office.Customer ON office.Customer.deviceID = tech.Device.id
INNER JOIN tech.CustomerSignalType ON tech.CustomerSignalType.customerID = office.Customer.id
INNER JOIN office.CustomerContact ON office.CustomerContact.customerID = office.Customer.id
WHERE office.Customer.isActive = 1;
GO 


--view for technicians to get Customer device technical datas
CREATE OR ALTER VIEW [tech].[vTechnical]
AS 
SELECT	CAST(tech.Device.lineNumber AS varchar) 
					+ '-' 
					+ CAST(tech.Device.deviceNumber AS varchar) AS [DeviceID]
				,office.Customer.installerID AS [Installer]
				,CASE 
					 WHEN fst.phoneNumber IS NULL THEN 'n/a'
					 ELSE tech.phoneFormat(fst.phoneNumber)
				 END AS [Device 1st SIM PhoneNo.]
				,CASE 
					 WHEN sec.phoneNumber IS NULL THEN 'n/a'
					 ELSE tech.phoneFormat(sec.phoneNumber)
				 END AS [Device 2nd SIM PhoneNo.]
				,tech.Device.serial AS [Device Serial No.]
				,tech.DeviceType.protocol AS [Protocol]
				,CASE 
				 	 WHEN office.Customer.isActive = 1 THEN N'Active'
				 	 ELSE N'Suspended'
				 END AS [Customer status]
FROM tech.Device
INNER JOIN office.Customer ON office.Customer.deviceID = tech.Device.id
INNER JOIN tech.DeviceType ON tech.DeviceType.id = tech.Device.deviceTypeID
LEFT JOIN office.SIM AS fst ON fst.id = tech.Device.firstSIM
LEFT JOIN office.SIM AS sec ON sec.id = tech.Device.secondSIM
WHERE isDeleted = 0;
GO 


--view on invoices and payments info
CREATE OR ALTER VIEW [office].[vAccount]
WITH SCHEMABINDING
AS 
SELECT	STR(YEAR(invoiceDate)) + '/' + FORMAT(invoiceNumber, '00000') AS [Invoice Number]
				,CAST(lineNumber AS varchar(2)) 
						+ '-' 
						+ CAST(deviceNumber AS varchar(5)) AS [Customer Device]
				,customerName AS [Billed To]
				,CAST(customerZIP AS varchar(4)) 
						+ ' ' 
						+ customerCity 
						+ ', ' 
						+ customerAddress AS [Customer Address]
				,quantity AS [Quantity]
				,unitPrice AS [Unit Price]
				,unitPrice * quantity AS [Line Total]
				,unitPrice * quantity * 0.27 AS [Tax]
				,unitPrice * quantity * 1.27 AS [Amount Due]
				,invoiceDate AS [Date Issued]
				,amount AS [Settled]
				,paymentDate AS [Settlement Date]
				,CASE 
					 WHEN status IS NULL THEN 'Fully paid'
					 WHEN status = 0 THEN 'Partial payment'
					 ELSE 'Overpaid'
				 END AS [Payment Status]
				,CASE
					 WHEN isActive = 1 THEN N'Active'
					 ELSE N'Suspended'
				 END AS [Customer status]
FROM tech.Device
INNER JOIN office.Customer ON office.Customer.deviceID = tech.Device.id
INNER JOIN office.Invoice ON office.Invoice.customerID = office.Customer.id
LEFT JOIN office.Payment ON office.Payment.invoiceID = office.Invoice.id
WHERE office.Customer.isDeleted = 0;
GO 


--=============== CREATE STORED PROCEDURES ===============
--SP for Error Handling
CREATE OR ALTER PROC dbadmin.error_handler(@errMsg nvarchar(2048), @errState tinyint)
AS
SET NOCOUNT ON;
BEGIN 
	DECLARE @errProc sysname;
	DECLARE @errNo int;
	DECLARE @errSeverity tinyint;
	DECLARE @errLine int;
	DECLARE @usrname nvarchar(50);
         
	SELECT @errProc = ERROR_PROCEDURE()
				,@errNo = ERROR_NUMBER()
				,@errMsg = COALESCE(@errMsg, ERROR_MESSAGE())
				,@errSeverity = ERROR_SEVERITY()
				,@errState = ERROR_STATE()
				,@errLine = ERROR_LINE()
				,@usrname = USER_NAME();
				
	--check for faulting CONSTRAINTS
	IF 0 <> CHARINDEX('CK_customer_installertech', @errMsg)
		SET @errMsg = N'Employee is not a technician. Invalid installer ID. ' + @errMsg; 
				
	IF 0 <> CHARINDEX('CK_customer_taxnum', @errMsg)
		SET @errMsg = N'Can''t register firms without tax number. ' + @errMsg;
		
	IF 0 <> CHARINDEX('idx_customer_deviceID', @errMsg)
		SET @errMsg = N'Device ID is assigned to existing customer. Choose another one. ' + @errMsg;
		
	IF 0 <> CHARINDEX('CK_device_sim', @errMsg) OR 0 <> CHARINDEX('CK_staff_sim', @errMsg)
		SET @errMsg = N'Not existing SIM or SIM is used or not for intended purpuse. ' + @errMsg;
		
	IF 0 <> CHARINDEX('CK_staff_department', @errMsg)
		SET @errMsg = N'Employee must be a member of one of the departments. ' + @errMsg;
		
	IF 0 <> CHARINDEX('CK_staff_active', @errMsg)
		SET @errMsg = N'Employee can have only one status. Employed or fired. Hmm? ' + @errMsg;
		
	IF 0 <> CHARINDEX('CK_staff_passNumber', @errMsg)
		SET @errMsg = N'Technician must have a license to hire. ' + @errMsg;
		
	IF 0 <> CHARINDEX('CK_staff_quit', @errMsg)
		SET @errMsg = N'Employee quits can''t have a car and/or phone. ' + @errMsg;
		
	IF 0 <> CHARINDEX('CK_staff_workplace', @errMsg)
		SET @errMsg = N'Employee quits does not belong to any workplace. ' + @errMsg;
		
	IF 0 <> CHARINDEX('FK_device_sim', @errMsg) OR 0 <> CHARINDEX('FK_staff_sim', @errMsg)
		SET @errMsg = N'Not existing SIM card. ' + @errMsg;
	
		
	--do not raise the same error message again
	IF @errMsg NOT LIKE '*****%'
		BEGIN
			SELECT @errMsg = 
				'*****' + CHAR(13) + CHAR(10) +
				'ERROR in proc: ' + COALESCE(QUOTENAME(@errProc), '<Batch / Dynamic SQL>') + CHAR(13) + CHAR(10) +
				'ERROR Message: ' + @errMsg + CHAR(13) + CHAR(10) +
				'Error Number: ' + LTRIM(STR(@errNo)) + CHAR(13) + CHAR(10) +
        'Line: ' + LTRIM(STR(@errLine)) + CHAR(13) + CHAR(10) +
        'Error State: '+ LTRIM(STR(@errState)) + CHAR(13) + CHAR(10) +
        'User: ' + @usrname;
	END;
	
	THROW 50010, @errMsg, @errState;
END;
GO 


--simple SP to make better use of the function office.customerBalance
CREATE OR ALTER PROC [office].[custBalance] (
		@lineNumber smallint
		,@deviceNumber smallint
		,@startDate date
		,@endDate date = NULL
)
AS 
SET NOCOUNT ON;
BEGIN TRY
	DECLARE @errMsg nvarchar(2048);
	DECLARE @errState tinyint; 
	
	--check for existing customer
	IF (SELECT office.findCustomer(@lineNumber, @deviceNumber)) IS NULL  
		BEGIN 
			SELECT @errMsg = N'Not existing customer. Can''t calculate balance.', @errState = 1;
			THROW 50010, @errMsg, @errState;
		END;
		
	DECLARE @balance int = (SELECT office.customerBalance(@lineNumber, @deviceNumber, @startDate, @endDate));
	
	--check if customer has an invoice at all
	IF @balance IS NULL SELECT N'Customer has no invoice.' AS Balance;
	ELSE SELECT FORMAT(@balance, 'C0', 'hu-hu') AS Balance;
END TRY
BEGIN CATCH
	EXEC dbadmin.error_handler @errMsg, @errState;
	RETURN (-1);
END CATCH;
GO 


--SP to add new Customer
CREATE OR ALTER PROC [office].[addCustomer] (
		@lineNumber smallint
		,@deviceNumber smallint
		,@firstSIM int = NULL 
		,@secondSIM int = NULL 
		,@cancelCode nvarchar(20) 
		,@customerName nvarchar(150) 
		,@customerCity nvarchar(50)  
		,@customerAddress nvarchar(150) 
		,@customerZIP smallint  
		,@customerLONG decimal(9,6) = NULL
		,@customerLAT decimal(9,6) = NULL 
		,@customerPhone varchar(30)  
		,@customerEmail varchar(100) = NULL 
		,@serviceFee int 
		,@invoiceName nvarchar(150) = NULL 
		,@invoiceCity nvarchar(50) = NULL 
		,@invoiceAddress varchar(150) = NULL 
		,@invoiceZIP varchar(10) = NULL 
		,@isCompany bit = 0
		,@invoiceTaxNumber varchar(20) = NULL 
		,@contractDate date = NULL
		,@note nvarchar(300) = NULL 
		,@isDog bit = 0
		,@isKey bit = 0
		,@isCard bit = 0
		,@isCode bit = 0
		,@isRemote bit = 0
		,@isGuard bit = 0
		,@isSprinkler bit = 0
		,@category varchar(30)
		,@subscriptionID int
		,@installerID int
)
AS
SET XACT_ABORT, NOCOUNT ON;
BEGIN TRY
	DECLARE @errMsg nvarchar(2048);
	DECLARE @errState tinyint;
	DECLARE @deviceID int = (SELECT id FROM tech.Device
													 WHERE @lineNumber = lineNumber AND @deviceNumber = deviceNumber);
	
	--check for existing deviceID
	IF @deviceID IS NULL 
		BEGIN
			SELECT @errMsg = N'No such device. Consult with tech department.', @errState = 1;
			THROW 50010, @errMsg, @errState;
		END;
		
	--check weather GPRS device and if yes, was SIM applied at all
	DECLARE @gprsDevID int = (SELECT tech.Device.id 
				 								  	FROM tech.Device
													  INNER JOIN tech.DeviceType ON tech.DeviceType.id = tech.Device.deviceTypeID
													  WHERE protocol = 'GPRS' AND @deviceID = tech.Device.id
													 );
											
	IF ( @firstSIM IS NOT NULL OR @secondSIM IS NOT NULL ) AND @gprsDevID IS NULL 
		BEGIN 
			SELECT @errMsg = N'Not GPRS device. SIM not allowed.', @errState = 2;
			THROW 50010, @errMsg, @errState;
		END;
		
	IF @firstSIM IS NULL AND @secondSIM IS NULL AND @gprsDevID IS NOT NULL 
		BEGIN 
			SELECT @errMsg = N'GPRS device can not be installed without SIM.', @errState = 3;
			THROW 50010, @errMsg, @errState;
		END;		
		
	--set billing to Customer's name / address if no billing info supplied
	IF @invoiceName IS NULL OR @invoiceCity IS NULL OR @invoiceAddress IS NULL OR @invoiceZIP IS NULL 
		BEGIN
			SET @invoiceName = ISNULL(@invoiceName, @customerName);
			SET @invoiceCity = ISNULL(@invoiceCity, @customerCity);
			SET @invoiceAddress = ISNULL(@invoiceAddress, @customerAddress);
			SET @invoiceZIP = ISNULL(@invoiceZIP, @customerZIP);
		END;
	
	BEGIN TRAN;
		INSERT INTO office.Customer (deviceID, cancelCode, customerName, customerCity, customerAddress, 
				customerZIP, geoData, customerPhone, customerEmail, serviceFee, invoiceName, invoiceCity, 
				invoiceAddress, invoiceZIP, isCompany, invoiceTaxNumber, contractDate, note, isDog, isKey,
				isCard, isCode, isRemote, isGuard, isSprinkler, category, subscriptionID, installerID)
		VALUES (@deviceID, @cancelCode, @customerName, @customerCity, @customerAddress, @customerZIP, 
						geography::Point(@customerLAT, @customerLONG, 4326), @customerPhone, @customerEmail, 
						@serviceFee, @invoiceName, @invoiceCity, @invoiceAddress, @invoiceZIP, @isCompany, 
						@invoiceTaxNumber, ISNULL(@contractDate, GETDATE()), @note, @isDog, @isKey, @isCard, 
						@isCode, @isRemote, @isGuard, @isSprinkler, @category, @subscriptionID, @installerID);
						
		UPDATE tech.Device
		SET firstSIM = @firstSIM, secondSIM = @secondSIM
		FROM tech.Device
		WHERE tech.Device.id = @deviceID;
	COMMIT TRAN;
	PRINT(N'Customer added. / Device SIM(s) were successfully updated.');
END TRY
BEGIN CATCH
	IF @@TRANCOUNT > 0 ROLLBACK TRAN;
	SET @errMsg = N'Customer insert failed. ' + @errMsg;
	EXEC dbadmin.error_handler @errMsg, @errState;
	RETURN (-1);
END CATCH;
GO 


--SP to modify existing Customer's data
CREATE OR ALTER PROC office.modCustomer (
		@lineNumber smallint
		,@deviceNumber smallint
		,@firstSIM int = NULL 
		,@secondSIM int = NULL 
		,@cancelCode nvarchar(20) = NULL
		,@customerName nvarchar(150) = NULL
		,@customerCity nvarchar(50) = NULL
		,@customerAddress nvarchar(150) = NULL 
		,@customerZIP smallint = NULL
		,@customerLONG decimal(9,6) = NULL
		,@customerLAT decimal(9,6) = NULL 
		,@customerPhone varchar(30) = NULL
		,@customerEmail varchar(100) = NULL 
		,@serviceFee int = NULL
		,@invoiceName nvarchar(150) = NULL 
		,@invoiceCity nvarchar(50) = NULL 
		,@invoiceAddress varchar(150) = NULL 
		,@invoiceZIP varchar(10) = NULL 
		,@isCompany bit = 0
		,@invoiceTaxNumber varchar(20) = NULL 
		,@note nvarchar(300) = NULL 
		,@isActive bit = 1
		,@isDog bit = 0
		,@isKey bit = 0
		,@isCard bit = 0
		,@isCode bit = 0
		,@isRemote bit = 0
		,@isGuard bit = 0
		,@isSprinkler bit = 0
		,@category varchar(30) = NULL 
		,@subscriptionID int = NULL 
		,@installerID int = NULL
		,@patrolCount tinyint = NULL
)
AS
SET XACT_ABORT, NOCOUNT ON;
BEGIN TRY
	DECLARE @errMsg nvarchar(2048);
	DECLARE @errState tinyint; 
	DECLARE @customerID int = (SELECT office.findCustomer(@lineNumber, @deviceNumber));
	
	IF @customerID IS NULL  
		BEGIN 
			SELECT @errMsg = N'Not existing customer.', @errState = 1;
			THROW 50010, @errMsg, @errState;
		END;
	
	DECLARE @gprsDevID int = (SELECT tech.Device.id 
				 								  	FROM tech.Device
													  INNER JOIN tech.DeviceType ON tech.DeviceType.id = tech.Device.deviceTypeID
													  WHERE protocol = 'GPRS' AND @lineNumber = lineNumber AND @deviceNumber = deviceNumber
													 );
											
	IF ( @firstSIM IS NOT NULL OR @secondSIM IS NOT NULL ) AND @gprsDevID IS NULL 
		BEGIN 
			SELECT @errMsg = N'Not GPRS device. SIM not allowed.', @errState = 2;
			THROW 50010, @errMsg, @errState;
		END;
	
	BEGIN TRAN;
		UPDATE office.Customer
		SET cancelCode = ISNULL(@cancelCode, cancelCode) 
				,customerName = ISNULL(@customerName, customerName)
				,customerCity = ISNULL(@customerCity, customerCity)
				,customerAddress = ISNULL(@customerAddress, customerAddress)
				,customerZIP = ISNULL(@customerZIP, customerZIP)
				,geoData = CASE
										 WHEN @customerLAT IS NULL OR @customerLONG IS NULL THEN geoData
										 ELSE geography::Point(@customerLAT, @customerLONG, 4326)
									 END 
				,customerPhone = ISNULL(@customerPhone, customerPhone)
				,customerEmail = ISNULL(@customerEmail, customerEmail)
				,serviceFee = ISNULL(@serviceFee, serviceFee)
				,invoiceName = ISNULL(@invoiceName, invoiceName)
				,invoiceCity = ISNULL(@invoiceCity, invoiceCity)
				,invoiceAddress = ISNULL(@invoiceAddress, invoiceAddress)
				,invoiceZIP = ISNULL(@invoiceZIP, invoiceZIP)
				,isCompany = ISNULL(@isCompany, isCompany)
				,invoiceTaxNumber = ISNULL(@invoiceTaxNumber, invoiceTaxNumber)
				,note = ISNULL(@note, note)
				,isActive = ISNULL(@isActive, isActive)
				,isDog = ISNULL(@isDog, isDog)
				,isKey = ISNULL(@isKey, isKey)
				,isCard = ISNULL(@isCard, isCard)
				,isCode = ISNULL(@isCode, isCode)
				,isRemote = ISNULL(@isRemote, isRemote)
				,isGuard = ISNULL(@isGuard, isGuard)
				,isSprinkler = ISNULL(@isSprinkler, isSprinkler)
				,category = ISNULL(@category, category)
				,subscriptionID = ISNULL(@subscriptionID, subscriptionID)
				,installerID = ISNULL(@installerID, installerID)
				,patrolCount = ISNULL(@patrolCount, patrolCount)
		FROM office.Customer
		WHERE id = @customerID;
		
		--if GPRS, update SIM(s) if any of them provided
		IF @gprsDevID IS NOT NULL AND ( @firstSIM IS NOT NULL OR @secondSIM IS NOT NULL )
			BEGIN 
				IF @firstSIM IS NOT NULL
					BEGIN 
						UPDATE tech.Device 
						SET firstSIM = @firstSIM
						FROM tech.Device
						WHERE tech.Device.id = @gprsDevID;
					END;
				
				IF @secondSIM IS NOT NULL
					BEGIN 
						UPDATE tech.Device 
						SET secondSIM = @secondSIM
						FROM tech.Device
						WHERE tech.Device.id = @gprsDevID;
					END;
			END;
	COMMIT TRAN;
	PRINT('Customer update succeeded.');
END TRY
BEGIN CATCH
	IF @@TRANCOUNT > 0 ROLLBACK TRAN;
	SET @errMsg = 'Customer update failed.' + @errMsg;
	EXEC dbadmin.error_handler @errMsg, @errState;
	RETURN(-1);
END CATCH;
GO 


--SP to delete Customer 
CREATE OR ALTER PROC [office].[delCustomer] (
		@lineNumber smallint
		,@deviceNumber smallint
)
AS
SET XACT_ABORT, NOCOUNT ON;
BEGIN TRY
	DECLARE @errMsg nvarchar(2048);
	DECLARE @errState tinyint; 
	DECLARE @customerID int = (SELECT office.findCustomer(@lineNumber, @deviceNumber));
	
	IF @customerID IS NULL  
		BEGIN 
			SELECT @errMsg = N'Not existing customer.', @errState = 1;
			THROW 50010, @errMsg, @errState;
		END;
		
	DECLARE @contractDate date = (SELECT contractDate FROM office.Customer WHERE id = @customerID);													
	DECLARE @balance int = office.customerBalance(@lineNumber, @deviceNumber, @contractDate, DEFAULT);
	
	IF @balance <> 0
		BEGIN
			SELECT @errMsg = N'Balance is not 0. Can''t delete customer with due or overpay.', @errState = 2;
			THROW 50010, @errMsg, @errState;
		END
		
	DECLARE @deviceID int = (SELECT deviceID FROM office.Customer WHERE id = @customerID);
		
	BEGIN TRAN;
		UPDATE office.Customer
		SET isActive = 0, isDeleted = 1, deviceID = NULL
		FROM office.Customer
		WHERE id = @customerID;
				
		DELETE tech.Device
		WHERE id = @deviceID;
	
		DELETE occ
		FROM office.CustomerContact AS occ
		WHERE occ.customerID = @customerID;
		
		DELETE tcst
		FROM tech.CustomerSignalType AS tcst
		WHERE tcst.customerID = @customerID;
	COMMIT TRAN;
	PRINT (N'Customer deleted.');
END TRY
BEGIN CATCH
	IF @@TRANCOUNT > 0 ROLLBACK TRAN;
	SET @errMsg = N'Customer deletion failed. ' + @errMsg;
	EXEC dbadmin.error_handler @errMsg, @errState;
	RETURN (-1);
END CATCH;
GO 


--SP to add an Invoice
--
--Dynamic SQL - to guarantee invoice number continuity. 
--If insert fails counter is set back. 
CREATE OR ALTER PROC [office].[addInvoice] (
		@lineNumber smallint 
		,@deviceNumber smallint   
		,@invoiceDate date = NULL
		,@invoiceDueDate date = NULL
		,@unitDescription nvarchar(50)
		,@unitPrice int 
		,@quantity int 
		,@description nvarchar(500)
		,@isViaMail bit = 0
)
AS
SET XACT_ABORT, NOCOUNT ON;
BEGIN TRY
	DECLARE @errMsg nvarchar(2048);
	DECLARE @errState tinyint; 
	DECLARE @counterMax int = (SELECT MAX(invoiceNumber) FROM office.Invoice);
	DECLARE @cmd nvarchar(100);
	DECLARE @customerID int = (SELECT office.findCustomer(@lineNumber, @deviceNumber));

	IF @customerID IS NULL  
		BEGIN 
			SELECT @errMsg = N'Not existing customer. Can''t set up invoice.', @errState = 1;
			THROW 50010, @errMsg, @errState;
		END;
		
	IF @invoiceDate IS NULL SET @invoiceDate = GETDATE();
	IF @invoiceDueDate IS NULL SET @invoiceDueDate = DATEADD(dd, 10, @invoiceDate);
		
	BEGIN TRAN;
		INSERT INTO office.Invoice (customerID, invoiceDate, invoiceDueDate, unitDescription,
																		unitPrice, quantity, description, isViaMail)
		VALUES (@customerID, @invoiceDate, @invoiceDueDate, @unitDescription, 
						@unitPrice, @quantity, @description, @isViaMail);
	COMMIT TRAN;
	PRINT (N'Invoice added.');
END TRY
BEGIN CATCH
	IF @@TRANCOUNT > 0 ROLLBACK TRAN;
	
	SET @cmd = 'ALTER SEQUENCE ' + QUOTENAME('office') + '.' + QUOTENAME('Counter') + 
						 ' RESTART WITH ' + CAST(@counterMax + 1 AS varchar);
	EXEC sp_executesql @cmd;
	
	SET @errMsg = N'Invoice insert failed. ' + @errMsg;
	EXEC dbadmin.error_handler @errMsg, @errState;
	RETURN (-1);
END CATCH;
GO 


--SP to "delete" an invoice
--Invoices can not be deleted, only isDeleted is set to 1 and a 
--negativ pair of canceled invoice is created refering to the 
--canceled invoice number in descriptions.
CREATE OR ALTER PROC [office].[delInvoice] (
		@lineNumber smallint 
		,@deviceNumber smallint
		,@invoiceNumber int
)
AS
SET XACT_ABORT, NOCOUNT ON;
BEGIN TRY
	DECLARE @errMsg nvarchar(2048);
	DECLARE @errState tinyint; 
	DECLARE @cmd nvarchar(100);
	DECLARE @counterMax int = (SELECT MAX(invoiceNumber) FROM office.Invoice);
	DECLARE @customerID int = (SELECT office.findCustomer(@lineNumber, @deviceNumber));
	
	IF @customerID IS NULL  
		BEGIN 
			SELECT @errMsg = N'Not existing customer.', @errState = 1;
			THROW 50010, @errMsg, @errState;
		END;

	IF NOT EXISTS (SELECT invoiceNumber FROM office.Invoice
								 WHERE @customerID = customerID AND @invoiceNumber = invoiceNumber
								)
		BEGIN 
			SELECT @errMsg = N'No invoice found with given invoice number.', @errState = 2;
			THROW 50010, @errMsg, @errState;
		END;
		
	BEGIN TRAN;
		DELETE
		FROM office.Invoice
		WHERE @customerID = customerID AND @invoiceNumber = invoiceNumber;
	COMMIT TRAN;
	PRINT (N'Invoice is set to void. Negative pair was created.');
END TRY
BEGIN CATCH
	IF @@TRANCOUNT > 0 ROLLBACK TRAN;
	
	SET @cmd = 'ALTER SEQUENCE ' + QUOTENAME('office') + '.' + QUOTENAME('Counter') + 
						 ' RESTART WITH ' + CAST(@counterMax + 1 AS varchar);
	EXEC sp_executesql @cmd;
	
	SET @errMsg = N'Invoice deletion failed. ' + @errMsg;
	EXEC dbadmin.error_handler @errMsg, @errState;
	RETURN (-1);
END CATCH;
GO 


--SP to add new Employee
CREATE OR ALTER PROC [office].[addStaffMember] (
	@staffName nvarchar(80) 
	,@passNumber varchar(10) = NULL 
	,@salary int 
	,@dateHired date = NULL
	,@isTech bit = 0 
	,@isOffice bit = 0 
	,@isPatrol bit = 0 
	,@isDispatcher bit = 0 
	,@workplaceID int 
	,@carID int = NULL 
	,@SIMid int = NULL 
)
AS
SET XACT_ABORT, NOCOUNT ON;
BEGIN TRY
	DECLARE @errMsg nvarchar(2048);
	DECLARE @errState tinyint; 
		
	IF @dateHired IS NULL SET @dateHired = GETDATE();
	
	BEGIN TRAN
		INSERT INTO office.Staff (staffName, passNumber, salary, dateHired, isTech, isOffice, 
															isPatrol, isDispatcher, workplaceID, carID, SIMid)
		VALUES (@staffName, @passNumber, @salary, @dateHired, @isTech, @isOffice, @isPatrol,
						@isDispatcher, @workplaceID, @carID, @SIMid);
	COMMIT TRAN;
	PRINT (N'Employee registered.');
END TRY
BEGIN CATCH
	IF @@TRANCOUNT > 0 ROLLBACK TRAN;
	SET @errMsg = N'Empolyee registration failed. ' + @errMsg;
	EXEC dbadmin.error_handler @errMsg, @errState;
	RETURN (-1);
END CATCH;
GO 


--SP to modify existing member
CREATE OR ALTER PROC [office].[modStaffMember] (
		@staffid int
		,@staffName nvarchar(80) = NULL
		,@passNumber varchar(10) = NULL 
		,@salary int = NULL 
		,@dateHired date = NULL 
		,@isTech bit = NULL
		,@isOffice bit = NULL
		,@isPatrol bit = NULL
		,@isDispatcher bit = NULL 
		,@workplaceID int = NULL 
		,@carID int = NULL 
		,@SIMid int = NULL
)
AS
SET XACT_ABORT, NOCOUNT ON;
BEGIN TRY
	DECLARE @errMsg nvarchar(2048);
	DECLARE @errState tinyint; 
	
	IF NOT EXISTS (SELECT id FROM office.Staff WHERE isActive = 1 AND @staffid = id)
		BEGIN 
			SELECT @errMsg = N'No such employee. Invalid user ID.', @errState = 1;
			THROW 50010, @errMsg, @errState;
		END;
		
	BEGIN TRAN;
		UPDATE office.Staff
		SET	staffName = ISNULL(@staffName, staffName)
				,passNumber = ISNULL(@passNumber, passNumber)
				,salary = ISNULL(@salary, salary)
				,dateHired = ISNULL(@dateHired, dateHired)
				,isTech = ISNULL(@isTech, isTech)
				,isOffice = ISNULL(@isOffice, isOffice)
				,isPatrol = ISNULL(@isPatrol, isPatrol)
				,isDispatcher = ISNULL(@isDispatcher, isDispatcher)
				,workplaceID = ISNULL(@workplaceID, workplaceID)
				,carID = ISNULL(@carID, carID)
				,SIMid = ISNULL(@SIMid, SIMid)
		FROM office.Staff
		WHERE id = @staffid;
	COMMIT TRAN;
	PRINT (N'Employee update succeeded.');
END TRY
BEGIN CATCH
	IF @@TRANCOUNT > 0 ROLLBACK TRAN;
	SET @errMsg = N'Employee update failed. ' + @errMsg;
	EXEC dbadmin.error_handler @errMsg, @errState;
	RETURN (-1);
END CATCH;
GO 


--SP to delete Employee
--upon deletion only isActive is set to 0 and terminition date is set to current date
CREATE OR ALTER PROC [office].[delStaffMember] (
		@staffid int
)
AS
SET XACT_ABORT, NOCOUNT ON;
BEGIN TRY
	DECLARE @errMsg nvarchar(2048);
	DECLARE @errState tinyint; 
	
	IF NOT EXISTS (SELECT id FROM office.Staff WHERE isActive = 1 AND @staffid = id)
		BEGIN 
			SELECT @errMsg = N'No such employee. Invalid user ID.', @errState = 1;
			THROW 50010, @errMsg, @errState;
		END;
	
	BEGIN TRAN;
		DELETE
		FROM office.Staff
		WHERE id = @staffid;
	COMMIT TRAN;
	PRINT (N'Employee deleted.')
END TRY
BEGIN CATCH
	IF @@TRANCOUNT > 0 ROLLBACK TRAN;
	SET @errMsg = N'Employee deletion failed. ' + @errMsg;
	EXEC dbadmin.error_handler @errMsg, @errState;
	RETURN (-1);
END CATCH;
GO 


--=============== CREATE TRIGGERS ===============
--SIM (GPRS device) trigger - when GPRS device is applied / changed
CREATE OR ALTER TRIGGER [tech].[trgDeviceUpdate]
ON tech.Device
AFTER INSERT, UPDATE   
AS
BEGIN 
	SET NOCOUNT ON;
	
	UPDATE o
	SET dateIssued = NULL, isIssued = 0
	FROM office.SIM AS o
	INNER JOIN deleted AS d ON o.id IN (ISNULL(d.firstSIM,0), ISNULL(d.secondSIM,0));
	
	UPDATE o
	SET dateIssued = GETDATE(), isIssued = 1
	FROM office.SIM AS o
	INNER JOIN inserted AS i ON o.id IN (ISNULL(i.firstSIM,0), ISNULL(i.secondSIM,0));	
END;
GO 


--SIM (GPRS device) trigger - when GPRS device is deleted 
CREATE OR ALTER TRIGGER [tech].[trgDeviceDelete]
ON tech.Device
INSTEAD OF DELETE  
AS
BEGIN TRY 
	SET NOCOUNT ON;
	DECLARE @errMsg nvarchar(2048);
	DECLARE @errState tinyint; 
	
	IF EXISTS (SELECT 1
						 FROM office.Customer AS c
						 INNER JOIN deleted AS d ON c.deviceID IN (d.id)
						 WHERE c.isDeleted = 0)
		BEGIN 
			SELECT @errMsg = N'Device is assigned to existing customer. Can''t delete.', @errState = 1;
			THROW 50010, @errMsg, @errState;
		END;
	
	UPDATE t
	SET firstSIM = NULL, secondSIM = NULL
	FROM tech.Device AS t
	INNER JOIN deleted AS d ON t.id IN (d.id);
END TRY
BEGIN CATCH
	EXEC dbadmin.error_handler @errMsg, @errState;
END CATCH;
GO 

--SIM (Staff) trigger - when SIM is applied to new employee
CREATE OR ALTER TRIGGER [office].[trgStaffIns]
ON office.Staff
AFTER INSERT
AS
BEGIN 
	SET NOCOUNT ON;
	
	--if there was no tech employee, distribute Customers for newcomers
	IF (SELECT installerID  
			FROM office.Customer
			WHERE id = 1) IS NULL 
		BEGIN 
			UPDATE office.Customer
			SET installerID = (SELECT tech.randomInst())
			FROM office.Customer
			WHERE office.Customer.id % 3 = 1;
			
			UPDATE office.Customer
			SET installerID = (SELECT tech.randomInst())
			FROM office.Customer
			WHERE office.Customer.id % 4 = 2;
			
			UPDATE office.Customer
			SET installerID = (SELECT tech.randomInst())
			FROM office.Customer
			WHERE office.Customer.id % 2 = 1;
			
			UPDATE office.Customer
			SET installerID = (SELECT tech.randomInst())
			FROM office.Customer
			WHERE office.Customer.installerID IS NULL 
		END;
		
	--update SIM cards
	UPDATE o
	SET dateIssued = GETDATE(), isIssued = 1
	FROM office.SIM AS o
	INNER JOIN inserted AS i ON o.id IN (i.SIMid);
END;
GO 


--SIM (Staff) trigger - when SIM is applied / changed 
CREATE OR ALTER TRIGGER [office].[trgStaffUp]
ON office.Staff
AFTER UPDATE   
AS
BEGIN 
	SET NOCOUNT ON;

	--if it's a dispacth and not the last one, fake update SIM
	--preserve SIM(s) current data in a temp table 'fooling' the update
	IF EXISTS (SELECT 1 
						 FROM deleted 
						 WHERE isDispatcher = 1 
						 AND 0 <> (SELECT COUNT(*) FROM office.Staff WHERE isDispatcher = 1) - 
						 				 (SELECT COUNT(*) FROM deleted WHERE isDispatcher = 1))
		BEGIN
			SELECT TOP 1 sta.SIMid, sim.dateIssued INTO #simTemp 
			FROM office.staff AS sta
			INNER JOIN office.SIM AS sim ON sim.id = sta.SIMid
			INNER JOIN deleted AS d ON d.SIMid = sim.id
			WHERE sta.isDispatcher = 1;
		END;			
		
	--update SIM cards 
	UPDATE o
	SET isIssued = 0, dateIssued = NULL
	FROM office.SIM AS o
	LEFT JOIN inserted AS i ON o.id IN (i.SIMid)
	LEFT JOIN deleted AS d ON o.id IN (d.SIMid)
	WHERE ISNULL(i.SIMid, 0) <> ISNULL(d.SIMid, 0) AND o.id = d.SIMid
				OR d.SIMid IS NULL AND o.id = i.SIMid;
	
	UPDATE o
  SET dateIssued = GETDATE(), isIssued = 1
  FROM office.SIM AS o
  LEFT JOIN inserted AS i ON o.id IN (i.SIMid)
	LEFT JOIN deleted AS d ON o.id IN (d.SIMid)
	WHERE ISNULL(i.SIMid, 0) <> ISNULL(d.SIMid, 0) AND o.id = i.SIMid;
				
	--let's 'fool update' with dispacth mobil
	IF 0 <= (SELECT COUNT(*) FROM office.Staff WHERE isDispatcher = 1)  - 
 					(SELECT COUNT(*) FROM deleted WHERE isDispatcher = 1)
		IF OBJECT_ID('tempdb..#simTemp', 'U') IS NOT NULL 
			BEGIN
				UPDATE sim
				SET isIssued = 1, dateIssued = (SELECT dateIssued FROM #simTemp)
				FROM office.SIM AS sim
				INNER JOIN #simTemp ON #simTemp.SIMid = sim.id;
				
				DROP TABLE #simTemp;
			END;
END;
GO 


--SIM (Staff) trigger - on employee quit make SIM reusable 
CREATE OR ALTER TRIGGER [office].[trgStaffDel]
ON office.Staff
INSTEAD OF DELETE   
AS
BEGIN 
	SET NOCOUNT ON;
	
	--randomly distribute Customers through the rest of installers, if isTech is to be deleted
	IF EXISTS (SELECT office.Staff.id 
						 FROM office.Staff 
						 INNER JOIN deleted ON office.Staff.id IN (deleted.id) 
						 WHERE office.Staff.isTech = 1)
		BEGIN 
			UPDATE office.Customer
			SET installerID = (SELECT TOP 1 office.Staff.id 
												 FROM office.Staff 
												 WHERE office.Staff.isTech = 1 
												 AND NOT EXISTS (SELECT deleted.id 
											                   FROM deleted
                      									 WHERE deleted.id = office.Staff.id)
												 ORDER BY NEWID())
			FROM office.Customer
			INNER JOIN deleted ON office.Customer.installerID IN (deleted.id)
			WHERE office.Customer.id % 3 = 1;
			
			UPDATE office.Customer
			SET installerID = (SELECT TOP 1 office.Staff.id 
												 FROM office.Staff 
												 WHERE office.Staff.isTech = 1 
												 AND NOT EXISTS (SELECT deleted.id 
											                   FROM deleted
                      									 WHERE deleted.id = office.Staff.id)
												 ORDER BY NEWID())
			FROM office.Customer
			INNER JOIN deleted ON office.Customer.installerID IN (deleted.id)
			WHERE office.Customer.id % 4 = 2;
			
			UPDATE office.Customer
			SET installerID = (SELECT TOP 1 office.Staff.id 
												 FROM office.Staff 
												 WHERE office.Staff.isTech = 1 
												 AND NOT EXISTS (SELECT deleted.id 
											                   FROM deleted
                      									 WHERE deleted.id = office.Staff.id)
												 ORDER BY NEWID())
			FROM office.Customer
			INNER JOIN deleted ON office.Customer.installerID IN (deleted.id)
			WHERE office.Customer.id % 3 = 2;
			
			UPDATE office.Customer
			SET installerID = (SELECT TOP 1 office.Staff.id 
												 FROM office.Staff 
												 WHERE office.Staff.isTech = 1 
												 AND NOT EXISTS (SELECT deleted.id 
											                   FROM deleted
                      									 WHERE deleted.id = office.Staff.id)
												 ORDER BY NEWID())
			FROM office.Customer
			INNER JOIN deleted ON office.Customer.installerID IN (deleted.id);
		END;
			
		--there's no references to the tech employee any more, it can be deleted (updated only)
		--will invoke AFTER UPDATE trigger
		UPDATE o
		SET terminationDate = GETDATE()
				,isTech = 0
				,isOffice = 0
				,isPatrol = 0
				,isDispatcher = 0
				,isActive = 0
				,passNumber = NULL
				,workplaceID = NULL
				,SIMid = NULL 
				,carID = NULL
		FROM office.Staff AS o
		INNER JOIN deleted AS d ON o.id IN (d.id);
END;
GO 


--INVOICE trigger to be activated on office.Invoice deletion
CREATE OR ALTER TRIGGER [office].[trgInvoiceDel]
ON office.Invoice
INSTEAD OF DELETE   
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @isDeleted bit = 0;

	UPDATE o
	SET isDeleted = 1
	FROM office.Invoice AS o
	INNER JOIN deleted AS d ON o.invoiceNumber IN (d.id);
	
	--create the negativ pair of the invoice
	INSERT INTO office.Invoice 
	SELECT customerID
				,NEXT VALUE FOR office.Counter
				,invoiceDate
				,invoiceDueDate
				,unitDescription
				,unitPrice * -1
				,quantity
				,N'Canceled invoice: ' + CAST(deleted.invoiceNumber AS varchar(6)) + ' - ' + description
				,isViaMail
				,@isDeleted
	FROM deleted;
END;
GO

--PAYMENT trigger to keep status updated on office.Payment INSERT / UPDATE
CREATE OR ALTER TRIGGER [office].[trgPayStatusUp]
ON office.Payment
AFTER INSERT, UPDATE
AS
BEGIN
	SET NOCOUNT ON;

	WITH paymentTotal AS (
		SELECT offp.invoiceID AS payTotID
					,SUM(offp.amount) AS sumAmount
		FROM office.Payment AS offp
		GROUP BY offp.invoiceID
	)
	UPDATE p
	SET status = CASE 
								 WHEN (SELECT (unitPrice * quantity * 1.27) - sumAmount
								 			 FROM office.Invoice AS offi
								 			 WHERE offi.invoiceNumber = p.invoiceID
								 			) = 0 THEN NULL
								 WHEN (SELECT (unitPrice * quantity * 1.27) - sumAmount
								 			 FROM office.Invoice AS offi
								 			 WHERE offi.invoiceNumber = p.invoiceID
								 			) > 0 THEN 0
								 ELSE 1
							 END 
	FROM office.Payment AS p
	INNER JOIN paymentTotal ON p.invoiceID IN (payTotID)
	WHERE p.invoiceID IN (SELECT invoiceID FROM inserted);
END;
GO 

--PAYMENT trigger to keep status updated on office.Payment DELETE
CREATE OR ALTER TRIGGER [office].[trgPayStatusDel]
ON office.Payment
AFTER DELETE 
AS
BEGIN
	SET NOCOUNT ON;

	WITH paymentTotal AS (
		SELECT offp.invoiceID AS payTotID
					,SUM(offp.amount) AS sumAmount
		FROM office.Payment AS offp
		GROUP BY offp.invoiceID
	)
	UPDATE p
	SET status = CASE 
								 WHEN (SELECT (unitPrice * quantity * 1.27) - sumAmount
								 			 FROM office.Invoice AS offi
								 			 WHERE offi.invoiceNumber = p.invoiceID
								 			) = 0 THEN NULL
								 WHEN (SELECT (unitPrice * quantity * 1.27) - sumAmount
								 			 FROM office.Invoice AS offi
								 			 WHERE offi.invoiceNumber = p.invoiceID
								 			) > 0 THEN 0
								 ELSE 1
							 END 
	FROM office.Payment AS p
	INNER JOIN paymentTotal ON p.invoiceID IN (payTotID)
	WHERE p.invoiceID IN (SELECT invoiceID FROM deleted);
END;
GO 


--=============== CREATE USERS AND ROLES ===============
DROP USER IF EXISTS [officestaff];
DROP USER IF EXISTS [technicians];
DROP USER IF EXISTS [dispatchers];

DROP ROLE IF EXISTS [officeRole];
DROP ROLE IF EXISTS [techRole];
DROP ROLE IF EXISTS [dispRole];
GO 

CREATE USER [officestaff] WITHOUT LOGIN
WITH DEFAULT_SCHEMA = [office];

CREATE USER [technicians] WITHOUT LOGIN
WITH DEFAULT_SCHEMA = [tech];

CREATE USER [dispatchers] WITHOUT LOGIN
WITH DEFAULT_SCHEMA = [patrol];

CREATE ROLE [techRole];
CREATE ROLE [dispRole];
CREATE ROLE [officeRole];

ALTER ROLE [techRole] ADD MEMBER [technicians];
ALTER ROLE [dispRole] ADD MEMBER [dispatchers];
ALTER ROLE [officeRole] ADD MEMBER [officestaff];
GO 


--=============== SET ROLE PERMISSIONS ===============
--technicians
GRANT SELECT ON SCHEMA::[office] TO [techRole];
GRANT SELECT ON SCHEMA::[patrol] TO [techRole];
GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE ON SCHEMA::[tech] TO [techRole];
GRANT EXECUTE ON [office].[customerBalance] TO [techRole];
GRANT EXECUTE ON [office].[custBalance] TO [techRole];
DENY SELECT ON [office].[Invoice] TO [techRole];
DENY SELECT ON [office].[Payment] TO [techRole];
DENY SELECT ON [office].[SIM] TO [techRole];
DENY SELECT ON [office].[Staff] TO [techRole];
DENY SELECT ON [office].[Workplace] TO [techRole];
DENY SELECT ON [office].[customerDue] TO [techRole];
DENY SELECT ON [office].[vAccount] TO [techRole];
DENY SELECT ON [patrol].[Car] TO [techRole];
DENY SELECT ON [patrol].[Patrol] TO [techRole];
DENY SELECT ON [patrol].[vAlarm] TO [techRole];
DENY SELECT ON [patrol].[ReceivedSignal] (dispatcherID, timePatrolstart, timePatrolOnSpot, patrolID) TO [techRole];
DENY SELECT ON [patrol].[findNextXPatrol] TO [techRole];
DENY CONTROL ON SCHEMA::[dbadmin] TO [techRole];
GO 
 

--dispatchers
GRANT SELECT ON SCHEMA::[office] TO [dispRole];
GRANT SELECT ON SCHEMA::[tech] TO [dispRole];
GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE ON SCHEMA::[patrol] TO [dispRole];
GRANT EXECUTE ON [tech].[phoneFormat] TO [dispRole];
GRANT UNMASK TO [dispRole];
DENY DELETE ON [patrol].[ReceivedSignal] TO [dispRole];
DENY UPDATE ON [patrol].[ReceivedSignal] (customerID, zoneNumber, timeReceived) TO [dispRole];
DENY SELECT ON [office].[Customer] (serviceFee) TO [dispRole];
DENY SELECT ON [office].[CustomerArchive] TO [dispRole];
DENY SELECT ON [office].[Invoice] TO [dispRole];
DENY SELECT ON [office].[Payment] TO [dispRole];
DENY SELECT ON [office].[SIM] TO [dispRole];
DENY SELECT ON [office].[Staff] TO [dispRole];
DENY SELECT ON [office].[SubscriptionType] TO [dispRole];
DENY SELECT ON [office].[Workplace] TO [dispRole];
DENY SELECT ON [office].[vAccount] TO [dispRole];
DENY SELECT ON [office].[customerDue] TO [dispRole];
DENY SELECT ON [tech].[Device] TO [dispRole];
DENY SELECT ON [tech].[DeviceType] TO [dispRole];
DENY SELECT ON [tech].[vTechnical] TO [dispRole];
DENY CONTROL ON SCHEMA::[dbadmin] TO [dispRole];
GO 


--office
GRANT SELECT ON SCHEMA::[patrol] TO [officeRole];
GRANT SELECT ON SCHEMA::[tech] TO [officeRole];
GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE ON SCHEMA::[office] TO [officeRole];
GRANT ALTER ON OBJECT::[office].[Counter] TO [officeRole];
GRANT EXECUTE ON [tech].[chkSIM] TO [officeRole];
GRANT EXECUTE ON [tech].[phoneFormat] TO [officeRole];
GRANT EXECUTE ON [tech].[randomInst] TO [officeRole];
GRANT UNMASK TO [officeRole];
DENY INSERT, UPDATE, DELETE ON [office].[Customer] TO [officeRole];
DENY INSERT, UPDATE, DELETE ON [office].[Invoice] TO [officeRole];
DENY UPDATE ON [office].[SIM] TO [officeRole];
DENY SELECT ON [tech].[Device] TO [officeRole];
DENY SELECT ON [tech].[DeviceType] TO [officeRole];
DENY SELECT ON [tech].[vTechnical] TO [officeRole];
DENY SELECT ON [patrol].[Car] TO [officeRole];
DENY SELECT ON [patrol].[Patrol] TO [officeRole];
DENY SELECT ON [patrol].[vAlarm] TO [officeRole];
DENY SELECT ON [patrol].[findNextXPatrol] TO [officeRole];
DENY CONTROL ON SCHEMA::[dbadmin] TO [officeRole];
GO 

