C $Header: /u/gcmpack/MITgcm/eesupp/src/open_copy_data_file.F,v 1.3 2010/12/13 04:24:25 jmc Exp $
C $Name: checkpoint62r $

#include "CPP_EEOPTIONS.h"

CBOP
C     !ROUTINE: OPEN_COPY_DATA_FILE
C     !INTERFACE:
      SUBROUTINE OPEN_COPY_DATA_FILE(
     I                                data_file, caller_sub,
     O                                iUnit,
     I                                myThid )
C     !DESCRIPTION: \bv
C     *==========================================================*
C     | SUBROUTINE OPEN_COPY_DATA_FILE
C     | o Routine to open and copy a data.* file to STDOUT
C     |   and return the open unit in iUnit
C     *==========================================================*
C     \ev

C     !USES:
      IMPLICIT NONE
C     === Global variables ===
#include "SIZE.h"
#include "EEPARAMS.h"

C     !INPUT/OUTPUT PARAMETERS:
C     === Routine arguments ===
C     data_file  :: parameter file to open and copy
C     caller_sub :: name of subroutine which is calling this S/R
C     iUnit      :: IO unit of parameter-file copy (already opened)
C     myThid     :: my Thread Id number
      CHARACTER*(*) data_file
      CHARACTER*(*) caller_sub
      INTEGER iUnit
      INTEGER myThid

C     !FUNCTIONS:
      INTEGER  ILNBLNK
      EXTERNAL ILNBLNK

C     !LOCAL VARIABLES:
C     === Local variables ===
C     msgBuf    :: Informational/error message buffer
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      CHARACTER*(MAX_LEN_PREC) record
#if defined (TARGET_BGL) || defined (TARGET_CRAYXT)
      CHARACTER*(MAX_LEN_FNAM) scratchFile1
      CHARACTER*(MAX_LEN_FNAM) scratchFile2
#endif
      INTEGER  errIO,IL
      LOGICAL  exst
CEOP

      _BEGIN_MASTER(myThid)

C--   Open the parameter file
      INQUIRE( FILE=data_file, EXIST=exst )
      IF (exst) THEN
       WRITE(msgbuf,'(A,A)')
     &   ' OPEN_COPY_DATA_FILE: opening file ',data_file
       CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                     SQUEEZE_RIGHT, myThid )
      ELSE
       WRITE(msgBuf,'(A,A,A)')
     &  'File ',data_file,' does not exist!'
       CALL PRINT_ERROR( msgBuf, myThid )
       WRITE(msgBuf,'(A,A)') 'S/R CALLED BY ',caller_sub
       CALL PRINT_ERROR( msgBuf, myThid )
       STOP 'ABNORMAL END: S/R OPEN_COPY_DATA_FILE'
      ENDIF

#if defined (TARGET_BGL) || defined (TARGET_CRAYXT)
      WRITE(scratchFile1,'(A,I4.4)') 'scratch1.', myProcId
      WRITE(scratchFile2,'(A,I4.4)') 'scratch2.', myProcId
      OPEN(UNIT=scrUnit1, FILE=scratchFile1, STATUS='UNKNOWN')
      OPEN(UNIT=scrUnit2, FILE=scratchFile2, STATUS='UNKNOWN')
#else
      OPEN(UNIT=scrUnit1,STATUS='SCRATCH')
      OPEN(UNIT=scrUnit2,STATUS='SCRATCH')
#endif
      OPEN(UNIT=modelDataUnit,FILE=data_file,STATUS='OLD',
     &     IOSTAT=errIO)
      IF ( errIO .LT. 0 ) THEN
       WRITE(msgBuf,'(A,A)')
     &  'Unable to open parameter file: ',data_file
       CALL PRINT_ERROR( msgBuf, myThid )
       WRITE(msgBuf,'(A,A)') 'S/R CALLED BY ',caller_sub
       CALL PRINT_ERROR( msgBuf, myThid )
       STOP 'ABNORMAL END: S/R OPEN_COPY_DATA_FILE'
      ENDIF

      DO WHILE ( .TRUE. )
       READ(modelDataUnit,FMT='(A)',END=1001) RECORD
       IL = MAX(ILNBLNK(RECORD),1)
       IF ( RECORD(1:1) .NE. commentCharacter ) THEN
c        CALL NML_SET_TERMINATOR( RECORD )
         CALL NML_CHANGE_SYNTAX( RECORD, data_file, myThid )
         WRITE(UNIT=scrUnit1,FMT='(A)') RECORD(:IL)
       ENDIF
       WRITE(UNIT=scrUnit2,FMT='(A)') RECORD(:IL)
      ENDDO
 1001 CONTINUE
      CLOSE(modelDataUnit)

C--   Report contents of model parameter file
      WRITE(msgBuf,'(A)')
     &'// ======================================================='
      CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                    SQUEEZE_RIGHT, myThid )
      WRITE(msgBuf,'(A,A,A)') '// Parameter file "',data_file,'"'
      CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                    SQUEEZE_RIGHT, myThid )
      WRITE(msgBuf,'(A)')
     &'// ======================================================='
      CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                    SQUEEZE_RIGHT, myThid )
      iUnit = scrUnit2
      REWIND(iUnit)
      DO WHILE ( .TRUE. )
       READ(UNIT=iUnit,FMT='(A)',END=2001) RECORD
       IL = MAX(ILNBLNK(RECORD),1)
       WRITE(msgBuf,'(A,A)') '>',RECORD(:IL)
       CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                     SQUEEZE_RIGHT, myThid )
      ENDDO
 2001 CONTINUE
      CLOSE(iUnit)
      WRITE(msgBuf,'(A)') ' '
      CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                    SQUEEZE_RIGHT, myThid )

C--   Return open unit to caller
      iUnit = scrUnit1
      REWIND(iUnit)

      _END_MASTER(myThid)

      RETURN
      END
