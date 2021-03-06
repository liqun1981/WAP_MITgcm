C $Header: /u/gcmpack/MITgcm/pkg/seaice/seaice_model.F,v 1.83 2010/11/18 17:32:37 jmc Exp $
C $Name: checkpoint62r $

#include "SEAICE_OPTIONS.h"

CBOP
C !ROUTINE: SEAICE_MODEL

C !INTERFACE: ==========================================================
      SUBROUTINE SEAICE_MODEL( myTime, myIter, myThid )

C !DESCRIPTION: \bv
C     *===========================================================*
C     | SUBROUTINE SEAICE_MODEL                                   |
C     | o Time stepping of a dynamic/thermodynamic sea ice model. |
C     |  Dynamics solver: Zhang/Hibler, JGR, 102, 8691-8702, 1997 |
C     |  Thermodynamics:        Hibler, MWR, 108, 1943-1973, 1980 |
C     |  Rheology:              Hibler, JPO,   9,  815- 846, 1979 |
C     |  Snow:          Zhang et al.  , JPO,  28,  191- 217, 1998 |
C     |  Parallel forward ice model written by Jinlun Zhang PSC/UW|
C     |  & coupled into MITgcm by Dimitris Menemenlis (JPL) 2/2001|
C     |  zhang@apl.washington.edu / menemenlis@jpl.nasa.gov       |
C     *===========================================================*
C     *===========================================================*
      IMPLICIT NONE
C \ev

C !USES: ===============================================================
#include "SIZE.h"
#include "EEPARAMS.h"
#include "DYNVARS.h"
#include "PARAMS.h"
#include "GRID.h"
#include "FFIELDS.h"
#include "SEAICE.h"
#include "SEAICE_PARAMS.h"
#ifdef ALLOW_EXF
# include "EXF_OPTIONS.h"
# include "EXF_FIELDS.h"
#endif
#ifdef ALLOW_SALT_PLUME
# include "SALT_PLUME.h"
#endif
#ifdef ALLOW_AUTODIFF_TAMC
# include "tamc.h"
#endif

C !INPUT PARAMETERS: ===================================================
C     myTime - Simulation time
C     myIter - Simulation timestep number
C     myThid - Thread no. that called this routine.
      _RL     myTime
      INTEGER myIter
      INTEGER myThid
CEndOfInterface

C     !FUNCTIONS:
#ifdef ALLOW_DIAGNOSTICS
      LOGICAL  DIAGNOSTICS_IS_ON
      EXTERNAL DIAGNOSTICS_IS_ON
#endif

C !LOCAL VARIABLES: ====================================================
C     i,j,bi,bj :: Loop counters
C     iceFld    :: Copy of seaice field
      INTEGER i, j, bi, bj
c     _RL iceFld (1-OLx:sNx+OLx,1-OLy:sNy+OLy)

C     temporary arrays for pahol diagnostics
      _RL AREAstart      (1:sNx,1:sNy)
      _RL AREApreth      (1:sNx,1:sNy)
      _RL AREAend        (1:sNx,1:sNy)
      _RL HEFFstart      (1:sNx,1:sNy)
      _RL HEFFpreth      (1:sNx,1:sNy)
      _RL HEFFend        (1:sNx,1:sNy)
      _RL DIAGarray      (1:sNx,1:sNy)
CEOP

C     pahol store field
      DO bj = myByLo(myThid), myByHi(myThid)
       DO bi = myBxLo(myThid), myBxHi(myThid)
        DO J=1,sNy
         DO I=1,sNx
          HEFFstart(I,J)=HEFF(I,J,bi,bj)
          AREAstart(I,J)=AREA(I,J,bi,bj)
         ENDDO
        ENDDO
       ENDDO
      ENDDO
#ifdef ALLOW_DEBUG
      IF (debugMode) CALL DEBUG_ENTER( 'SEAICE_MODEL', myThid )
#endif

C--   Winds are from pkg/exf, which does not update edges.
      CALL EXCH_UV_AGRID_3D_RL( uwind, vwind, .TRUE., 1, myThid )

#ifdef ALLOW_THSICE
      IF ( useThSice ) THEN
C--   Map thSice-variables to HEFF and AREA
       CALL SEAICE_MAP_THSICE( myTime, myIter, myThid )
      ENDIF
