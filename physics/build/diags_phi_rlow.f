C $Header: /u/gcmpack/MITgcm/model/src/diags_phi_rlow.F,v 1.7 2010/03/16 00:08:27 jmc Exp $
C $Name: checkpoint62r $

#include "CPP_OPTIONS.h"

CBOP
C     !ROUTINE: DIAGS_PHI_RLOW
C     !INTERFACE:
      SUBROUTINE DIAGS_PHI_RLOW(
     I                       k, bi, bj, iMin,iMax, jMin,jMax,
     I                       phiHydF, phiHydC, alphRho, tFld, sFld,
     I                       myTime, myIter, myThid)
C     !DESCRIPTION: \bv
C     *==========================================================*
C     | S/R DIAGS_PHI_RLOW
C     | o Diagnose Phi-Hydrostatic at r-lower boundary
C     |   = bottom pressure (ocean in z-coord) ;
C     |   = sea surface elevation (ocean in p-coord) ;
C     |   = height at the top of atmosphere (in p-coord) ;
C     *==========================================================*
C     \ev

C     !USES:
      IMPLICIT NONE
C     == Global variables ==
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "GRID.h"
#include "SURFACE.h"
#include "DYNVARS.h"

C     !INPUT/OUTPUT PARAMETERS:
C     == Routine Arguments ==
C     bi,bj      :: tile index
C     iMin,iMax,jMin,jMax :: Loop counters
C     phiHydF    :: hydrostatic potential anomaly at middle between
C                   2 centers k & k+1 (interface k+1)
C     phiHydC    :: hydrostatic potential anomaly at cell center
C                  (atmos: =Geopotential ; ocean-z: =Pressure/rho)
C     alphRho    :: Density (z-coord) or specific volume (p-coord)
C     tFld       :: Potential temp.
C     sFld       :: Salinity
C     myTime     :: Current time
C     myIter     :: Current iteration number
C     myThid     :: my Thread Id number
      INTEGER k, bi,bj, iMin,iMax, jMin,jMax
      _RL phiHydF(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL phiHydC(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL alphRho(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL tFld(1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL sFld(1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL myTime
      INTEGER myIter, myThid

#ifdef INCLUDE_PHIHYD_CALCULATION_CODE

C     !LOCAL VARIABLES:
C     == Local variables ==
C     i,j :: Loop counters
      INTEGER i,j
      _RL zero, one, half
      _RL ddRloc, ratioRm, ratioRp
      PARAMETER ( zero= 0. _d 0 , one= 1. _d 0 , half= .5 _d 0 )
CEOP

      IF ( usingZCoords ) THEN

C----- Compute bottom pressure deviation from gravity*rho0*H
C      Start from phiHyd at the (bottom) tracer point and add Del_h*g*rho_prime
C      with Del_h = distance from the bottom up to tracer point

C--    Initialise to zero (otherwise phi0surf accumulate over land)
       IF ( k.EQ.1 ) THEN
         DO j=1-Oly,sNy+Oly
          DO i=1-Olx,sNx+Olx
            phiHydLow(i,j,bi,bj) = 0. _d 0
          ENDDO
         ENDDO
       ENDIF

       IF (integr_GeoPot.EQ.1) THEN
C  --  Finite Volume Form

         DO j=jMin,jMax
          DO i=iMin,iMax
           IF ( k .EQ. kLowC(i,j,bi,bj) ) THEN
             ddRloc = rC(k)-R_low(i,j,bi,bj)
             phiHydLow(i,j,bi,bj) = phiHydC(i,j)
     &            + ddRloc*gravity*alphRho(i,j)*recip_rhoConst
           ENDIF
          ENDDO
         ENDDO

       ELSE
C  --  Finite Difference Form

         ratioRm = one
         ratioRp = one
         IF (k.GT.1 ) ratioRm = half*drC(k)/(rF(k)-rC(k))
         IF (k.LT.Nr) ratioRp = half*drC(k+1)/(rC(k)-rF(k+1))

         DO j=jMin,jMax
          DO i=iMin,iMax
           IF ( k .EQ. kLowC(i,j,bi,bj) ) THEN
             ddRloc = rC(k)-R_low(i,j,bi,bj)
             phiHydLow(i,j,bi,bj) = phiHydC(i,j)
     &                  +( MIN(zero,ddRloc)*ratioRm
     &                    +MAX(zero,ddRloc)*ratioRp
     &                   )*gravity*alphRho(i,j)*recip_rhoConst
           ENDIF
          ENDDO
         ENDDO

C  --  end if integr_GeoPot = ...
       ENDIF

C  -- end usingZCoords
      ENDIF

      IF ( k.EQ.Nr ) THEN
C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
C  --  last level (bottom): rescale (r*) and add surface contribution

       IF ( usingPCoords ) THEN
C  -- P coordinate : Phi(R_low) is simply at the top :
        DO j=jMin,jMax
         DO i=iMin,iMax
           phiHydLow(i,j,bi,bj) = phiHydF(i,j)
         ENDDO
        ENDDO
       ENDIF

#ifdef NONLIN_FRSURF
c      IF ( select_rStar.GE.2 .AND. nonlinFreeSurf.GE.4 ) THEN
       IF ( select_rStar.GT.0 .AND. nonlinFreeSurf.GE.4 ) THEN
        DO j=jMin,jMax
         DO i=iMin,iMax
           phiHydLow(i,j,bi,bj) = phiHydLow(i,j,bi,bj)
     &                          *rStarFacC(i,j,bi,bj)
         ENDDO
        ENDDO
       ENDIF
#endif /* NONLIN_FRSURF */

        DO j=jMin,jMax
         DO i=iMin,iMax
           phiHydLow(i,j,bi,bj) = phiHydLow(i,j,bi,bj)
     &            + Bo_surf(i,j,bi,bj)*etaN(i,j,bi,bj)
     &            + phi0surf(i,j,bi,bj)
         ENDDO
        ENDDO

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
C  -- end if k=Nr.
      ENDIF

#endif /* INCLUDE_PHIHYD_CALCULATION_CODE */

      RETURN
      END
