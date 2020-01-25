C $Header: /u/gcmpack/MITgcm/pkg/shelfice/shelfice_thermodynamics.F,v 1.28 2012/03/12 16:48:29 mlosch Exp $
C $Name: checkpoint63k $

#include "SHELFICE_OPTIONS.h"

CBOP
C     !ROUTINE: SHELFICE_THERMODYNAMICS
C     !INTERFACE:
      SUBROUTINE SHELFICE_THERMODYNAMICS(
     I                        myTime, myIter, myThid )
C     !DESCRIPTION: \bv
C     *=============================================================*
C     | S/R  SHELFICE_THERMODYNAMICS
C     | o shelf-ice main routine.
C     |   compute temperature and (virtual) salt flux at the
C     |   shelf-ice ocean interface
C     |
C     | stresses at the ice/water interface are computed in separate
C     | routines that are called from mom_fluxform/mom_vecinv
C     *=============================================================*

C     !USES:
      IMPLICIT NONE

C     === Global variables ===
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "GRID.h"
#include "DYNVARS.h"
#include "FFIELDS.h"
#include "SHELFICE.h"
#ifdef ALLOW_AUTODIFF
# include "ctrl.h"
# include "ctrl_dummy.h"
#endif /* ALLOW_AUTODIFF */
#ifdef ALLOW_AUTODIFF_TAMC
# ifdef SHI_ALLOW_GAMMAFRICT
#  include "tamc.h"
#  include "tamc_keys.h"
# endif /* SHI_ALLOW_GAMMAFRICT */
#endif /* ALLOW_AUTODIFF_TAMC */

C     !INPUT/OUTPUT PARAMETERS:
C     === Routine arguments ===
C     myIter :: iteration counter for this thread
C     myTime :: time counter for this thread
C     myThid :: thread number for this instance of the routine.
      _RL  myTime
      INTEGER myIter
      INTEGER myThid
CEOP