#endif /* ALLOW_THSICE */

      IF ( .NOT.useThSice ) THEN
#ifdef ALLOW_AUTODIFF_TAMC
CADJ STORE heff  = comlev1, key=ikey_dynamics, kind=isbyte
CADJ STORE heffm = comlev1, key=ikey_dynamics, kind=isbyte
CADJ STORE area  = comlev1, key=ikey_dynamics, kind=isbyte
CADJ STORE hsnow = comlev1, key=ikey_dynamics, kind=isbyte
CADJ STORE tice  = comlev1, key=ikey_dynamics, kind=isbyte
#ifdef SEAICE_SALINITY
CADJ STORE hsalt = comlev1, key=ikey_dynamics, kind=isbyte
#endif
#endif
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-Oly,sNy+Oly
         DO i=1-Olx,sNx+Olx
          IF ( (heff(i,j,bi,bj).EQ.0.)
     &     .OR.(area(i,j,bi,bj).EQ.0.)
     &     ) THEN
           HEFF(i,j,bi,bj) = 0. _d 0
           AREA(i,j,bi,bj) = 0. _d 0
           HSNOW(i,j,bi,bj) = 0. _d 0
           TICE(i,j,bi,bj) = celsius2K
#ifdef SEAICE_SALINITY
           HSALT(i,j,bi,bj) = 0. _d 0
#endif
          ENDIF
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      ENDIF

#ifdef ALLOW_AUTODIFF_TAMC
c
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-Oly,sNy+Oly
         DO i=1-Olx,sNx+Olx
          HEFFNM1(i,j,bi,bj) = 0. _d 0
          AREANM1(i,j,bi,bj) = 0. _d 0
          uIceNm1(i,j,bi,bj) = 0. _d 0
          vIceNm1(i,j,bi,bj) = 0. _d 0
         ENDDO
        ENDDO
       ENDDO
      ENDDO
c
CADJ STORE uwind = comlev1, key=ikey_dynamics, kind=isbyte
CADJ STORE vwind = comlev1, key=ikey_dynamics, kind=isbyte
CADJ STORE heff  = comlev1, key=ikey_dynamics, kind=isbyte
CADJ STORE heffm = comlev1, key=ikey_dynamics, kind=isbyte
CADJ STORE area  = comlev1, key=ikey_dynamics, kind=isbyte
# ifdef SEAICE_ALLOW_DYNAMICS
#  ifdef SEAICE_CGRID
CADJ STORE seaicemasku = comlev1, key=ikey_dynamics, kind=isbyte
CADJ STORE seaicemaskv = comlev1, key=ikey_dynamics, kind=isbyte
CADJ STORE fu    = comlev1, key=ikey_dynamics, kind=isbyte
CADJ STORE fv    = comlev1, key=ikey_dynamics, kind=isbyte
CADJ STORE uice  = comlev1, key=ikey_dynamics, kind=isbyte
CADJ STORE vice  = comlev1, key=ikey_dynamics, kind=isbyte
cphCADJ STORE eta   = comlev1, key=ikey_dynamics, kind=isbyte
cphCADJ STORE zeta  = comlev1, key=ikey_dynamics, kind=isbyte
cph(
CADJ STORE dwatn    = comlev1, key=ikey_dynamics, kind=isbyte
cccCADJ STORE press0   = comlev1, key=ikey_dynamics, kind=isbyte
cccCADJ STORE taux   = comlev1, key=ikey_dynamics, kind=isbyte
cccCADJ STORE tauy  = comlev1, key=ikey_dynamics, kind=isbyte
cccCADJ STORE zmax   = comlev1, key=ikey_dynamics, kind=isbyte
cccCADJ STORE zmin  = comlev1, key=ikey_dynamics, kind=isbyte
cph)
#   ifdef SEAICE_ALLOW_EVP
CADJ STORE seaice_sigma1  = comlev1, key=ikey_dynamics, kind=isbyte
CADJ STORE seaice_sigma2  = comlev1, key=ikey_dynamics, kind=isbyte
CADJ STORE seaice_sigma12 = comlev1, key=ikey_dynamics, kind=isbyte
#   endif
#  endif
# endif
#endif /* ALLOW_AUTODIFF_TAMC */

C solve ice momentum equations and calculate ocean surface stress
#ifdef ALLOW_DEBUG
      IF (debugMode) CALL DEBUG_CALL( 'SEAICE_DYNSOLVER', myThid )
