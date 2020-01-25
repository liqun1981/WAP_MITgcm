C $Header: /u/gcmpack/MITgcm/model/src/integrate_for_w.F,v 1.15 2010/09/11 21:27:13 jmc Exp $
C $Name: checkpoint62r $

#include "CPP_OPTIONS.h"

CBOP
C     !ROUTINE: INTEGRATE_FOR_W
C     !INTERFACE:
      SUBROUTINE INTEGRATE_FOR_W(
     I                     bi, bj, k, uFld, vFld, mFld,
     O                     wFld,
     I                     myThid )

C     !DESCRIPTION: \bv
C     *==========================================================*
C     | SUBROUTINE INTEGRATE_FOR_W
C     | o Integrate for vertical velocity.
C     *==========================================================*
C     \ev

C     !USES:
      IMPLICIT NONE
C     == GLobal variables ==
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "GRID.h"
#include "SURFACE.h"

C     !INPUT/OUTPUT PARAMETERS:
C     == Routine arguments ==
C     uFld, vFld :: Zonal and meridional flow
C     mFld       :: added mass
C     wFld       :: Vertical flow
      INTEGER bi,bj,k
      _RL  uFld (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL  vFld (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
#ifdef ALLOW_ADDFLUID
      _RL  mFld (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
#else
      _RL  mFld (1)
#endif
      _RL  wFld (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      INTEGER myThid

C     !LOCAL VARIABLES:
C     == Local variables ==
C     uTrans, vTrans :: Temps. for volume transports
C     conv2d         :: horizontal transport convergence [m^3/s]
      INTEGER i,j
      _RL uTrans(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL vTrans(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL conv2d(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
CEOP

C--   Calculate velocity field "volume transports" through
C     tracer cell faces (anelastic: scaled as a mass transport).
      DO j=1,sNy+1
        DO i=1,sNx+1
          uTrans(i,j) = uFld(i,j,k,bi,bj)
     &                *_dyG(i,j,bi,bj)*deepFacC(k)*rhoFacC(k)
     &                *drF(k)*_hFacW(i,j,k,bi,bj)
          vTrans(i,j) = vFld(i,j,k,bi,bj)
     &                *_dxG(i,j,bi,bj)*deepFacC(k)*rhoFacC(k)
     &                *drF(k)*_hFacS(i,j,k,bi,bj)
        ENDDO
      ENDDO
      DO j=1,sNy
        DO i=1,sNx
          conv2d(i,j) = -( uTrans(i+1,j)-uTrans(i,j)
     &                    +vTrans(i,j+1)-vTrans(i,j) )
        ENDDO
      ENDDO
#ifdef ALLOW_ADDFLUID
      IF ( selectAddFluid.GE.1 ) THEN
       DO j=1,sNy
        DO i=1,sNx
          conv2d(i,j) = conv2d(i,j)
     &                + mFld(i,j,k,bi,bj)*mass2rUnit
        ENDDO
       ENDDO
      ENDIF
#endif /* ALLOW_ADDFLUID */

C--   Calculate vertical "volume transport" through face k
C     between tracer cell k-1 & k
      IF (rigidLid) THEN
C-  o Rigid-Lid case: zero at lower and upper boundaries
        IF (k.EQ.1) THEN
          DO j=1,sNy
           DO i=1,sNx
             wFld(i,j,k,bi,bj) = 0.
           ENDDO
          ENDDO
        ELSEIF (k.EQ.Nr) THEN
          DO j=1,sNy
           DO i=1,sNx
             wFld(i,j,k,bi,bj) =
     &          conv2d(i,j)*recip_rA(i,j,bi,bj)
     &         *maskC(i,j,k,bi,bj)*maskC(i,j,k-1,bi,bj)
     &         *recip_deepFac2F(k)*recip_rhoFacF(k)
           ENDDO
          ENDDO
        ELSE
          DO j=1,sNy
           DO i=1,sNx
             wFld(i,j,k,bi,bj) =
     &        ( wFld(i,j,k+1,bi,bj)*deepFac2F(k+1)*rhoFacF(k+1)
     &         +conv2d(i,j)*recip_rA(i,j,bi,bj)
     &        )*maskC(i,j,k,bi,bj)*maskC(i,j,k-1,bi,bj)
     &         *recip_deepFac2F(k)*recip_rhoFacF(k)
           ENDDO
          ENDDO
        ENDIF
#ifdef NONLIN_FRSURF
# ifndef DISABLE_RSTAR_CODE
      ELSEIF ( select_rStar.NE.0 ) THEN
C-  o rStar case: zero under-ground and at r_lower boundary
C     can be non-zero at surface (useRealFreshWaterFlux).
        IF (k.EQ.Nr) THEN
          DO j=1,sNy
           DO i=1,sNx
             wFld(i,j,k,bi,bj) =
     &        ( conv2d(i,j)*recip_rA(i,j,bi,bj)
     &         -rStarDhCDt(i,j,bi,bj)*drF(k)*h0FacC(i,j,k,bi,bj)
     &        )*maskC(i,j,k,bi,bj)
     &         *recip_deepFac2F(k)*recip_rhoFacF(k)
           ENDDO
          ENDDO
        ELSE
          DO j=1,sNy
           DO i=1,sNx
             wFld(i,j,k,bi,bj) =
     &        ( wFld(i,j,k+1,bi,bj)*deepFac2F(k+1)*rhoFacF(k+1)
     &         +conv2d(i,j)*recip_rA(i,j,bi,bj)
     &         -rStarDhCDt(i,j,bi,bj)*drF(k)*h0FacC(i,j,k,bi,bj)
     &        )*maskC(i,j,k,bi,bj)
     &         *recip_deepFac2F(k)*recip_rhoFacF(k)
           ENDDO
          ENDDO
        ENDIF
# endif /* DISABLE_RSTAR_CODE */
# ifndef DISABLE_SIGMA_CODE
      ELSEIF ( selectSigmaCoord.NE.0 ) THEN
C-  o Hybrid Sigma coordinate:
        IF (k.EQ.Nr) THEN
          DO j=1,sNy
           DO i=1,sNx
             wFld(i,j,k,bi,bj) =
     &        ( conv2d(i,j)*recip_rA(i,j,bi,bj)
     &         -dEtaHdt(i,j,bi,bj)*dBHybSigF(k)
     &        )*maskC(i,j,k,bi,bj)
           ENDDO
          ENDDO
        ELSE
          DO j=1,sNy
           DO i=1,sNx
             wFld(i,j,k,bi,bj) =
     &        ( wFld(i,j,k+1,bi,bj)
     &         +conv2d(i,j)*recip_rA(i,j,bi,bj)
     &         -dEtaHdt(i,j,bi,bj)*dBHybSigF(k)
     &        )*maskC(i,j,k,bi,bj)
           ENDDO
          ENDDO
        ENDIF
# endif /* DISABLE_SIGMA_CODE */
#endif /* NONLIN_FRSURF */
      ELSE
C-  o Free Surface case (r-Coordinate):
C      non zero at surface ; zero under-ground and at r_lower boundary
        IF (k.EQ.Nr) THEN
          DO j=1,sNy
           DO i=1,sNx
             wFld(i,j,k,bi,bj) =
     &          conv2d(i,j)*recip_rA(i,j,bi,bj)
     &         *maskC(i,j,k,bi,bj)
     &         *recip_deepFac2F(k)*recip_rhoFacF(k)
           ENDDO
          ENDDO
        ELSE
          DO j=1,sNy
           DO i=1,sNx
             wFld(i,j,k,bi,bj) =
     &        ( wFld(i,j,k+1,bi,bj)*deepFac2F(k+1)*rhoFacF(k+1)
     &         +conv2d(i,j)*recip_rA(i,j,bi,bj)
     &        )*maskC(i,j,k,bi,bj)
     &         *recip_deepFac2F(k)*recip_rhoFacF(k)
           ENDDO
          ENDDO
        ENDIF
C-  endif - rigid-lid / Free-Surf.
      ENDIF

      RETURN
      END
