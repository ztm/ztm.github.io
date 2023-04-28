--script to insert sample data into the tables
--Customer and Invoice tables must be filled 
--with their respective stored procedures

USE [AlarmFirst];
GO 

--insert some values into the Workplace table
INSERT INTO [office].[Workplace] (city, district, description, code)
VALUES	(N'Budapest', 'XIII.', N'Headquarters', N'HQ'),
				(N'Budapest', 'XIII.', N'Technicians', N'TECH'),
				(N'Budapest', 'XIII.', N'Dispatcher', N'DISP'),
				(N'Pécs', NULL, N'Office and Storage', N'PECS'),
				(N'Budapest', 'I.', N'Patrol - 1st district', N'P1'),
				(N'Budapest', 'II.', N'Patrol - 2nd district', N'P2'),
				(N'Budapest', 'III.', N'Patrol - 3rd district', N'P3'),
				(N'Tatabánya', NULL, N'Patrol - Tatabánya', N'PTAT'),
				(N'Siófok', N'Balaton', N'Patrol - DK-Balaton', N'PBAL');
GO


--insert some values into the Car table
INSERT INTO [patrol].[Car] (licensePlate, coveredDistance, carGeoData,
														lastInspectionDate, nextMOTtestKM, make, model, productionYear)
VALUES	(N'ABC-123', 2345, geography::Point(47.508512, 19.027334, 4326), '20220516', 15000, N'Suzuki', N'Swift', 2018),
				(N'ABC-124', 12435, geography::Point(47.523112, 19.017134, 4326), '20211204', 15000, N'Suzuki', N'Swift', 2019),
				(N'ABC-125', 118369, geography::Point(47.524212, 19.067413, 4326), '20220625', 120000, N'Suzuki', N'Swift', 2018),
				(N'RAC-452', 16598, geography::Point(47.596031, 19.120753, 4326), '20210405', 30000, N'Suzuki', N'Baleno', 2020),
				(N'RAC-453', 17598, geography::Point(47.406183, 19.203353, 4326), '20210505', 30000, N'Suzuki', N'Swift', 2020),
				(N'RAC-454', 18598, geography::Point(47.416359, 19.002418, 4326), '20210805', 30000, N'Suzuki', N'Swift', 2020),
				(N'RAC-455', 19598, geography::Point(47.431641, 19.209188, 4326), '20210705', 30000, N'Suzuki', N'Baleno', 2020),
				(N'GHK-253', 120598, geography::Point(46.064313, 18.152490, 4326), '20220405', 135000, N'Suzuki', N'Baleno', 2020),
				(N'GHK-254', 135258, geography::Point(46.909471, 18.067100, 4326), '20220129', 150000, N'Dacia', N'Duster', 2016),
				(N'GHK-255', 121598, geography::Point(47.562493, 18.415468, 4326), '20220405', 135000, N'Renault', N'Clio', 2020);
GO 


--insert some values into the SIM table
INSERT INTO [office].[SIM] (SIMnumber, phoneNumber, isData)
VALUES	('89311612652718444915', '302549874', 1),
				('89216303428812532268', '301258947', 1),
				('89216015780153622036', '208624455', 1),
				('89216011378730694703', '203786255', 1),
				('89216308464661865851', '307025896', 1),
				('78931161265271844491', '702567874', 1),
				('79216303428812532262', '701258947', 1),
				('79216015780153622033', '708667455', 1),
				('79216011378730694704', '703766255', 1),
				('79216308464661865855', '707028996', 1),
				('89216308464661865852', '304025897', 0),
				('89216306682166477713', '304589621', 0),
				('89216306682166477714', '304589622', 0),
				('89216306682166477715', '304589623', 0),
				('89216306682166477716', '304589624', 0),
				('89216306682166477717', '304589625', 0),
				('89216306682166477718', '304589626', 0),
				('79216308464661865856', '704034897', 0),
				('79216306682166477717', '704589245', 0),
				('79216306682166477718', '704589667', 0),
				('79216306682166477719', '704589656', 0),
				('79216306682166477710', '704523624', 0),
				('79216306682166477711', '704589264', 0),
				('79216306682166477712', '704539627', 0);
