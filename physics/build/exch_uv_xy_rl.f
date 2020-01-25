C $Header: /u/gcmpack/MITgcm/eesupp/src/exch_uv_xy_rx.template,v 1.11 2010/05/19 01:53:46 jmc Exp $
C $Name: checkpoint62r $

#include "PACKAGES_CONFIG.h"
#include "CPP_EEOPTIONS.h"
#ifdef ALLOW_EXCH2
#include "W2_OPTIONS.h"
#endif

CBOP
C     !ROUTINE: EXCH_UV_XY_RL

C     !INTERFACE:
      SUBROUTINE EXCH_UV_XY_RL(
     U                          Uphi, Vphi,
     I                          withSigns, myThid )

C     !DESCRIPTION:
C     *==========================================================*
C     | SUBROUTINE EXCH_UV_XY_RL
C     | o Handle exchanges for _RL, 2-dimensional vector arrays.
C     *==========================================================*
C     | Vector arrays need to be rotated and interchaged for
C     | exchange operations on some grids. This driver routine
C     | branches to support this.
C     *==========================================================*

C     !USES:
      IMPLICIT NONE

C     === Global data ===
#include "SIZE.h"
#include "EEPARAMS.h"

C     !INPUT/OUTPUT PARAMETERS:
C     === Routine arguments ===
C     Uphi      :: 2 components of a vector field with overlap regions
C     Vphi      :: to be exchanged
C     withSigns :: Flag controlling whether vector is signed.
C     myThid    :: my Thread Id. number
      _RL Uphi(1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RL Vphi(1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      LOGICAL withSigns
      INTEGER myThid

C     !LOCAL VARIABLES:
#ifndef ALLOW_EXCH2
C     == Local variables ==
C     OL[wens]       :: Overlap extents in west, east, north, south.
C     exchWidth[XY]  :: Extent of regions that will be exchanged.
      INTEGER OLw, OLe, OLn, OLs, exchWidthX, exchWidthY, myNz
#endif
CEOP

#ifdef ALLOW_EXCH2
#ifdef W2_USE_R1_ONLY
      CALL EXCH2_UV_CGRID_3D_RL(
     U                     Uphi, Vphi,
     I                     withSigns, 1, myThid )
#else
      CALL EXCH2_UV_3D_RL(
     U                     Uphi, Vphi,
     I                     withSigns, 1, myThid )
#endif
      RETURN
#else /* ALLOW_EXCH2 */

      OLw        = OLx
      OLe        = OLx
      OLn        = OLy
      OLs        = OLy
      exchWidthX = OLx
      exchWidthY = OLy
      myNz       = 1
      IF (useCubedSphereExchange) THEN
       CALL EXCH1_UV_RL_CUBE( Uphi, Vphi, withSigns,
     I            OLw, OLe, OLs, OLn, myNz,
     I            exchWidthX, exchWidthY,
     I            EXCH_UPDATE_CORNERS, myThid )
      ELSE
       CALL EXCH1_RL( Uphi,
     I            OLw, OLe, OLs, OLn, myNz,
     I            exchWidthX, exchWidthY,
     I            EXCH_UPDATE_CORNERS, myThid )
       CALL EXCH1_RL( Vphi,
     I            OLw, OLe, OLs, OLn, myNz,
     I            exchWidthX, exchWidthY,
     I            EXCH_UPDATE_CORNERS, myThid )
      ENDIF

      RETURN
#endif /* ALLOW_EXCH2 */
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|

CEH3 ;;; Local Variables: ***
CEH3 ;;; mode:fortran ***
CEH3 ;;; End: ***