#endif
#ifdef SEAICE_CGRID
      CALL TIMER_START('SEAICE_DYNSOLVER   [SEAICE_MODEL]',myThid)
      CALL SEAICE_DYNSOLVER ( myTime, myIter, myThid )
      CALL TIMER_STOP ('SEAICE_DYNSOLVER   [SEAICE_MODEL]',myThid)
#else
      CALL TIMER_START('DYNSOLVER          [SEAICE_MODEL]',myThid)
      CALL DYNSOLVER ( myTime, myIter, myThid )
      CALL TIMER_STOP ('DYNSOLVER          [SEAICE_MODEL]',myThid)
#endif /* SEAICE_CGRID */

C--   Apply ice velocity open boundary conditions
#ifdef ALLOW_OBCS
# ifndef DISABLE_SEAICE_OBCS
       IF ( useOBCS ) CALL OBCS_APPLY_UVICE( uice, vice, myThid )
# endif /* DISABLE_SEAICE_OBCS */
#endif /* ALLOW_OBCS */

#ifdef ALLOW_THSICE
      IF ( .NOT.useThSice ) THEN
#endif
C--   Only call advection of heff, area, snow, and salt and
C--   growth for the generic 0-layer thermodynamics of seaice
C--   (called from DO_OCEANIC_PHYSICS) take care of this

C NOW DO ADVECTION and DIFFUSION
      IF ( SEAICEadvHeff .OR. SEAICEadvArea .OR. SEAICEadvSnow
     &        .OR. SEAICEadvSalt .OR. SEAICEadvAge ) THEN
#ifdef ALLOW_DEBUG
       IF (debugMode) CALL DEBUG_CALL( 'SEAICE_ADVDIFF', myThid )
#endif
       CALL SEAICE_ADVDIFF( myTime, myIter, myThid )
      ENDIF
#ifdef ALLOW_AUTODIFF_TAMC
CADJ STORE heffm  = comlev1, key=ikey_dynamics, kind=isbyte
cph-test(
cphCADJ STORE heff   = comlev1, key=ikey_dynamics, kind=isbyte
cphCADJ STORE area   = comlev1, key=ikey_dynamics, kind=isbyte
cphCADJ STORE hsnow  = comlev1, key=ikey_dynamics, kind=isbyte
cphCADJ STORE qnet   = comlev1, key=ikey_dynamics, kind=isbyte
cphCADJ STORE qsw    = comlev1, key=ikey_dynamics, kind=isbyte
cphCADJ STORE tice   = comlev1, key=ikey_dynamics, kind=isbyte
cph-test)
# ifdef SEAICE_ALLOW_DYNAMICS
cphCADJ STORE uice   = comlev1, key=ikey_dynamics, kind=isbyte
cphCADJ STORE vice   = comlev1, key=ikey_dynamics, kind=isbyte
# endif
#endif /* ALLOW_AUTODIFF_TAMC */

C     pahol store field
      DO bj = myByLo(myThid), myByHi(myThid)
       DO bi = myBxLo(myThid), myBxHi(myThid)
        DO J=1,sNy
         DO I=1,sNx
          HEFFpreth(I,J)=HEFF(I,J,bi,bj)
          AREApreth(I,J)=AREA(I,J,bi,bj)
         ENDDO
        ENDDO
       ENDDO
      ENDDO

C     thermodynamics growth
C     must call growth after calling advection
C     because of ugly time level business
       IF ( usePW79thermodynamics ) THEN
#ifdef ALLOW_DEBUG
        IF (debugMode) CALL DEBUG_CALL( 'SEAICE_GROWTH', myThid )
#endif
#ifndef SEAICE_ALLOW_TD_IF
        CALL SEAICE_GROWTH( myTime, myIter, myThid )
#else
        CALL SEAICE_GROWTH_IF( myTime, myIter, myThid )
#endif
       ENDIF

C--   Apply ice tracer open boundary conditions
#ifdef ALLOW_OBCS
# ifndef DISABLE_SEAICE_OBCS
       IF ( useOBCS ) CALL OBCS_APPLY_SEAICE( myThid )
# endif /* DISABLE_SEAICE_OBCS */
#endif /* ALLOW_OBCS */

