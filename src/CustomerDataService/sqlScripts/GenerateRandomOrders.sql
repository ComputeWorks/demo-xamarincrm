USE [XamarinCRMv2];
GO

SET ANSI_NULLS ON;
GO

SET QUOTED_IDENTIFIER ON;
GO

IF object_id('[XamarinCRMv2_CustomerDataService].[GenerateRandomOrders]') IS NOT NULL
  DROP PROCEDURE [XamarinCRMv2_CustomerDataService].[GenerateRandomOrders];
GO

CREATE PROCEDURE [XamarinCRMv2_CustomerDataService].[GenerateRandomOrders] @numberOfOrdersToGenerate INT = 100
AS
BEGIN

	SET NOCOUNT ON;

	TRUNCATE TABLE [XamarinCRMv2].[XamarinCRMv2_CustomerDataService].[Order];

	DECLARE @TempOrders TABLE
	(
	   id NVARCHAR(255),
	   createdAt DATETIMEOFFSET(3),
	   updatedAt DATETIMEOFFSET(3),
	   isOpen BIT,
	   accountId NVARCHAR(MAX),
	   price FLOAT,
	   item NVARCHAR(MAX),
	   order_date DATETIMEOFFSET(3),
	   due_date DATETIMEOFFSET(3),
	   closed_date DATETIMEOFFSET(3),
	   deleted BIT
	);

	DECLARE @createdAndUpdatedDate DATETIMEOFFSET(3);
	SET @createdAndUpdatedDate = GETDATE();

	DECLARE @Iteration INT;
	SET @Iteration = 1;
	WHILE @Iteration <= @numberOfOrdersToGenerate
	BEGIN
		
		DECLARE @isOpen AS INT;
		DECLARE @accountId AS NVARCHAR(MAX);
		DECLARE @price AS FLOAT;
		DECLARE @item AS NVARCHAR(MAX);
		DECLARE @order_date DATETIMEOFFSET(3);
		DECLARE @due_date DATETIMEOFFSET(3);
		DECLARE @closed_date DATETIMEOFFSET(3) = NULL;

		-- select random isOpen bit
		SELECT @isOpen = CAST(CAST(CRYPT_GEN_RANDOM(1) AS int) % 2 AS BIT);

		-- Select random account
		SELECT TOP 1 @accountId = id FROM [XamarinCRMv2].[XamarinCRMv2_CustomerDataService].[Account] WHERE is_lead = 0 ORDER BY NEWID();

		-- Select random product
		SELECT TOP 1 @item = Name, @price = Price FROM [XamarinCRMv2].[XamarinCRMv2_CatalogDataService].[Products] ORDER BY NEWID();

		-- Select random date in the past within 6 weeks
		SELECT @order_date = (SELECT DATEADD(DAY, -(ABS(CHECKSUM(NEWID()) % 40) + 1), GETDATE()));

		-- get due date 1 week after order date
		SELECT @due_date = (SELECT DATEADD(DAY, 7, @order_date));

		-- if the order is not open, get a closed date that is random within 4 days in either direction of the due date
		IF (@isOpen = 0)
			BEGIN
				DECLARE @random_bool AS BIT;
				SELECT @random_bool = CAST(CAST(CRYPT_GEN_RANDOM(1) AS int) % 2 AS BIT);
				DECLARE @random_closed_day_range AS INT;
				SELECT @random_closed_day_range = ABS(CHECKSUM(NEWID()) % 3) + 1;
				IF @random_bool = 0
					BEGIN
						SELECT @closed_date = (SELECT DATEADD(day, -@random_closed_day_range, @due_date));
					END
				ELSE 
					BEGIN
						SELECT @closed_date = (SELECT DATEADD(day, @random_closed_day_range, @due_date));
					END
			END

		-- insert order into temp table
		INSERT @TempOrders 
		VALUES 
		(
			NEWID(),
			@createdAndUpdatedDate,
			@createdAndUpdatedDate,
			@isOpen,
			@accountId,
			@price,
			@item,
			@order_date,
			@due_date,
			@closed_date,
			0
		)
		SET @Iteration = @Iteration + 1;
	END

	-- insert all temp table records into destination table
	INSERT INTO [XamarinCRMv2].[XamarinCRMv2_CustomerDataService].[Order] 
	(
		id,
		__createdAt,
		__updatedAt,
		is_open,
		account_id,
		price,
		item,
		order_date,
		due_date,
		closed_date,
		__deleted
	)
	SELECT 
		id,
		createdAt,
		updatedAt,
		isOpen,
		accountId,
		price,
		item,
		order_date,
		due_date,
		closed_date,
		deleted 
	FROM @TempOrders
END

GO