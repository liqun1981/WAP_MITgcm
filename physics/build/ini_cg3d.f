C $Header: /u/gcmpack/MITgcm/model/src/ini_cg3d.F,v 1.26 2010/01/23 00:04:03 jmc Exp $
C $Name: checkpoint62r $

#include "PACKAGES_CONFIG.h"
#include "CPP_OPTIONS.h"

CBOP
C     !ROUTINE: INI_CG3D
C     !INTERFACE:
      SUBROUTINE INI_CG3D( myThid )
C     !DESCRIPTION: \bv
C     *==========================================================*
C     | SUBROUTINE INI_CG3D
C     | o Initialise 3d conjugate gradient solver operators.
C     *==========================================================*
C     | These arrays are purely a function of the basin geom.
C     | We set then here once and them use then repeatedly.
C     *==========================================================*
C     \ev

C     !USES:
      IMPLICIT NONE
C     === Global variables ===
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "GRID.h"
#include "SURFACE.h"
#include "CG3D.h"
#include "SOLVE_FOR_PRESSURE3D.h"
#ifdef ALLOW_OBCS
#include "OBCS.h"
#endif

C     !INPUT/OUTPUT PARAMETERS:
C     === Routine arguments ===
C     myThid   :: My Thread Id number
      INTEGER myThid

#ifdef ALLOW_NONHYDROSTATIC

C     !LOCAL VARIABLES:
C     === Local variables ===
C     bi,bj    :: tile indices
C     i,j,k    :: Loop counters
C     faceArea :: Temporary used to hold cell face areas.
C     myNorm   :: Work variable used in clculating normalisation factor
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      INTEGER bi, bj
      INTEGER i, j, k, ks
      _RL     faceArea
      _RS     myNorm
      _RL     theRecip_Dr
      _RL     aU, aL, aW, aE, aN, aS
      _RL     tmpFac, nh_Fac, igwFac
      _RL     tmpSurf
CEOP