GO


--insert some values into the Staff table
EXEC office.addStaffMember
	@staffName = N'Tech János' 
	,@passNumber = N'SZ002564' 
	,@salary = 350000
	,@dateHired = '20140501'
	,@isTech = 1 
	,@workplaceID = 2 
	,@carID = 1
	,@SIMid = 11;
EXEC office.addStaffMember
	@staffName = N'Szerelő Péter' 
	,@passNumber = N'SZ001534' 
	,@salary = 350000
	,@dateHired = '20180322'
	,@isTech = 1 
	,@workplaceID = 2 
	,@carID = 2
	,@SIMid = 12;
EXEC office.addStaffMember
	@staffName = N'Office Aranka' 
	,@salary = 280000
	,@dateHired = '20190901'
	,@isOffice = 1 
	,@workplaceID = 1 
	,@SIMid = 13;
EXEC office.addStaffMember
	@staffName = N'Irodai Zsuzsa' 
	,@salary = 280000
	,@dateHired = '20160301'
	,@isOffice = 1 
	,@workplaceID = 1 
	,@SIMid = 14;
EXEC office.addStaffMember
	@staffName = N'Patrol Péter' 
	,@salary = 325000
	,@dateHired = '20170701'
	,@isPatrol = 1 
	,@workplaceID = 5 
	,@carID = 5
	,@SIMid = 15;
EXEC office.addStaffMember
	@staffName = N'Járőr Balázs' 
	,@salary = 325000
	,@dateHired = '20131201'
	,@isPatrol = 1 
	,@workplaceID = 5 
	,@carID = 6
	,@SIMid = 16;
EXEC office.addStaffMember
	@staffName = N'Disp Béla' 
	,@salary = 288000
	,@dateHired = '20160520'
	,@isDispatcher = 1 
	,@workplaceID = 3
	,@SIMid = 17;
EXEC office.addStaffMember
	@staffName = N'Disp Beatrix' 
	,@salary = 290000
	,@dateHired = '20160520'
	,@isDispatcher = 1 
	,@workplaceID = 3
	,@SIMid = 17;
EXEC office.addStaffMember 
	@staffName = N'PróbaTech Ernő'
	,@passNumber = N'ABC1258'
	,@salary = 250000
	,@isTech = 1
	,@workplaceID = 1;
EXEC office.addStaffMember 
	@staffName = N'Irodai Jenő'
	,@salary = 325000
	,@isOffice = 1
	,@workplaceID = 1;
EXEC office.addStaffMember 
	@staffName = N'Mappa Piroska'
	,@salary = 280000
	,@isDispatcher = 1
	,@workplaceID = 2;
EXEC office.addStaffMember 
	@staffName = N'Gyors Géza'
	,@salary = 280000
	,@isPatrol = 1
	,@workplaceID = 1
	,@carID = 7
	,@SIMid = 18;
EXEC office.addStaffMember 
	@staffName = N'Ütős Mátyás'
	,@salary = 280000
	,@isPatrol = 1
	,@workplaceID = 4
	,@carID = 4
	,@SIMid = 19;
EXEC office.addStaffMember 
	@staffName = N'Darab Gizi'
	,@salary = 280000
	,@isPatrol = 1
	,@workplaceID = 5
	,@carID = 8
	,@SIMid = 20;
EXEC office.addStaffMember 
	@staffName = N'Erős Pista'
	,@salary = 280000
	,@isPatrol = 1
	,@workplaceID = 6
	,@carID = 9
	,@SIMid = 21;
EXEC office.addStaffMember 
	@staffName = N'Járőr Misi'
	,@salary = 280000
	,@isPatrol = 1
	,@workplaceID = 8
	,@carID = 10
	,@SIMid = 22;
