C $Header: /u/gcmpack/MITgcm/pkg/matrix/matrix_output.F,v 1.2 2007/11/05 18:58:00 jmc Exp $
C $Name: checkpoint62r $

#include "PACKAGES_CONFIG.h"
#include "CPP_OPTIONS.h"

CBOP
C     !ROUTINE: MATRIX_OUTPUT

C     !INTERFACE:
      SUBROUTINE MATRIX_OUTPUT(
     I     myTime, myIter, myThid )

C     !DESCRIPTION:
C     This is the controlling routine for MATRIX output. It is
C     called from DO_THE_MODEL_IO.

C     !USES:
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"

C     !INPUT PARAMETERS:
C     myIter    :: time-step number
C     myTime    :: model time
C     myThid    :: thread number
      INTEGER myIter
      INTEGER myThid
      _RL myTime
CEOP

#ifdef ALLOW_MATRIX
C     !LOCAL VARIABLES:

      IF (myIter.NE.nIter0) THEN
C       Write matrix to file
        CALL MATRIX_WRITE_TENDENCY( myTime, myIter, myThid )
      ELSEIF (myIter.EQ.nIter0) THEN
C       Write grid info for pkg/matrix
        CALL MATRIX_WRITE_GRID( myThid )
      ENDIF

#endif /* ALLOW_MATRIX */

      RETURN
      END