CcnhDebugStarts
c     _RL    phi(1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
CcnhDebugEnds

C--   Initialise to zero over the full range of indices
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO k=1,Nr
C-       From common bloc CG3D_R:
         DO j=1-OLy,sNy+OLy
          DO i=1-OLx,sNx+OLx
           aW3d(i,j,k,bi,bj) = 0.
           aS3d(i,j,k,bi,bj) = 0.
           aV3d(i,j,k,bi,bj) = 0.
           aC3d(i,j,k,bi,bj) = 0.
           zMC (i,j,k,bi,bj) = 0.
           zML (i,j,k,bi,bj) = 0.
           zMU (i,j,k,bi,bj) = 0.
          ENDDO
         ENDDO
C-       From common bloc CG3D_WK_R:
         DO j=0,sNy+1
          DO i=0,sNx+1
           cg3d_q(i,j,k,bi,bj) = 0.
           cg3d_r(i,j,k,bi,bj) = 0.
           cg3d_s(i,j,k,bi,bj) = 0.
          ENDDO
         ENDDO
C-       From common bloc SFP3D_COMMON_R:
         DO j=1-OLy,sNy+OLy
          DO i=1-OLx,sNx+OLx
           cg3d_b(i,j,k,bi,bj) = 0.
          ENDDO
         ENDDO
        ENDDO
       ENDDO
      ENDDO

      nh_Fac = 0.
      igwFac = 0.
      IF ( nonHydrostatic
     &      .AND. nh_Am2.NE.0. ) nh_Fac = 1. _d 0 / nh_Am2
      IF ( implicitIntGravWave ) igwFac = 1. _d 0

      IF ( use3Dsolver ) THEN
C--   Initialise laplace operator
C     aW3d: Ax/dX
C     aS3d: Ay/dY
C     aV3d: Ar/dR
      myNorm = 0. _d 0
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO k=1,Nr
         DO j=1,sNy
          DO i=1,sNx+1
           faceArea = _dyG(i,j,bi,bj)*drF(k)
     &                *_hFacW(i,j,k,bi,bj)
           aW3d(i,j,k,bi,bj) = faceArea*recip_dxC(i,j,bi,bj)
     &                        *implicitNHPress*implicDiv2DFlow
           myNorm = MAX(ABS(aW3d(i,j,k,bi,bj)),myNorm)
          ENDDO
         ENDDO
C  deep-model: *deepFacC (faceArea), /deepFacC (recip_dx,y): => no net effect
         DO j=1,sNy+1
          DO i=1,sNx
           faceArea = _dxG(i,j,bi,bj)*drF(K)
     &                *_hFacS(i,j,k,bi,bj)
           aS3d(i,j,k,bi,bj) = faceArea*recip_dyC(i,j,bi,bj)
     &                        *implicitNHPress*implicDiv2DFlow
           myNorm = MAX(ABS(aS3d(i,j,k,bi,bj)),myNorm)
          ENDDO
         ENDDO
        ENDDO
        DO k=1,1
         DO j=1,sNy
          DO i=1,sNx
           aV3d(i,j,k,bi,bj) =  0.
          ENDDO
         ENDDO
        ENDDO
        DO k=2,Nr
         tmpFac = nh_Fac*rVel2wUnit(k)*rVel2wUnit(k)
     &          + igwFac*dBdrRef(k)*deltaTMom*dTtracerLev(k)
         IF (tmpFac.GT.0. ) tmpFac = 1. _d 0 / tmpFac
         DO j=1,sNy
          DO i=1,sNx
           faceArea = _rA(i,j,bi,bj)*maskC(i,j, k ,bi,bj)
     &                              *maskC(i,j,k-1,bi,bj)
     &                              *deepFac2F(k)
           theRecip_Dr = recip_drC(k)
c          theRecip_Dr =
caja &      drF(k  )*_hFacC(i,j,k  ,bi,bj)*0.5
caja &     +drF(k-1)*_hFacC(i,j,k-1,bi,bj)*0.5
c          IF ( theRecip_Dr .NE. 0. )
c    &      theRecip_Dr = 1. _d 0/theRecip_Dr
           aV3d(i,j,k,bi,bj) = faceArea*theRecip_Dr*tmpFac
     &                        *implicitNHPress*implicDiv2DFlow
           myNorm = MAX(ABS(aV3d(i,j,k,bi,bj)),myNorm)
          ENDDO
         ENDDO
        ENDDO
#ifdef ALLOW_OBCS
        IF ( useOBCS ) THEN
         DO k=1,Nr
          DO i=1,sNx
           IF (OB_Jn(i,bi,bj).NE.0) THEN
            aS3d( i, OB_Jn(i,bi,bj), k,bi,bj) = 0.
            aS3d( i,OB_Jn(i,bi,bj)+1,k,bi,bj) = 0.
            aW3d( i, OB_Jn(i,bi,bj), k,bi,bj) = 0.
            aW3d(i+1,OB_Jn(i,bi,bj), k,bi,bj) = 0.
            aV3d( i, OB_Jn(i,bi,bj), k,bi,bj) = 0.
           ENDIF
           IF (OB_Js(i,bi,bj).NE.0) THEN
            aS3d( i,OB_Js(i,bi,bj)+1,k,bi,bj) = 0.
            aS3d( i, OB_Js(i,bi,bj), k,bi,bj) = 0.
            aW3d( i, OB_Js(i,bi,bj), k,bi,bj) = 0.
            aW3d(i+1,OB_Js(i,bi,bj), k,bi,bj) = 0.
            aV3d( i, OB_Js(i,bi,bj), k,bi,bj) = 0.
           ENDIF
          ENDDO
          DO j=1,sNy
           IF (OB_Ie(j,bi,bj).NE.0) THEN
            aW3d( OB_Ie(j,bi,bj), j, k,bi,bj) = 0.
            aW3d(OB_Ie(j,bi,bj)+1,j, k,bi,bj) = 0.
            aS3d( OB_Ie(j,bi,bj), j, k,bi,bj) = 0.
            aS3d( OB_Ie(j,bi,bj),j+1,k,bi,bj) = 0.
            aV3d( OB_Ie(j,bi,bj), j, k,bi,bj) = 0.
           ENDIF
           IF (OB_Iw(j,bi,bj).NE.0) THEN
            aW3d(OB_Iw(j,bi,bj)+1,j, k,bi,bj) = 0.
            aW3d( OB_Iw(j,bi,bj), j, k,bi,bj) = 0.
            aS3d( OB_Iw(j,bi,bj), j, k,bi,bj) = 0.
            aS3d( OB_Iw(j,bi,bj),j+1,k,bi,bj) = 0.
            aV3d( OB_Iw(j,bi,bj), j, k,bi,bj) = 0.
           ENDIF
          ENDDO
         ENDDO
        ENDIF
#endif
       ENDDO
      ENDDO
      _GLOBAL_MAX_RS( myNorm, myThid )
      IF ( myNorm .NE. 0. _d 0 ) THEN
       myNorm = 1. _d 0/myNorm
      ELSE
       myNorm = 1. _d 0
      ENDIF

      _BEGIN_MASTER( myThid )
C-- set global parameter in common block:
       cg3dNorm = myNorm
       WRITE(msgBuf,'(2A,1PE23.16)') 'INI_CG3D: ',
     &      'CG3D normalisation factor = ', cg3dNorm
       CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                     SQUEEZE_RIGHT, myThid )
       WRITE(msgBuf,*) '                               '
       CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                     SQUEEZE_RIGHT, myThid )
      _END_MASTER( myThid )

      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