GO 

 
--insert some values into the Patrol table
INSERT INTO [patrol].[Patrol] (dutyStart, dutyEnd, staffID, isArmed, isOnCase)
VALUES	('2022-02-20T07:00:00', '2022-02-20T19:00:00', 6, 0, 0),
				('2022-02-21T07:00:00', '2022-02-21T19:00:00', 7, 1, 0),
				('2022-02-22T07:00:00', '2022-02-22T19:00:00', 7, 1, 0),
				('2022-02-23T07:00:00', '2022-02-23T19:00:00', 13, 0, 0),
				('2022-02-24T07:00:00', '2022-02-24T19:00:00', 6, 0, 0),
				('2022-02-24T07:00:00', '2022-02-24T19:00:00', 13, 0, 0),
				('2022-02-24T07:00:00', '2022-02-24T19:00:00', 14, 1, 0),
				('2022-02-24T07:00:00', '2022-02-24T19:00:00', 16, 0, 1),
				('2022-02-25T07:00:00', '2022-02-26T07:00:00', 7, 1, 0);
GO 


--insert some values into the SubscriptionType table
INSERT INTO [office].[SubscriptionType] (code, description, price, validFrom, validUntil, isDiscount)
VALUES	(N'FULLM', N'Full price monitoring service',	80000, '20020101', '99990101', 0),
				(N'2YMO',  N'2-year monitoring',							16000, '20180101', '99990101', 1),
				(N'3YMO',  N'3-year monitoring ',							5000,  '20190101', '99990101', 1),
				(N'DSCMI',	N'DSC mini kit with monitoring',	50000, '20200101', '99990101', 1),
				(N'PARMAX', N'Paradox maxi kit',							95000, '20220405', '20220601', 1),
				(N'ELWKIT', N'EL Wireless Basic kit',					48000, '20200101', '20201231', 1);
GO 


--insert some values into the DeviceType table
INSERT INTO [tech].[DeviceType] (code, protocol, description, lifeTimeCycle, TSTcode, TSTfailedCode, 
																 encoderType, receiver)
VALUES	(N'RAD0', N'UHF',		N'UHF Net-0',					24, N'PTS', N'NSR', 1, N'RCV-0'),
				(N'RAD1', N'UHF',		N'UHF Net-1',	 				24, N'PTS', N'NSR', 2, N'RCV-1'),
				(N'RGVG', N'GPRS',	N'CID RG-Type',				2,  N'PTS', N'NSR', 3, N'RCV-3'),
				(N'ELDS', N'GPRS',	N'CID Eldes', 				12, N'PT2', N'NSR', 3, N'SZTE'),
				(N'RG41', N'GPRS',	N'DoubleSIM Fire', 		1,  N'LCT', N'NSA', 5, N'RCV-FIRE'),
				(N'RIVI', N'IP',		N'CID RG-Type',				12,	N'PTT', N'NSR', 7, N'IP-CONV');
GO


--insert some values into the Device table
INSERT INTO [tech].[Device] (lineNumber, deviceNumber, serial, IMEI, deviceTypeID)
VALUES 	(1,		1000, NULL, NULL, 2),
				(0, 	3800, NULL, NULL, 1),
				(33, 	6600, N'568947',	N'338415254330254', 4),
				(90, 	6600, N'0560',		N'914216981316166', 3),
				(93, 	6600, N'1601',		N'989217581316566', 5),
				(3, 	2000, NULL, NULL, 2),
				(3, 	2100, NULL, NULL, 2),
				(1, 	2000, NULL, NULL, 2),
				(1, 	2100, NULL, NULL, 2),
				(90, 	6700, N'1562',		N'789217581316554', 3),
				(90, 	6800, N'2589',		N'989217581316593', 3),
				(33, 	6700, N'569852',	N'589217596316585', 4),
				(33, 	6800, N'236985',	N'489218581316545', 4);
GO 


