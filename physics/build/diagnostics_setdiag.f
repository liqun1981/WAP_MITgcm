C $Header: /u/gcmpack/MITgcm/pkg/diagnostics/diagnostics_setdiag.F,v 1.5 2008/02/05 15:13:01 jmc Exp $
C $Name: checkpoint62r $

#include "DIAG_OPTIONS.h"

CBOP
C     !ROUTINE: DIAGNOSTICS_SETDIAG
C     !INTERFACE:
      SUBROUTINE DIAGNOSTICS_SETDIAG(
     O                      mate,
     U                      ndiagmx,
     I                      mId, listId, ndId, myThid )

C     !DESCRIPTION: \bv
C     *==================================================================
C     | S/R DIAGNOSTICS_SETDIAG
C     | o activate diagnostic "ndId":
C     |   set pointer locations for this diagnostic ;
C     |   look for a counter mate and set it
C     *==================================================================
C     \ev

C     !USES:
      IMPLICIT NONE

C     == Global variables ===
#include "EEPARAMS.h"
#include "SIZE.h"
#include "DIAGNOSTICS_SIZE.h"
#include "DIAGNOSTICS.h"

C     !INPUT/OUTPUT PARAMETERS:
C     == Routine arguments ==
C     mate    :: counter-mate number in available diagnostics list
C     ndiagmx :: current space allocated in storage array
C     mId     :: current field index in list "listId"
C     listId  :: current list number that contains field "mId"
C     ndId    :: diagnostic number in available diagnostics list
C     myThid  :: Thread number for this instance of the routine.
      INTEGER mate
      INTEGER ndiagmx
      INTEGER mId, listId, ndId
      INTEGER myThid
CEOP

C     !LOCAL VARIABLES:
C     == Local variables ==
      INTEGER stdUnit, errUnit
      INTEGER k, l
      LOGICAL flag

      CHARACTER*10 gcode
      CHARACTER*(MAX_LEN_MBUF) msgBuf


C **********************************************************************
C ****                SET POINTERS FOR DIAGNOSTIC ndId              ****
C **********************************************************************

      gcode   = gdiag(ndId)(1:10)
      stdUnit = standardMessageUnit
      errUnit = errorMessageUnit

C--   Seach for the same diag (with same freq) to see if already set
      flag = .TRUE.
      DO l=1,listId
       IF (flag .AND. freq(l) .EQ. freq(listId)
     &          .AND. phase(l).EQ.phase(listId)
     &          .AND. averageFreq(l) .EQ.averageFreq(listId)
     &          .AND. averagePhase(l).EQ.averagePhase(listId)
     &          .AND. averageCycle(l).EQ.averageCycle(listId) ) THEN
        DO k=1,MIN(nActive(l),numperlist)
         IF (flag .AND. jdiag(k,l).GT.0) THEN
          IF ( cdiag(ndId).EQ.cdiag(jdiag(k,l)) ) THEN
C-    diagnostics already set ; use the same slot:
           flag = .FALSE.
           idiag(mId,listId) = -ABS(idiag(k,l))
           mdiag(mId,listId) = mdiag(k,l)
          ENDIF
         ENDIF
        ENDDO
       ENDIF
      ENDDO

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|

      IF ( flag ) THEN
        idiag(mId,listId) = ndiagmx + 1
        ndiagmx = ndiagmx + kdiag(ndId)*averageCycle(listId)
        IF ( ndiagmx.GT.numDiags ) THEN
         WRITE(msgBuf,'(A,I6,1X,A)')
     &    'SETDIAG: Not enough space for Diagnostic #',ndId,cdiag(ndId)
         CALL PRINT_MESSAGE(msgBuf, errUnit, SQUEEZE_RIGHT, myThid)
        ELSE
         WRITE(msgBuf,'(A,2(I3,A),I6,1X,A)') 'SETDIAG: Allocate',
     &                   kdiag(ndId), ' x', averageCycle(listId),
     &                ' Levels for Diagnostic #', ndId, cdiag(ndId)
         CALL PRINT_MESSAGE(msgBuf, stdUnit, SQUEEZE_RIGHT, myThid)
        ENDIF
      ELSE
        WRITE(msgBuf,'(A,I6,1X,2A)')
     &    '- WARNING - SETDIAG: Diagnostic #', ndId, cdiag(ndId),
     &    ' has already been set'
        CALL PRINT_MESSAGE(msgBuf, errUnit, SQUEEZE_RIGHT, myThid)
        mate = 0
        RETURN
      ENDIF

c Check for Counter Diagnostic
c ----------------------------
      mate = 0
      IF ( gcode(5:5).EQ.'C') THEN
        mate = hdiag(ndId)

C--     Seach for the same diag (with same freq) to see if already set
        flag = .TRUE.
        DO l=1,listId
         IF (flag .AND. freq(l) .EQ.freq(listId)
     &            .AND. phase(l).EQ.phase(listId)
     &            .AND. averageFreq(l) .EQ.averageFreq(listId)
     &            .AND. averagePhase(l).EQ.averagePhase(listId)
     &            .AND. averageCycle(l).EQ.averageCycle(listId) ) THEN
          DO k=1,MIN(nActive(l),numperlist)
           IF (flag .AND. jdiag(k,l).GT.0) THEN
            IF (cdiag(mate).EQ.cdiag(jdiag(k,l)) ) THEN
C-    diagnostics already set ; use the same slot:
             flag = .FALSE.
             mdiag(mId,listId) = ABS(idiag(k,l))
            ENDIF
           ENDIF
          ENDDO
         ENDIF
        ENDDO

        IF ( flag ) THEN
          mdiag(mId,listId) = ndiagmx + 1
          ndiagmx = ndiagmx + kdiag(mate)*averageCycle(listId)
          IF ( ndiagmx.GT.numDiags ) THEN
           WRITE(msgBuf,'(A,I6,1X,A)')
     &      'SETDIAG: Not enough space for Counter Diagnostic #',
     &      mate, cdiag(mate)
           CALL PRINT_MESSAGE(msgBuf, errUnit, SQUEEZE_RIGHT, myThid)
          ELSE
           WRITE(msgBuf,'(A,2(I3,A),I6,1X,A)') 'SETDIAG: Allocate',
     &                     kdiag(mate), ' x', averageCycle(listId),
     &                  ' Levels for Count.Diag #', mate, cdiag(mate)
           CALL PRINT_MESSAGE(msgBuf, stdUnit, SQUEEZE_RIGHT, myThid)
          ENDIF
        ELSE
          WRITE(msgBuf,'(A,I6,1X,2A)')
     &    '- NOTE - SETDIAG: Counter Diagnostic #', mate, cdiag(mate),
     &    ' has already been set'
          CALL PRINT_MESSAGE(msgBuf, stdUnit, SQUEEZE_RIGHT, myThid)
          mate = 0
        ENDIF
      ENDIF

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      RETURN
      END