C-    Set solver main diagonal term
        DO k=1,Nr
         DO j=1,sNy
          DO i=1,sNx
           aW = aW3d( i, j, k, bi,bj)
           aE = aW3d(i+1,j, k, bi,bj)
           aN = aS3d( i,j+1,k, bi,bj)
           aS = aS3d( i, j, k, bi,bj)
           aU = aV3d( i, j, k, bi,bj)
           IF ( k .NE. Nr  ) THEN
            aL = aV3d(i, j,k+1,bi,bj)
           ELSE
            aL = 0.
           ENDIF
           aC3d(i,j,k,bi,bj) = -aW-aE-aN-aS-aU-aL
          ENDDO
         ENDDO
        ENDDO
C-    Add free-surface source term
        IF ( select_rStar .EQ. 0 ) THEN
         DO j=1,sNy
          DO i=1,sNx
           tmpSurf = 1.
           IF ( selectNHfreeSurf.GE.1 ) THEN
             tmpSurf = deltaTMom*deltaTfreesurf
     &                *Bo_surf(i,j,bi,bj)*recip_drC(1)
     &                *implicitNHPress*implicDiv2DFlow
             tmpSurf = tmpSurf / (1. _d 0 + tmpSurf )
           ENDIF
           ks = ksurfC(i,j,bi,bj)
           IF ( ks.LE.Nr ) THEN
             aC3d(i,j,ks,bi,bj) = aC3d(i,j,ks,bi,bj)
     &         - freeSurfFac*recip_Bo(i,j,bi,bj)
     &          *rA(i,j,bi,bj)*deepFac2F(ks)/deltaTMom/deltaTfreesurf
     &          *tmpSurf
           ENDIF
          ENDDO
         ENDDO
        ENDIF
C-    Matrix solver normalisation
        DO k=1,Nr
         DO j=1,sNy
          DO i=1,sNx
           aW3d(i,j,k,bi,bj) = aW3d(i,j,k,bi,bj)*myNorm
           aS3d(i,j,k,bi,bj) = aS3d(i,j,k,bi,bj)*myNorm
           aV3d(i,j,k,bi,bj) = aV3d(i,j,k,bi,bj)*myNorm
           aC3d(i,j,k,bi,bj) = aC3d(i,j,k,bi,bj)*myNorm
          ENDDO
         ENDDO
        ENDDO
       ENDDO
      ENDDO

C--   Update overlap regions
      CALL EXCH_UV_XYZ_RS(aW3d,aS3d,.FALSE.,myThid)
      _EXCH_XYZ_RS(aV3d, myThid)
      _EXCH_XYZ_RS(aC3d, myThid)
CcnhDebugStarts
C     CALL PLOT_FIELD_XYZRS( aW3d, 'AW3D INI_CG3D.1' , Nr, 1, myThid )
C     CALL PLOT_FIELD_XYZRS( aS3d, 'AS3D INI_CG3D.1' , Nr, 1, myThid )
CcnhDebugEnds