--insert some values into the Customer table
EXEC office.addCustomer 
	@lineNumber = 1
	,@deviceNumber = 1000
	,@cancelCode = N'1201'
	,@customerName = N'Customer1 Bálint'
	,@customerCity = N'Budapest' 
	,@customerAddress = N'Első u. 1.' 
	,@customerZIP = N'1111'
	,@customerLAT = 47.509512
	,@customerLONG = 19.017334
	,@customerPhone = N'301231111'
	,@customerEmail = N'cbalint@gmail.com'
	,@serviceFee = 1000
	,@invoiceName = N'Customer1 Bálintné'
	,@invoiceCity = N'Budapest'
	,@invoiceAddress = N'Első tér 11.'
	,@invoiceZIP = N'1111' 
	,@isCompany = 0
	,@contractDate = '2020-06-11'
	,@note = N'no elevator' 
	,@category = N'family house'
	,@subscriptionID = 1
	,@installerID = 2;
EXEC office.addCustomer 
	@lineNumber = 0
	,@deviceNumber = 3800
	,@cancelCode = N'1202'
	,@customerName = N'Customer2 Péter'
	,@customerCity = N'Tatabánya' 
	,@customerAddress = N'Második út 2.' 
	,@customerZIP = N'2222'
	,@customerLAT = 48.509556
	,@customerLONG = 20.017378
	,@customerPhone = N'301231112'
	,@customerEmail = N'cpeter@gmail.com'
	,@serviceFee = 2000
	,@invoiceName = N'Customer2 Kft.'
	,@invoiceCity = N'Tatabánya'
	,@invoiceAddress = N'Második út 2.'
	,@invoiceZIP = N'2222' 
	,@isCompany = 1
	,@invoiceTaxNumber = N'12345678-41-1'
	,@contractDate = '2020-06-11'
	,@category = N'apartment'
	,@subscriptionID = 2
	,@installerID = 1;
EXEC office.addCustomer 
	@lineNumber = 33
	,@deviceNumber = 6600
	,@firstSIM = 1
	,@cancelCode = N'1203'
	,@customerName = N'Customer3 Éva'
	,@customerCity = N'Budapest' 
	,@customerAddress = N'Harmadik u. 3.' 
	,@customerZIP = N'3333'
	,@customerLAT = 49.509509
	,@customerLONG = 21.017301
	,@customerPhone = N'301231113'
	,@customerEmail = N'ceva@gmail.com'
	,@serviceFee = 3000
	,@contractDate = '2020-06-11'
	,@note = N'dog bites'
	,@category = N'apartment'
	,@subscriptionID = 3
	,@installerID = 2;
EXEC office.addCustomer 
	@lineNumber = 90
	,@deviceNumber = 6600
	,@firstSIM = 2
	,@cancelCode = N'1204'
	,@customerName = N'Customer4 Zsuzsa'
	,@customerCity = N'Pécs' 
	,@customerAddress = N'Negyedik st. 4.' 
	,@customerZIP = N'4444'
	,@customerLAT = 50.509500
	,@customerLONG = 22.017312
	,@customerPhone = N'301231114'
	,@serviceFee = 4000
	,@invoiceName = N'Customer4 Bt.'
	,@invoiceCity = N'Győr'
	,@invoiceAddress = N'Győri út 14.'
	,@invoiceZIP = N'7788' 
	,@isCompany = 1
	,@invoiceTaxNumber = N'87654321-42-1'
	,@contractDate = '2020-06-11'
	,@category = N'family house'
	,@subscriptionID = 4
	,@installerID = 1;
EXEC office.addCustomer 
	@lineNumber = 93
	,@deviceNumber = 6600
	,@firstSIM = 5
	,@secondSIM = 7
	,@cancelCode = N'1205'
	,@customerName = N'Customer5 Zrt.'
	,@customerCity = N'Budapest' 
	,@customerAddress = N'Ötödik tér 5.' 
	,@customerZIP = N'5555'
	,@customerLAT = 51.509561
	,@customerLONG = 23.017353
	,@customerPhone = N'301231115'
	,@customerEmail = N'czrt@gmail.com'
	,@serviceFee = 5000
	,@invoiceName = N'Customer5 Zrt.'
	,@invoiceCity = N'Budapest'
	,@invoiceAddress = N'Ötödik tér 5.'
	,@invoiceZIP = N'5522' 
	,@isCompany = 1
	,@invoiceTaxNumber = N'23568974-41-1'
	,@contractDate = '2020-06-11'
	,@note = N'hard to get there'
	,@category = N'supermarket'
	,@subscriptionID = 5
	,@installerID = 2;
