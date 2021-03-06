C $Header: /u/gcmpack/MITgcm/verification/OpenAD/code_oad_all/ini_linear_phisurf.F,v 1.2 2009/04/28 18:06:14 jmc Exp $
C $Name: checkpoint62r $

#include "CPP_OPTIONS.h"

CBOP
C     !ROUTINE: INI_LINEAR_PHISURF
C     !INTERFACE:
      SUBROUTINE INI_LINEAR_PHISURF( myThid )

C     !DESCRIPTION: \bv
C     *==========================================================*
C     | SUBROUTINE INI_LINEAR_PHISURF
C     | o Initialise the Linear Relation Phi_surf(eta)
C     *==========================================================*
C     | Initialise -Boyancy at surface level (Bo_surf)
C     |  to setup the Linear relation: Phi_surf(eta)=Bo_surf*eta
C     | Initialise phi0surf = starting point for integrating
C     |                       phiHyd (= phiHyd at r=RoSurf)
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

C     !INPUT/OUTPUT PARAMETERS:
C     === Routine arguments ===
C     myThid - Thread no. that called this routine.
      INTEGER myThid

C     == Local variables in common ==
C     Hloc  - Temporary array used to write surface topography
C             has to be in common for multi threading
      COMMON / LOCAL_INI_PHISURF / topoHloc
      _RS topoHloc(1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)

C     !LOCAL VARIABLES:
C     === Local variables ===
C     bi,bj  - Loop counters
C     I,J,K
      INTEGER bi, bj
      INTEGER I, J, K
      _RL     pLoc, rhoLoc
      _RL     dPIdp
CEOP

#ifdef ALLOW_AUTODIFF_TAMC
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO J=1-Oly,sNy+Oly
         DO I=1-Olx,sNx+Olx
           Bo_surf(I,J,bi,bj)  = 0. _d 0
           recip_Bo(I,J,bi,bj) = 0. _d 0
         ENDDO
        ENDDO
       ENDDO
      ENDDO
#endif

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|

C-- Initialise -Boyancy at surface level : Bo_surf
C   Bo_surf is defined as d/dr(Phi_surf) and set to g/z2rUnit with
C     z2rUnit = conversion factor from z-unit to r-unit: [z] * z2rUnit = [r]
C   an accurate formulation includes P_surf and T,S_ref effects on rho_surf:
C    (setting uniformLin_PhiSurf=.FALSE.):
C    z-coord (z2rUnit=1): Bo_surf = - Boyancy
C                                 = g * rho_surf(Tref,Sref,pSurf_0)/rho_0
C    p-coord (z2rUnit=rho*g): Bo_surf = 1/rho(Tref(ksurf),pSurf_0)
C   Note: on Phi_surf splitting : Non-linear Time-dependent effects on B_surf
C   [through eta & (T-tRef)_surf] are included in PhiHyd rather than in Bo_surf
C--
      IF ( buoyancyRelation .EQ. 'OCEANIC' ) THEN
C-  gBaro = gravity (except for External mode test with reduced gravity)
        DO bj=myByLo(myThid),myByHi(myThid)
         DO bi=myBxLo(myThid),myBxHi(myThid)
          DO J=1-Oly,sNy+Oly
           DO I=1-Olx,sNx+Olx
             Bo_surf(I,J,bi,bj) = gBaro
             recip_Bo(I,J,bi,bj) = 1. _d 0 / gBaro
           ENDDO
          ENDDO
         ENDDO
        ENDDO
      ELSEIF ( uniformLin_PhiSurf ) THEN
C-  use a linear (in ps) uniform relation : Phi'_surf = 1/rhoConst * ps'_surf
        DO bj=myByLo(myThid),myByHi(myThid)
         DO bi=myBxLo(myThid),myBxHi(myThid)
          DO J=1-Oly,sNy+Oly
           DO I=1-Olx,sNx+Olx