C--   Initialise preconditioner
C     For now PC is just the identity. Change to
C     be LU factorization of d2/dz2 later. Note
C     check for consistency with S/R CG3D before
C     assuming zML is lower and zMU is upper!
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO k=1,Nr
         DO j=1,sNy
          DO i=1,sNx
           IF ( aC3d(i,j,k,bi,bj) .NE. 0. ) THEN
            zMC(i,j,k,bi,bj) = aC3d(i,j,k,bi,bj)
            zML(i,j,k,bi,bj) = aV3d(i,j,k,bi,bj)
            IF ( k.NE.Nr ) THEN
             zMU(i,j,k,bi,bj)= aV3d(i,j,k+1,bi,bj)
            ELSE
             zMU(i,j,k,bi,bj)= 0.
            ENDIF
CcnhDebugStarts
C           zMC(i,j,k,bi,bj) = 1.
C           zMU(i,j,k,bi,bj) = 0.
C           zML(i,j,k,bi,bj) = 0.
CcnhDebugEnds
           ELSE
            zMC(i,j,k,bi,bj) = 1. _d 0
            zMU(i,j,k,bi,bj) = 0.
            zML(i,j,k,bi,bj) = 0.
           ENDIF
          ENDDO
         ENDDO
        ENDDO
        k = 1
         DO j=1,sNy
          DO i=1,sNx
           zMC(i,j,k,bi,bj) = 1. _d 0 / zMC(i,j,k,bi,bj)
           zMU(i,j,k,bi,bj) = zMU(i,j,k,bi,bj)*zMC(i,j,k,bi,bj)
          ENDDO
         ENDDO
        DO k=2,Nr
         DO j=1,sNy
          DO i=1,sNx
           zMC(i,j,k,bi,bj) = 1. _d 0 /
     &     (zMC(i,j,k,bi,bj)-zML(i,j,k,bi,bj)*zMU(i,j,k-1,bi,bj))
           zMU(i,j,k,bi,bj) = zMU(i,j,k,bi,bj)*zMC(i,j,k,bi,bj)
          ENDDO
         ENDDO
        ENDDO
        DO k=1,Nr
         DO j=1,sNy
          DO i=1,sNx
           IF ( aC3d(i,j,k,bi,bj) .EQ. 0. ) THEN
            zMC(i,j,k,bi,bj) = 1.
            zML(i,j,k,bi,bj) = 0.
            zMU(i,j,k,bi,bj) = 0.
CcnhDebugStarts
C          ELSE
C           zMC(i,j,k,bi,bj) = 1.
C           zML(i,j,k,bi,bj) = 0.
C           zMU(i,j,k,bi,bj) = 0.
CcnhDEbugEnds
           ENDIF
          ENDDO
         ENDDO
        ENDDO
       ENDDO
      ENDDO
C--   Update overlap regions
      _EXCH_XYZ_RS(zMC, myThid)
      _EXCH_XYZ_RS(zML, myThid)
      _EXCH_XYZ_RS(zMU, myThid)

      IF ( debugLevel .GE. debLevB ) THEN
        CALL WRITE_FLD_XYZ_RS( 'zMC',' ',zMC, 0, myThid )
        CALL WRITE_FLD_XYZ_RS( 'zML',' ',zML, 0, myThid )
        CALL WRITE_FLD_XYZ_RS( 'zMU',' ',zMU, 0, myThid )
      ENDIF
CcnhDebugStarts
c     DO k=1,Nr
c     DO j=1-OLy,sNy+OLy
c     DO i=1-OLx,sNx+OLx
c      phi(i,j,1,1) = zMc(i,j,k,1,1)
c     ENDDO
c     ENDDO
C     CALL PLOT_FIELD_XYRS( phi, 'zMC INI_CG3D.1' , 1, myThid )
c     ENDDO
C     CALL PLOT_FIELD_XYRS( zMU, 'zMU INI_CG3D.1' , Nr, 1, myThid )
C     CALL PLOT_FIELD_XYRS( zML, 'zML INI_CG3D.1' , Nr, 1, myThid )
CcnhDebugEnds

C--   end if (use3Dsolver)
      ENDIF

#endif /* ALLOW_NONHYDROSTATIC */

      RETURN
      END