EXEC office.addCustomer 
	@lineNumber = 3
	,@deviceNumber = 2000
	,@cancelCode = N'm@rlb0ro'
	,@customerName = N'Customer6 Zsuzsa'
	,@customerCity = N'Pécs' 
	,@customerAddress = N'Hatodik tér 6' 
	,@customerZIP = N'6666'
	,@customerLAT = 46.031420
	,@customerLONG = 18.232079
	,@customerPhone = N'706666655'
	,@serviceFee = 6660
	,@isCompany = 0
	,@contractDate = '2020-06-11'
	,@note = N'Has dog!' 
	,@category = N'family house'
	,@subscriptionID = 5
	,@installerID = 9;
EXEC office.addCustomer 
	@lineNumber = 90
	,@deviceNumber = 6700
	,@firstSIM = 9
	,@secondSIM = 10
	,@cancelCode = N'hétszerhét'
	,@customerName = N'Customer7 Egon'
	,@customerCity = N'Budapest' 
	,@customerAddress = N'Hetedik út 7.' 
	,@customerZIP = N'7777'
	,@customerLAT = 47.416920
	,@customerLONG = 19.180581
	,@customerPhone = N'3047777755'
	,@serviceFee = 7000
	,@invoiceName = N'Hetedik Kft.' 
	,@invoiceCity = N'Alsófelső' 
	,@invoiceAddress = N'Felsői utca 3.' 
	,@invoiceZIP = N'2023' 
	,@invoiceTaxNumber = '77766677-7-6'
	,@contractDate = '2020-06-11'
	,@isCompany = 1
	,@category = N'apartment'
	,@subscriptionID = 5
	,@installerID = 2;
GO 


--insert some values into the CustomerSignalType table
INSERT INTO [tech].[CustomerSignalType] (customerID, zoneNumber, code, description, isPatrol)
VALUES	(1, 1, N'BTS', N'Intrusion Front door', 1),
				(1, 2, N'BTS', N'Entry motion', 1),
				(1, 3, N'BTS', N'Living room motion', 1),
				(1, 4, N'OPN', N'Disarm system', 0),
				(1, 5, N'CLO', N'Arm system', 0),
				(2, 1, N'ACT', N'Power loss', 0),
				(2, 2, N'ACR', N'Power restored', 0),
				(3, 1, N'LOW', N'Battery low', 0),
				(3, 2, N'BTR', N'Battery restore', 0),
				(4, 1, N'PAN', N'Police panic', 1),
				(4, 2, N'REM', N'Remote armed', 0),
				(5, 3, N'BTS', N'Intrusion Front door', 1);
GO 


--insert some values into the CustomerContact table
INSERT INTO [office].[CustomerContact] (customerID, priority, name, phone, email, note)
VALUES	(1, 1, N'Customer1 Bálint',	N'202225555', NULL, NULL),
				(1, 2, N'Cust1 Cont Olga',	N'202226666', N'olga@olga.hu', N'only afternoon'),
				(2, 1, N'Customer2 Péter',	N'302225555', NULL, NULL),
				(2, 2, N'Cust2 Cont Mária', N'302226666', NULL, NULL),
				(3, 1, N'Customer3 Éva', 		N'702227777', N'custe@mail.eu', NULL),
				(4, 1, N'Customer4 Zsuzsa', N'704441111', N'cust4@mail.com', NULL),
				(4, 2, N'Cust4 Cont Béla', 	N'704441122', NULL, N'just on weekend'),
				(5, 1, N'Customer5 Alex', 	N'305552233', NULL, NULL);
GO 
				

--insert some values into the Invoice table
EXEC office.addInvoice
	@lineNumber = 3 
	,@deviceNumber = 2000
	,@invoiceDate = '2021-01-01'
	,@unitDescription = 'db' 
	,@unitPrice = 1000
	,@quantity = 3
	,@description = N'I. quarter fee'
	,@isViaMail = 1;
