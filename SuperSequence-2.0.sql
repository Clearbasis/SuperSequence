CREATE PROCEDURE [dbo].[cbpXSuperSequence]
/****************************************************************************************************
*****************************************************************************************************
** Copyright 2011 ClearBasis Corporation
** Author: Greg Steirer
** Date Created: 10/24/2003
** Previous Version: 1.0
** This Version: 2.0
** Version Date: 3/28/2011
** License: MIT License - see MIT-LICENSE.txt
*****************************************************************************************************
** Name: SuperSequence
** Desc: Returns a friendly sequential ID within the context of a Sequence Id (SeqId)
** Key: cbp = ClearBasis Plug-in, X = execute, seq = Sequence
** Components:
**	cbpXSuperSequence - Stored Procedure
**  cbpSuperSequence - Table (auto-generated)
*****************************************************************************************************
** Special Settings
*****************************************************************************************************
** SeqMask
** - Purpose: Sequence Mask allows you to specify the format of the sequential ID
** - Options:
**				# : REQUIRED - placeholder for the numeric sequence
**				A-Z, a-z, 0-9, punctuation marks, other symbols : OPTIONAL -  characters for customization
**
*****************************************************************************************************
** Test Example Below (Copy and Paste Into New Query Window)
*****************************************************************************************************

DECLARE	@SuperSequenceOut	varchar(255)

EXEC cbpXSuperSequence
		@SeqMask = 'CUST-#',
		@SeqMaxLength = 0,
		@SeqId = 'SONINT',
		@SeqPadLength = 4,
		@SeqPadChar = '0',
		@SeqSeed = 1,
		@SeqIncrement = 1,
		@SeqLinkId = null,
		@SuperSequenceOut = @SuperSequenceOut OUTPUT,
		@ReturnOption = 2
		
*****************************************************************************************************
****************************************************************************************************/
	@SeqMask			varchar(255),			-- Sequence Mask allows you to specify the format of the sequential ID
	@SeqMaxLength		int,					-- Sets the maximum length of the sequential ID - (for throwing an error, if needed)
	@SeqId				varchar(255),			-- Specifies the context of the sequential ID
	@SeqPadLength		int,					-- Sets the length of padding to the left of the #
	@SeqPadChar			varchar(1),				-- Sets the padding character
	@SeqSeed			int,					-- Sets the seed for the # - (must be > 0)
	@SeqIncrement		int,					-- Sets the increment of the # (must be > 0)
	@SeqLinkId			varchar(100),			-- Sets a third-party or linked Id (used to cross reference if needed)
	@SuperSequenceOut	varchar(255) OUTPUT,	-- Returns the ID
	@ReturnOption		tinyint	= 1				-- 1 = @SuperSequenceOut variable, 2 = SuperSequenceOut result

AS

