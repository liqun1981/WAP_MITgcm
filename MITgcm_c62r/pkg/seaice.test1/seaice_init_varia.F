C $Header: /u/gcmpack/MITgcm/pkg/seaice/seaice_init_varia.F,v 1.53 2010/11/08 21:50:56 dimitri Exp $
C $Name: checkpoint62r $

#include "SEAICE_OPTIONS.h"

CStartOfInterface
      SUBROUTINE SEAICE_INIT_VARIA( myThid )
C     *==========================================================*
C     | SUBROUTINE SEAICE_INIT_VARIA                             |
C     | o Initialization of sea ice model.                       |
C     *==========================================================*
C     *==========================================================*
      IMPLICIT NONE

C     === Global variables ===
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "GRID.h"
#include "DYNVARS.h"
#include "FFIELDS.h"
#include "SEAICE_PARAMS.h"
#include "SEAICE.h"
#include "SEAICE_TAVE.h"
#ifdef ALLOW_EXCH2
# include "W2_EXCH2_SIZE.h"
# include "W2_EXCH2_TOPOLOGY.h"
#endif
#ifdef ALLOW_OBCS
# include "OBCS_OPTIONS.h"
# include "OBCS.h"
#endif

C     === Routine arguments ===
C     myThid - Thread no. that called this routine.
      INTEGER myThid
CEndOfInterface

C     === Local variables ===
C     i,j,k,bi,bj - Loop counters

      INTEGER i, j, bi, bj
      _RL PSTAR
      _RS  mask_uice
      INTEGER myIter, kSurface
#ifdef SEAICE_MULTICATEGORY
      INTEGER k
#endif
#ifdef ALLOW_OBCS
      INTEGER I_obc, J_obc
#endif /* ALLOW_OBCS */
#ifdef ALLOW_EXCH2
# ifndef SEAICE_CGRID
      INTEGER myTile
# endif
#endif

      IF ( buoyancyRelation .EQ. 'OCEANICP' ) THEN
       kSurface = Nr
      ELSE
       kSurface = 1
      ENDIF

C--   Initialise all variables in common blocks:
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          HEFF(i,j,bi,bj)=0. _d 0
          AREA(i,j,bi,bj)=0. _d 0
          UICE(i,j,bi,bj)=0. _d 0
          VICE(i,j,bi,bj)=0. _d 0
C
          uIceNm1(i,j,bi,bj)=0. _d 0
          vIceNm1(i,j,bi,bj)=0. _d 0
          areaNm1(i,j,bi,bj)=0. _d 0
          hEffNm1(i,j,bi,bj)=0. _d 0
         ENDDO
        ENDDO
#ifdef SEAICE_MULTICATEGORY
        DO k=1,MULTDIM
         DO j=1-OLy,sNy+OLy
          DO i=1-OLx,sNx+OLx
           TICES(i,j,k,bi,bj)=0. _d 0
           QSWM(i,j,k,bi,bj)=0. _d 0
          ENDDO
         ENDDO
        ENDDO
#endif
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          ETA (i,j,bi,bj)   = 0. _d 0
          ZETA(i,j,bi,bj)   = 0. _d 0
          DRAGS(i,j,bi,bj)  = 0. _d 0
          DRAGA(i,j,bi,bj)  = 0. _d 0
          FORCEX(i,j,bi,bj) = 0. _d 0
          FORCEY(i,j,bi,bj) = 0. _d 0
          UICEC(i,j,bi,bj)  = 0. _d 0
          VICEC(i,j,bi,bj)  = 0. _d 0
#ifdef SEAICE_CGRID
          seaiceMassC(i,j,bi,bj)=0. _d 0
          seaiceMassU(i,j,bi,bj)=0. _d 0
          seaiceMassV(i,j,bi,bj)=0. _d 0
          stressDivergenceX(i,j,bi,bj) = 0. _d 0
          stressDivergenceY(i,j,bi,bj) = 0. _d 0
# ifdef SEAICE_ALLOW_EVP
          seaice_sigma1 (i,j,bi,bj) = 0. _d 0
          seaice_sigma2 (i,j,bi,bj) = 0. _d 0
          seaice_sigma12(i,j,bi,bj) = 0. _d 0