C--   Update overlap regions for a bunch of stuff
       _EXCH_XY_RL( HEFF,  myThid )
       _EXCH_XY_RL( AREA,  myThid )
       _EXCH_XY_RL( HSNOW, myThid )
#ifdef SEAICE_SALINITY
       _EXCH_XY_RL( HSALT, myThid )
#endif
#ifdef SEAICE_AGE
       _EXCH_XY_RL( IceAge,myThid )
#endif
       _EXCH_XY_RS(EmPmR, myThid )
       _EXCH_XY_RS(saltFlux, myThid )
       _EXCH_XY_RS(Qnet , myThid )
#ifdef SHORTWAVE_HEATING
       _EXCH_XY_RS(Qsw  , myThid )
#endif /* SHORTWAVE_HEATING */
#ifdef ALLOW_SALT_PLUME
       IF ( useSALT_PLUME )
     &       _EXCH_XY_RL(saltPlumeFlux, myThid )
#endif /* ALLOW_SALT_PLUME */
#ifdef ATMOSPHERIC_LOADING
       IF ( useRealFreshWaterFlux )
     &      _EXCH_XY_RS( sIceLoad, myThid )
#endif
#ifdef ALLOW_OBCS
       IF ( useOBCS ) THEN
        DO bj=myByLo(myThid),myByHi(myThid)
         DO bi=myBxLo(myThid),myBxHi(myThid)
           CALL OBCS_COPY_TRACER( HEFF(1-Olx,1-Oly,bi,bj),
     I                            1, bi, bj, myThid )
           CALL OBCS_COPY_TRACER( AREA(1-Olx,1-Oly,bi,bj),
     I                            1, bi, bj, myThid )
           CALL OBCS_COPY_TRACER( HSNOW(1-Olx,1-Oly,bi,bj),
     I                            1, bi, bj, myThid )
#ifdef SEAICE_SALINITY
           CALL OBCS_COPY_TRACER( HSALT(1-Olx,1-Oly,bi,bj),
     I                            1, bi, bj, myThid )
#endif
#ifdef SEAICE_AGE
           CALL OBCS_COPY_TRACER( IceAge(1-Olx,1-Oly,bi,bj),
     I                            1, bi, bj, myThid )
#endif
         ENDDO
        ENDDO
       ENDIF
#endif /* ALLOW_OBCS */

#ifdef ALLOW_DIAGNOSTICS
       IF ( useDiagnostics ) THEN
C     diagnostics for "non-state variables" that are modified by
C     the seaice model
# ifdef ALLOW_EXF
        CALL DIAGNOSTICS_FILL(UWIND   ,'SIuwind ',0,1 ,0,1,1,myThid)
        CALL DIAGNOSTICS_FILL(VWIND   ,'SIvwind ',0,1 ,0,1,1,myThid)
# endif
        CALL DIAGNOSTICS_FILL_RS(FU   ,'SIfu    ',0,1 ,0,1,1,myThid)
        CALL DIAGNOSTICS_FILL_RS(FV   ,'SIfv    ',0,1 ,0,1,1,myThid)
        CALL DIAGNOSTICS_FILL_RS(Qnet ,'SIqnet  ',0,1 ,0,1,1,myThid)
        CALL DIAGNOSTICS_FILL_RS(Qsw  ,'SIqsw   ',0,1 ,0,1,1,myThid)
        CALL DIAGNOSTICS_FILL_RS(EmPmR,'SIempmr ',0,1 ,0,1,1,myThid)
       ENDIF
#endif /* ALLOW_DIAGNOSTICS */

#ifdef ALLOW_THSICE
C     endif .not.useThSice
      ENDIF
#endif /* ALLOW_THSICE */
CML   This has already been done in seaice_ocean_stress/ostres, so why repeat?
CML   CALL EXCH_UV_XY_RS(fu,fv,.TRUE.,myThid)

#ifdef ALLOW_EXF
# ifdef ALLOW_AUTODIFF_TAMC
#  if (defined (ALLOW_AUTODIFF_MONITOR))
        CALL EXF_ADJOINT_SNAPSHOTS( 3, myTime, myIter, myThid )
#  endif
# endif
#endif

#ifdef ALLOW_DEBUG
      IF (debugMode) CALL DEBUG_LEAVE( 'SEAICE_MODEL', myThid )
#endif

