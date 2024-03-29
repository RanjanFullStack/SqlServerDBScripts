USE [BFlow_v2.0]
GO
/****** Object:  Schema [Tzdb]    Script Date: 5/24/2019 12:11:46 PM ******/
CREATE SCHEMA [Tzdb]
GO
/****** Object:  UserDefinedFunction [dbo].[fn_ConvertDateToUserTimeZone]    Script Date: 5/24/2019 12:11:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[fn_ConvertDateToUserTimeZone]
(
@TimeZoneID SMALLINT,
@UTCDate DATETIME
)
RETURNS Datetime
as
BEGIN
DECLARE @ISOTimeZoneID varchar(250)
DECLARE @hour int
DECLARE @minute int
DECLARE @localTime DATETIME

Select top 1  @ISOTimeZoneID= b.Name, @hour = [Hour], @minute = [Minutes]  
from TimeZone a
inner join Tzdb.Zones b on a.SystemTimeZoneID = b.StandardName
 where a.ID = @TimeZoneID

If(@UTCDate is not null)
begin
    Set  @localTime = Tzdb.UtcToLocal(@UTCDate, @ISOTimeZoneID)
end

if(@localTime is null)
begin
 Set @localTime = DATEADD(HH, @hour, DATEADD(MI, @minute, @UTCDate))
end

if(@localTime is null)
begin
	set @localTime = @UTCDate
end
return @localTime

END


GO
/****** Object:  UserDefinedFunction [dbo].[fn_GetUsers]    Script Date: 5/24/2019 12:11:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		<Sharma, Nitish>
-- Create date: <27/08/2018>
-- Description:	<To Get Managers with Hierachy>
-- =============================================
CREATE FUNCTION [dbo].[fn_GetUsers]
(	
  @UserId int
)
RETURNS  @UserWithRole table(UserId int, ManagerId int, RoleName varchar(50), RegionId int)
AS
Begin
	declare @RoleName varchar(50);
	Select @RoleName = r.Name from Users u inner join Roles r on u.RoleId = r.Id where u.UserId = @UserId

	;WITH MangerWithUsers as(
    SELECT UserId,  ManagerId, r.Name as RoleName, u.RegionId
	FROM Users  u 
		inner join Roles r on r.Id = u.RoleId 
	where UserId = @UserId 
    UNION ALL
    SELECT  u.UserId, u.ManagerId, r.Name as RoleName, u.RegionId  
	FROM Users u
    inner join MangerWithUsers x on u.ManagerId = x.UserId
	inner join Roles r on r.Id = u.RoleId 
)
Insert into @UserWithRole
Select * from MangerWithUsers u
 where UserId = case when  @RoleName in ('Admin', 'Global COO','Regional COO') then @UserId else  UserId end 
return 
End


GO
/****** Object:  UserDefinedFunction [dbo].[TRY_CAST]    Script Date: 5/24/2019 12:11:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[TRY_CAST]
(
	@pExpression AS VARCHAR(8000),
	@pData_Type AS VARCHAR(8000),
	@pReturnValueIfErrorCast AS SQL_VARIANT = NULL
)
RETURNS SQL_VARIANT
AS
BEGIN
	--------------------------------------------------------------------------------
	--	INT	
	--------------------------------------------------------------------------------
	
	IF @pData_Type = 'INT'
	BEGIN
		IF ISNUMERIC(@pExpression) = 1 AND @pExpression NOT IN ('-','+','$','.',',','\')	--JEPM20170216
		BEGIN
			DECLARE @pExpressionINT AS FLOAT = CAST(@pExpression AS FLOAT)
			IF @pExpressionINT BETWEEN - 2147483648.0 AND 2147483647.0
			BEGIN
				RETURN CAST(@pExpressionINT as INT)
			END
			ELSE
			BEGIN
				RETURN @pReturnValueIfErrorCast
			END --FIN IF @pExpressionINT BETWEEN - 2147483648.0 AND 2147483647.0
		END
		ELSE
		BEGIN
			RETURN @pReturnValueIfErrorCast
		END 
	END
	
	--------------------------------------------------------------------------------
	--	DATE	
	--------------------------------------------------------------------------------
	
	IF @pData_Type IN ('DATE','DATETIME')
	BEGIN
		IF ISDATE(@pExpression) = 1
		BEGIN
			
			DECLARE @pExpressionDATE AS DATETIME = cast(@pExpression AS DATETIME)
			IF @pData_Type = 'DATE'
			BEGIN
				RETURN cast(@pExpressionDATE as DATE)
			END
			
			IF @pData_Type = 'DATETIME'
			BEGIN
				RETURN cast(@pExpressionDATE as datetime2)
			END
			
		END
		ELSE 
		BEGIN
			--DECLARE @pExpressionDATEReplaced AS VARCHAR(50) = REPLACE(REPLACE(REPLACE(@pExpression,'\',''),'/',''),'-','')
			DECLARE @pExpressionDATEReplaced AS VARCHAR(50) = '' --REPLACE(REPLACE(REPLACE(@pExpression,'\',''),'/',''),'-','')
			SET @pExpressionDATEReplaced  = left(@pExpression, 23)
			IF ISDATE(@pExpressionDATEReplaced) = 1
			BEGIN
				IF @pData_Type = 'DATE'
				BEGIN
					RETURN cast(@pExpressionDATEReplaced as DATE)
				END
			
				IF @pData_Type = 'DATETIME'
				BEGIN
					RETURN cast(@pExpressionDATEReplaced as datetime)
				END
			END
			ELSE
			BEGIN
				RETURN @pReturnValueIfErrorCast
			END
		END --FIN IF ISDATE(@pExpression) = 1
	END --FIN IF @pData_Type = 'DATE'
	--------------------------------------------------------------------------------
	--	NUMERIC	
	--------------------------------------------------------------------------------
	
	IF @pData_Type LIKE 'NUMERIC%'
	BEGIN
		IF ISNUMERIC(@pExpression) = 1
		BEGIN
			
			DECLARE @TotalDigitsOfType AS INT = SUBSTRING(@pData_Type,CHARINDEX('(',@pData_Type)+1,  CHARINDEX(',',@pData_Type) - CHARINDEX('(',@pData_Type) - 1)
				, @TotalDecimalsOfType AS INT = SUBSTRING(@pData_Type,CHARINDEX(',',@pData_Type)+1,  CHARINDEX(')',@pData_Type) - CHARINDEX(',',@pData_Type) - 1)
				, @TotalDigitsOfValue AS INT 
				, @TotalDecimalsOfValue AS INT 
				, @TotalWholeDigitsOfType AS INT 
				, @TotalWholeDigitsOfValue AS INT 
			SET @pExpression = REPLACE(@pExpression, ',','.')
			SET @TotalDigitsOfValue = LEN(REPLACE(@pExpression, '.',''))
			SET @TotalDecimalsOfValue = CASE Charindex('.', @pExpression)
										WHEN 0
											THEN 0
										ELSE Len(Cast(Cast(Reverse(CONVERT(VARCHAR(50), @pExpression, 128)) AS FLOAT) AS BIGINT))
										END 
			SET @TotalWholeDigitsOfType = @TotalDigitsOfType - @TotalDecimalsOfType
			SET @TotalWholeDigitsOfValue = @TotalDigitsOfValue - @TotalDecimalsOfValue
			-- The total digits can not be greater than the p part of NUMERIC (p, s)
			-- The total of decimals can not be greater than the part s of NUMERIC (p, s)
			-- The total digits of the whole part can not be greater than the subtraction between p and s
			IF (@TotalDigitsOfValue <= @TotalDigitsOfType) AND (@TotalDecimalsOfValue <= @TotalDecimalsOfType) AND (@TotalWholeDigitsOfValue <= @TotalWholeDigitsOfType)
			BEGIN
				DECLARE @pExpressionNUMERIC AS FLOAT
				SET @pExpressionNUMERIC = CAST (ROUND(@pExpression, @TotalDecimalsOfValue) AS FLOAT) 
				
				RETURN @pExpressionNUMERIC --Returns type FLOAT
			END 
			else
			BEGIN
				RETURN @pReturnValueIfErrorCast
			END-- FIN IF (@TotalDigitisOfValue <= @TotalDigits) AND (@TotalDecimalsOfValue <= @TotalDecimals) 
		END
		ELSE 
		BEGIN
			RETURN @pReturnValueIfErrorCast
		END --FIN IF ISNUMERIC(@pExpression) = 1
	END --IF @pData_Type LIKE 'NUMERIC%'
	
	--------------------------------------------------------------------------------
	--	BIT	
	--------------------------------------------------------------------------------
	
	IF @pData_Type LIKE 'BIT'
	BEGIN
		set @pExpression = Case when @pExpression  = 'true' then '1' 
								when  @pExpression  = 'false' then '0'
								else @pExpression
								end
		IF @pExpression in('0', '1')
		BEGIN
			RETURN CAST(@pExpression AS BIT) 
		END
		ELSE 
		BEGIN
			RETURN @pReturnValueIfErrorCast
		END --FIN IF ISNUMERIC(@pExpression) = 1
	END --IF @pData_Type LIKE 'BIT'
	--------------------------------------------------------------------------------
	--	FLOAT	
	--------------------------------------------------------------------------------
	
	IF @pData_Type LIKE 'FLOAT'
	BEGIN
		IF ISNUMERIC(REPLACE(REPLACE(@pExpression, CHAR(13), ''), CHAR(10), '')) = 1
		BEGIN
			RETURN CAST(@pExpression AS FLOAT) 
		END
		ELSE 
		BEGIN
			
			IF REPLACE(@pExpression, CHAR(13), '') = '' --Only white spaces are replaced, not new lines
			BEGIN
				RETURN 0
			END
			ELSE 
			BEGIN
				RETURN @pReturnValueIfErrorCast
			END --IF REPLACE(@pExpression, CHAR(13), '') = '' 
			
		END --FIN IF ISNUMERIC(@pExpression) = 1
	END 

	IF @pData_Type LIKE 'Decimal%'
	BEGIN
		IF (ISNUMERIC(REPLACE(@pExpression, '.', '') ) = 1)
		BEGIN
			if(cast(@pExpression as decimal(18,2)) = 0)
			begin
				 return cast(@pExpression as decimal(18))
			end 
			declare @fisrtPart  varchar(10), @secondPart varchar(10)
			declare @fisrtPartType  int, @secondParttype int

			set @pData_Type = Replace(REPLACE(@pData_Type, 'decimal(', ''), ')', '')

			set @fisrtPartType = rtrim(ltrim(Substring(@pData_Type, 0,  CHARINDEX(',', @pData_Type))))
			set @secondParttype = rtrim(ltrim(Replace(@pData_Type, cast(@fisrtPartType as varchar)+',' , '')))

			set @fisrtPart = Substring(@pExpression, 0,  CHARINDEX('.', @pExpression))
			set @secondPart = Replace(@pExpression, @fisrtPart+'.' , '')

			if(len(@fisrtPart) > @fisrtPartType or len(@secondPart) > @secondParttype)
			begin
			 RETURN @pReturnValueIfErrorCast
			end
			else
			begin
				  return @pExpression
			end
			  
		END
		ELSE 
		BEGIN
			
			RETURN @pReturnValueIfErrorCast
			
		END --FIN IF ISNUMERIC(@pExpression) = 1
	END 


	IF (@pData_Type Like 'Varchar%' or @pData_Type Like 'char%' or @pData_Type Like 'nvarchar%'  )
	BEGIN
		if(@pData_Type in('Varchar(max)', 'nVarchar(max)', 'char(max)') )
		begin
			return @pExpression
		end
		Declare @Length varchar(10) = '30'
		if(Charindex( ')', @pData_Type) > 1)
		begin
		set  @Length = SUBSTRING(@pData_Type, CHARINDEX('(', @pData_Type)+1, CHARINDEX(')',@pData_Type) - (CHARINDEX('(', @pData_Type) +1))
		end
		if(LEN(@pExpression) <= @Length)
		begin
			return @pExpression
		end 
		 return @pReturnValueIfErrorCast
	END
	
	RETURN @pReturnValueIfErrorCast
		
END
GO
/****** Object:  Table [Tzdb].[Intervals]    Script Date: 5/24/2019 12:11:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [Tzdb].[Intervals](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[ZoneId] [int] NOT NULL,
	[UtcStart] [datetime2](0) NOT NULL,
	[UtcEnd] [datetime2](0) NOT NULL,
	[LocalStart] [datetime2](0) NOT NULL,
	[LocalEnd] [datetime2](0) NOT NULL,
	[OffsetMinutes] [smallint] NOT NULL,
	[Abbreviation] [varchar](10) NOT NULL,
 CONSTRAINT [PK_Intervals] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [Tzdb].[Links]    Script Date: 5/24/2019 12:11:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [Tzdb].[Links](
	[LinkZoneId] [int] NOT NULL,
	[CanonicalZoneId] [int] NOT NULL,
 CONSTRAINT [PK_Links] PRIMARY KEY CLUSTERED 
(
	[LinkZoneId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [Tzdb].[Zones]    Script Date: 5/24/2019 12:11:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [Tzdb].[Zones](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Name] [varchar](50) NOT NULL,
	[StandardName] [varchar](250) NULL,
 CONSTRAINT [PK_Zones] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  UserDefinedFunction [Tzdb].[GetZoneId_Inline]    Script Date: 5/24/2019 12:11:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [Tzdb].[GetZoneId_Inline]
(
	@tz VARCHAR(50)
) 
RETURNS TABLE WITH SCHEMABINDING AS 
RETURN (
	SELECT ISNULL(l.CanonicalZoneId, z.Id) AS ZoneId
	FROM Tzdb.Zones z LEFT JOIN Tzdb.Links l ON l.LinkZoneId = z.Id
	WHERE z.Name = @tz
)


GO
/****** Object:  UserDefinedFunction [Tzdb].[LocalToUtc]    Script Date: 5/24/2019 12:11:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [Tzdb].[LocalToUtc]
(
    @local datetime2,
    @tz varchar(50),
    @SkipOnSpringForwardGap bit = 1, -- if the local time is in a gap, 1 skips forward and 0 will return null
    @FirstOnFallBackOverlap bit = 1  -- if the local time is ambiguous, 1 uses the first (daylight) instance and 0 will use the second (standard) instance
)
RETURNS datetimeoffset
WITH SCHEMABINDING AS
BEGIN
    DECLARE @OffsetMinutes int

    IF @FirstOnFallBackOverlap = 1
        SELECT TOP 1 @OffsetMinutes = [OffsetMinutes]
        FROM [Tzdb].[Intervals] i INNER JOIN Tzdb.GetZoneId_Inline(@tz) z ON z.ZoneId = i.ZoneId
        WHERE [LocalStart] <= @local AND [LocalEnd] > @local
        ORDER BY [UtcStart]
    ELSE
        SELECT TOP 1 @OffsetMinutes = [OffsetMinutes]
        FROM [Tzdb].[Intervals] i INNER JOIN Tzdb.GetZoneId_Inline(@tz) z ON z.ZoneId = i.ZoneId
        WHERE [LocalStart] <= @local AND [LocalEnd] > @local
        ORDER BY [UtcStart] DESC

    IF @OffsetMinutes IS NULL
    BEGIN
        IF @SkipOnSpringForwardGap = 0 RETURN NULL

        SET @local = DATEADD(MINUTE, CASE @tz WHEN 'Australia/Lord_Howe' THEN 30 ELSE 60 END, @local)
        SELECT TOP 1 @OffsetMinutes = [OffsetMinutes]
        FROM [Tzdb].[Intervals] i INNER JOIN Tzdb.GetZoneId_Inline(@tz) z ON z.ZoneId = i.ZoneId
        WHERE [LocalStart] <= @local AND [LocalEnd] > @local
    END

    RETURN TODATETIMEOFFSET(DATEADD(MINUTE, -@OffsetMinutes, @local), 0)
END


GO
/****** Object:  UserDefinedFunction [Tzdb].[UtcToLocal]    Script Date: 5/24/2019 12:11:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [Tzdb].[UtcToLocal]
(
    @utc DATETIME2,
    @tz VARCHAR(50)
)
RETURNS DATETIMEOFFSET
WITH SCHEMABINDING AS
BEGIN
    DECLARE @OffsetMinutes INT

    SELECT TOP 1 @OffsetMinutes = [OffsetMinutes]
    FROM [Tzdb].[Intervals] i INNER JOIN Tzdb.GetZoneId_Inline(@tz) z ON i.ZoneId = z.ZoneId
    WHERE  [UtcStart] <= @utc AND [UtcEnd] > @utc

    RETURN TODATETIMEOFFSET(DATEADD(MINUTE, @OffsetMinutes, @utc), @OffsetMinutes)
END


GO
/****** Object:  Table [dbo].[Attributes]    Script Date: 5/24/2019 12:11:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Attributes](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Name] [varchar](100) NULL,
	[Order] [int] NULL,
	[MasterId] [int] NOT NULL,
 CONSTRAINT [PK__Attribut__3214EC070F975522] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Capacity]    Script Date: 5/24/2019 12:11:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Capacity](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Date] [datetime] NOT NULL,
	[hour] [decimal](4, 2) NOT NULL,
	[UserId] [int] NOT NULL,
	[CreatedOn] [datetime] NOT NULL,
	[CreatedBy] [int] NOT NULL,
	[ModifiedOn] [datetime] NULL,
	[ModifiedBy] [int] NULL,
 CONSTRAINT [PK_Capacity] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[ColumnMaster]    Script Date: 5/24/2019 12:11:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ColumnMaster](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[TableId] [int] NOT NULL,
	[Name] [varchar](100) NOT NULL,
	[Datatype] [varchar](50) NOT NULL,
	[DataValidation] [varchar](max) NULL,
	[BusinessValidation] [varchar](max) NULL,
	[IsPrimary] [bit] NOT NULL,
	[IsUnique] [bit] NOT NULL,
	[ForeignKeyField] [varchar](200) NULL,
	[IsRequired] [bit] NOT NULL,
	[CssClass] [varchar](500) NULL,
	[DisplayName] [varchar](200) NOT NULL,
	[DefaultControlType] [varchar](200) NULL,
	[IsSystemDefined] [bit] NOT NULL,
	[ControlHTMLID] [varchar](100) NULL,
 CONSTRAINT [PK_BFlowColumnMaster] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Comments]    Script Date: 5/24/2019 12:11:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Comments](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Text] [nvarchar](4000) NOT NULL,
	[RequestId] [int] NOT NULL,
	[CreatedOn] [datetime] NOT NULL,
	[CreatedBy] [int] NOT NULL,
	[ModifiedOn] [datetime] NULL,
	[ModifiedBy] [int] NULL
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[ControlFormat]    Script Date: 5/24/2019 12:11:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ControlFormat](
	[Id] [smallint] IDENTITY(1,1) NOT NULL,
	[Name] [varchar](100) NULL,
	[Type] [varchar](100) NULL,
 CONSTRAINT [PK_ControlFormat] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Documents]    Script Date: 5/24/2019 12:11:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Documents](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Name] [varchar](1000) NULL,
	[RequestId] [int] NULL,
	[Type] [varchar](100) NULL,
	[Comment] [varchar](1000) NULL,
	[Version] [int] NOT NULL,
	[Tags] [varchar](2000) NULL,
	[Path] [varchar](2000) NULL,
	[Size] [decimal](10, 2) NULL,
	[CreatedOn] [datetime] NOT NULL,
	[CreatedBy] [int] NOT NULL,
	[ModifiedOn] [datetime] NULL,
	[ModifiedBy] [int] NULL,
 CONSTRAINT [PK_Documents] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[EmailNotifications]    Script Date: 5/24/2019 12:11:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[EmailNotifications](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[EventId] [int] NOT NULL,
	[ForRequestor] [bit] NOT NULL,
	[ForAssignee] [bit] NOT NULL,
	[ForWatcher] [bit] NOT NULL,
	[EmailTemplateId] [int] NULL,
 CONSTRAINT [PK_EmailNotifications] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[EmailTemplates]    Script Date: 5/24/2019 12:11:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[EmailTemplates](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Name] [varchar](100) NULL,
	[EmailSubject] [varchar](255) NOT NULL,
	[EmailBody] [ntext] NOT NULL,
	[ModifiedOn] [datetime] NULL,
	[CreatedBy] [int] NULL,
	[CreatedOn] [datetime] NULL,
	[ModifiedBy] [int] NULL,
	[Condition] [varchar](400) NULL,
	[IsDeleted] [bit] NULL,
 CONSTRAINT [PK_EmailTemplates] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Events]    Script Date: 5/24/2019 12:11:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Events](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Name] [varchar](250) NOT NULL,
	[Type] [int] NULL,
	[IsReadonly] [bit] NULL,
	[IsActive] [bit] NULL,
	[IsMappedToRequest] [bit] NOT NULL,
	[Order] [int] NULL,
	[IsDefault] [bit] NOT NULL,
 CONSTRAINT [PK_Events] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[EventType]    Script Date: 5/24/2019 12:11:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[EventType](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Name] [varchar](100) NOT NULL,
	[IsNotificationRequired] [bit] NOT NULL,
 CONSTRAINT [PK_EventType] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[EventWorkFlow]    Script Date: 5/24/2019 12:11:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[EventWorkFlow](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[EventId] [int] NOT NULL,
	[SuccessorEventId] [int] NOT NULL,
	[Order] [int] NULL,
 CONSTRAINT [PK_EventWorkFlow] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Features]    Script Date: 5/24/2019 12:11:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Features](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Name] [varchar](500) NOT NULL,
	[Group] [int] NULL,
	[CreatedOn] [datetime] NOT NULL,
	[CreatedBy] [int] NOT NULL,
	[ModifiedOn] [datetime] NULL,
	[ModifiedBy] [int] NULL,
 CONSTRAINT [PK_Features] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[FeaturesGroup]    Script Date: 5/24/2019 12:11:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[FeaturesGroup](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Name] [varchar](50) NOT NULL,
	[AliasName] [varchar](50) NOT NULL,
	[IsDeafult] [bit] NOT NULL,
 CONSTRAINT [PK_FeaturesGroup] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Key]    Script Date: 5/24/2019 12:11:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Key](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Name] [varchar](100) NOT NULL,
	[MasterId] [int] NULL,
	[IsMappedToRequest] [bit] NOT NULL,
	[IsMappedToUser] [bit] NOT NULL,
	[IsRequired] [bit] NOT NULL,
	[IsActive] [bit] NOT NULL,
	[Order] [smallint] NULL,
 CONSTRAINT [PK__KeyVal__3214EC07145C0A3F] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[MapAttributesWithAttributes]    Script Date: 5/24/2019 12:11:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[MapAttributesWithAttributes](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[PrimaryAttributeId] [int] NOT NULL,
	[SecondaryAttributeId] [int] NOT NULL,
	[TertiaryAttributeId] [int] NULL,
 CONSTRAINT [PK_MappingAttributesWithAttributes] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[MapMasterAttributesWithUsers]    Script Date: 5/24/2019 12:11:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[MapMasterAttributesWithUsers](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[AttributeId] [int] NOT NULL,
	[UserId] [int] NOT NULL,
	[CreatedOn] [datetime] NULL,
	[CreatedBy] [int] NULL,
	[ModifiedOn] [datetime] NULL,
	[ModifiedBy] [int] NULL,
 CONSTRAINT [PK_MappingMasterWithUsers] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[MapMasterWithMasters]    Script Date: 5/24/2019 12:11:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[MapMasterWithMasters](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[PrimaryMasterId] [int] NOT NULL,
	[SecondaryMasterId] [int] NOT NULL,
 CONSTRAINT [PK_MapMasterWithMasters] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[MapRequestWithMasterAttributes]    Script Date: 5/24/2019 12:11:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[MapRequestWithMasterAttributes](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[RequestId] [int] NOT NULL,
	[AttributeId] [int] NOT NULL,
 CONSTRAINT [PK_MappingRequestWithMasterAttributes] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[MapRoleWithEvents]    Script Date: 5/24/2019 12:11:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[MapRoleWithEvents](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[RoleId] [int] NULL,
	[EventId] [int] NULL,
 CONSTRAINT [PK_MapRoleWithEvents] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[MapRoleWithFeatures]    Script Date: 5/24/2019 12:11:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[MapRoleWithFeatures](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[RoleId] [int] NOT NULL,
	[FeatureId] [int] NOT NULL,
	[CanAdd] [bit] NOT NULL,
	[CanRead] [bit] NOT NULL,
	[CanUpdate] [bit] NOT NULL,
	[CanDelete] [bit] NOT NULL,
 CONSTRAINT [PK_MapRoleWithFeatures] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[MapUserWithRoles]    Script Date: 5/24/2019 12:11:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[MapUserWithRoles](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[UserId] [int] NULL,
	[RoleId] [int] NULL,
 CONSTRAINT [PK_MapUserWithRoles] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[MapUserWithTeams]    Script Date: 5/24/2019 12:11:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[MapUserWithTeams](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[UserId] [int] NOT NULL,
	[TeamId] [int] NOT NULL,
	[CreatedOn] [datetime] NOT NULL,
	[CreatedBy] [int] NOT NULL,
	[ModifiedOn] [datetime] NULL,
	[ModifiedBy] [int] NULL,
 CONSTRAINT [PK_MappingUserWithTeams] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Master]    Script Date: 5/24/2019 12:11:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Master](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Name] [varchar](100) NOT NULL,
	[Order] [smallint] NULL,
 CONSTRAINT [PK__Master__3214EC070BC6C43E] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[MasterKeyValues]    Script Date: 5/24/2019 12:11:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[MasterKeyValues](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[KeyId] [int] NOT NULL,
	[Value] [varchar](250) NOT NULL,
 CONSTRAINT [PK_MasterKeyValues] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Recurrence]    Script Date: 5/24/2019 12:11:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Recurrence](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[RequestId] [int] NOT NULL,
	[RecurrenceTypeId] [int] NOT NULL,
	[Sunday] [bit] NULL,
	[Monday] [bit] NULL,
	[Tuesday] [bit] NULL,
	[Wednesday] [bit] NULL,
	[Thursday] [bit] NULL,
	[Friday] [bit] NULL,
	[Saturday] [bit] NULL,
	[Instance] [int] NULL,
	[Interval] [int] NULL,
	[MonthOfYear] [int] NULL,
	[Occurrences] [int] NULL,
	[StartDate] [datetime] NULL,
	[EndDate] [datetime] NULL,
	[MonthlyAdjustedValue] [int] NULL,
	[WeekOfMonth] [int] NULL,
	[DayOfMonth] [int] NULL,
 CONSTRAINT [Recurrence1] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Reports]    Script Date: 5/24/2019 12:11:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Reports](
	[Id] [int] NOT NULL,
	[Title] [varchar](250) NOT NULL,
	[Group] [varchar](250) NOT NULL,
	[Description] [nvarchar](200) NULL,
	[Query] [nvarchar](max) NOT NULL,
	[ChartType] [varchar](20) NULL,
	[IsDownload] [bit] NULL,
	[CreatedBy] [int] NOT NULL,
	[CreatedOn] [datetime] NOT NULL,
	[ModifiedBy] [int] NULL,
	[ModifiedOn] [datetime] NULL,
 CONSTRAINT [PK_Reports] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Request]    Script Date: 5/24/2019 12:11:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Request](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Title] [varchar](2000) NOT NULL,
	[Description] [varchar](8000) NULL,
	[ParentId] [int] NULL,
	[IsRecurrence] [bit] NOT NULL,
	[DueDateTime] [datetime] NULL,
	[CreatedOn] [datetime] NOT NULL,
	[CreatedBy] [int] NOT NULL,
	[ModifiedOn] [datetime] NULL,
	[ModifiedBy] [int] NULL,
 CONSTRAINT [PK_Request] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[RequestFeedback]    Script Date: 5/24/2019 12:11:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[RequestFeedback](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[RequestId] [int] NULL,
	[FeedBackTemplateId] [int] NULL,
	[Value] [int] NOT NULL,
	[Comments] [varchar](max) NULL,
	[IsReminded] [bit] NOT NULL,
	[CreatedOn] [datetime] NOT NULL,
	[CreatedBy] [int] NOT NULL,
	[ModifiedOn] [datetime] NULL,
	[ModifiedBy] [int] NULL,
 CONSTRAINT [PK_RequestFeedback] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[RequestKeyValues]    Script Date: 5/24/2019 12:11:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[RequestKeyValues](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[RequestId] [int] NOT NULL,
	[KeyId] [int] NOT NULL,
	[Value] [varchar](8000) NOT NULL,
 CONSTRAINT [PK_MappingRequestWithRequestAttributes] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[RequestWatchers]    Script Date: 5/24/2019 12:11:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[RequestWatchers](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[RequestId] [int] NOT NULL,
	[UserId] [int] NOT NULL,
	[TeamId] [int] NULL,
 CONSTRAINT [PK_RequestWatchers] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Role]    Script Date: 5/24/2019 12:11:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Role](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Name] [varchar](250) NOT NULL,
	[IsActive] [bit] NOT NULL,
	[IsNotifiedOnCreateRequest] [bit] NOT NULL,
	[CreatedOn] [datetime] NOT NULL,
	[CreatedBy] [int] NOT NULL,
	[ModifiedOn] [datetime] NULL,
	[ModifiedBy] [int] NULL,
 CONSTRAINT [PK_Role] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[TablesMaster]    Script Date: 5/24/2019 12:11:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[TablesMaster](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[TableName] [varchar](100) NOT NULL,
 CONSTRAINT [PK_BFlowMaster] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Team]    Script Date: 5/24/2019 12:11:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Team](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Name] [varchar](250) NOT NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedOn] [datetime] NOT NULL,
	[CreatedBy] [int] NOT NULL,
	[ModifiedOn] [datetime] NULL,
	[ModifiedBy] [int] NULL,
 CONSTRAINT [PK_Team] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Timeline]    Script Date: 5/24/2019 12:11:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Timeline](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[RequestId] [int] NOT NULL,
	[EventId] [int] NOT NULL,
	[Value] [datetime] NULL,
	[UserId] [int] NULL,
	[TeamId] [int] NULL,
	[CreatedOn] [datetime] NOT NULL,
	[CreatedBy] [int] NOT NULL,
	[ModifiedOn] [datetime] NULL,
	[ModifiedBy] [int] NULL,
 CONSTRAINT [PK_Timeline] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[TimeTracking]    Script Date: 5/24/2019 12:11:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[TimeTracking](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Hours] [decimal](4, 2) NULL,
	[RequestId] [int] NULL,
	[TrackingDate] [date] NULL,
	[UserId] [int] NULL,
	[CapacityId] [int] NULL,
	[CreatedOn] [datetime] NULL,
	[ModifiedOn] [datetime] NULL,
	[CreatedBy] [int] NULL,
	[ModifiedBy] [int] NULL,
 CONSTRAINT [PK_TimeTracking] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[TimeZone]    Script Date: 5/24/2019 12:11:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[TimeZone](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[TimeZoneName] [varchar](100) NOT NULL,
	[TimeZoneCode] [varchar](50) NOT NULL,
	[SystemTimeZoneID] [nvarchar](100) NOT NULL,
	[IsActive] [bit] NOT NULL,
	[Hour] [nvarchar](50) NOT NULL,
	[Minutes] [nchar](10) NOT NULL,
	[CreatedOn] [datetime] NOT NULL,
	[CreatedBy] [int] NOT NULL,
	[ModifiedOn] [datetime] NULL,
	[ModifiedBy] [int] NULL,
 CONSTRAINT [PK_TimeZone] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[UserKeyValues]    Script Date: 5/24/2019 12:11:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[UserKeyValues](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[UserId] [int] NOT NULL,
	[KeyId] [int] NOT NULL,
	[Value] [varchar](8000) NOT NULL,
 CONSTRAINT [PK_UserKeyValues] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Users]    Script Date: 5/24/2019 12:11:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Users](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[AuthUserId] [int] NULL,
	[FirstName] [varchar](150) NOT NULL,
	[LastName] [varchar](150) NOT NULL,
	[UserName] [varchar](350) NOT NULL,
	[Email] [varchar](300) NOT NULL,
	[ManagerId] [int] NULL,
	[TimeZoneID] [int] NOT NULL,
	[LastLoginDateTime] [datetime] NULL,
	[LastLogoutDateTime] [datetime] NULL,
	[CreatedOn] [datetime] NOT NULL,
	[CreatedBy] [int] NOT NULL,
	[ModifiedOn] [datetime] NULL,
	[ModifiedBy] [int] NULL,
	[IsActive] [bit] NOT NULL,
 CONSTRAINT [PK_Users] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [Tzdb].[VersionInfo]    Script Date: 5/24/2019 12:11:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [Tzdb].[VersionInfo](
	[Version] [char](5) NOT NULL,
	[Loaded] [datetimeoffset](0) NOT NULL,
 CONSTRAINT [PK_VersionInfo] PRIMARY KEY CLUSTERED 
(
	[Version] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ColumnMaster] ADD  CONSTRAINT [DF_ColumnMaster_IsRequired]  DEFAULT ((0)) FOR [IsRequired]
GO
ALTER TABLE [dbo].[ColumnMaster] ADD  CONSTRAINT [DF_ColumnMaster_SystemDefined]  DEFAULT ((1)) FOR [IsSystemDefined]
GO
ALTER TABLE [dbo].[EmailNotifications] ADD  CONSTRAINT [DF_EmailNotifications_ForRequestor]  DEFAULT ((0)) FOR [ForRequestor]
GO
ALTER TABLE [dbo].[EmailNotifications] ADD  CONSTRAINT [DF_EmailNotifications_ForAssignee]  DEFAULT ((0)) FOR [ForAssignee]
GO
ALTER TABLE [dbo].[EmailNotifications] ADD  CONSTRAINT [DF_EmailNotifications_ForWatcher]  DEFAULT ((0)) FOR [ForWatcher]
GO
ALTER TABLE [dbo].[EmailNotifications] ADD  CONSTRAINT [DF_EmailNotifications_EmailTemplateId]  DEFAULT ((0)) FOR [EmailTemplateId]
GO
ALTER TABLE [dbo].[Events] ADD  CONSTRAINT [DF_Events_IsReadonly]  DEFAULT ((0)) FOR [IsReadonly]
GO
ALTER TABLE [dbo].[Events] ADD  CONSTRAINT [DF_Events_IsActive]  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[Events] ADD  CONSTRAINT [DF_Events_IsMappedToRequest]  DEFAULT ((0)) FOR [IsMappedToRequest]
GO
ALTER TABLE [dbo].[Events] ADD  CONSTRAINT [DF_Events_IsDefault]  DEFAULT ((0)) FOR [IsDefault]
GO
ALTER TABLE [dbo].[EventType] ADD  CONSTRAINT [DF_EventType_IsNotificationRequired]  DEFAULT ((0)) FOR [IsNotificationRequired]
GO
ALTER TABLE [dbo].[FeaturesGroup] ADD  CONSTRAINT [DF_FeaturesGroup_AliasName]  DEFAULT ('') FOR [AliasName]
GO
ALTER TABLE [dbo].[FeaturesGroup] ADD  CONSTRAINT [DF_FeaturesGroup_IsDeafult]  DEFAULT ((1)) FOR [IsDeafult]
GO
ALTER TABLE [dbo].[Key] ADD  CONSTRAINT [DF_Key_IsMappedToRequest]  DEFAULT ((0)) FOR [IsMappedToRequest]
GO
ALTER TABLE [dbo].[Key] ADD  CONSTRAINT [DF_Key_IsMappedToRequest1]  DEFAULT ((0)) FOR [IsMappedToUser]
GO
ALTER TABLE [dbo].[Key] ADD  CONSTRAINT [DF_Key_IsActive1]  DEFAULT ((1)) FOR [IsRequired]
GO
ALTER TABLE [dbo].[Key] ADD  CONSTRAINT [DF_Key_IsActive]  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[MapRoleWithFeatures] ADD  CONSTRAINT [DF_MapRoleWithFeatures_CanAdd]  DEFAULT ((0)) FOR [CanAdd]
GO
ALTER TABLE [dbo].[MapRoleWithFeatures] ADD  CONSTRAINT [DF_MapRoleWithFeatures_CanRead]  DEFAULT ((0)) FOR [CanRead]
GO
ALTER TABLE [dbo].[MapRoleWithFeatures] ADD  CONSTRAINT [DF_MapRoleWithFeatures_CanUpdate]  DEFAULT ((0)) FOR [CanUpdate]
GO
ALTER TABLE [dbo].[MapRoleWithFeatures] ADD  CONSTRAINT [DF_MapRoleWithFeatures_CanDelete]  DEFAULT ((0)) FOR [CanDelete]
GO
ALTER TABLE [dbo].[Reports] ADD  CONSTRAINT [DF_Reports_IsDownload]  DEFAULT ((0)) FOR [IsDownload]
GO
ALTER TABLE [dbo].[Request] ADD  CONSTRAINT [DF_Request_IsRecurrence]  DEFAULT ((0)) FOR [IsRecurrence]
GO
ALTER TABLE [dbo].[RequestFeedback] ADD  CONSTRAINT [DF_RequestFeedback_IsReminded]  DEFAULT ((0)) FOR [IsReminded]
GO
ALTER TABLE [dbo].[Role] ADD  CONSTRAINT [DF_Role_IsActive_1]  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[Role] ADD  CONSTRAINT [DF_Role_IsNotifiedOnCreateRequest]  DEFAULT ((0)) FOR [IsNotifiedOnCreateRequest]
GO
ALTER TABLE [dbo].[Attributes]  WITH CHECK ADD  CONSTRAINT [fk_attributes_master] FOREIGN KEY([MasterId])
REFERENCES [dbo].[Master] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[Attributes] CHECK CONSTRAINT [fk_attributes_master]
GO
ALTER TABLE [dbo].[Capacity]  WITH CHECK ADD  CONSTRAINT [FK_Capacity_Users] FOREIGN KEY([UserId])
REFERENCES [dbo].[Users] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[Capacity] CHECK CONSTRAINT [FK_Capacity_Users]
GO
ALTER TABLE [dbo].[ColumnMaster]  WITH CHECK ADD  CONSTRAINT [FK_ColumnMaster_TablesMaster] FOREIGN KEY([TableId])
REFERENCES [dbo].[TablesMaster] ([Id])
GO
ALTER TABLE [dbo].[ColumnMaster] CHECK CONSTRAINT [FK_ColumnMaster_TablesMaster]
GO
ALTER TABLE [dbo].[Comments]  WITH CHECK ADD  CONSTRAINT [FK_Comments_Request] FOREIGN KEY([RequestId])
REFERENCES [dbo].[Request] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[Comments] CHECK CONSTRAINT [FK_Comments_Request]
GO
ALTER TABLE [dbo].[Documents]  WITH CHECK ADD  CONSTRAINT [FK_Documents_Request] FOREIGN KEY([RequestId])
REFERENCES [dbo].[Request] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[Documents] CHECK CONSTRAINT [FK_Documents_Request]
GO
ALTER TABLE [dbo].[EmailNotifications]  WITH CHECK ADD  CONSTRAINT [FK_EmailNotifications_EmailTemplates] FOREIGN KEY([EmailTemplateId])
REFERENCES [dbo].[EmailTemplates] ([Id])
GO
ALTER TABLE [dbo].[EmailNotifications] CHECK CONSTRAINT [FK_EmailNotifications_EmailTemplates]
GO
ALTER TABLE [dbo].[EmailNotifications]  WITH CHECK ADD  CONSTRAINT [FK_EmailNotifications_Events] FOREIGN KEY([EventId])
REFERENCES [dbo].[Events] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[EmailNotifications] CHECK CONSTRAINT [FK_EmailNotifications_Events]
GO
ALTER TABLE [dbo].[Events]  WITH CHECK ADD  CONSTRAINT [FK_Events_Events1] FOREIGN KEY([Type])
REFERENCES [dbo].[EventType] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[Events] CHECK CONSTRAINT [FK_Events_Events1]
GO
ALTER TABLE [dbo].[EventWorkFlow]  WITH CHECK ADD  CONSTRAINT [FK_EventWorkFlow_Events] FOREIGN KEY([EventId])
REFERENCES [dbo].[Events] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[EventWorkFlow] CHECK CONSTRAINT [FK_EventWorkFlow_Events]
GO
ALTER TABLE [dbo].[EventWorkFlow]  WITH CHECK ADD  CONSTRAINT [FK_EventWorkFlow_Events1] FOREIGN KEY([SuccessorEventId])
REFERENCES [dbo].[Events] ([Id])
GO
ALTER TABLE [dbo].[EventWorkFlow] CHECK CONSTRAINT [FK_EventWorkFlow_Events1]
GO
ALTER TABLE [dbo].[Features]  WITH CHECK ADD  CONSTRAINT [FK_Features_FeatureGroup] FOREIGN KEY([Group])
REFERENCES [dbo].[FeaturesGroup] ([Id])
GO
ALTER TABLE [dbo].[Features] CHECK CONSTRAINT [FK_Features_FeatureGroup]
GO
ALTER TABLE [dbo].[Key]  WITH CHECK ADD  CONSTRAINT [FK_Key_Master] FOREIGN KEY([MasterId])
REFERENCES [dbo].[Master] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[Key] CHECK CONSTRAINT [FK_Key_Master]
GO
ALTER TABLE [dbo].[MapAttributesWithAttributes]  WITH CHECK ADD  CONSTRAINT [FK_MappingAttributesWithAttributes_Attributes] FOREIGN KEY([PrimaryAttributeId])
REFERENCES [dbo].[Attributes] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[MapAttributesWithAttributes] CHECK CONSTRAINT [FK_MappingAttributesWithAttributes_Attributes]
GO
ALTER TABLE [dbo].[MapAttributesWithAttributes]  WITH CHECK ADD  CONSTRAINT [FK_MappingAttributesWithAttributes_Attributes2] FOREIGN KEY([TertiaryAttributeId])
REFERENCES [dbo].[Attributes] ([Id])
GO
ALTER TABLE [dbo].[MapAttributesWithAttributes] CHECK CONSTRAINT [FK_MappingAttributesWithAttributes_Attributes2]
GO
ALTER TABLE [dbo].[MapMasterAttributesWithUsers]  WITH CHECK ADD  CONSTRAINT [FK_MappingMasterAttributesWithUsers_Attributes] FOREIGN KEY([AttributeId])
REFERENCES [dbo].[Attributes] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[MapMasterAttributesWithUsers] CHECK CONSTRAINT [FK_MappingMasterAttributesWithUsers_Attributes]
GO
ALTER TABLE [dbo].[MapMasterAttributesWithUsers]  WITH CHECK ADD  CONSTRAINT [FK_MappingMasterAttributesWithUsers_Users] FOREIGN KEY([UserId])
REFERENCES [dbo].[Users] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[MapMasterAttributesWithUsers] CHECK CONSTRAINT [FK_MappingMasterAttributesWithUsers_Users]
GO
ALTER TABLE [dbo].[MapMasterWithMasters]  WITH NOCHECK ADD  CONSTRAINT [FK_MapMasterWithMasters_Master] FOREIGN KEY([PrimaryMasterId])
REFERENCES [dbo].[Master] ([Id])
ON UPDATE CASCADE
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[MapMasterWithMasters] CHECK CONSTRAINT [FK_MapMasterWithMasters_Master]
GO
ALTER TABLE [dbo].[MapMasterWithMasters]  WITH NOCHECK ADD  CONSTRAINT [FK_MapMasterWithMasters_Master1] FOREIGN KEY([SecondaryMasterId])
REFERENCES [dbo].[Master] ([Id])
GO
ALTER TABLE [dbo].[MapMasterWithMasters] CHECK CONSTRAINT [FK_MapMasterWithMasters_Master1]
GO
ALTER TABLE [dbo].[MapRequestWithMasterAttributes]  WITH CHECK ADD  CONSTRAINT [FK_MappingRequestWithMasterAttributes_Attributes] FOREIGN KEY([AttributeId])
REFERENCES [dbo].[Attributes] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[MapRequestWithMasterAttributes] CHECK CONSTRAINT [FK_MappingRequestWithMasterAttributes_Attributes]
GO
ALTER TABLE [dbo].[MapRequestWithMasterAttributes]  WITH CHECK ADD  CONSTRAINT [FK_MappingRequestWithMasterAttributes_Request] FOREIGN KEY([RequestId])
REFERENCES [dbo].[Request] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[MapRequestWithMasterAttributes] CHECK CONSTRAINT [FK_MappingRequestWithMasterAttributes_Request]
GO
ALTER TABLE [dbo].[MapRoleWithEvents]  WITH CHECK ADD  CONSTRAINT [FK_MapRoleWithEvents_Events] FOREIGN KEY([EventId])
REFERENCES [dbo].[Events] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[MapRoleWithEvents] CHECK CONSTRAINT [FK_MapRoleWithEvents_Events]
GO
ALTER TABLE [dbo].[MapRoleWithEvents]  WITH CHECK ADD  CONSTRAINT [FK_MapRoleWithEvents_Role] FOREIGN KEY([RoleId])
REFERENCES [dbo].[Role] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[MapRoleWithEvents] CHECK CONSTRAINT [FK_MapRoleWithEvents_Role]
GO
ALTER TABLE [dbo].[MapRoleWithFeatures]  WITH CHECK ADD  CONSTRAINT [FK_MapRoleWithFeatures_Features] FOREIGN KEY([FeatureId])
REFERENCES [dbo].[Features] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[MapRoleWithFeatures] CHECK CONSTRAINT [FK_MapRoleWithFeatures_Features]
GO
ALTER TABLE [dbo].[MapRoleWithFeatures]  WITH CHECK ADD  CONSTRAINT [FK_MapRoleWithFeatures_Role] FOREIGN KEY([RoleId])
REFERENCES [dbo].[Role] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[MapRoleWithFeatures] CHECK CONSTRAINT [FK_MapRoleWithFeatures_Role]
GO
ALTER TABLE [dbo].[MapUserWithRoles]  WITH CHECK ADD  CONSTRAINT [FK_MapUserWithRoles_Role] FOREIGN KEY([RoleId])
REFERENCES [dbo].[Role] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[MapUserWithRoles] CHECK CONSTRAINT [FK_MapUserWithRoles_Role]
GO
ALTER TABLE [dbo].[MapUserWithRoles]  WITH CHECK ADD  CONSTRAINT [FK_MapUserWithRoles_Users] FOREIGN KEY([UserId])
REFERENCES [dbo].[Users] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[MapUserWithRoles] CHECK CONSTRAINT [FK_MapUserWithRoles_Users]
GO
ALTER TABLE [dbo].[MapUserWithTeams]  WITH CHECK ADD  CONSTRAINT [FK_MappingUserWithTeams_Team] FOREIGN KEY([TeamId])
REFERENCES [dbo].[Team] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[MapUserWithTeams] CHECK CONSTRAINT [FK_MappingUserWithTeams_Team]
GO
ALTER TABLE [dbo].[MapUserWithTeams]  WITH CHECK ADD  CONSTRAINT [FK_MappingUserWithTeams_Users] FOREIGN KEY([UserId])
REFERENCES [dbo].[Users] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[MapUserWithTeams] CHECK CONSTRAINT [FK_MappingUserWithTeams_Users]
GO
ALTER TABLE [dbo].[MasterKeyValues]  WITH CHECK ADD  CONSTRAINT [FK_MasterKeyValues_Key] FOREIGN KEY([KeyId])
REFERENCES [dbo].[Key] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[MasterKeyValues] CHECK CONSTRAINT [FK_MasterKeyValues_Key]
GO
ALTER TABLE [dbo].[Recurrence]  WITH CHECK ADD  CONSTRAINT [FK_Recurrence_Request] FOREIGN KEY([RequestId])
REFERENCES [dbo].[Request] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[Recurrence] CHECK CONSTRAINT [FK_Recurrence_Request]
GO
ALTER TABLE [dbo].[RequestFeedback]  WITH CHECK ADD  CONSTRAINT [FK_RequestFeedback_Request] FOREIGN KEY([RequestId])
REFERENCES [dbo].[Request] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[RequestFeedback] CHECK CONSTRAINT [FK_RequestFeedback_Request]
GO
ALTER TABLE [dbo].[RequestKeyValues]  WITH CHECK ADD  CONSTRAINT [FK_MappingRequestWithRequestAttributes_Request] FOREIGN KEY([RequestId])
REFERENCES [dbo].[Request] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[RequestKeyValues] CHECK CONSTRAINT [FK_MappingRequestWithRequestAttributes_Request]
GO
ALTER TABLE [dbo].[RequestKeyValues]  WITH CHECK ADD  CONSTRAINT [FK_RequestKeyValues_Key] FOREIGN KEY([KeyId])
REFERENCES [dbo].[Key] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[RequestKeyValues] CHECK CONSTRAINT [FK_RequestKeyValues_Key]
GO
ALTER TABLE [dbo].[RequestWatchers]  WITH CHECK ADD  CONSTRAINT [FK_RequestWatchers_Request] FOREIGN KEY([RequestId])
REFERENCES [dbo].[Request] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[RequestWatchers] CHECK CONSTRAINT [FK_RequestWatchers_Request]
GO
ALTER TABLE [dbo].[RequestWatchers]  WITH CHECK ADD  CONSTRAINT [FK_RequestWatchers_Team] FOREIGN KEY([TeamId])
REFERENCES [dbo].[Team] ([Id])
GO
ALTER TABLE [dbo].[RequestWatchers] CHECK CONSTRAINT [FK_RequestWatchers_Team]
GO
ALTER TABLE [dbo].[RequestWatchers]  WITH CHECK ADD  CONSTRAINT [FK_RequestWatchers_Users] FOREIGN KEY([UserId])
REFERENCES [dbo].[Users] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[RequestWatchers] CHECK CONSTRAINT [FK_RequestWatchers_Users]
GO
ALTER TABLE [dbo].[Timeline]  WITH CHECK ADD  CONSTRAINT [FK_Timeline_Events] FOREIGN KEY([EventId])
REFERENCES [dbo].[Events] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[Timeline] CHECK CONSTRAINT [FK_Timeline_Events]
GO
ALTER TABLE [dbo].[Timeline]  WITH CHECK ADD  CONSTRAINT [FK_Timeline_Request] FOREIGN KEY([RequestId])
REFERENCES [dbo].[Request] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[Timeline] CHECK CONSTRAINT [FK_Timeline_Request]
GO
ALTER TABLE [dbo].[Timeline]  WITH CHECK ADD  CONSTRAINT [FK_Timeline_Team] FOREIGN KEY([TeamId])
REFERENCES [dbo].[Team] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[Timeline] CHECK CONSTRAINT [FK_Timeline_Team]
GO
ALTER TABLE [dbo].[Timeline]  WITH CHECK ADD  CONSTRAINT [FK_Timeline_Users] FOREIGN KEY([UserId])
REFERENCES [dbo].[Users] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[Timeline] CHECK CONSTRAINT [FK_Timeline_Users]
GO
ALTER TABLE [dbo].[TimeTracking]  WITH CHECK ADD  CONSTRAINT [FK_TimeTracking_Capacity] FOREIGN KEY([CapacityId])
REFERENCES [dbo].[Capacity] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[TimeTracking] CHECK CONSTRAINT [FK_TimeTracking_Capacity]
GO
ALTER TABLE [dbo].[TimeTracking]  WITH CHECK ADD  CONSTRAINT [FK_TimeTracking_Request] FOREIGN KEY([RequestId])
REFERENCES [dbo].[Request] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[TimeTracking] CHECK CONSTRAINT [FK_TimeTracking_Request]
GO
ALTER TABLE [dbo].[TimeTracking]  WITH CHECK ADD  CONSTRAINT [FK_TimeTracking_Users] FOREIGN KEY([UserId])
REFERENCES [dbo].[Users] ([Id])
GO
ALTER TABLE [dbo].[TimeTracking] CHECK CONSTRAINT [FK_TimeTracking_Users]
GO
ALTER TABLE [dbo].[UserKeyValues]  WITH CHECK ADD  CONSTRAINT [FK_UserKeyValues_Users] FOREIGN KEY([UserId])
REFERENCES [dbo].[Users] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[UserKeyValues] CHECK CONSTRAINT [FK_UserKeyValues_Users]
GO
ALTER TABLE [dbo].[Users]  WITH CHECK ADD  CONSTRAINT [FK_Users_TimeZone] FOREIGN KEY([TimeZoneID])
REFERENCES [dbo].[TimeZone] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[Users] CHECK CONSTRAINT [FK_Users_TimeZone]
GO
ALTER TABLE [Tzdb].[Intervals]  WITH CHECK ADD  CONSTRAINT [FK_Intervals_Zones] FOREIGN KEY([ZoneId])
REFERENCES [Tzdb].[Zones] ([Id])
GO
ALTER TABLE [Tzdb].[Intervals] CHECK CONSTRAINT [FK_Intervals_Zones]
GO
ALTER TABLE [Tzdb].[Links]  WITH CHECK ADD  CONSTRAINT [FK_Links_Zones_1] FOREIGN KEY([LinkZoneId])
REFERENCES [Tzdb].[Zones] ([Id])
GO
ALTER TABLE [Tzdb].[Links] CHECK CONSTRAINT [FK_Links_Zones_1]
GO
ALTER TABLE [Tzdb].[Links]  WITH CHECK ADD  CONSTRAINT [FK_Links_Zones_2] FOREIGN KEY([CanonicalZoneId])
REFERENCES [Tzdb].[Zones] ([Id])
GO
ALTER TABLE [Tzdb].[Links] CHECK CONSTRAINT [FK_Links_Zones_2]
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'(Status=1, Date=2)' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Events', @level2type=N'COLUMN',@level2name=N'Type'
GO
