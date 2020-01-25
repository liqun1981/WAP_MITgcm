C $Header: /u/gcmpack/MITgcm/eesupp/src/exch_s3d_rx.template,v 1.5 2010/05/19 01:53:46 jmc Exp $
C $Name: checkpoint62r $

#include "PACKAGES_CONFIG.h"
#include "CPP_EEOPTIONS.h"

CBOP
C     !ROUTINE: EXCH_S3D_R4

C     !INTERFACE:
      SUBROUTINE EXCH_S3D_R4(
     U                       phi,
     I                       myNz, myThid )

C     !DESCRIPTION:
C     *==========================================================*
C     | SUBROUTINE EXCH_S3D_R4
C     | o Handle Simple exchanges (= that ignore corners)
C     |   for _R4, 3-dim scalar arrays with overlap size = 1
C     *==========================================================*
C     | Invoke appropriate exchange routine depending on type
C     | of grid (cube or globally indexed) to be operated on.
C     *==========================================================*

C     !USES:
      IMPLICIT NONE
C     === Global data ===
#include "SIZE.h"
#include "EEPARAMS.h"

C     !INPUT/OUTPUT PARAMETERS:
C     === Routine arguments ===
C     phi    :: Array with overlap regions are to be exchanged
C     myNz   :: 3rd dimension of array to exchange
C     myThid :: My thread id.
      INTEGER myNz
      _R4 phi(0:sNx+1,0:sNy+1,myNz,nSx,nSy)
      INTEGER myThid

C     !LOCAL VARIABLES:
#ifndef ALLOW_EXCH2
C     == Local variables ==
C     OL[wens]       :: Overlap extents in west, east, north, south.
C     exchWidth[XY]  :: Extent of regions that will be exchanged.
      INTEGER OLw, OLe, OLn, OLs, exchWidthX, exchWidthY
#endif
CEOP

#ifdef ALLOW_EXCH2
      CALL EXCH2_S3D_R4( phi, myNz, myThid )
      RETURN
#else /* ALLOW_EXCH2 */

      OLw        = 1
      OLe        = 1
      OLn        = 1
      OLs        = 1
      exchWidthX = 1
      exchWidthY = 1
      IF (useCubedSphereExchange) THEN
       CALL EXCH1_R4_CUBE( phi, .FALSE.,
     I            OLw, OLe, OLs, OLn, myNz,
     I            exchWidthX, exchWidthY,
     I            EXCH_IGNORE_CORNERS, myThid )
      ELSE
       CALL EXCH1_R4( phi,
     I            OLw, OLe, OLs, OLn, myNz,
     I            exchWidthX, exchWidthY,
     I            EXCH_IGNORE_CORNERS, myThid )
      ENDIF

      RETURN
#endif /* ALLOW_EXCH2 */
      END