# endif /* SEAICE_ALLOW_EVP */
#else /* SEAICE_CGRID */
          AMASS(i,j,bi,bj)  = 0. _d 0
          DAIRN(i,j,bi,bj)  = 0. _d 0
          WINDX(i,j,bi,bj)  = 0. _d 0
          WINDY(i,j,bi,bj)  = 0. _d 0
          GWATX(i,j,bi,bj)  = 0. _d 0
          GWATY(i,j,bi,bj)  = 0. _d 0
#endif /* SEAICE_CGRID */
          DWATN(i,j,bi,bj)  = 0. _d 0
          PRESS0(i,j,bi,bj) = 0. _d 0
          FORCEX0(i,j,bi,bj)= 0. _d 0
          FORCEY0(i,j,bi,bj)= 0. _d 0
          ZMAX(i,j,bi,bj)   = 0. _d 0
          ZMIN(i,j,bi,bj)   = 0. _d 0
          HSNOW(i,j,bi,bj)  = 0. _d 0
#ifdef SEAICE_SALINITY
          HSALT(i,j,bi,bj)  = 0. _d 0
#endif
#ifdef SEAICE_AGE
          ICEAGE(i,j,bi,bj) = 0. _d 0
#endif
          YNEG (i,j,bi,bj)  = 0. _d 0
          RIVER(i,j,bi,bj)  = 0. _d 0
          TMIX(i,j,bi,bj)   = 0. _d 0
          TICE(i,j,bi,bj)   = 0. _d 0
          TAUX(i,j,bi,bj)   = 0. _d 0
          TAUY(i,j,bi,bj)   = 0. _d 0
#ifdef ALLOW_SEAICE_COST_EXPORT
          uHeffExportCell(i,j,bi,bj) = 0. _d 0
          vHeffExportCell(i,j,bi,bj) = 0. _d 0
#endif
          saltWtrIce(i,j,bi,bj) = 0. _d 0
          frWtrIce(i,j,bi,bj)   = 0. _d 0
#ifdef ALLOW_MEAN_SFLUX_COST_CONTRIBUTION
          frWtrAtm(i,j,bi,bj)   = 0. _d 0
#endif
         ENDDO
        ENDDO
       ENDDO
      ENDDO

#ifdef ALLOW_TIMEAVE
C     Initialize averages to zero
      DO bj = myByLo(myThid), myByHi(myThid)
       DO bi = myBxLo(myThid), myBxHi(myThid)
        CALL TIMEAVE_RESET( FUtave   , 1, bi, bj, myThid )
        CALL TIMEAVE_RESET( FVtave   , 1, bi, bj, myThid )
        CALL TIMEAVE_RESET( EmPmRtave, 1, bi, bj, myThid )
        CALL TIMEAVE_RESET( QNETtave , 1, bi, bj, myThid )
        CALL TIMEAVE_RESET( QSWtave  , 1, bi, bj, myThid )
        CALL TIMEAVE_RESET( UICEtave , 1, bi, bj, myThid )
        CALL TIMEAVE_RESET( VICEtave , 1, bi, bj, myThid )
        CALL TIMEAVE_RESET( HEFFtave , 1, bi, bj, myThid )
        CALL TIMEAVE_RESET( AREAtave , 1, bi, bj, myThid )
        SEAICE_timeAve(bi,bj) = ZERO
       ENDDO
      ENDDO
#endif /* ALLOW_TIMEAVE */

C--   Initialize (variable) grid info. As long as we allow masking of
C--   velocities outside of ice covered areas (in seaice_dynsolver)
C--   we need to re-initialize seaiceMaskU/V here for TAF/TAMC
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy+1,sNy+OLy
         DO i=1-OLx+1,sNx+OLx