c            Bo_surf(I,J,bi,bj)  = rVel2wUnit(1)*gravity
c            recip_Bo(I,J,bi,bj) = wUnit2rVel(1)*recip_gravity
             Bo_surf(I,J,bi,bj)  = recip_rhoConst
             recip_Bo(I,J,bi,bj) = rhoConst
           ENDDO
          ENDDO
         ENDDO
        ENDDO
      ELSEIF ( buoyancyRelation .EQ. 'OCEANICP' ) THEN
        DO bj=myByLo(myThid),myByHi(myThid)
         DO bi=myBxLo(myThid),myBxHi(myThid)
          DO J=1-Oly,sNy+Oly
           DO I=1-Olx,sNx+Olx
            IF ( Ro_surf(I,J,bi,bj).GT.0. _d 0
     &          .AND. ksurfC(I,J,bi,bj).LE.Nr ) THEN
             pLoc = Ro_surf(I,J,bi,bj)
             CALL FIND_RHO_SCALAR(
     I            tRef(ksurfC(I,J,bi,bj)), 
     I            sRef(ksurfC(I,J,bi,bj)), 
     I            pLoc,
     O            rhoLoc, myThid )
             IF ( rhoLoc .EQ. 0. _d 0 ) THEN
              Bo_surf(I,J,bi,bj) = 0. _d 0
             ELSE
              Bo_surf(I,J,bi,bj) = 1. _d 0/rhoLoc
             ENDIF
             recip_Bo(I,J,bi,bj) =  rhoLoc
            ELSE
              Bo_surf(I,J,bi,bj)  = 0. _d 0
              recip_Bo(I,J,bi,bj) = 0. _d 0
            ENDIF
           ENDDO
          ENDDO
         ENDDO
        ENDDO
      ELSEIF ( buoyancyRelation .EQ. 'ATMOSPHERIC' ) THEN
C-  use a linearized (in ps) Non-uniform relation : Bo_surf(Po_surf,tRef_surf)
C--- Bo = d/d_p(Phi_surf) = tRef_surf*d/d_p(PI) ; PI = Cp*(p/Po)^kappa
        DO bj=myByLo(myThid),myByHi(myThid)
         DO bi=myBxLo(myThid),myBxHi(myThid)
          DO J=1-Oly,sNy+Oly
           DO I=1-Olx,sNx+Olx
            IF ( Ro_surf(I,J,bi,bj).GT.0. _d 0
     &          .AND. ksurfC(I,J,bi,bj).LE.Nr ) THEN
              dPIdp = (atm_Cp*atm_kappa/atm_Po)*
     &         (Ro_surf(I,J,bi,bj)/atm_Po)**(atm_kappa-1. _d 0)
              Bo_surf(I,J,bi,bj) = dPIdp*tRef(ksurfC(I,J,bi,bj))
              recip_Bo(I,J,bi,bj) = 1. _d 0 / Bo_surf(I,J,bi,bj)
            ELSE
              Bo_surf(I,J,bi,bj) = 0.
              recip_Bo(I,J,bi,bj) = 0.
            ENDIF
           ENDDO
          ENDDO
         ENDDO
        ENDDO
      ELSE
        STOP 'INI_LINEAR_PHISURF: We should never reach this point!'
      ENDIF

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|

C--   Update overlap regions (jmc: is it really needed ?)
      _EXCH_XY_RL(Bo_surf, myThid)
      _EXCH_XY_RL(recip_Bo, myThid)

      IF ( ( buoyancyRelation .EQ. 'ATMOSPHERIC' .OR.
     &       buoyancyRelation .EQ. 'OCEANICP'         )
     &       .AND. .NOT.uniformLin_PhiSurf              ) THEN

C--     EXCH (above) contains barrier calls
c       _BARRIER
        CALL WRITE_FLD_XY_RL( 'Bo_surf',' ',Bo_surf,0,myThid)

      ENDIF

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|

C--   Initialise phi0surf: used for atmos. surf. P-loading (ocean, z-coord)
C                               or topographic geopotential anom. (p-coord)

        DO bj=myByLo(myThid),myByHi(myThid)
         DO bi=myBxLo(myThid),myBxHi(myThid)
          DO J=1-Oly,sNy+Oly
           DO I=1-Olx,sNx+Olx
             phi0surf(I,J,bi,bj) = 0.
           ENDDO
          ENDDO
         ENDDO
        ENDDO

      IF ( buoyancyRelation .EQ. 'ATMOSPHERIC'
     &                   .AND. topoFile.NE.' ' ) THEN

#ifdef ALLOW_AUTODIFF_TAMC
         STOP 'CANNOT PRESENTLY USE THIS OPTION WITH ADJOINT'
#else

C--   Compute topoH = PhiRef(Po_surf)/g ; is different from original
C      topoZ(read from file) because of truncation of Po_surf.
C     NOTE: not clear for now which topoZ needs to be saved in common block
C--   AND set phi0surf = starting point for integrating Geopotential;

        CALL INI_P_GROUND( -2,
     O                     topoHloc,
     I                     Ro_surf, myThid )


       IF (selectFindRoSurf.NE.0) THEN
        _EXCH_XY_RS(phi0surf, myThid)

        CALL WRITE_FLD_XY_RS( 'phi0surf',' ',phi0surf,0,myThid)
       ELSE
        _BARRIER
       ENDIF

        CALL WRITE_FLD_XY_RS( 'topo_H',' ',topoHloc,0,myThid)

#endif /* ALLOW_AUTODIFF_TAMC */

      ENDIF

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      RETURN
      END
