C $Header: /u/gcmpack/MITgcm/eesupp/src/exch_uv_dgrid_3d_rx.template,v 1.3 2010/05/19 01:53:46 jmc Exp $
C $Name: checkpoint62r $

#include "PACKAGES_CONFIG.h"
#include "CPP_EEOPTIONS.h"

CBOP
C     !ROUTINE: EXCH_UV_DGRID_3D_RL

C     !INTERFACE:
      SUBROUTINE EXCH_UV_DGRID_3D_RL(
     U                                 uPhi, vPhi,
     I                                 withSigns, myNz, myThid )

C     !DESCRIPTION:
C*=====================================================================*
C  Purpose: SUBROUTINE EXCH_UV_DGRID_3D_RL
C      handle exchanges for a 3D vector field on an D-grid.
C
C  Input:
C    uPhi(lon,lat,levs,bi,bj) :: first component of vector
C    vPhi(lon,lat,levs,bi,bj) :: second component of vector
C    withSigns (logical)      :: true to use sign of components
C    myNz                     :: 3rd dimension of input arrays uPhi,vPhi
C    myThid                   :: my Thread Id number
C
C  Output: uPhi and vPhi are updated (halo regions filled)
C
C  Calls: EXCH_RL (EXCH_UV_RL_cube) ignoring sign
C         then put back the right signs
C
C  NOTES: 1) If using CubedSphereExchange, only works on ONE PROCESSOR!
C*=====================================================================*

C     !USES:
      IMPLICIT NONE

#include "SIZE.h"
#include "EEPARAMS.h"

C     !INPUT/OUTPUT PARAMETERS:
C     == Argument list variables ==
      INTEGER myNz
      _RL uPhi(1-OLx:sNx+OLx,1-OLy:sNy+OLy,myNz,nSx,nSy)
      _RL vPhi(1-OLx:sNx+OLx,1-OLy:sNy+OLy,myNz,nSx,nSy)
      LOGICAL withSigns
      INTEGER myThid

C     !LOCAL VARIABLES:
#ifndef ALLOW_EXCH2
C     == Local variables ==
C     i,j,k,bi,bj   :: loop indices.
C     OL[wens]      :: Overlap extents in west, east, north, south.
C     exchWidth[XY] :: Extent of regions that will be exchanged.

      INTEGER i,j,k,bi,bj
      INTEGER OLw, OLe, OLn, OLs, exchWidthX, exchWidthY
      _RL negOne
      INTEGER  myFace
#endif
CEOP

#ifdef ALLOW_EXCH2
      CALL EXCH2_UV_DGRID_3D_RL(
     U                     Uphi, Vphi,
     I                     withSigns, myNz, myThid )
      RETURN
#else /* ALLOW_EXCH2 */
      OLw        = OLx
      OLe        = OLx
      OLn        = OLy
      OLs        = OLy
      exchWidthX = OLx
      exchWidthY = OLy
      negOne = 1.
      IF (withSigns) negOne = -1.

      IF ( useCubedSphereExchange ) THEN
C---  using CubedSphereExchange:

C--   First call the exchanges for the two components, ignoring the Sign
C     note the order: vPhi,uPhi on D-grid are co-located with (u,v)_Cgrid

c      CALL EXCH1_UV_RL_CUBE( vPhi, uPhi, .FALSE.,
c    I            OLw, OLe, OLs, OLn, myNz,
c    I            exchWidthX, exchWidthY,
c    I            EXCH_UPDATE_CORNERS, myThid )

C- note: can substitute the low-level S/R calls above with:
      CALL EXCH_UV_3D_RL(
     U                     vPhi, uPhi,
     I                     .FALSE., myNz, myThid )

C--   Then we may need to switch the signs depending on which cube face
C     we are located.

C--   Loops on tile indices:
       DO bj = myByLo(myThid), myByHi(myThid)
        DO bi = myBxLo(myThid), myBxHi(myThid)

C-    Now choose what to do at each edge of the halo based on which face
C     (we assume that bj is always=1)
         myFace = bi

C--   Loops on level index:
         DO k = 1,myNz

C-    odd faces share disposition of all sections of the halo
          IF ( MOD(myFace,2).EQ.1 ) THEN
C-    North:
c          IF (exch2_isNedge(myTile).EQ.1) THEN
             DO j = 1,exchWidthY
              DO i = 1-OLx,sNx+OLx
               uPhi(i,sNy+j,k,bi,bj) = uPhi(i,sNy+j,k,bi,bj)*negOne