EXEC office.addInvoice
	@lineNumber = 0
	,@deviceNumber = 3800
	,@invoiceDate = '2021-01-01'
	,@invoiceDueDate = '2021-01-12'
	,@unitDescription = 'db' 
	,@unitPrice = 15000
	,@quantity = 1
	,@description = N'I. quarter fee';
EXEC office.addInvoice
	@lineNumber = 33
	,@deviceNumber = 6600
	,@invoiceDate = '2021-01-01'
	,@unitDescription = 'db' 
	,@unitPrice = 7000
	,@quantity = 2
	,@description = N'I. quarter fee';
EXEC office.addInvoice
	@lineNumber = 90
	,@deviceNumber = 6600
	,@invoiceDate = '2021-01-01'
	,@invoiceDueDate = '2021-05-22'
	,@unitDescription = 'db' 
	,@unitPrice = 10000
	,@quantity = 1
	,@description = N'I. quarter fee'
	,@isViaMail = 1;
EXEC office.addInvoice
	@lineNumber = 93
	,@deviceNumber = 6600
	,@invoiceDate = '2021-01-01'
	,@invoiceDueDate = '2021-01-15'
	,@unitDescription = 'db' 
	,@unitPrice = 25000
	,@quantity = 1
	,@description = N'I. quarter fee'
	,@isViaMail = 1;
EXEC office.addInvoice
	@lineNumber = 3
	,@deviceNumber = 2000
	,@invoiceDate = '2021-02-01'
	,@unitDescription = 'db' 
	,@unitPrice = 1200
	,@quantity = 3
	,@description = N'repair'
	,@isViaMail = 1;
EXEC office.addInvoice
	@lineNumber = 0
	,@deviceNumber = 3800
	,@invoiceDate = '2021-02-02'
	,@invoiceDueDate = '2021-02-12'
	,@unitDescription = 'db' 
	,@unitPrice = 15200
	,@quantity = 1
	,@description = N'maintenance';
EXEC office.addInvoice
	@lineNumber = 33
	,@deviceNumber = 6600
	,@invoiceDate = '2021-02-02'
	,@unitDescription = 'db' 
	,@unitPrice = 7200
	,@quantity = 2
	,@description = N'patrol fee';
EXEC office.addInvoice
	@lineNumber = 3
	,@deviceNumber = 2000
	,@invoiceDate = '2021-02-04'
	,@unitDescription = 'db' 
	,@unitPrice = 10200
	,@quantity = 1
	,@description = N'1st quarter maintenace'
	,@isViaMail = 1;
EXEC office.addInvoice
	@lineNumber = 90
	,@deviceNumber = 6700
	,@invoiceDate = '2021-04-01'
	,@unitDescription = 'db' 
	,@unitPrice = 1400
	,@quantity = 3
	,@description = N'2nd quarter maintenace'
	,@isViaMail = 1;
EXEC office.addInvoice
	@lineNumber = 0
	,@deviceNumber = 3800
	,@invoiceDate = '2021-04-02'
	,@unitDescription = 'db' 
	,@unitPrice = 15400
	,@quantity = 1
	,@description = N'II. quarter fee';
EXEC office.addInvoice
	@lineNumber = 33
	,@deviceNumber = 6600
	,@invoiceDate = '2021-04-03'
	,@unitDescription = 'db' 
	,@unitPrice = 7400
	,@quantity = 2
	,@description = N'II. quarter fee';
EXEC office.addInvoice
	@lineNumber = 90
	,@deviceNumber = 6700
	,@invoiceDate = '2021-04-04'
	,@unitDescription = 'db' 
	,@unitPrice = 10400
	,@quantity = 1
	,@description = N'II. quarter fee'
	,@isViaMail = 1;
EXEC office.addInvoice
	@lineNumber = 93
	,@deviceNumber = 6600
	,@invoiceDate = '2021-04-05'
	,@invoiceDueDate = '2021-04-25'
	,@unitDescription = 'db' 
	,@unitPrice = 25400
	,@quantity = 1
	,@description = N'II. quarter fee'
	,@isViaMail = 1;