BEGIN

	SET NOCOUNT ON

	/*Declare Variables*/
	DECLARE	@SuperSequence		varchar(255),
			@SeqNum				int,
			@SeqNumTemp			varchar(255),
			@Token				int,
			@Error				varchar(255),
			@Continue			int,
			@CurDate			datetime

	SELECT 	@Error = '',
			@Continue = 1,
			@CurDate = getdate()

	--Now check for/create the 'SuperSequence' table
	IF (SELECT count(Table_Name) FROM INFORMATION_SCHEMA.TABLES WHERE Table_Name = 'cbpSuperSequence') = 0
		BEGIN

			CREATE TABLE [dbo].[cbpSuperSequence] (
			[SuperSequence]		[varchar] (255) NOT NULL ,
			[SeqId]				[varchar] (50) NOT NULL ,
			[SeqNum]			[int] NOT NULL ,
			[SeqMask]			[varchar] (100) NOT NULL ,
			[SeqMaxLength]		[int] NOT NULL ,
			[SeqPadLength]		[int] NULL ,
			[SeqPadChar]		[varchar] (1) NULL ,
			[SeqSeed]			[int] NULL ,
			[SeqIncrement]		[int] NOT NULL ,
			[SeqLinkId]			[varchar] (50) NULL
			) ON [PRIMARY]

			ALTER TABLE [dbo].[cbpSuperSequence] WITH NOCHECK ADD 
			CONSTRAINT [PK_cbpSuperSequence_SeqId_SeqNum] PRIMARY KEY  CLUSTERED 
			(
				[SeqId],
				[SeqNum]
			)  ON [PRIMARY] 

		END

	--Check to see that the mask contains a #
	IF (SELECT CHARINDEX('#',@SeqMask)) = 0
	BEGIN
		SELECT @Error = 'The mask must contain a #.'
	END

	--Now produce the final value buy using the mask
	IF (SELECT @Error) = ''
	BEGIN

		/*Look for an existing LinkID and if found, abort*/
		SET	@SeqLinkId = isnull(@SeqLinkId, '<SeqLinkId>')
		
		IF (SELECT  @SeqLinkId) <> '<SeqLinkId>'
		BEGIN
			SELECT	@SuperSequence = SuperSequence
			FROM	cbpSuperSequence
			WHERE	SeqLinkId = @SeqLinkId
		END

		IF (SELECT @SuperSequence) IS NULL
			BEGIN
				
				/*Set mask; self explanatory*/
				SET @SuperSequence = @SeqMask
				
				/*Perform optional date masking*/
				-- FUTURE --
				
				/*****************************/
				/*Start the sequence creation*/
				/*****************************/
				BEGIN TRANSACTION
	
				--Get the max id
				SELECT 	@SeqNum = isnull(max(SeqNum),@SeqSeed - @SeqIncrement) + @SeqIncrement
				FROM	cbpSuperSequence  WITH (TABLOCKX)
				WHERE	SeqId = @SeqId

				--Now create the final value based on the mask
				--Replace the # with the sequential number
				SELECT @SeqNumTemp = convert(varchar(255),@SeqNum)
		
				IF (SELECT @SeqPadLength) > 0
					BEGIN
						SELECT @SuperSequence = REPLACE(@SuperSequence,'#',REPLICATE(@SeqPadChar,@SeqPadLength - DATALENGTH(@SeqNumTemp)) + @SeqNumTemp)
					END
	
				ELSE
	
					BEGIN
						SELECT @SuperSequence = REPLACE(@SuperSequence,'#',@SeqNumTemp)
					END

				--Now commit the final value to the table
				INSERT	cbpSuperSequence
						(
						SuperSequence,
						SeqId,
						SeqNum,
						SeqMask,
						SeqMaxLength,
						SeqPadLength,
						SeqPadChar,
						SeqSeed,
						SeqIncrement,
						SeqLinkId
						)
				SELECT	SuperSequence = @SuperSequence,
						SeqId = @SeqId,
						SeqNum = @SeqNum,
						SeqMask = @SeqMask,
						SeqMaxLength = @SeqMaxLength,
						SeqPadLength = @SeqPadLength,
						SeqPadChar = @SeqPadChar,
						SeqSeed = @SeqSeed,
						SeqIncrement = @SeqIncrement,
						SeqLinkId = @SeqLinkId
		
				COMMIT TRANSACTION

				--Verify the length and compare to @SeqMaxLength
				--If it is too long, then delete the token and retun an error
				IF (SELECT DATALENGTH(@SuperSequence)) > @SeqMaxLength
				AND (SELECT @SeqMaxLength) > 0
				BEGIN
				
					SELECT 	@Error = 'Final value exceeds specified length.'
					
					DELETE 	cbpSuperSequence
					WHERE 	SeqNum = @SeqNum
					AND		SeqId = @SeqId
					
				END
	
			END

		END

	IF (SELECT @Error) = ''
		BEGIN
			SELECT	@SuperSequenceOut = @SuperSequence
		END
		
	IF (SELECT	@ReturnOption) = 2
	BEGIN
		SELECT	Error = @Error,
				SuperSequenceOut = @SuperSequenceOut
	END

	PRINT 'SuperSequence has completed with the following results:'
	PRINT '*****************************************************'
	PRINT 'Errors: ' + isnull(@Error,'- none -')
	PRINT ''
	PRINT 'Mask: ' + @SeqMask
	PRINT 'Max Length: ' + convert(varchar(25),@SeqMaxLength)
	PRINT 'Id: ' + @SeqId
	PRINT 'Pad Length: ' + convert(varchar(25),@SeqPadLength)
	PRINT 'Pad Char: ' + @SeqPadChar
	PRINT 'Seed: ' + convert(varchar(25),@SeqSeed)
	PRINT 'Increment: ' + convert(varchar(25),@SeqIncrement)
	PRINT 'Link Id: ' + @SeqLinkId
	PRINT 'SuperSequenceOut: ' + isnull(@SuperSequence,'')
	PRINT ''
	
RETURN 0

END