c              vPhi(i,sNy+j,k,bi,bj) = vPhi(i,sNy+j,k,bi,bj)
              ENDDO
             ENDDO
c          ENDIF
C-    South: (nothing to change)
c          IF (exch2_isSedge(myTile).EQ.1) THEN
c            DO j = 1,exchWidthY
c             DO i = 1-OLx,sNx+OLx
c              uPhi(i,1-j,k,bi,bj) = uPhi(i,1-j,k,bi,bj)
c              vPhi(i,1-j,k,bi,bj) = vPhi(i,1-j,k,bi,bj)
c             ENDDO
c            ENDDO
c          ENDIF
C-    East: (nothing to change)
c          IF (exch2_isEedge(myTile).EQ.1) THEN
c            DO j = 1-OLy,sNy+OLy
c             DO i = 1,exchWidthX
c              uPhi(sNx+i,j,k,bi,bj) = uPhi(sNx+i,j,k,bi,bj)
c              vPhi(sNx+i,j,k,bi,bj) = vPhi(sNx+i,j,k,bi,bj)
c             ENDDO
c            ENDDO
c          ENDIF
C-    West:
c          IF (exch2_isWedge(myTile).EQ.1) THEN
             DO j = 1-OLy,sNy+OLy
              DO i = 1,exchWidthX
c              uPhi(1-i,j,k,bi,bj) = uPhi(1-i,j,k,bi,bj)
               vPhi(1-i,j,k,bi,bj) = vPhi(1-i,j,k,bi,bj)*negOne
              ENDDO
             ENDDO
c          ENDIF

          ELSE
C-    Now the even faces (share disposition of all sections of the halo)

C-    East:
c          IF (exch2_isEedge(myTile).EQ.1) THEN
             DO j = 1-OLy,sNy+OLy
              DO i = 1,exchWidthX
c              uPhi(sNx+i,j,k,bi,bj) = uPhi(sNx+i,j,k,bi,bj)
               vPhi(sNx+i,j,k,bi,bj) = vPhi(sNx+i,j,k,bi,bj)*negOne
              ENDDO
             ENDDO
c          ENDIF
C-    West: (nothing to change)
c          IF (exch2_isWedge(myTile).EQ.1) THEN
c            DO j = 1-OLy,sNy+OLy
c             DO i = 1,exchWidthX
c              uPhi(1-i,j,k,bi,bj) = uPhi(1-i,j,k,bi,bj)
c              vPhi(1-i,j,k,bi,bj) = vPhi(1-i,j,k,bi,bj)
c             ENDDO
c            ENDDO
c          ENDIF
C-    North: (nothing to change)
c          IF (exch2_isNedge(myTile).EQ.1) THEN
c            DO j = 1,exchWidthY
c             DO i = 1-OLx,sNx+OLx
c              uPhi(i,sNy+j,k,bi,bj) = uPhi(i,sNy+j,k,bi,bj)
c              vPhi(i,sNy+j,k,bi,bj) = vPhi(i,sNy+j,k,bi,bj)
c             ENDDO
c            ENDDO
c          ENDIF
C-    South:
c          IF (exch2_isSedge(myTile).EQ.1) THEN
             DO j = 1,exchWidthY
              DO i = 1-OLx,sNx+OLx
               uPhi(i,1-j,k,bi,bj) = uPhi(i,1-j,k,bi,bj)*negOne
c              vPhi(i,1-j,k,bi,bj) = vPhi(i,1-j,k,bi,bj)
              ENDDO
             ENDDO
c          ENDIF

C end odd / even faces
          ENDIF

C--    end of Loops on tile and level indices (k,bi,bj).
         ENDDO
        ENDDO
       ENDDO

      ELSE
C---  not using CubedSphereExchange:

       CALL EXCH1_RL( uPhi,
     I            OLw, OLe, OLs, OLn, myNz,
     I            exchWidthX, exchWidthY,
     I            EXCH_UPDATE_CORNERS, myThid )
       CALL EXCH1_RL( vPhi,
     I            OLw, OLe, OLs, OLn, myNz,
     I            exchWidthX, exchWidthY,
     I            EXCH_UPDATE_CORNERS, myThid )

C---  using or not using CubedSphereExchange: end
      ENDIF

      RETURN
#endif /* ALLOW_EXCH2 */
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|

CEH3 ;;; Local Variables: ***
CEH3 ;;; mode:fortran ***
CEH3 ;;; End: ***