#ifdef ALLOW_SHELFICE
C     !LOCAL VARIABLES :
C     === Local variables ===
C     I,J,K,Kp1,bi,bj  :: loop counters
C     tLoc, sLoc, pLoc :: local in-situ temperature, salinity, pressure
C     theta/saltFreeze :: temperature and salinity of water at the
C                         ice-ocean interface (at the freezing point)
C     freshWaterFlux   :: local variable for fresh water melt flux due
C                         to melting in kg/m^2/s 
C                         (negative density x melt rate)
C     convertFW2SaltLoc:: local copy of convertFW2Salt
C     cFac             :: 1 for conservative form, 0, otherwise
C     auxiliary variables and abbreviations:
C     a0, a1, a2, b, c0
C     eps1, eps2, eps3, eps3a, eps4, eps5, eps6, eps7, eps8
C     aqe, bqe, cqe, discrim, recip_aqe
C     drKp1, recip_drLoc
      INTEGER I,J,K,Kp1
      INTEGER bi,bj
      _RL tLoc(1:sNx,1:sNy)
      _RL sLoc(1:sNx,1:sNy)
      _RL pLoc(1:sNx,1:sNy)
      _RL uLoc(1:sNx,1:sNy)
      _RS TminTb(1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RS ustarA(1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RL vLoc(1:sNx,1:sNy)
      _RL thetaFreeze, saltFreeze
      _RL freshWaterFlux, convertFW2SaltLoc
      _RL a0, a1, a2, b, c0
      _RL eps1, eps2, eps3, eps3a, eps4, eps5, eps6, eps7
      _RL cFac, rFac
      _RL aqe, bqe, cqe, discrim, recip_aqe
      _RL drKp1, recip_drLoc
      _RL tmpFac

#ifdef SHI_ALLOW_GAMMAFRICT
      _RL shiPr, shiSc, shiLo, recip_shiKarman, shiTwoThirds
      _RL gammaTmoleT, gammaTmoleS, gammaTurb, gammaTurbConst
      _RL ustar, ustarSq, etastar
      PARAMETER ( shiTwoThirds = 0.66666666666666666666666666667D0 )
#endif

      _RL SW_TEMP
      EXTERNAL SW_TEMP

#ifdef ALLOW_SHIFWFLX_CONTROL
      _RL xx_shifwflx_loc(1-olx:snx+olx,1-oly:sny+oly,nsx,nsy)
#endif
C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|

#ifdef SHI_ALLOW_GAMMAFRICT
#ifdef ALLOW_AUTODIFF_TAMC
C     re-initialize here again, curtesy to TAF
      DO bj = myByLo(myThid), myByHi(myThid)
       DO bi = myBxLo(myThid), myBxHi(myThid)
        DO J = 1-Oly,sNy+Oly
         DO I = 1-Olx,sNx+Olx
          shiTransCoeffT(i,j,bi,bj) = SHELFICEheatTransCoeff
          shiTransCoeffS(i,j,bi,bj) = SHELFICEsaltTransCoeff
         ENDDO
        ENDDO
        ENDDO
       ENDDO
#endif /* ALLOW_AUTODIFF_TAMC */
      IF ( SHELFICEuseGammaFrict ) THEN
C     Implement friction velocity-dependent transfer coefficient
C     of Holland and Jenkins, JPO, 1999
       recip_shiKarman= 1. _d 0 / 0.4 _d 0
       shiLo = 0. _d 0
       shiPr = shiPrandtl**shiTwoThirds
       shiSc = shiSchmidt**shiTwoThirds
cph      shiPr = (viscArNr(1)/diffKrNrT(1))**shiTwoThirds
cph      shiSc = (viscArNr(1)/diffKrNrS(1))**shiTwoThirds
       gammaTmoleT = 12.5 _d 0 * shiPr - 6. _d 0
       gammaTmoleS = 12.5 _d 0 * shiSc - 6. _d 0
C     instead of etastar = sqrt(1+zetaN*ustar./(f*Lo*Rc))
       etastar = 1. _d 0
       gammaTurbConst  = 1. _d 0 / (2. _d 0 * shiZetaN*etastar) 
     &      - recip_shiKarman
#ifdef ALLOW_AUTODIFF_TAMC
       DO bj = myByLo(myThid), myByHi(myThid)
        DO bi = myBxLo(myThid), myBxHi(myThid)
         DO J = 1-Oly,sNy+Oly
          DO I = 1-Olx,sNx+Olx
           shiTransCoeffT(i,j,bi,bj) = 0. _d 0
           shiTransCoeffS(i,j,bi,bj) = 0. _d 0
          ENDDO
         ENDDO
        ENDDO
       ENDDO
#endif /* ALLOW_AUTODIFF_TAMC */
      ENDIF
#endif /* SHI_ALLOW_GAMMAFRICT */

C     are we doing the conservative form of Jenkins et al. (2001)?
      cFac = 0. _d 0
      IF ( SHELFICEconserve ) cFac = 1. _d 0
C     with "real fresh water flux" (affecting ETAN), 
C     there is more to modify
      rFac = 1. _d 0
      IF ( SHELFICEconserve .AND. useRealFreshWaterFlux ) rFac = 0. _d 0
C     linear dependence of freezing point on salinity
      a0 = -0.0575   _d  0
      a1 =  0.0      _d -0
      a2 =  0.0      _d -0
      c0 =  0.0901   _d  0
      b  =  -7.61    _d -4
#ifdef ALLOW_ISOMIP_TD
      IF ( useISOMIPTD ) THEN
C     non-linear dependence of freezing point on salinity
       a0 = -0.0575   _d  0
       a1 = 1.710523  _d -3
       a2 = -2.154996 _d -4
       b  = -7.53     _d -4
       c0 = 0. _d 0
      ENDIF
      convertFW2SaltLoc = convertFW2Salt
C     hardcoding this value here is OK because it only applies to ISOMIP
C     where this value is part of the protocol
      IF ( convertFW2SaltLoc .EQ. -1. ) convertFW2SaltLoc = 33.4 _d 0
#endif /* ALLOW_ISOMIP_TD */

      DO bj = myByLo(myThid), myByHi(myThid)
       DO bi = myBxLo(myThid), myBxHi(myThid)
        DO J = 1-Oly,sNy+Oly
         DO I = 1-Olx,sNx+Olx
          shelfIceHeatFlux      (I,J,bi,bj) = 0. _d 0
          shelfIceFreshWaterFlux(I,J,bi,bj) = 0. _d 0
          shelficeForcingT      (I,J,bi,bj) = 0. _d 0
          shelficeForcingS      (I,J,bi,bj) = 0. _d 0
          ustarA                (I,J,bi,bj) = 0. _d 0
          TminTb                (I,J,bi,bj) = 0. _d 0
         ENDDO
        ENDDO
       ENDDO
      ENDDO
#ifdef ALLOW_SHIFWFLX_CONTROL
      DO bj = myByLo(myThid), myByHi(myThid)
       DO bi = myBxLo(myThid), myBxHi(myThid)
        DO J = 1-Oly,sNy+Oly
         DO I = 1-Olx,sNx+Olx
          xx_shifwflx_loc(I,J,bi,bj) = 0. _d 0
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      CALL CTRL_GET_GEN (
     &     xx_shifwflx_file, xx_shifwflxstartdate, xx_shifwflxperiod,
     &     maskSHI, xx_shifwflx_loc, xx_shifwflx0, xx_shifwflx1,
     &     xx_shifwflx_dummy,
     &     xx_shifwflx_remo_intercept, xx_shifwflx_remo_slope,
     &     mytime, myiter, mythid )
#endif /* ALLOW_SHIFWFLX_CONTROL */
      DO bj = myByLo(myThid), myByHi(myThid)
       DO bi = myBxLo(myThid), myBxHi(myThid)
#ifdef ALLOW_AUTODIFF_TAMC
# ifdef SHI_ALLOW_GAMMAFRICT
        act1 = bi - myBxLo(myThid)
        max1 = myBxHi(myThid) - myBxLo(myThid) + 1
        act2 = bj - myByLo(myThid)
        max2 = myByHi(myThid) - myByLo(myThid) + 1
        act3 = myThid - 1
        max3 = nTx*nTy
        act4 = ikey_dynamics - 1
        ikey = (act1 + 1) + act2*max1
     &                    + act3*max1*max2
     &                    + act4*max1*max2*max3
# endif /* SHI_ALLOW_GAMMAFRICT */
#endif /* ALLOW_AUTODIFF_TAMC */
        DO J = 1, sNy
         DO I = 1, sNx
C--   make local copies of temperature, salinity and depth (pressure)
C--   underneath the ice
          K         = MAX(1,kTopC(I,J,bi,bj))
          pLoc(I,J) = ABS(R_shelfIce(I,J,bi,bj))
          tLoc(I,J) = theta(I,J,K,bi,bj)
          sLoc(I,J) = MAX(salt(I,J,K,bi,bj), 0. _d 0)
          uLoc(I,J) = recip_hFacC(I,J,K,bi,bj) *
     &         ( uVel(I,  J,K,bi,bj) * _hFacW(I,  J,K,bi,bj)
     &         + uVel(I+1,J,K,bi,bj) * _hFacW(I+1,J,K,bi,bj) )
          vLoc(I,J) = recip_hFacC(I,J,K,bi,bj) *
     &         ( vVel(I,J,  K,bi,bj) * _hFacS(I,J,  K,bi,bj)
     &         + vVel(I,J+1,K,bi,bj) * _hFacS(I,J+1,K,bi,bj) )
         ENDDO
        ENDDO
        IF ( SHELFICEBoundaryLayer ) THEN
C--   average over boundary layer width
         DO J = 1, sNy
          DO I = 1, sNx
           K   = kTopC(I,J,bi,bj)
           IF ( K .NE. 0 .AND. K .LT. Nr ) THEN
            Kp1 = MIN(Nr,K+1)
C--   overlap into lower cell
            drKp1 = drF(K)*( 1. _d 0 - _hFacC(I,J,K,bi,bj) )
C--   lower cell may not be as thick as required
            drKp1 = MIN( drKp1, drF(Kp1) * _hFacC(I,J,Kp1,bi,bj) )
            recip_drLoc = 1. _d 0 /
     &           ( drF(K)*_hFacC(I,J,K,bi,bj) + drKp1 )
            tLoc(I,J) = ( tLoc(I,J) * drF(K)*_hFacC(I,J,K,bi,bj)
     &           + theta(I,J,Kp1,bi,bj) *drKp1 )
     &           * recip_drLoc
            sLoc(I,J) = ( sLoc(I,J) * drF(K)*_hFacC(I,J,K,bi,bj)
     &           + MAX(salt(I,J,Kp1,bi,bj), 0. _d 0) * drKp1 )
     &           * recip_drLoc
            uLoc(I,J) = ( uLoc(I,J) * drF(K)*_hFacC(I,J,K,bi,bj)
     &           + drKp1 * recip_hFacC(I,J,Kp1,bi,bj) *
     &           ( uVel(I,  J,Kp1,bi,bj) * _hFacW(I,  J,Kp1,bi,bj)
     &           + uVel(I+1,J,Kp1,bi,bj) * _hFacW(I+1,J,Kp1,bi,bj) )
     &           ) * recip_drLoc
            vLoc(I,J) = ( vLoc(I,J) * drF(K)*_hFacC(I,J,K,bi,bj)
     &           + drKp1 * recip_hFacC(I,J,Kp1,bi,bj) *
     &           ( vVel(I,J,  Kp1,bi,bj) * _hFacS(I,J,  Kp1,bi,bj)
     &           + vVel(I,J+1,Kp1,bi,bj) * _hFacS(I,J+1,Kp1,bi,bj) )
     &           ) * recip_drLoc
           ENDIF
          ENDDO
         ENDDO
        ENDIF

C--   turn potential temperature into in-situ temperature relative
C--   to the surface
        DO J = 1, sNy
         DO I = 1, sNx
          tLoc(I,J) = SW_TEMP(sLoc(I,J),tLoc(I,J),pLoc(I,J),0.D0)
         ENDDO
        ENDDO

#ifdef SHI_ALLOW_GAMMAFRICT
        IF ( SHELFICEuseGammaFrict ) THEN
         DO J = 1, sNy
          DO I = 1, sNx
           K = kTopC(I,J,bi,bj)
           IF ( K .NE. 0 .AND. pLoc(I,J) .GT. 0. _d 0 ) THEN
            ustarSq = shiCdrag * MAX( 1.D-06,
     &           0.25 _d 0 *(uLoc(I,J)*uLoc(I,J)+vLoc(I,J)*vLoc(I,J)) )
            ustar   = SQRT(ustarSq)
            ustarA(I,J,bi,bj) = ustar
C     instead of etastar = sqrt(1+zetaN*ustar./(f*Lo*Rc))
C           etastar = 1. _d 0
C           gammaTurbConst  = 1. _d 0 / (2. _d 0 * shiZetaN*etastar) 
C    &           - recip_shiKarman
            IF ( fCori(I,J,bi,bj) .NE. 0. _d 0 ) THEN
             gammaTurb = LOG( ustarSq * shiZetaN * etastar**2
     &            / ABS(fCori(I,J,bi,bj) * 5.0 _d 0 * shiKinVisc))
     &            * recip_shiKarman 
     &            + gammaTurbConst
C     Do we need to catch the unlikely case of very small ustar 
C     that can lead to negative gammaTurb?
C            gammaTurb = MAX(0.D0, gammaTurb)
            ELSE
             gammaTurb = gammaTurbConst
            ENDIF
            shiTransCoeffT(i,j,bi,bj) = MAX( 0.D-10, 
     &           ustar/(gammaTurb + gammaTmoleT) )
            shiTransCoeffS(i,j,bi,bj) = MAX( 0.D-10, 
     &           ustar/(gammaTurb + gammaTmoleS) )
           ENDIF
          ENDDO
         ENDDO
        ENDIF
#endif /* SHI_ALLOW_GAMMAFRICT */

#ifdef ALLOW_AUTODIFF_TAMC
# ifdef SHI_ALLOW_GAMMAFRICT
CADJ STORE shiTransCoeffS(:,:,bi,bj) = comlev1_bibj,
CADJ &     key=ikey, byte=isbyte
CADJ STORE shiTransCoeffT(:,:,bi,bj) = comlev1_bibj,
CADJ &     key=ikey, byte=isbyte
# endif /* SHI_ALLOW_GAMMAFRICT */
#endif /* ALLOW_AUTODIFF_TAMC */
#ifdef ALLOW_ISOMIP_TD
        IF ( useISOMIPTD ) THEN
         DO J = 1, sNy
          DO I = 1, sNx
           K = kTopC(I,J,bi,bj)
           IF ( K .NE. 0 .AND. pLoc(I,J) .GT. 0. _d 0 ) THEN
C--   Calculate freezing temperature as a function of salinity and pressure
            thetaFreeze =
     &           sLoc(I,J) * ( a0 + a1*sqrt(sLoc(I,J)) + a2*sLoc(I,J) )
     &           + b*pLoc(I,J) + c0
C--   Calculate the upward heat and  fresh water fluxes
            shelfIceHeatFlux(I,J,bi,bj) = maskC(I,J,K,bi,bj)
     &           * shiTransCoeffT(i,j,bi,bj)
     &           * ( tLoc(I,J) - thetaFreeze )
     &           * HeatCapacity_Cp*rUnit2mass
#ifdef ALLOW_SHIFWFLX_CONTROL
     &           - xx_shifwflx_loc(I,J,bi,bj)*SHELFICElatentHeat
#endif /*  ALLOW_SHIFWFLX_CONTROL */
C     upward heat flux into the shelf-ice implies basal melting,
C     thus a downward (negative upward) fresh water flux (as a mass flux),
C     and vice versa
            shelfIceFreshWaterFlux(I,J,bi,bj) =
     &           - shelfIceHeatFlux(I,J,bi,bj)
     &           *recip_SHELFICElatentHeat
C--   compute surface tendencies
            shelficeForcingT(i,j,bi,bj) =
     &           - shelfIceHeatFlux(I,J,bi,bj)
     &           *recip_Cp*mass2rUnit
     &           - cFac * shelfIceFreshWaterFlux(I,J,bi,bj)*mass2rUnit
     &           * ( thetaFreeze - tLoc(I,J) )
            shelficeForcingS(i,j,bi,bj) =
     &           shelfIceFreshWaterFlux(I,J,bi,bj) * mass2rUnit
     &           * ( cFac*sLoc(I,J) + (1. _d 0-cFac)*convertFW2SaltLoc )
C--   stress at the ice/water interface is computed in separate
C     routines that are called from mom_fluxform/mom_vecinv
           ELSE
            shelfIceHeatFlux      (I,J,bi,bj) = 0. _d 0
            shelfIceFreshWaterFlux(I,J,bi,bj) = 0. _d 0
            shelficeForcingT      (I,J,bi,bj) = 0. _d 0
            shelficeForcingS      (I,J,bi,bj) = 0. _d 0
           ENDIF
          ENDDO
         ENDDO
        ELSE
#else
        IF ( .TRUE. ) THEN
#endif /* ALLOW_ISOMIP_TD */
C     use BRIOS thermodynamics, following Hellmers PhD thesis:
C     Hellmer, H., 1989, A two-dimensional model for the thermohaline
C     circulation under an ice shelf, Reports on Polar Research, No. 60
C     (in German).

         DO J = 1, sNy
          DO I = 1, sNx
           K    = kTopC(I,J,bi,bj)
           IF ( K .NE. 0 .AND. pLoc(I,J) .GT. 0. _d 0 ) THEN
C     a few abbreviations
            eps1 = rUnit2mass*HeatCapacity_Cp
     &           *shiTransCoeffT(i,j,bi,bj)
            eps2 = rUnit2mass*SHELFICElatentHeat
     &           *shiTransCoeffS(i,j,bi,bj)
            eps5 = rUnit2mass*HeatCapacity_Cp
     &           *shiTransCoeffS(i,j,bi,bj)

C     solve quadratic equation for salinity at shelfice-ocean interface
C     note: this part of the code is not very intuitive as it involves
C     many arbitrary abbreviations that were introduced to derive the
C     correct form of the quadratic equation for salinity. The abbreviations
C     only make sense in connection with my notes on this (M.Losch)
            eps3 = rhoShelfIce*SHELFICEheatCapacity_Cp
     &           * SHELFICEkappa/pLoc(I,J)
cph introduce a constant variant of eps3 to avoid AD of
cph code of typ (pLoc-const)/pLoc
            eps3a = rhoShelfIce*SHELFICEheatCapacity_Cp
     &           * SHELFICEkappa
            eps4 = b*pLoc(I,J) + c0
            eps6 = eps4 - tLoc(I,J)
            eps7 = eps4 - SHELFICEthetaSurface
            aqe = a0  *(eps1+eps3)
            recip_aqe = 0. _d 0
            IF ( aqe .NE. 0. _d 0 ) recip_aqe = 0.5 _d 0/aqe
c           bqe = eps1*eps6 + eps3*eps7 - eps2
            bqe = eps1*eps6
     &           + eps3a*( b
     &                   + ( c0 - SHELFICEthetaSurface )/pLoc(I,J) )
     &           - eps2
            cqe = eps2*sLoc(I,J)
            discrim = bqe*bqe - 4. _d 0*aqe*cqe
#undef ALLOW_SHELFICE_DEBUG
#ifdef ALLOW_SHELFICE_DEBUG
            IF ( discrim .LT. 0. _d 0 ) THEN
             print *, 'ml-shelfice: discrim = ', discrim,aqe,bqe,cqe
             print *, 'ml-shelfice: pLoc    = ', pLoc(I,J)
             print *, 'ml-shelfice: tLoc    = ', tLoc(I,J)
             print *, 'ml-shelfice: sLoc    = ', sLoc(I,J)
             print *, 'ml-shelfice: tsurface= ',
     &            SHELFICEthetaSurface
             print *, 'ml-shelfice: eps1    = ', eps1
             print *, 'ml-shelfice: eps2    = ', eps2
             print *, 'ml-shelfice: eps3    = ', eps3
             print *, 'ml-shelfice: eps4    = ', eps4
             print *, 'ml-shelfice: eps5    = ', eps5
             print *, 'ml-shelfice: eps6    = ', eps6
             print *, 'ml-shelfice: eps7    = ', eps7
             print *, 'ml-shelfice: rU2mass = ', rUnit2mass
             print *, 'ml-shelfice: rhoIce  = ', rhoShelfIce
             print *, 'ml-shelfice: cFac    = ', cFac
             print *, 'ml-shelfice: Cp_W    = ', HeatCapacity_Cp
             print *, 'ml-shelfice: Cp_I    = ',
     &            SHELFICEHeatCapacity_Cp
             print *, 'ml-shelfice: gammaT  = ',
     &            SHELFICEheatTransCoeff
             print *, 'ml-shelfice: gammaS  = ',
     &            SHELFICEsaltTransCoeff
             print *, 'ml-shelfice: lat.heat= ',
     &            SHELFICElatentHeat
             STOP 'ABNORMAL END in S/R SHELFICE_THERMODYNAMICS'
            ENDIF
#endif /* ALLOW_SHELFICE_DEBUG */
            saltFreeze = (- bqe - SQRT(discrim))*recip_aqe
            IF ( saltFreeze .LT. 0. _d 0 )
     &           saltFreeze = (- bqe + SQRT(discrim))*recip_aqe
            thetaFreeze = a0*saltFreeze + eps4
            TminTb(I,J,bi,bj) = tLoc(I,J) - thetaFreeze
C--   upward fresh water flux due to melting (in kg/m^2/s)
cph change to identical form
cph            freshWaterFlux = rUnit2mass
cph     &           * shiTransCoeffS(i,j,bi,bj)
cph     &           * ( saltFreeze - sLoc(I,J) ) / saltFreeze
            freshWaterFlux = rUnit2mass
     &           * shiTransCoeffS(i,j,bi,bj)
     &           * ( 1. _d 0 - sLoc(I,J) / saltFreeze )
#ifdef ALLOW_SHIFWFLX_CONTROL
     &           + xx_shifwflx_loc(I,J,bi,bj)
#endif /*  ALLOW_SHIFWFLX_CONTROL */
C--   Calculate the upward heat and fresh water fluxes;
C--   MITgcm sign conventions: downward (negative) fresh water flux
C--   implies melting and due to upward (positive) heat flux
            shelfIceHeatFlux(I,J,bi,bj) =
     &           ( eps3*( thetaFreeze - SHELFICEthetaSurface )
     &           -  cFac*freshWaterFlux*( SHELFICElatentHeat
     &             - HeatCapacity_Cp*( thetaFreeze - rFac*tLoc(I,J) ) )
     &           )
            shelfIceFreshWaterFlux(I,J,bi,bj) = freshWaterFlux
C--   compute surface tendencies
            shelficeForcingT(i,j,bi,bj) =
     &           ( shiTransCoeffT(i,j,bi,bj)
     &           - cFac*shelfIceFreshWaterFlux(I,J,bi,bj)*mass2rUnit )
     &           * ( thetaFreeze - tLoc(I,J) )
            shelficeForcingS(i,j,bi,bj) =
     &           ( shiTransCoeffS(i,j,bi,bj)
     &           - cFac*shelfIceFreshWaterFlux(I,J,bi,bj)*mass2rUnit )
     &           * ( saltFreeze - sLoc(I,J) )
           ELSE
            shelfIceHeatFlux      (I,J,bi,bj) = 0. _d 0
            shelfIceFreshWaterFlux(I,J,bi,bj) = 0. _d 0
            shelficeForcingT      (I,J,bi,bj) = 0. _d 0
            shelficeForcingS      (I,J,bi,bj) = 0. _d 0
           ENDIF
          ENDDO
         ENDDO
        ENDIF
C     endif (not) useISOMIPTD
       ENDDO
      ENDDO

#ifdef ALLOW_DIAGNOSTICS
      IF ( useDiagnostics ) THEN
       CALL DIAGNOSTICS_FILL_RS(shelfIceFreshWaterFlux,'SHIfwFlx',
     &      0,1,0,1,1,myThid)
       CALL DIAGNOSTICS_FILL_RS(shelfIceHeatFlux,      'SHIhtFlx',
     &      0,1,0,1,1,myThid)
       CALL DIAGNOSTICS_FILL_RS(ustarA,                'SHIustar',
     &      0,1,0,1,1,myThid)
       CALL DIAGNOSTICS_FILL_RS(TminTb,                'SHIdelT ',
     &      0,1,0,1,1,myThid)
C     SHIForcT (Ice shelf forcing for theta [W/m2], >0 increases theta)
       tmpFac = HeatCapacity_Cp*rUnit2mass
       CALL DIAGNOSTICS_SCALE_FILL(shelficeForcingT,tmpFac,1,
     &      'SHIForcT',0,1,0,1,1,myThid)
C     SHIForcS (Ice shelf forcing for salt [g/m2/s], >0 increases salt)
       tmpFac = rUnit2mass
       CALL DIAGNOSTICS_SCALE_FILL(shelficeForcingS,tmpFac,1,
     &      'SHIForcS',0,1,0,1,1,myThid)
C     Transfer coefficients
       CALL DIAGNOSTICS_FILL(shiTransCoeffT,'SHIgammT',
     &      0,1,0,1,1,myThid)
       CALL DIAGNOSTICS_FILL(shiTransCoeffS,'SHIgammS',
     &      0,1,0,1,1,myThid)
      ENDIF
#endif /* ALLOW_DIAGNOSTICS */

#endif /* ALLOW_SHELFICE */
      RETURN
      END