C     pahol store field
      DO bj = myByLo(myThid), myByHi(myThid)
       DO bi = myBxLo(myThid), myBxHi(myThid)
        DO J=1,sNy
         DO I=1,sNx
          HEFFend(I,J)=HEFF(I,J,bi,bj)
          AREAend(I,J)=AREA(I,J,bi,bj)
         ENDDO
        ENDDO
       ENDDO
      ENDDO

C     pahol populate diagnostics
      IF ( useDiagnostics ) THEN

       IF ( DIAGNOSTICS_IS_ON('SIttendh',myThid) ) THEN
        DO bj = myByLo(myThid), myByHi(myThid)
         DO bi = myBxLo(myThid), myBxHi(myThid)
          DO J=1,sNy
           DO I=1,sNx
            DIAGarray(I,J) = (HEFFend(I,J)-HEFFstart(I,J))
     &                       /SEAICE_deltaTtherm
           ENDDO
          ENDDO
          CALL DIAGNOSTICS_FILL(DIAGarray,'SIttendh',0,1,3,bi,bj,myThid)
         ENDDO
        ENDDO
       ENDIF

       IF ( DIAGNOSTICS_IS_ON('SIdyngrh',myThid) ) THEN
        DO bj = myByLo(myThid), myByHi(myThid)
         DO bi = myBxLo(myThid), myBxHi(myThid)
          DO J=1,sNy
           DO I=1,sNx
            DIAGarray(I,J) = (HEFFpreth(I,J)-HEFFstart(I,J))
     &                       /SEAICE_deltaTtherm
           ENDDO
          ENDDO
          CALL DIAGNOSTICS_FILL(DIAGarray,'SIdyngrh',0,1,3,bi,bj,myThid)
         ENDDO
        ENDDO
       ENDIF

       IF ( DIAGNOSTICS_IS_ON('SIthdgrh',myThid) ) THEN
        DO bj = myByLo(myThid), myByHi(myThid)
         DO bi = myBxLo(myThid), myBxHi(myThid)
          DO J=1,sNy
           DO I=1,sNx
            DIAGarray(I,J) = (HEFFend(I,J)-HEFFpreth(I,J))
     &                       /SEAICE_deltaTtherm
           ENDDO
          ENDDO
          CALL DIAGNOSTICS_FILL(DIAGarray,'SIthdgrh',0,1,3,bi,bj,myThid)
         ENDDO
        ENDDO
       ENDIF

       IF ( DIAGNOSTICS_IS_ON('SIttenda',myThid) ) THEN
        DO bj = myByLo(myThid), myByHi(myThid)
         DO bi = myBxLo(myThid), myBxHi(myThid)
          DO J=1,sNy
           DO I=1,sNx
            DIAGarray(I,J) = (AREAend(I,J)-AREAstart(I,J))
     &                       /SEAICE_deltaTtherm
           ENDDO
          ENDDO
          CALL DIAGNOSTICS_FILL(DIAGarray,'SIttenda',0,1,3,bi,bj,myThid)
         ENDDO
        ENDDO
       ENDIF

       IF ( DIAGNOSTICS_IS_ON('SIdyngra',myThid) ) THEN
        DO bj = myByLo(myThid), myByHi(myThid)
         DO bi = myBxLo(myThid), myBxHi(myThid)
          DO J=1,sNy
           DO I=1,sNx
            DIAGarray(I,J) = (AREApreth(I,J)-AREAstart(I,J))
     &                       /SEAICE_deltaTtherm
           ENDDO
          ENDDO
          CALL DIAGNOSTICS_FILL(DIAGarray,'SIdyngra',0,1,3,bi,bj,myThid)
         ENDDO
        ENDDO
       ENDIF

       IF ( DIAGNOSTICS_IS_ON('SIthdgra',myThid) ) THEN
        DO bj = myByLo(myThid), myByHi(myThid)
         DO bi = myBxLo(myThid), myBxHi(myThid)
          DO J=1,sNy
           DO I=1,sNx
            DIAGarray(I,J) = (AREAend(I,J)-AREApreth(I,J))
     &                       /SEAICE_deltaTtherm
           ENDDO
          ENDDO
          CALL DIAGNOSTICS_FILL(DIAGarray,'SIthdgra',0,1,3,bi,bj,myThid)
         ENDDO
        ENDDO
       ENDIF

      ENDIF

      RETURN
      END