#ifdef SEAICE_CGRID
          seaiceMaskU(i,j,bi,bj)=   0.0 _d 0
          seaiceMaskV(i,j,bi,bj)=   0.0 _d 0
          mask_uice=HEFFM(i,j,bi,bj)+HEFFM(i-1,j  ,bi,bj)
          IF(mask_uice.GT.1.5 _d 0) seaiceMaskU(i,j,bi,bj)=1.0 _d 0
          mask_uice=HEFFM(i,j,bi,bj)+HEFFM(i  ,j-1,bi,bj)
          IF(mask_uice.GT.1.5 _d 0) seaiceMaskV(i,j,bi,bj)=1.0 _d 0
#else
          UVM(i,j,bi,bj)=   0.0 _d 0
#endif /* SEAICE_CGRID */
         ENDDO
        ENDDO
       ENDDO
      ENDDO

      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
#ifdef ALLOW_OBCS
        IF (useOBCS) THEN
C--   If OBCS is turned on, close southern and western boundaries
#ifdef ALLOW_OBCS_SOUTH
         DO i=1-Olx,sNx+Olx
C Southern boundary
          J_obc = OB_Js(i,bi,bj)
          IF (J_obc.NE.0) THEN
#ifdef SEAICE_CGRID
           seaiceMaskU(i,J_obc,bi,bj)=   0.0 _d 0
           seaiceMaskV(i,J_obc,bi,bj)=   0.0 _d 0
#else
           UVM(i,J_obc,bi,bj)=0. _d 0
#endif /* SEAICE_CGRID */
          ENDIF
         ENDDO
#endif /* ALLOW_OBCS_SOUTH */
#ifdef ALLOW_OBCS_WEST
         DO j=1-Oly,sNy+Oly
C Western boundary
          I_obc=OB_Iw(j,bi,bj)
          IF (I_obc.NE.0) THEN
#ifdef SEAICE_CGRID
           seaiceMaskU(I_obc,j,bi,bj)=   0.0 _d 0
           seaiceMaskV(I_obc,j,bi,bj)=   0.0 _d 0
#else
           UVM(I_obc,j,bi,bj)=0. _d 0
#endif /* SEAICE_CGRID */
          ENDIF
         ENDDO
#endif /* ALLOW_OBCS_WEST */
        ENDIF
#endif /* ALLOW_OBCS */

#ifdef ALLOW_EXCH2
#ifndef SEAICE_CGRID
C--   Special stuff for cubed sphere: assume grid is rectangular and
C     set UV mask to zero except for Arctic and Antarctic cube faces.
        IF (useCubedSphereExchange) THEN
         myTile = W2_myTileList(bi,bj)
         IF ( exch2_myFace(myTile) .EQ. 1 .OR.
     &        exch2_myFace(myTile) .EQ. 2 .OR.
     &        exch2_myFace(myTile) .EQ. 4 .OR.
     &        exch2_myFace(myTile) .EQ. 5 ) THEN
          DO j=1-OLy,sNy+OLy
           DO i=1-OLx,sNx+OLx
            UVM(i,j,bi,bj)=0. _d 0
           ENDDO
          ENDDO
         ELSEIF ( exch2_isWedge(myTile) .EQ. 1 ) THEN
          i=1
          DO j=1-OLy,sNy+OLy
           UVM(i,j,bi,bj)=0. _d 0
          ENDDO
         ELSEIF ( exch2_isSedge(myTile) .EQ. 1 ) THEN
          j=1
          DO i=1-OLx,sNx+OLx
           UVM(i,j,bi,bj)=0. _d 0
          ENDDO
         ENDIF
        ENDIF
#endif /* SEAICE_CGRID */
#endif /* ALLOW_EXCH2 */

        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          TICE(i,j,bi,bj)=273.0 _d 0
#ifdef SEAICE_MULTICATEGORY
          DO k=1,MULTDIM
           TICES(i,j,k,bi,bj)=273.0 _d 0
          ENDDO
#endif /* SEAICE_MULTICATEGORY */
#ifndef SEAICE_CGRID
          AMASS      (i,j,bi,bj)=1000.0 _d 0
#else
          seaiceMassC(i,j,bi,bj)=1000.0 _d 0
          seaiceMassU(i,j,bi,bj)=1000.0 _d 0
          seaiceMassV(i,j,bi,bj)=1000.0 _d 0
