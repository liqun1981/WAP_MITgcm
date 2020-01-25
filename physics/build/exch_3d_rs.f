C $Header: /u/gcmpack/MITgcm/eesupp/src/exch_3d_rx.template,v 1.3 2010/05/19 01:53:46 jmc Exp $
C $Name: checkpoint62r $

#include "PACKAGES_CONFIG.h"
#include "CPP_EEOPTIONS.h"

CBOP
C     !ROUTINE: EXCH_3D_RS

C     !INTERFACE:
      SUBROUTINE EXCH_3D_RS(
     U                       phi,
     I                       myNz, myThid )

C     !DESCRIPTION:
C     *==========================================================*
C     | SUBROUTINE EXCH_3D_RS
C     | o Handle exchanges for _RS, three-dim scalar arrays.
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
      _RS phi(1-OLx:sNx+OLx,1-OLy:sNy+OLy,1:myNz,nSx,nSy)
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
      CALL EXCH2_3D_RS( phi, myNz, myThid )
      RETURN
#else /* ALLOW_EXCH2 */

      OLw        = OLx
      OLe        = OLx
      OLn        = OLy
      OLs        = OLy
      exchWidthX = OLx
      exchWidthY = OLy
      IF (useCubedSphereExchange) THEN
       CALL EXCH1_RS_CUBE( phi, .FALSE.,
     I            OLw, OLe, OLs, OLn, myNz,
     I            exchWidthX, exchWidthY,
     I            EXCH_UPDATE_CORNERS, myThid )
      ELSE
       CALL EXCH1_RS( phi,
     I            OLw, OLe, OLs, OLn, myNz,
     I            exchWidthX, exchWidthY,
     I            EXCH_UPDATE_CORNERS, myThid )
      ENDIF

      RETURN
#endif /* ALLOW_EXCH2 */
      END
