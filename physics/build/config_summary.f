C $Header: /u/gcmpack/MITgcm/model/src/config_summary.F,v 1.126 2010/11/30 20:52:07 jmc Exp $
C $Name: checkpoint62r $

#include "PACKAGES_CONFIG.h"
#include "CPP_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C     !ROUTINE: CONFIG_SUMMARY

C     !INTERFACE:
      SUBROUTINE CONFIG_SUMMARY( myThid )

C     !DESCRIPTION:
C     This routine summarizes the model parameter settings by writing a
C     tabulated list of the kernel model configuration variables.  It
C     describes all the parameter settings in force and the meaning and
C     units of those parameters. Individal packages report a similar
C     table for each package using the same format as employed here. If
C     parameters are missing or incorrectly described or dimensioned
C     please contact <MITgcm-support@mitgcm.org>

C     !USES:
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "EOS.h"
#include "GRID.h"
#ifdef ALLOW_MNC
#include "MNC_PARAMS.h"
#endif

C     !INPUT/OUTPUT PARAMETERS:
C     myThid ::  Number of this instance of CONFIG_SUMMARY
      INTEGER myThid
CEOP

C     !FUNCTIONS:
      INTEGER  ILNBLNK
      EXTERNAL ILNBLNK

C     !LOCAL VARIABLES:
C     msgBuf :: Temp. for building output string.
C     rUnits :: vertical coordinate units
C     ioUnit :: Temp. for fortran I/O unit
C     i, k   :: Loop counters.
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      CHARACTER*2 rUnits
      CHARACTER*10 endList
      INTEGER ioUnit
      INTEGER i, k
      _RL     bufRL(Nr+1)
      INTEGER buffI(1)
      INTEGER coordLine
      INTEGER tileLine


      _BARRIER
      _BEGIN_MASTER(myThid)

      ioUnit = standardMessageUnit
      rUnits = ' m'
      endList = '    ;     '
      IF ( usingPCoords ) rUnits = 'Pa'

      WRITE(msgBuf,'(A)')
     &'// ======================================================='
      CALL PRINT_MESSAGE( msgBuf, ioUnit, SQUEEZE_RIGHT, myThid )
      WRITE(msgBuf,'(A)') '// Model configuration'
      CALL PRINT_MESSAGE( msgBuf, ioUnit, SQUEEZE_RIGHT, myThid )
      WRITE(msgBuf,'(A)')
     &'// ======================================================='
      CALL PRINT_MESSAGE( msgBuf, ioUnit, SQUEEZE_RIGHT, myThid )

      WRITE(msgBuf,'(A)') '//  '
      CALL PRINT_MESSAGE( msgBuf, ioUnit, SQUEEZE_RIGHT, myThid )
      WRITE(msgBuf,'(A)')
     & '// "Physical" paramters ( PARM01 in namelist ) '
      CALL PRINT_MESSAGE( msgBuf, ioUnit, SQUEEZE_RIGHT, myThid )
      WRITE(msgBuf,'(A)') '//  '
      CALL PRINT_MESSAGE( msgBuf, ioUnit, SQUEEZE_RIGHT, myThid )
      CALL WRITE_0D_C( buoyancyRelation, -1, INDEX_NONE,
     & 'buoyancyRelation =', ' /* Type of relation to get Buoyancy */')
      CALL WRITE_0D_L( fluidIsAir,   INDEX_NONE,
     & 'fluidIsAir   =', '  /* fluid major constituent is Air */')
      CALL WRITE_0D_L( fluidIsWater, INDEX_NONE,
     & 'fluidIsWater =', '  /* fluid major constituent is Water */')
      CALL WRITE_0D_L( usingPCoords, INDEX_NONE,
     & 'usingPCoords =', '  /* use p (or p*) vertical coordinate */')
      CALL WRITE_0D_L( usingZCoords, INDEX_NONE,
     & 'usingZCoords =', '  /* use z (or z*) vertical coordinate */')
      CALL WRITE_1D_RL( tRef, Nr, INDEX_K, 'tRef =',
     & '   /* Reference temperature profile ( oC or K ) */')
      CALL WRITE_1D_RL( sRef, Nr, INDEX_K, 'sRef =',
     & '   /* Reference salinity profile ( psu ) */')
      CALL WRITE_0D_RL( viscAh, INDEX_NONE, 'viscAh  =  ',
     & ' /* Lateral eddy viscosity ( m^2/s ) */')
      IF ( viscAhD.NE.viscAh )
     & CALL WRITE_0D_RL( viscAhD, INDEX_NONE, 'viscAhD =  ',
     & ' /* Lateral eddy viscosity (Divergence)( m^2/s ) */')
      IF ( viscAhZ.NE.viscAh )
     & CALL WRITE_0D_RL( viscAhZ, INDEX_NONE, 'viscAhZ =  ',
     & ' /* Lateral eddy viscosity (Vorticity) ( m^2/s ) */')
      CALL WRITE_0D_RL( viscAhMax, INDEX_NONE, 'viscAhMax =',
     & ' /* Maximum lateral eddy viscosity ( m^2/s ) */')
      CALL WRITE_0D_RL( viscAhGrid, INDEX_NONE, 'viscAhGrid =',
     & ' /* Grid dependent lateral eddy viscosity ( non-dim. ) */')
      CALL WRITE_0D_L( useFullLeith, INDEX_NONE, 'useFullLeith =',
     & ' /* Use Full Form of Leith Viscosity on/off flag*/')
      CALL WRITE_0D_L( useStrainTensionVisc, INDEX_NONE,
     & 'useStrainTensionVisc=',
     & ' /* Use StrainTension Form of Viscous Operator flag*/')
      CALL WRITE_0D_L( useAreaViscLength, INDEX_NONE,
     & 'useAreaViscLength =',
     & ' /* Use area for visc length instead of geom. mean*/')
      CALL WRITE_0D_RL( viscC2leith, INDEX_NONE, 'viscC2leith =',
     & ' /* Leith harmonic visc. factor (on grad(vort),non-dim.) */')
      CALL WRITE_0D_RL( viscC2leithD, INDEX_NONE, 'viscC2leithD =',
     & ' /* Leith harmonic viscosity factor (on grad(div),non-dim.)*/')
      CALL WRITE_0D_RL( viscC2smag, INDEX_NONE, 'viscC2smag =',
     & ' /* Smagorinsky harmonic viscosity factor (non-dim.) */')
      CALL WRITE_0D_RL( viscA4, INDEX_NONE, 'viscA4  =  ',
     & ' /* Lateral biharmonic viscosity ( m^4/s ) */')
      IF ( viscA4D.NE.viscA4 )
     & CALL WRITE_0D_RL( viscA4D, INDEX_NONE, 'viscA4D =  ',
     & ' /* Lateral biharmonic viscosity (Divergence)( m^4/s ) */')
      IF ( viscA4Z.NE.viscA4 )
     & CALL WRITE_0D_RL( viscA4Z, INDEX_NONE, 'viscA4Z =  ',
     & ' /* Lateral biharmonic viscosity (Vorticity) ( m^4/s ) */')
      CALL WRITE_0D_RL( viscA4Max, INDEX_NONE, 'viscA4Max =',
     & ' /* Maximum biharmonic viscosity ( m^2/s ) */')
      CALL WRITE_0D_RL( viscA4Grid, INDEX_NONE, 'viscA4Grid =',
     & ' /* Grid dependent biharmonic viscosity ( non-dim. ) */')
      CALL WRITE_0D_RL( viscC4leith, INDEX_NONE,'viscC4leith =',
     & ' /* Leith biharm viscosity factor (on grad(vort), non-dim.)*/')
      CALL WRITE_0D_RL( viscC4leithD, INDEX_NONE,'viscC4leithD =',
     & ' /* Leith biharm viscosity factor (on grad(div), non-dim.) */')
      CALL WRITE_0D_RL( viscC4Smag, INDEX_NONE,'viscC4Smag =',
     & ' /* Smagorinsky biharm viscosity factor (non-dim) */')
      CALL WRITE_0D_L( no_slip_sides, INDEX_NONE,
     & 'no_slip_sides =', '  /* Viscous BCs: No-slip sides */')
      CALL WRITE_0D_RL( sideDragFactor, INDEX_NONE, 'sideDragFactor =',
     & ' /* side-drag scaling factor (non-dim) */')
      CALL WRITE_1D_RL( viscArNr, Nr, INDEX_K, 'viscArNr =',
     &  ' /* vertical profile of vertical viscosity ('
     &  //rUnits//'^2/s )*/')
      CALL WRITE_0D_L( no_slip_bottom, INDEX_NONE,
     & 'no_slip_bottom =', '  /* Viscous BCs: No-slip bottom */')
      CALL WRITE_0D_RL( bottomDragLinear, INDEX_NONE,
     & 'bottomDragLinear =',
     & ' /* linear bottom-drag coefficient ( m/s ) */')
      CALL WRITE_0D_RL( bottomDragQuadratic, INDEX_NONE,
     & 'bottomDragQuadratic =',
     & ' /* quadratic bottom-drag coefficient (-) */')
      CALL WRITE_0D_RL( diffKhT, INDEX_NONE,'diffKhT =',
     &'   /* Laplacian diffusion of heat laterally ( m^2/s ) */')
      CALL WRITE_0D_RL( diffK4T, INDEX_NONE,'diffK4T =',
     &'   /* Biharmonic diffusion of heat laterally ( m^4/s ) */')
      CALL WRITE_0D_RL( diffKhS, INDEX_NONE,'diffKhS =',
     &'   /* Laplacian diffusion of salt laterally ( m^2/s ) */')
      CALL WRITE_0D_RL( diffK4S, INDEX_NONE,'diffK4S =',
     &'   /* Biharmonic diffusion of salt laterally ( m^4/s ) */')
      CALL WRITE_1D_RL( diffKrNrT, Nr, INDEX_K, 'diffKrNrT =',
     &  ' /* vertical profile of vertical diffusion of Temp ('
     &  //rUnits//'^2/s )*/')
      CALL WRITE_1D_RL( diffKrNrS, Nr, INDEX_K, 'diffKrNrS =',
     &  ' /* vertical profile of vertical diffusion of Salt ('
     &  //rUnits//'^2/s )*/')
      CALL WRITE_0D_RL( diffKrBL79surf, INDEX_NONE,'diffKrBL79surf =',
     &  ' /* Surface diffusion for Bryan and Lewis 79 ( m^2/s ) */')
      CALL WRITE_0D_RL( diffKrBL79deep, INDEX_NONE,'diffKrBL79deep =',
     &  ' /* Deep diffusion for Bryan and Lewis 1979 ( m^2/s ) */')
      CALL WRITE_0D_RL( diffKrBL79scl, INDEX_NONE,'diffKrBL79scl =',
     &  ' /* Depth scale for Bryan and Lewis 1979 ( m ) */')
      CALL WRITE_0D_RL( diffKrBL79Ho, INDEX_NONE,'diffKrBL79Ho =',
     &  ' /* Turning depth for Bryan and Lewis 1979 ( m ) */')
      CALL WRITE_0D_RL( ivdc_kappa, INDEX_NONE,'ivdc_kappa =',
     &  ' /* Implicit Vertical Diffusivity for Convection ('
     &  //rUnits//'^2/s) */')
      CALL WRITE_0D_RL( hMixCriteria, INDEX_NONE,'hMixCriteria=',
     & '  /* Criteria for mixed-layer diagnostic */')
      CALL WRITE_0D_RL( dRhoSmall, INDEX_NONE,'dRhoSmall =',
     & '  /* Parameter for mixed-layer diagnostic */')
      CALL WRITE_0D_RL( hMixSmooth, INDEX_NONE,'hMixSmooth=',
     & '  /* Smoothing parameter for mixed-layer diagnostic */')
      CALL WRITE_0D_C( eosType, 0, INDEX_NONE, 'eosType =',
     & '  /* Type of Equation of State */')
      CALL WRITE_0D_RL( tAlpha,  INDEX_NONE,'tAlpha =',
     &'   /* Linear EOS thermal expansion coefficient ( 1/oC ) */')
      CALL WRITE_0D_RL( sBeta,   INDEX_NONE,'sBeta =',
     &'   /* Linear EOS haline contraction coefficient ( 1/psu ) */')
      IF ( eosType .EQ. 'POLY3' ) THEN
        WRITE(msgBuf,'(A)')
     &   '// Polynomial EQS parameters ( from POLY3.COEFFS ) '
        DO k = 1, Nr
         WRITE(msgBuf,'(I3,13F8.3)')
     &   k,eosRefT(k),eosRefS(k),eosSig0(k), (eosC(i,k),i=1,9)
         CALL PRINT_MESSAGE( msgBuf, ioUnit, SQUEEZE_RIGHT, myThid )
        ENDDO
      ENDIF
      IF ( fluidIsAir ) THEN
       CALL WRITE_0D_RL( atm_Rd, INDEX_NONE, 'atm_Rd =',
     & '  /* gas constant for dry air ( J/kg/K ) */')
      CALL WRITE_0D_RL( atm_Cp, INDEX_NONE, 'atm_Cp =',
     & '  /* specific heat (Cp) of dry air ( J/kg/K ) */')
      CALL WRITE_0D_RL( atm_kappa, INDEX_NONE, 'atm_kappa =',
     & '  /* kappa (=Rd/Cp ) of dry air */')
       CALL WRITE_0D_RL( atm_Rq, INDEX_NONE, 'atm_Rq =',
     &  ' /* water vap. specific vol. anomaly relative to dry air */')
      CALL WRITE_0D_RL( atm_Po, INDEX_NONE, 'atm_Po =',
     & '  /* standard reference pressure ( Pa ) */')
      CALL WRITE_0D_I( integr_GeoPot, INDEX_NONE, 'integr_GeoPot =',
     & '  /* select how the geopotential is integrated */')
      CALL WRITE_0D_I( selectFindRoSurf, INDEX_NONE,
     & 'selectFindRoSurf=',
     & '  /* select how Surf.Ref. pressure is defined */')
      ENDIF
      CALL WRITE_0D_RL( rhonil,  INDEX_NONE,'rhonil =',
     &'   /* Reference density ( kg/m^3 ) */')
      CALL WRITE_0D_RL( rhoConst, INDEX_NONE,'rhoConst =',
     &'   /* Reference density ( kg/m^3 ) */')
      CALL WRITE_1D_RL( rhoFacC, Nr,   INDEX_K, 'rhoFacC = ',
     &  ' /* normalized Reference density @ cell-Center (-) */')
      CALL WRITE_1D_RL( rhoFacF, Nr+1, INDEX_K, 'rhoFacF = ',
     &  ' /* normalized Reference density @ W-Interface (-) */')
      CALL WRITE_0D_RL( rhoConstFresh, INDEX_NONE,'rhoConstFresh =',
     &'   /* Reference density ( kg/m^3 ) */')
      CALL WRITE_0D_RL( gravity, INDEX_NONE,'gravity =',
     &'   /* Gravitational acceleration ( m/s^2 ) */')
      CALL WRITE_0D_RL( gBaro,   INDEX_NONE,'gBaro =',
     &'   /* Barotropic gravity ( m/s^2 ) */')
      CALL WRITE_0D_RL(rotationPeriod,INDEX_NONE,'rotationPeriod =',
     &'   /* Rotation Period ( s ) */')
      CALL WRITE_0D_RL( omega,   INDEX_NONE,'omega =',
     &'   /* Angular velocity ( rad/s ) */')
      CALL WRITE_0D_RL( f0,      INDEX_NONE,'f0 =',
     &'   /* Reference coriolis parameter ( 1/s ) */')
      CALL WRITE_0D_RL( beta,    INDEX_NONE,'beta =',
     &'   /* Beta ( 1/(m.s) ) */')
      CALL WRITE_0D_RL( fPrime,  INDEX_NONE,'fPrime =',
     &'   /* Second coriolis parameter ( 1/s ) */')
      CALL WRITE_0D_L( rigidLid, INDEX_NONE, 'rigidLid =',
     &'   /* Rigid lid on/off flag */')
      CALL WRITE_0D_L( implicitFreeSurface, INDEX_NONE,
     &                 'implicitFreeSurface =',
     &'   /* Implicit free surface on/off flag */')
      CALL WRITE_0D_RL( freeSurfFac, INDEX_NONE,'freeSurfFac =',
     &'   /* Implicit free surface factor */')
      CALL WRITE_0D_RL( implicSurfPress, INDEX_NONE,
     & 'implicSurfPress =',
     & '  /* Surface Pressure implicit factor (0-1)*/')
      CALL WRITE_0D_RL( implicDiv2Dflow, INDEX_NONE,
     & 'implicDiv2Dflow =',
     & '  /* Barot. Flow Div. implicit factor (0-1)*/')
      CALL WRITE_0D_L( exactConserv, INDEX_NONE,
     & 'exactConserv =',
     & '  /* Exact Volume Conservation on/off flag*/')
      CALL WRITE_0D_L( linFSConserveTr, INDEX_NONE,
     & 'linFSConserveTr =',
     &  ' /* Tracer correction for Lin Free Surface on/off flag*/')
      CALL WRITE_0D_L( uniformLin_PhiSurf, INDEX_NONE,
     & 'uniformLin_PhiSurf =',
     &  ' /* use uniform Bo_surf on/off flag*/')
      CALL WRITE_0D_RL( hFacMin, INDEX_NONE, 'hFacMin = ',
     & '  /* minimum partial cell factor (hFac) */')
      CALL WRITE_0D_RL( hFacMin, INDEX_NONE, 'hFacMinDr =',
     &  ' /* minimum partial cell thickness ('//rUnits//') */')
      WRITE(msgBuf,'(2A)') 'nonlinFreeSurf =',
     &  ' /* Non-linear Free Surf. options (-1,0,1,2,3)*/'
      CALL PRINT_MESSAGE( msgBuf, ioUnit, SQUEEZE_RIGHT, myThid )
      buffI(1) = nonlinFreeSurf
      CALL PRINT_LIST_I( buffI, 1, 1, INDEX_NONE,
     &                   .FALSE., .TRUE., ioUnit )
      WRITE(msgBuf,'(2A)') '     -1,0= Off ; 1,2,3= On,',
     &  ' 2=+rescale gU,gV, 3=+update cg2d solv.'
      CALL PRINT_MESSAGE( msgBuf, ioUnit, SQUEEZE_RIGHT, myThid )
      CALL PRINT_MESSAGE(endList, ioUnit, SQUEEZE_RIGHT, myThid )
      CALL WRITE_0D_RL( hFacInf, INDEX_NONE, 'hFacInf = ',
     & '  /* lower threshold for hFac (nonlinFreeSurf only)*/')
      CALL WRITE_0D_RL( hFacSup, INDEX_NONE, 'hFacSup = ',
     & '  /* upper threshold for hFac (nonlinFreeSurf only)*/')
      CALL WRITE_0D_I( select_rStar, INDEX_NONE,
     & 'select_rStar =',
     &  ' /* r* Vertical coord. options (=0 r coord.; >0 uses r*)*/')
      CALL WRITE_0D_I( selectAddFluid, INDEX_NONE,
     & 'selectAddFluid =',
     &  ' /* option for mass source/sink of fluid (=0: off) */')
      CALL WRITE_0D_L( useRealFreshWaterFlux, INDEX_NONE,
     & 'useRealFreshWaterFlux =',
     &  ' /* Real Fresh Water Flux on/off flag*/')
      CALL WRITE_0D_RL( temp_EvPrRn, INDEX_NONE,
     & 'temp_EvPrRn =',
     &  ' /* Temp. of Evap/Prec/R (UNSET=use local T)(oC)*/')
      CALL WRITE_0D_RL( salt_EvPrRn, INDEX_NONE,
     &  'salt_EvPrRn =',
     &  ' /* Salin. of Evap/Prec/R (UNSET=use local S)(psu)*/')
      CALL WRITE_0D_RL( temp_addMass, INDEX_NONE,
     & 'temp_addMass =',
     &  ' /* Temp. of addMass array (UNSET=use local T)(oC)*/')
      CALL WRITE_0D_RL( salt_addMass, INDEX_NONE,
     & 'salt_addMass =',
     &  ' /* Salin. of addMass array (UNSET=use local S)(psu)*/')
      IF ( .NOT.useRealFreshWaterFlux .OR. selectAddFluid.EQ.-1
     &                                .OR. nonlinFreeSurf.LE.0 ) THEN
      CALL WRITE_0D_RL( convertFW2Salt, INDEX_NONE,
     & 'convertFW2Salt =',
     & ' /* convert F.W. Flux to Salt Flux (-1=use local S)(psu)*/')
      ENDIF

      CALL WRITE_0D_L( use3Dsolver, INDEX_NONE,
     & 'use3Dsolver =', ' /* use 3-D pressure solver on/off flag */')
      CALL WRITE_0D_L( nonHydrostatic, INDEX_NONE,
     & 'nonHydrostatic =', '  /* Non-Hydrostatic on/off flag */')
      CALL WRITE_0D_RL( nh_Am2, INDEX_NONE, 'nh_Am2 =',
     & ' /* Non-Hydrostatic terms scaling factor */')
      CALL WRITE_0D_RL( implicitNHPress, INDEX_NONE,
     & 'implicitNHPress =',
     & ' /* Non-Hyd Pressure implicit factor (0-1)*/')
      CALL WRITE_0D_I( selectNHfreeSurf, INDEX_NONE,
     & 'selectNHfreeSurf =',
     & ' /* Non-Hyd (free-)Surface option */')
      CALL WRITE_0D_L( quasiHydrostatic, INDEX_NONE,
     & 'quasiHydrostatic =', ' /* Quasi-Hydrostatic on/off flag */')
      CALL WRITE_0D_L( momStepping,  INDEX_NONE,
     & 'momStepping =', '  /* Momentum equation on/off flag */')
      CALL WRITE_0D_L( vectorInvariantMomentum,  INDEX_NONE,
     & 'vectorInvariantMomentum=',
     & ' /* Vector-Invariant Momentum on/off */')
      CALL WRITE_0D_L( momAdvection, INDEX_NONE,
     & 'momAdvection =', '  /* Momentum advection on/off flag */')
      CALL WRITE_0D_L( momViscosity, INDEX_NONE,
     & 'momViscosity =', '  /* Momentum viscosity on/off flag */')
      CALL WRITE_0D_L( momImplVertAdv, INDEX_NONE, 'momImplVertAdv=',
     &                ' /* Momentum implicit vert. advection on/off*/')
      CALL WRITE_0D_L( implicitViscosity, INDEX_NONE,
     & 'implicitViscosity =', ' /* Implicit viscosity on/off flag */')
      CALL WRITE_0D_L( metricTerms,  INDEX_NONE, 'metricTerms =',
     &                '  /* metric-Terms on/off flag */')
      CALL WRITE_0D_L( useNHMTerms,  INDEX_NONE, 'useNHMTerms =',
     &              ' /* Non-Hydrostatic Metric-Terms on/off */')
c------------
      WRITE(msgBuf,'(2A)')
     & 'selectCoriMap =', ' /* Coriolis Map options (0,1,2,3)*/'
      CALL PRINT_MESSAGE( msgBuf, ioUnit, SQUEEZE_RIGHT, myThid )
      buffI(1) = selectCoriMap
      CALL PRINT_LIST_I( buffI, 1, 1, INDEX_NONE,
     &                   .FALSE., .TRUE., ioUnit )
      WRITE(msgBuf,'(2A)') '    0= f-Plane ; 1= Beta-Plane ;',
     &  ' 2= Spherical ; 3= read from file'
      CALL PRINT_MESSAGE( msgBuf, ioUnit, SQUEEZE_RIGHT, myThid )
      CALL PRINT_MESSAGE(endList, ioUnit, SQUEEZE_RIGHT, myThid )
c------------
      CALL WRITE_0D_L( use3dCoriolis,  INDEX_NONE,
     & 'use3dCoriolis =', ' /* 3-D Coriolis on/off flag */')
      CALL WRITE_0D_L( useCoriolis,  INDEX_NONE,
     & 'useCoriolis =', '  /* Coriolis on/off flag */')
      CALL WRITE_0D_L( useCDscheme,  INDEX_NONE,
     & 'useCDscheme =', '  /* CD scheme on/off flag */')
      CALL WRITE_0D_L( useJamartWetPoints,  INDEX_NONE,
     & 'useJamartWetPoints=',' /* Coriolis WetPoints method flag */')
      CALL WRITE_0D_L( useJamartMomAdv,  INDEX_NONE,
     & 'useJamartMomAdv=',' /* V.I. Non-linear terms Jamart flag */')
      CALL WRITE_0D_L( useAbsVorticity,  INDEX_NONE,
     & 'useAbsVorticity=',' /* Work with f+zeta in Coriolis */')
      WRITE(msgBuf,'(2A)')
     & 'selectVortScheme=',' /* Scheme selector for Vorticity-Term */'
      CALL PRINT_MESSAGE( msgBuf, ioUnit, SQUEEZE_RIGHT, myThid )
      buffI(1) = selectVortScheme
      CALL PRINT_LIST_I( buffI, 1, 1, INDEX_NONE,
     &                   .FALSE., .TRUE., ioUnit )
      WRITE(msgBuf,'(2A)') '   = 0 : enstrophy (Shallow-Water Eq.)',
     &                  ' conserving scheme by Sadourny, JAS 75'
      CALL PRINT_MESSAGE( msgBuf, ioUnit, SQUEEZE_RIGHT, myThid )
      WRITE(msgBuf,'(2A)') '   = 1 : same as 0 with modified hFac'
      CALL PRINT_MESSAGE( msgBuf, ioUnit, SQUEEZE_RIGHT, myThid )
      WRITE(msgBuf,'(2A)') '   = 2 : energy conserving scheme',
     &         ' (used by Sadourny in JAS 75 paper)'
      CALL PRINT_MESSAGE( msgBuf, ioUnit, SQUEEZE_RIGHT, myThid )
      WRITE(msgBuf,'(2A)') '   = 3 : energy (general)',
     &             ' and enstrophy (2D, nonDiv.) conserving scheme'
      CALL PRINT_MESSAGE( msgBuf, ioUnit, SQUEEZE_RIGHT, myThid )
      WRITE(msgBuf,'(2A)') '         from Sadourny',
     &                     ' (Burridge & Haseler, ECMWF Rep.4, 1977)'
      CALL PRINT_MESSAGE( msgBuf, ioUnit, SQUEEZE_RIGHT, myThid )
c     WRITE(msgBuf,'(2A)') '   = 4 : energy (general)',
c    &             ' and enstrophy (2D, nonDiv.) conserving scheme'
c     CALL PRINT_MESSAGE( msgBuf, ioUnit, SQUEEZE_RIGHT, myThid )
c     WRITE(msgBuf,'(2A)') '         from Arakawa & Lamb, 77'
c     CALL PRINT_MESSAGE( msgBuf, ioUnit, SQUEEZE_RIGHT, myThid )
      CALL PRINT_MESSAGE(endList, ioUnit, SQUEEZE_RIGHT, myThid )
      CALL WRITE_0D_L( upwindVorticity,  INDEX_NONE,
     & 'upwindVorticity=',' /* Upwind bias vorticity flag */')
      CALL WRITE_0D_L( highOrderVorticity,  INDEX_NONE,
     & 'highOrderVorticity=',' /* High order interp. of vort. flag */')
      CALL WRITE_0D_L( upwindShear,  INDEX_NONE,
     & 'upwindShear=', ' /* Upwind vertical Shear advection flag */')
      CALL WRITE_0D_I( selectKEscheme, INDEX_NONE,
     & 'selectKEscheme=', ' /* Kinetic Energy scheme selector */')
      CALL WRITE_0D_L( momForcing,   INDEX_NONE,
     & 'momForcing =', '  /* Momentum forcing on/off flag */')
      CALL WRITE_0D_L( momPressureForcing, INDEX_NONE,
     & 'momPressureForcing =',
     & '  /* Momentum pressure term on/off flag */')
      CALL WRITE_0D_L( implicitIntGravWave, INDEX_NONE,
     &  'implicitIntGravWave=',
     &  ' /* Implicit Internal Gravity Wave flag */')
      CALL WRITE_0D_L( staggerTimeStep, INDEX_NONE,
     &                 'staggerTimeStep =',
     &'   /* Stagger time stepping on/off flag */')
      CALL WRITE_0D_L( multiDimAdvection, INDEX_NONE,
     & 'multiDimAdvection =',
     &'   /* enable/disable Multi-Dim Advection */')
      CALL WRITE_0D_L( useMultiDimAdvec, INDEX_NONE,
     & 'useMultiDimAdvec =',
     &'   /* Multi-Dim Advection is/is-not used */')
      CALL WRITE_0D_L( implicitDiffusion, INDEX_NONE,
     & 'implicitDiffusion =',' /* Implicit Diffusion on/off flag */')
      CALL WRITE_0D_L( tempStepping,  INDEX_NONE,
     & 'tempStepping =', '  /* Temperature equation on/off flag */')
      CALL WRITE_0D_L( tempAdvection,  INDEX_NONE,
     & 'tempAdvection=', '  /* Temperature advection on/off flag */')
      CALL WRITE_0D_L( tempImplVertAdv,INDEX_NONE,'tempImplVertAdv =',
     &                ' /* Temp. implicit vert. advection on/off */')
      CALL WRITE_0D_L( tempForcing,  INDEX_NONE,
     & 'tempForcing  =', '  /* Temperature forcing on/off flag */')
      CALL WRITE_0D_L( tempIsActiveTr, INDEX_NONE, 'tempIsActiveTr =',
     & ' /* Temp. is a dynamically Active Tracer */')
      CALL WRITE_0D_L( saltStepping,  INDEX_NONE,
     & 'saltStepping =', '  /* Salinity equation on/off flag */')
      CALL WRITE_0D_L( saltAdvection,  INDEX_NONE,
     & 'saltAdvection=', '  /* Salinity advection on/off flag */')
      CALL WRITE_0D_L( saltImplVertAdv,INDEX_NONE,'saltImplVertAdv =',
     &                ' /* Sali. implicit vert. advection on/off */')
      CALL WRITE_0D_L( saltForcing,  INDEX_NONE,
     & 'saltForcing  =', '  /* Salinity forcing on/off flag */')
      CALL WRITE_0D_L( saltIsActiveTr, INDEX_NONE, 'saltIsActiveTr =',
     & ' /* Salt  is a dynamically Active Tracer */')
      CALL WRITE_0D_I( readBinaryPrec, INDEX_NONE, ' readBinaryPrec =',
     &  ' /* Precision used for reading binary files */')
      CALL WRITE_0D_I(writeBinaryPrec, INDEX_NONE, 'writeBinaryPrec =',
     &  ' /* Precision used for writing binary files */')
      CALL WRITE_0D_L( globalFiles,  INDEX_NONE,
     & ' globalFiles =',' /* write "global" (=not per tile) files */')
      CALL WRITE_0D_L( useSingleCpuIO,  INDEX_NONE,
     & ' useSingleCpuIO =', ' /* only master MPI process does I/O */')
      CALL WRITE_0D_L( debugMode,  INDEX_NONE,
     & ' debugMode  =', '  /* Debug Mode on/off flag */')
      CALL WRITE_0D_I( debLevA, INDEX_NONE,
     & '   debLevA  =', '  /* 1rst level of debugging */')
      CALL WRITE_0D_I( debLevB, INDEX_NONE,
     & '   debLevB  =', '  /* 2nd  level of debugging */')
      CALL WRITE_0D_I( debugLevel, INDEX_NONE,
     & ' debugLevel =', '  /* select debugging level */')

      WRITE(msgBuf,'(A)') '//  '
      CALL PRINT_MESSAGE( msgBuf, ioUnit, SQUEEZE_RIGHT, myThid )
      WRITE(msgBuf,'(A)')
     & '// Elliptic solver(s) paramters ( PARM02 in namelist ) '
      CALL PRINT_MESSAGE( msgBuf, ioUnit, SQUEEZE_RIGHT, myThid )
      WRITE(msgBuf,'(A)') '//  '
      CALL PRINT_MESSAGE( msgBuf, ioUnit, SQUEEZE_RIGHT, myThid )
      CALL WRITE_0D_I( cg2dMaxIters,   INDEX_NONE,'cg2dMaxIters =',
     &'   /* Upper limit on 2d con. grad iterations  */')
      CALL WRITE_0D_I( cg2dChkResFreq, INDEX_NONE,'cg2dChkResFreq =',
     &'   /* 2d con. grad convergence test frequency */')
      CALL WRITE_0D_RL( cg2dTargetResidual, INDEX_NONE,
     & 'cg2dTargetResidual =',
     &'   /* 2d con. grad target residual  */')
      CALL WRITE_0D_RL( cg2dTargetResWunit, INDEX_NONE,
     & 'cg2dTargetResWunit =',
     &'   /* CG2d target residual [W units] */')
      CALL WRITE_0D_I( cg2dPreCondFreq, INDEX_NONE,'cg2dPreCondFreq =',
     &'   /* Freq. for updating cg2d preconditioner */')
      CALL WRITE_0D_L( useSRCGSolver, INDEX_NONE,
     & 'useSRCGSolver =', '  /* use single reduction CG solver(s) */')

      WRITE(msgBuf,'(A)') '//  '
      CALL PRINT_MESSAGE( msgBuf, ioUnit, SQUEEZE_RIGHT, myThid )
      WRITE(msgBuf,'(A)')
     & '// Time stepping paramters ( PARM03 in namelist ) '
      CALL PRINT_MESSAGE( msgBuf, ioUnit, SQUEEZE_RIGHT, myThid )
      WRITE(msgBuf,'(A)') '//  '
      CALL PRINT_MESSAGE( msgBuf, ioUnit, SQUEEZE_RIGHT, myThid )
      CALL WRITE_0D_RL( deltaTmom, INDEX_NONE,'deltaTmom =',
     &'   /* Momentum equation timestep ( s ) */')
      CALL WRITE_0D_RL( deltaTfreesurf,INDEX_NONE,'deltaTfreesurf =',
     &  ' /* FreeSurface equation timestep ( s ) */')
      CALL WRITE_1D_RL( dTtracerLev, Nr, INDEX_K, 'dTtracerLev =',
     & '  /* Tracer equation timestep ( s ) */')
      CALL WRITE_0D_RL( deltaTClock, INDEX_NONE,'deltaTClock  =',
     &'   /* Model clock timestep ( s ) */')
      CALL WRITE_0D_RL( cAdjFreq, INDEX_NONE,'cAdjFreq =',
     &'   /* Convective adjustment interval ( s ) */')
      CALL WRITE_0D_I( momForcingOutAB, INDEX_NONE, 'momForcingOutAB =',
     & ' /* =1: take Momentum Forcing out of Adams-Bash. stepping */')
      CALL WRITE_0D_I( tracForcingOutAB, INDEX_NONE,
     & 'tracForcingOutAB =',
     & ' /* =1: take T,S,pTr Forcing out of Adams-Bash. stepping */')
      CALL WRITE_0D_L( momDissip_In_AB,INDEX_NONE,'momDissip_In_AB =',
     & ' /* put Dissipation Tendency in Adams-Bash. stepping */')
      CALL WRITE_0D_L( doAB_onGtGs, INDEX_NONE, 'doAB_onGtGs =',
     &  ' /* apply AB on Tendencies (rather than on T,S)*/')
      CALL WRITE_0D_RL( abEps, INDEX_NONE,'abEps =',
     &'   /* Adams-Bashforth-2 stabilizing weight */')
#ifdef ALLOW_ADAMSBASHFORTH_3
      CALL WRITE_0D_RL( alph_AB, INDEX_NONE,'alph_AB =',
     &'   /* Adams-Bashforth-3 primary factor */')
      CALL WRITE_0D_RL( beta_AB, INDEX_NONE,'beta_AB =',
     &'   /* Adams-Bashforth-3 secondary factor */')
      CALL WRITE_0D_L( startFromPickupAB2, INDEX_NONE,
     & 'startFromPickupAB2=',' /* start from AB-2 pickup */')
#endif
      IF (useCDscheme) THEN
      CALL WRITE_0D_RL( tauCD, INDEX_NONE,'tauCD =',
     &'   /* CD coupling time-scale ( s ) */')
      CALL WRITE_0D_RL( rCD, INDEX_NONE,'rCD =',
     &'   /* Normalised CD coupling parameter */')
      CALL WRITE_0D_RL( epsAB_CD, INDEX_NONE,'epsAB_CD =',
     &  ' /* AB-2 stabilizing weight for CD-scheme*/')
      ENDIF
      i = ILNBLNK(pickupSuff)
      IF ( i.GT.0 ) THEN
        CALL WRITE_0D_C( pickupSuff, 0, INDEX_NONE,
     & 'pickupSuff =', ' /* Suffix of pickup-file to restart from */')
      ENDIF
      CALL WRITE_0D_L( pickupStrictlyMatch, INDEX_NONE,
     & 'pickupStrictlyMatch=',
     & ' /* stop if pickup do not strictly match */')
      CALL WRITE_0D_I( nIter0, INDEX_NONE, 'nIter0   =',
     &'   /* Run starting timestep number */')
      CALL WRITE_0D_I( nTimeSteps, INDEX_NONE,'nTimeSteps =',
     &  ' /* Number of timesteps */')
      CALL WRITE_0D_I( nEndIter, INDEX_NONE, 'nEndIter =',
     &'   /* Run ending timestep number */')
      CALL WRITE_0D_RL( baseTime, INDEX_NONE,'baseTime =',
     &'   /* Model base time ( s ) */')
      CALL WRITE_0D_RL( startTime, INDEX_NONE,'startTime =',
     & '  /* Run start time ( s ) */')
      CALL WRITE_0D_RL( endTime, INDEX_NONE,'endTime  =',
     &'   /* Integration ending time ( s ) */')
      CALL WRITE_0D_RL( pChkPtFreq, INDEX_NONE,'pChkPtFreq =',
     &  ' /* Permanent restart/pickup file interval ( s ) */')
      CALL WRITE_0D_RL( chkPtFreq, INDEX_NONE,'chkPtFreq  =',
     &  ' /* Rolling restart/pickup file interval ( s ) */')
      CALL WRITE_0D_L(pickup_write_mdsio,INDEX_NONE,
     &     'pickup_write_mdsio =', '   /* Model IO flag. */')
      CALL WRITE_0D_L(pickup_read_mdsio,INDEX_NONE,
     &     'pickup_read_mdsio =', '   /* Model IO flag. */')
#ifdef ALLOW_MNC
      CALL WRITE_0D_L(pickup_write_mnc,INDEX_NONE,
     &     'pickup_write_mnc =', '   /* Model IO flag. */')
      CALL WRITE_0D_L(pickup_read_mnc,INDEX_NONE,
     &     'pickup_read_mnc =', '   /* Model IO flag. */')
#endif
      CALL WRITE_0D_L(pickup_write_immed,INDEX_NONE,
     &     'pickup_write_immed =','   /* Model IO flag. */')
      CALL WRITE_0D_L(writePickupAtEnd,INDEX_NONE,
     &     'writePickupAtEnd =','   /* Model IO flag. */')
      CALL WRITE_0D_RL( dumpFreq, INDEX_NONE,'dumpFreq =',
     &'   /* Model state write out interval ( s ). */')
      CALL WRITE_0D_L(dumpInitAndLast,INDEX_NONE,'dumpInitAndLast=',
     &  ' /* write out Initial & Last iter. model state */')
      CALL WRITE_0D_L(snapshot_mdsio,INDEX_NONE,
     &     'snapshot_mdsio =', '   /* Model IO flag. */')
#ifdef ALLOW_MNC
      CALL WRITE_0D_L(snapshot_mnc,INDEX_NONE,
     &     'snapshot_mnc =', '   /* Model IO flag. */')
#endif
      CALL WRITE_0D_RL( monitorFreq, INDEX_NONE,'monitorFreq =',
     &'   /* Monitor output interval ( s ). */')
      CALL WRITE_0D_I( monitorSelect, INDEX_NONE, 'monitorSelect =',
     & ' /* select group of variables to monitor */')
      CALL WRITE_0D_L(monitor_stdio,INDEX_NONE,
     &     'monitor_stdio =', '   /* Model IO flag. */')
#ifdef ALLOW_MNC
      CALL WRITE_0D_L(monitor_mnc,INDEX_NONE,
     &     'monitor_mnc =', '   /* Model IO flag. */')
#endif
      CALL WRITE_0D_RL( externForcingPeriod, INDEX_NONE,
     &   'externForcingPeriod =', '   /* forcing period (s) */')
      CALL WRITE_0D_RL( externForcingCycle, INDEX_NONE,
     &   'externForcingCycle =', '   /* period of the cyle (s). */')
      CALL WRITE_0D_RL( tauThetaClimRelax, INDEX_NONE,
     &   'tauThetaClimRelax =', '   /* relaxation time scale (s) */')
      CALL WRITE_0D_RL( tauSaltClimRelax, INDEX_NONE,
     &   'tauSaltClimRelax =',  '   /* relaxation time scale (s) */')
      CALL WRITE_0D_RL( latBandClimRelax, INDEX_NONE,
     &   'latBandClimRelax =', '   /* max. Lat. where relaxation */')

      WRITE(msgBuf,'(A)') '//  '
      CALL PRINT_MESSAGE( msgBuf, ioUnit, SQUEEZE_RIGHT, myThid )
      WRITE(msgBuf,'(A)')
     & '// Gridding paramters ( PARM04 in namelist ) '
      CALL PRINT_MESSAGE( msgBuf, ioUnit, SQUEEZE_RIGHT, myThid )
      WRITE(msgBuf,'(A)') '//  '
      CALL PRINT_MESSAGE( msgBuf, ioUnit, SQUEEZE_RIGHT, myThid )
      CALL WRITE_0D_L( usingCartesianGrid, INDEX_NONE,
     & 'usingCartesianGrid =',
     & ' /* Cartesian coordinates flag ( True/False ) */')
      CALL WRITE_0D_L( usingCylindricalGrid, INDEX_NONE,
     & 'usingCylindricalGrid =',
     & ' /* Cylindrical coordinates flag ( True/False ) */')
      CALL WRITE_0D_L( usingSphericalPolarGrid, INDEX_NONE,
     & 'usingSphericalPolarGrid =',
     & ' /* Spherical coordinates flag ( True/False ) */')
      CALL WRITE_0D_L( usingCurvilinearGrid, INDEX_NONE,
     & 'usingCurvilinearGrid =',
     & ' /* Curvilinear coordinates flag ( True/False ) */')
      CALL WRITE_0D_I( selectSigmaCoord, INDEX_NONE,
     & 'selectSigmaCoord =',
     & ' /* Hybrid-Sigma Vert. Coordinate option */')
      CALL WRITE_0D_RL( Ro_SeaLevel, INDEX_NONE,'Ro_SeaLevel =',
     & ' /* r(1) ( units of r == '//rUnits//' ) */')
      CALL WRITE_0D_RL( rSigmaBnd, INDEX_NONE, 'rSigmaBnd =',
     & ' /* r/sigma transition ( units of r == '//rUnits//' ) */')
      CALL WRITE_0D_RL( rkSign, INDEX_NONE,'rkSign =',
     &'   /* index orientation relative to vertical coordinate */')
      CALL WRITE_0D_RL( gravitySign, INDEX_NONE,'gravitySign =',
     &  ' /* gravity orientation relative to vertical coordinate */')
      IF ( usingZCoords ) THEN
       CALL WRITE_0D_RL( mass2rUnit, INDEX_NONE,'mass2rUnit =',
     & ' /* convert mass per unit area [kg/m2] to r-units [m] */')
       CALL WRITE_0D_RL( rUnit2mass, INDEX_NONE,'rUnit2mass =',
     & ' /* convert r-units [m] to mass per unit area [kg/m2] */')
      ENDIF
      IF ( usingPCoords ) THEN
       CALL WRITE_0D_RL( mass2rUnit, INDEX_NONE,'mass2rUnit =',
     & ' /* convert mass per unit area [kg/m2] to r-units [Pa] */')
       CALL WRITE_0D_RL( rUnit2mass, INDEX_NONE,'rUnit2mass =',
     & ' /* convert r-units [Pa] to mass per unit area [kg/m2] */')
      ENDIF
      CALL WRITE_COPY1D_RS( bufRL, drC, Nr, INDEX_K, 'drC = ',
     &'   /* C spacing ( units of r ) */')
      CALL WRITE_COPY1D_RS( bufRL, drF, Nr, INDEX_K, 'drF = ',
     &'   /* W spacing ( units of r ) */')
      IF ( selectSigmaCoord.NE.0 ) THEN
       CALL WRITE_COPY1D_RS( bufRL,dAHybSigF,Nr,INDEX_K,'dAHybSigF =',
     &  ' /* vertical increment of Hybrid-sigma Coeff. (-) */')
       CALL WRITE_COPY1D_RS( bufRL,dBHybSigF,Nr,INDEX_K,'dBHybSigF =',
     &  ' /* vertical increment of Hybrid-sigma Coeff. (-) */')
      ENDIF
      IF ( .NOT.usingCurvilinearGrid ) THEN
       CALL WRITE_1D_RL( delX, Nx, INDEX_I, 'delX = ',
     &  ' /* U spacing ( m - cartesian, degrees - spherical ) */')
       CALL WRITE_1D_RL( delY, Ny, INDEX_J, 'delY = ',
     &  ' /* V spacing ( m - cartesian, degrees - spherical ) */')
      ENDIF
      CALL WRITE_0D_RL( xgOrigin, INDEX_NONE,'xgOrigin = ',
     &'/* X-axis origin of West  edge (cartesian: m, lat-lon: deg.) */')
      CALL WRITE_0D_RL( ygOrigin, INDEX_NONE,'ygOrigin = ',
     &'/* Y-axis origin of South edge (cartesian: m, lat-lon: deg.) */')
      CALL WRITE_0D_RL( rSphere, INDEX_NONE,'rSphere = ',
     &  ' /* Radius ( ignored - cartesian, m - spherical ) */')
      CALL WRITE_0D_L(deepAtmosphere,INDEX_NONE, 'deepAtmosphere =',
     &  ' /* Deep/Shallow Atmosphere flag (True/False) */')
      coordLine = 1
      tileLine  = 1
      CALL WRITE_XY_XLINE_RS( xC, coordLine, tileLine, 'xC',
     I         ': P-point X coord ( deg. or m if cartesian)')
      CALL WRITE_XY_YLINE_RS( yC, coordLine, tileLine, 'yC',
     I         ': P-point Y coord ( deg. or m if cartesian)')
      CALL WRITE_COPY1D_RS( bufRL, rC, Nr, INDEX_K, 'rcoord =',
     &  ' /* P-point R coordinate (  units of r ) */')
      CALL WRITE_COPY1D_RS( bufRL, rF,Nr+1,INDEX_K, 'rF = ',
     &'   /* W-Interf. R coordinate (  units of r ) */')
      IF ( selectSigmaCoord.NE.0 ) THEN
       CALL WRITE_COPY1D_RS(bufRL,aHybSigmF,Nr+1,INDEX_K,'aHybSigmF =',
     &  ' /* Hybrid-sigma vert. Coord coeff. @ W-Interface (-) */')
       CALL WRITE_COPY1D_RS(bufRL,bHybSigmF,Nr+1,INDEX_K,'bHybSigmF =',
     &  ' /* Hybrid-sigma vert. Coord coeff. @ W-Interface (-) */')
      ENDIF
      CALL WRITE_1D_RL( deepFacC, Nr,   INDEX_K, 'deepFacC = ',
     &  ' /* deep-model grid factor @ cell-Center (-) */')
      CALL WRITE_1D_RL( deepFacF, Nr+1, INDEX_K, 'deepFacF = ',
     &  ' /* deep-model grid factor @ W-Interface (-) */')
      CALL WRITE_1D_RL(rVel2wUnit,Nr+1, INDEX_K,'rVel2wUnit =',
     &  ' /* convert units: rVel -> wSpeed (=1 if z-coord)*/')
      CALL WRITE_1D_RL(wUnit2rVel,Nr+1, INDEX_K,'wUnit2rVel =',
     &  ' /* convert units: wSpeed -> rVel (=1 if z-coord)*/')
      CALL WRITE_1D_RL( dBdrRef,  Nr,   INDEX_K, 'dBdrRef =',
     & ' /* Vertical gradient of reference boyancy [(m/s/r)^2)] */')
      CALL WRITE_0D_L( rotateGrid, INDEX_NONE,
     & 'rotateGrid =',' /* use rotated grid ( True/False ) */')
      CALL WRITE_0D_RL( phiEuler, INDEX_NONE,'phiEuler =',
     &' /* Euler angle, rotation about original z-coordinate [rad] */')
      CALL WRITE_0D_RL( thetaEuler, INDEX_NONE,'thetaEuler =',
     & ' /* Euler angle, rotation about new x-coordinate [rad] */')
      CALL WRITE_0D_RL( psiEuler, INDEX_NONE,'psiEuler =',
     & ' /* Euler angle, rotation about new z-coordinate [rad] */')

C     Grid along selected grid lines
      coordLine = 1
      tileLine  = 1
      CALL WRITE_XY_XLINE_RS( dxF, coordLine, tileLine, 'dxF',
     I              '( units: m )' )
      CALL WRITE_XY_YLINE_RS( dxF, coordLine, tileLine, 'dxF',
     I              '( units: m )' )
      CALL WRITE_XY_XLINE_RS( dyF, coordLine, tileLine, 'dyF',
     I              '( units: m )' )
      CALL WRITE_XY_YLINE_RS( dyF, coordLine, tileLine, 'dyF',
     I              '( units: m )' )
      CALL WRITE_XY_XLINE_RS( dxG, coordLine, tileLine, 'dxG',
     I              '( units: m )' )
      CALL WRITE_XY_YLINE_RS( dxG, coordLine, tileLine, 'dxG',
     I              '( units: m )' )
      CALL WRITE_XY_XLINE_RS( dyG, coordLine, tileLine, 'dyG',
     I              '( units: m )' )
      CALL WRITE_XY_YLINE_RS( dyG, coordLine, tileLine, 'dyG',
     I              '( units: m )' )
      CALL WRITE_XY_XLINE_RS( dxC, coordLine, tileLine, 'dxC',
     I              '( units: m )' )
      CALL WRITE_XY_YLINE_RS( dxC, coordLine, tileLine, 'dxC',
     I              '( units: m )' )
      CALL WRITE_XY_XLINE_RS( dyC, coordLine, tileLine, 'dyC',
     I              '( units: m )' )
      CALL WRITE_XY_YLINE_RS( dyC, coordLine, tileLine, 'dyC',
     I              '( units: m )' )
      CALL WRITE_XY_XLINE_RS( dxV, coordLine, tileLine, 'dxV',
     I              '( units: m )' )
      CALL WRITE_XY_YLINE_RS( dxV, coordLine, tileLine, 'dxV',
     I              '( units: m )' )
      CALL WRITE_XY_XLINE_RS( dyU, coordLine, tileLine, 'dyU',
     I              '( units: m )' )
      CALL WRITE_XY_YLINE_RS( dyU, coordLine, tileLine, 'dyU',
     I              '( units: m )' )
      CALL WRITE_XY_XLINE_RS( rA , coordLine, tileLine, 'rA ',
     I              '( units: m^2 )' )
      CALL WRITE_XY_YLINE_RS( rA , coordLine, tileLine, 'rA ',
     I              '( units: m^2 )' )
      CALL WRITE_XY_XLINE_RS( rAw, coordLine, tileLine, 'rAw',
     I              '( units: m^2 )' )
      CALL WRITE_XY_YLINE_RS( rAw, coordLine, tileLine, 'rAw',
     I              '( units: m^2 )' )
      CALL WRITE_XY_XLINE_RS( rAs, coordLine, tileLine, 'rAs',
     I              '( units: m^2 )' )
      CALL WRITE_XY_YLINE_RS( rAs, coordLine, tileLine, 'rAs',
     I              '( units: m^2 )' )

      CALL WRITE_0D_RL( globalArea, INDEX_NONE, 'globalArea =',
     & ' /* Integrated horizontal Area (m^2) */')

      i = ILNBLNK(the_run_name)
      IF ( i.GT.0 ) THEN
        CALL WRITE_0D_C( the_run_name, i, INDEX_NONE,
     &    'the_run_name = ', '/* Name of this simulation */' )
      ENDIF

      WRITE(msgBuf,'(A)')
     &'// ======================================================='
      CALL PRINT_MESSAGE( msgBuf, ioUnit, SQUEEZE_RIGHT, myThid )
      WRITE(msgBuf,'(A)') '// End of Model config. summary'
      CALL PRINT_MESSAGE( msgBuf, ioUnit, SQUEEZE_RIGHT, myThid )
      WRITE(msgBuf,'(A)')
     &'// ======================================================='
      CALL PRINT_MESSAGE( msgBuf, ioUnit, SQUEEZE_RIGHT, myThid )
      WRITE(msgBuf,'(A)') ' '
      CALL PRINT_MESSAGE( msgBuf, ioUnit, SQUEEZE_RIGHT, myThid )

      _END_MASTER(myThid)
      _BARRIER

      RETURN
      END