EXEC office.addInvoice
	@lineNumber = 3
	,@deviceNumber = 2000
	,@invoiceDate = '2021-09-01'
	,@unitDescription = 'db' 
	,@unitPrice = 1900
	,@quantity = 3
	,@description = N'repair'
	,@isViaMail = 1;
EXEC office.addInvoice
	@lineNumber = 0
	,@deviceNumber = 3800
	,@invoiceDate = '2021-09-02'
	,@unitDescription = 'db' 
	,@unitPrice = 15900
	,@quantity = 1
	,@description = N'repair';
EXEC office.addInvoice
	@lineNumber = 33
	,@deviceNumber = 6600
	,@invoiceDate = '2021-09-03'
	,@unitDescription = 'db' 
	,@unitPrice = 7900
	,@quantity = 2
	,@description = N'repair';
EXEC office.addInvoice
	@lineNumber = 90
	,@deviceNumber = 6600
	,@invoiceDate = '2021-09-04'
	,@unitDescription = 'db' 
	,@unitPrice = 10900
	,@quantity = 1
	,@description = N'repair'
	,@isViaMail = 1;
EXEC office.addInvoice
	@lineNumber = 90
	,@deviceNumber = 6700
	,@invoiceDate = '2021-09-05'
	,@unitDescription = 'db' 
	,@unitPrice = 25900
	,@quantity = 1
	,@description = N'repair'
	,@isViaMail = 1;
EXEC office.addInvoice
	@lineNumber = 0
	,@deviceNumber = 3800
	,@invoiceDate = '2021-09-25'
	,@unitDescription = 'db' 
	,@unitPrice = 150000
	,@quantity = 1
	,@description = N'New installation deposit.'
	,@isViaMail = 1;
GO 
				

--insert some values into the Payment table
--status - NULL: full paid, 0: partial paid, 1: overpaid
INSERT INTO [office].[Payment] (invoiceID, paymentDate, amount)
VALUES	(1, '2021-01-08',	1000),
				(2, '2021-01-08',	15000),
				(3, '2021-01-18',	7000),
				(4, '2021-01-17',	10000),
				(5, '2021-01-14',	25000),
				(6, '2021-02-08',	1200),
				(7, '2021-02-09',	10200),
				(8, '2021-02-28',	7200),
				(9, '2021-02-18',	11200),
				(10, '2021-04-19', 25200),
				(11, '2021-04-21', 1400),
				(12, '2021-04-08', 15400),
				(13, '2021-04-06', 7400),
				(14, '2021-04-14', 10400),
				(15, '2022-04-25', 20000),
				(16, '2021-09-09', 1900),
				(17, '2021-09-12', 15900),
				(18, '2021-09-13', 7900),
				(19, '2021-09-09', 10900),
				(20, '2021-10-05', 25900),
				(1, '2021-01-11',	2810),
				(14, '2021-05-08',	21858);
GO 
				

--insert some values into the ReceivedSignal table
INSERT INTO [patrol].[ReceivedSignal] (customerID, zoneNumber, timeReceived, dispatcherID, 
																			 timePatrolStart, timePatrolOnSpot, patrolID)
VALUES	(1, 1, '2022-02-20T09:32:00', 8, '2022-02-20T09:35:00', '2022-02-20T09:45:22', 6),
				(3, 1, '2022-02-21T10:52:00', 8, '2022-02-21T10:54:00', '2022-02-21T11:02:00', 7),
				(4, 1, '2022-02-22T09:02:00', 9, '2022-02-22T09:03:00', '2022-02-22T09:15:22', 14),
				(4, 1, '2022-02-23T14:11:00', 9, '2022-02-23T14:12:00', '2022-02-23T14:14:11', 15),
				(1, 3, '2022-02-24T16:32:00', 8, '2022-02-24T16:32:25', '2022-02-24T16:39:10', 6),
				(1, 4, DEFAULT, 8, NULL, NULL, NULL),
				(2, 1, DEFAULT, 9, NULL, NULL, NULL);

GO 