#endif
         ENDDO
        ENDDO

       ENDDO
      ENDDO

C--   Update overlap regions
#ifdef SEAICE_CGRID
      CALL EXCH_UV_XY_RL(seaiceMaskU,seaiceMaskV,.FALSE.,myThid)
#else
      _EXCH_XY_RL(UVM, myThid)
#endif

C--   Now lets look at all these beasts
      IF ( debugLevel .GE. debLevB ) THEN
         myIter=0
         CALL PLOT_FIELD_XYRL( HEFFM   , 'Current HEFFM   ' ,
     &        myIter, myThid )
#ifdef SEAICE_CGRID
         CALL PLOT_FIELD_XYRL( seaiceMaskU, 'Current seaiceMaskU',
     &        myIter, myThid )
         CALL PLOT_FIELD_XYRL( seaiceMaskV, 'Current seaiceMaskV',
     &        myIter, myThid )
#else
         CALL PLOT_FIELD_XYRL( UVM     , 'Current UVM     ' ,
     &        myIter, myThid )
#endif
      ENDIF

C--   Set model variables to initial/restart conditions
      IF ( .NOT. ( startTime .EQ. baseTime .AND.  nIter0 .EQ. 0
     &     .AND. pickupSuff .EQ. ' ') ) THEN

         CALL SEAICE_READ_PICKUP ( myThid )

      ELSE

       DO bj=myByLo(myThid),myByHi(myThid)
        DO bi=myBxLo(myThid),myBxHi(myThid)
         DO j=1-OLy,sNy+OLy
          DO i=1-OLx,sNx+OLx
           TMIX(i,j,bi,bj)=TICE(i,j,bi,bj)
           HEFF(i,j,bi,bj)=SEAICE_initialHEFF*HEFFM(i,j,bi,bj)
           UICE(i,j,bi,bj)=ZERO
           VICE(i,j,bi,bj)=ZERO
          ENDDO
         ENDDO
        ENDDO
       ENDDO

C--   Read initial sea-ice thickness from file if available.
       IF ( HeffFile .NE. ' ' ) THEN
        CALL READ_FLD_XY_RL( HeffFile, ' ', HEFF, 0, myThid )
        _EXCH_XY_RL(HEFF,myThid)
        DO bj=myByLo(myThid),myByHi(myThid)
         DO bi=myBxLo(myThid),myBxHi(myThid)
          DO j=1-OLy,sNy+OLy
           DO i=1-OLx,sNx+OLx
            HEFF(i,j,bi,bj) = MAX(HEFF(i,j,bi,bj),ZERO)
           ENDDO
          ENDDO
         ENDDO
        ENDDO
       ENDIF

       DO bj=myByLo(myThid),myByHi(myThid)
        DO bi=myBxLo(myThid),myBxHi(myThid)
         DO j=1-OLy,sNy+OLy
          DO i=1-OLx,sNx+OLx
           IF(HEFF(i,j,bi,bj).GT.ZERO) AREA(i,j,bi,bj)=ONE
          ENDDO
         ENDDO
        ENDDO
       ENDDO

C--   Read initial sea-ice area from file if available.
       IF ( AreaFile .NE. ' ' ) THEN
        CALL READ_FLD_XY_RL( AreaFile, ' ', AREA, 0, myThid )
        _EXCH_XY_RL(AREA,myThid)
        DO bj=myByLo(myThid),myByHi(myThid)
         DO bi=myBxLo(myThid),myBxHi(myThid)
          DO j=1-OLy,sNy+OLy
           DO i=1-OLx,sNx+OLx
            AREA(i,j,bi,bj) = MAX(AREA(i,j,bi,bj),ZERO)
            AREA(i,j,bi,bj) = MIN(AREA(i,j,bi,bj),ONE)
            IF ( AREA(i,j,bi,bj) .LE. ZERO ) HEFF(i,j,bi,bj) = ZERO
            IF ( HEFF(i,j,bi,bj) .LE. ZERO ) AREA(i,j,bi,bj) = ZERO
           ENDDO
          ENDDO
         ENDDO
        ENDDO
       ENDIF

       DO bj=myByLo(myThid),myByHi(myThid)
        DO bi=myBxLo(myThid),myBxHi(myThid)
         DO j=1-OLy,sNy+OLy
          DO i=1-OLx,sNx+OLx
           HSNOW(i,j,bi,bj) = 0.2 _d 0 * AREA(i,j,bi,bj)
          ENDDO
         ENDDO
        ENDDO
       ENDDO

C--   Read initial snow thickness from file if available.
       IF ( HsnowFile .NE. ' ' ) THEN
        CALL READ_FLD_XY_RL( HsnowFile, ' ', HSNOW, 0, myThid )
        _EXCH_XY_RL(HSNOW,myThid)
        DO bj=myByLo(myThid),myByHi(myThid)
         DO bi=myBxLo(myThid),myBxHi(myThid)
          DO j=1-OLy,sNy+OLy
           DO i=1-OLx,sNx+OLx
            HSNOW(i,j,bi,bj) = MAX(HSNOW(i,j,bi,bj),ZERO)
           ENDDO
          ENDDO
         ENDDO
        ENDDO
       ENDIF

#ifdef SEAICE_SALINITY
       DO bj=myByLo(myThid),myByHi(myThid)
        DO bi=myBxLo(myThid),myBxHi(myThid)
         DO j=1-OLy,sNy+OLy
          DO i=1-OLx,sNx+OLx
           HSALT(i,j,bi,bj)=HEFF(i,j,bi,bj)*salt(i,j,kSurface,bi,bj)*
     &            ICE2WATR*rhoConstFresh*SEAICE_salinity
          ENDDO
         ENDDO
        ENDDO
       ENDDO

C--   Read initial sea ice salinity from file if available.
       IF ( HsaltFile .NE. ' ' ) THEN
        CALL READ_FLD_XY_RL( HsaltFile, ' ', HSALT, 0, myThid )
        _EXCH_XY_RL(HSALT,myThid)
       ENDIF
#endif /* SEAICE_SALINITY */

#ifdef SEAICE_AGE
C--   Read initial sea ice age from file if available.
       IF ( IceAgeFile .NE. ' ' ) THEN
        CALL READ_FLD_XY_RL( IceAgeFile, ' ', ICEAGE, 0, myThid )
        _EXCH_XY_RL(ICEAGE,myThid)
       ENDIF
#endif /* SEAICE_AGE */

      ENDIF

C--   In case we use scheme with a large stencil that extends into overlap:
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
           CALL OBCS_COPY_TRACER( ICEAGE(1-Olx,1-Oly,bi,bj),
     I                            1, bi, bj, myThid )
#endif
         ENDDO
        ENDDO
      ENDIF
#endif /* ALLOW_OBCS */

C---  Complete initialization
      PSTAR = SEAICE_strength
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          ZETA(i,j,bi,bj)   = HEFF(i,j,bi,bj)*(1.0 _d 11)
          ETA(i,j,bi,bj)    = ZETA(i,j,bi,bj)/SEAICE_eccen**2
          PRESS0(i,j,bi,bj) = PSTAR*HEFF(i,j,bi,bj)
     &         *EXP(-20.0 _d 0*(ONE-AREA(i,j,bi,bj)))
          ZMAX(I,J,bi,bj)   = SEAICE_zetaMaxFac*PRESS0(I,J,bi,bj)
          ZMIN(i,j,bi,bj)   = SEAICE_zetaMin
          PRESS0(i,j,bi,bj) = PRESS0(i,j,bi,bj)*HEFFM(i,j,bi,bj)
         ENDDO
        ENDDO
        IF ( useRealFreshWaterFlux .AND. .NOT.useThSIce ) THEN
         DO j=1-OLy,sNy+OLy
          DO i=1-OLx,sNx+OLx
           sIceLoad(i,j,bi,bj) = HEFF(i,j,bi,bj)*SEAICE_rhoIce
     &                         + HSNOW(i,j,bi,bj)*SEAICE_rhoSnow

          ENDDO
         ENDDO
        ENDIF
       ENDDO
      ENDDO

      RETURN
      END
