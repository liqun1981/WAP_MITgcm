C $Header: /u/gcmpack/MITgcm/pkg/generic_advdiff/gad_advection.F,v 1.63 2010/10/31 15:20:48 jmc Exp $
C $Name: checkpoint62r $

#include "GAD_OPTIONS.h"
#undef OBCS_MULTIDIM_OLD_VERSION

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: GAD_ADVECTION

C !INTERFACE: ==========================================================
      SUBROUTINE GAD_ADVECTION(
     I     implicitAdvection, advectionScheme, vertAdvecScheme,
     I     tracerIdentity, deltaTLev,
     I     uVel, vVel, wVel, tracer,
     O     gTracer,
     I     bi,bj, myTime,myIter,myThid)

C !DESCRIPTION:
C Calculates the tendency of a tracer due to advection.
C It uses the multi-dimensional method given in \ref{sect:multiDimAdvection}
C and can only be used for the non-linear advection schemes such as the
C direct-space-time method and flux-limiters.
C
C The algorithm is as follows:
C \begin{itemize}
C \item{$\theta^{(n+1/3)} = \theta^{(n)}
C      - \Delta t \partial_x (u\theta^{(n)}) + \theta^{(n)} \partial_x u$}
C \item{$\theta^{(n+2/3)} = \theta^{(n+1/3)}
C      - \Delta t \partial_y (v\theta^{(n+1/3)}) + \theta^{(n)} \partial_y v$}
C \item{$\theta^{(n+3/3)} = \theta^{(n+2/3)}
C      - \Delta t \partial_r (w\theta^{(n+2/3)}) + \theta^{(n)} \partial_r w$}
C \item{$G_\theta = ( \theta^{(n+3/3)} - \theta^{(n)} )/\Delta t$}
C \end{itemize}
C
C The tendency (output) is over-written by this routine.

C !USES: ===============================================================
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "GRID.h"
#include "GAD.h"
#ifdef ALLOW_AUTODIFF_TAMC
# include "tamc.h"
# include "tamc_keys.h"
# ifdef ALLOW_PTRACERS
#  include "PTRACERS_SIZE.h"
# endif
#endif
#ifdef ALLOW_EXCH2
#include "W2_EXCH2_SIZE.h"
#include "W2_EXCH2_TOPOLOGY.h"
#endif /* ALLOW_EXCH2 */

C !INPUT PARAMETERS: ===================================================
C  implicitAdvection :: implicit vertical advection (later on)
C  advectionScheme   :: advection scheme to use (Horizontal plane)
C  vertAdvecScheme   :: advection scheme to use (vertical direction)
C  tracerIdentity    :: tracer identifier (required only for OBCS)
C  uVel              :: velocity, zonal component
C  vVel              :: velocity, meridional component
C  wVel              :: velocity, vertical component
C  tracer            :: tracer field
C  bi,bj             :: tile indices
C  myTime            :: current time
C  myIter            :: iteration number
C  myThid            :: thread number
      LOGICAL implicitAdvection
      INTEGER advectionScheme, vertAdvecScheme
      INTEGER tracerIdentity
      _RL deltaTLev(Nr)
      _RL uVel  (1-Olx:sNx+Olx,1-Oly:sNy+Oly,Nr,nSx,nSy)
      _RL vVel  (1-Olx:sNx+Olx,1-Oly:sNy+Oly,Nr,nSx,nSy)
      _RL wVel  (1-Olx:sNx+Olx,1-Oly:sNy+Oly,Nr,nSx,nSy)
      _RL tracer(1-Olx:sNx+Olx,1-Oly:sNy+Oly,Nr,nSx,nSy)
      INTEGER bi,bj
      _RL myTime
      INTEGER myIter
      INTEGER myThid

C !OUTPUT PARAMETERS: ==================================================
C  gTracer           :: tendency array
      _RL gTracer(1-Olx:sNx+Olx,1-Oly:sNy+Oly,Nr,nSx,nSy)

C !LOCAL VARIABLES: ====================================================
C  maskUp        :: 2-D array for mask at W points
C  maskLocW      :: 2-D array for mask at West points
C  maskLocS      :: 2-D array for mask at South points
C [iMin,iMax]Upd :: loop range to update tracer field
C [jMin,jMax]Upd :: loop range to update tracer field
C  i,j,k         :: loop indices
C  kUp           :: index into 2 1/2D array, toggles between 1 and 2
C  kDown         :: index into 2 1/2D array, toggles between 2 and 1
C  kp1           :: =k+1 for k<Nr, =Nr for k=Nr
C  xA,yA         :: areas of X and Y face of tracer cells
C  uFld,vFld     :: 2-D local copy of horizontal velocity, U,V components
C  wFld          :: 2-D local copy of vertical velocity
C  uTrans,vTrans :: 2-D arrays of volume transports at U,V points
C  rTrans        :: 2-D arrays of volume transports at W points
C  rTransKp1     :: vertical volume transport at interface k+1
C  af            :: 2-D array for horizontal advective flux
C  afx           :: 2-D array for horizontal advective flux, x direction
C  afy           :: 2-D array for horizontal advective flux, y direction
C  fVerT         :: 2 1/2D arrays for vertical advective flux
C  localTij      :: 2-D array, temporary local copy of tracer fld
C  localTijk     :: 3-D array, temporary local copy of tracer fld
C  kp1Msk        :: flag (0,1) for over-riding mask for W levels
C  calc_fluxes_X :: logical to indicate to calculate fluxes in X dir
C  calc_fluxes_Y :: logical to indicate to calculate fluxes in Y dir
C  interiorOnly  :: only update the interior of myTile, but not the edges
C  overlapOnly   :: only update the edges of myTile, but not the interior
C  npass         :: number of passes in multi-dimensional method
C  ipass         :: number of the current pass being made
C  myTile        :: variables used to determine which cube face
C  nCFace        :: owns a tile for cube grid runs using
C                :: multi-dim advection.
C [N,S,E,W]_edge :: true if N,S,E,W edge of myTile is an Edge of the cube
c     _RS maskUp  (1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RS maskLocW(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RS maskLocS(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      INTEGER iMinUpd,iMaxUpd,jMinUpd,jMaxUpd
      INTEGER i,j,k,kUp,kDown
      _RS xA      (1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RS yA      (1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL uFld    (1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL vFld    (1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL wFld    (1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL uTrans  (1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL vTrans  (1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL rTrans  (1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL rTransKp1(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL af      (1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL afx     (1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL afy     (1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL fVerT   (1-OLx:sNx+OLx,1-OLy:sNy+OLy,2)
      _RL localTij(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL localTijk(1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr)
      _RL kp1Msk
      LOGICAL calc_fluxes_X, calc_fluxes_Y, withSigns
      LOGICAL interiorOnly, overlapOnly
      INTEGER npass, ipass
      INTEGER nCFace
      LOGICAL N_edge, S_edge, E_edge, W_edge
#ifdef ALLOW_EXCH2
      INTEGER myTile
#endif
#ifdef ALLOW_DIAGNOSTICS
      CHARACTER*8 diagName
      CHARACTER*4 diagSufx
      LOGICAL     doDiagAdvX, doDiagAdvY, doDiagAdvR
C-    Functions:
      CHARACTER*4 GAD_DIAG_SUFX
      EXTERNAL    GAD_DIAG_SUFX
      LOGICAL  DIAGNOSTICS_IS_ON
      EXTERNAL DIAGNOSTICS_IS_ON
#endif
CEOP

#ifdef ALLOW_AUTODIFF_TAMC
          act0 = tracerIdentity
          max0 = maxpass
          act1 = bi - myBxLo(myThid)
          max1 = myBxHi(myThid) - myBxLo(myThid) + 1
          act2 = bj - myByLo(myThid)
          max2 = myByHi(myThid) - myByLo(myThid) + 1
          act3 = myThid - 1
          max3 = nTx*nTy
          act4 = ikey_dynamics - 1
          igadkey = act0
     &                      + act1*max0
     &                      + act2*max0*max1
     &                      + act3*max0*max1*max2
     &                      + act4*max0*max1*max2*max3
          IF (tracerIdentity.GT.maxpass) THEN
             print *, 'ph-pass gad_advection ', maxpass, tracerIdentity
             STOP 'maxpass seems smaller than tracerIdentity'
          ENDIF
#endif /* ALLOW_AUTODIFF_TAMC */

#ifdef ALLOW_DIAGNOSTICS
C--   Set diagnostics flags and suffix for the current tracer
      doDiagAdvX = .FALSE.
      doDiagAdvY = .FALSE.
      doDiagAdvR = .FALSE.
      IF ( useDiagnostics ) THEN
        diagSufx = GAD_DIAG_SUFX( tracerIdentity, myThid )
        diagName = 'ADVx'//diagSufx
        doDiagAdvX = DIAGNOSTICS_IS_ON( diagName, myThid )
        diagName = 'ADVy'//diagSufx
        doDiagAdvY = DIAGNOSTICS_IS_ON( diagName, myThid )
        diagName = 'ADVr'//diagSufx
        doDiagAdvR = DIAGNOSTICS_IS_ON( diagName, myThid )
      ENDIF
#endif

C--   Set up work arrays with valid (i.e. not NaN) values
C     These inital values do not alter the numerical results. They
C     just ensure that all memory references are to valid floating
C     point numbers. This prevents spurious hardware signals due to
C     uninitialised but inert locations.
      DO j=1-OLy,sNy+OLy
       DO i=1-OLx,sNx+OLx
        xA(i,j)      = 0. _d 0
        yA(i,j)      = 0. _d 0
        uTrans(i,j)  = 0. _d 0
        vTrans(i,j)  = 0. _d 0
        rTrans(i,j)  = 0. _d 0
        fVerT(i,j,1) = 0. _d 0
        fVerT(i,j,2) = 0. _d 0
        rTransKp1(i,j)= 0. _d 0
#ifdef ALLOW_AUTODIFF_TAMC
        localTij(i,j) = 0. _d 0
        wfld(i,j)    = 0. _d 0
#endif
       ENDDO
      ENDDO

C--   Set tile-specific parameters for horizontal fluxes
      IF (useCubedSphereExchange) THEN
       npass  = 3
#ifdef ALLOW_AUTODIFF_TAMC
       IF ( npass.GT.maxcube ) STOP 'maxcube needs to be = 3'
#endif
#ifdef ALLOW_EXCH2
       myTile = W2_myTileList(bi,bj)
       nCFace = exch2_myFace(myTile)
       N_edge = exch2_isNedge(myTile).EQ.1
       S_edge = exch2_isSedge(myTile).EQ.1
       E_edge = exch2_isEedge(myTile).EQ.1
       W_edge = exch2_isWedge(myTile).EQ.1
#else
       nCFace = bi
       N_edge = .TRUE.
       S_edge = .TRUE.
       E_edge = .TRUE.
       W_edge = .TRUE.
#endif
      ELSE
       npass  = 2
       nCFace = 0
       N_edge = .FALSE.
       S_edge = .FALSE.
       E_edge = .FALSE.
       W_edge = .FALSE.
      ENDIF

C--   Start of k loop for horizontal fluxes
      DO k=1,Nr
#ifdef ALLOW_AUTODIFF_TAMC
         kkey = (igadkey-1)*Nr + k
CADJ STORE tracer(:,:,k,bi,bj) =
CADJ &     comlev1_bibj_k_gad, key=kkey, kind=isbyte
#endif /* ALLOW_AUTODIFF_TAMC */

C--   Get temporary terms used by tendency routines
      CALL CALC_COMMON_FACTORS (
     I         uVel, vVel,
     O         uFld, vFld, uTrans, vTrans, xA, yA,
     I         k,bi,bj, myThid )

#ifdef ALLOW_GMREDI
C--   Residual transp = Bolus transp + Eulerian transp
      IF (useGMRedi)
     &   CALL GMREDI_CALC_UVFLOW(
     U                  uFld, vFld, uTrans, vTrans,
     I                  k, bi, bj, myThid )
#endif /* ALLOW_GMREDI */

C--   Make local copy of tracer array and mask West & South
      DO j=1-OLy,sNy+OLy
       DO i=1-OLx,sNx+OLx
         localTij(i,j)=tracer(i,j,k,bi,bj)
         maskLocW(i,j)=_maskW(i,j,k,bi,bj)
         maskLocS(i,j)=_maskS(i,j,k,bi,bj)
       ENDDO
      ENDDO

cph-exch2#ifndef ALLOW_AUTODIFF_TAMC
      IF (useCubedSphereExchange) THEN
        withSigns = .FALSE.
        CALL FILL_CS_CORNER_UV_RS(
     &            withSigns, maskLocW,maskLocS, bi,bj, myThid )
      ENDIF
cph-exch2#endif

C--   Multiple passes for different directions on different tiles
C--   For cube need one pass for each of red, green and blue axes.
      DO ipass=1,npass
#ifdef ALLOW_AUTODIFF_TAMC
         passkey = ipass
     &                   + (k-1)      *maxpass
     &                   + (igadkey-1)*maxpass*Nr
         IF (npass .GT. maxpass) THEN
          STOP 'GAD_ADVECTION: npass > maxcube. check tamc.h'
         ENDIF
#endif /* ALLOW_AUTODIFF_TAMC */

      interiorOnly = .FALSE.
      overlapOnly  = .FALSE.
      IF (useCubedSphereExchange) THEN
C-    CubedSphere : pass 3 times, with partial update of local tracer field
       IF (ipass.EQ.1) THEN
        overlapOnly  = MOD(nCFace,3).EQ.0
        interiorOnly = MOD(nCFace,3).NE.0
        calc_fluxes_X = nCFace.EQ.6 .OR. nCFace.EQ.1 .OR. nCFace.EQ.2
        calc_fluxes_Y = nCFace.EQ.3 .OR. nCFace.EQ.4 .OR. nCFace.EQ.5
       ELSEIF (ipass.EQ.2) THEN
        overlapOnly  = MOD(nCFace,3).EQ.2
        interiorOnly = MOD(nCFace,3).EQ.1
        calc_fluxes_X = nCFace.EQ.2 .OR. nCFace.EQ.3 .OR. nCFace.EQ.4
        calc_fluxes_Y = nCFace.EQ.5 .OR. nCFace.EQ.6 .OR. nCFace.EQ.1
       ELSE
        interiorOnly = .TRUE.
        calc_fluxes_X = nCFace.EQ.5 .OR. nCFace.EQ.6
        calc_fluxes_Y = nCFace.EQ.2 .OR. nCFace.EQ.3
       ENDIF
      ELSE
C-    not CubedSphere
        calc_fluxes_X = MOD(ipass,2).EQ.1
        calc_fluxes_Y = .NOT.calc_fluxes_X
      ENDIF

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
C--   X direction
C-     Advective flux in X
        DO j=1-Oly,sNy+Oly
         DO i=1-Olx,sNx+Olx
          af(i,j) = 0.
         ENDDO
        ENDDO
C
#ifdef ALLOW_AUTODIFF_TAMC
# ifndef DISABLE_MULTIDIM_ADVECTION
CADJ STORE localTij(:,:)  =
CADJ &     comlev1_bibj_k_gad_pass, key=passkey, kind=isbyte
CADJ STORE af(:,:)  =
CADJ &     comlev1_bibj_k_gad_pass, key=passkey, kind=isbyte
# endif
#endif /* ALLOW_AUTODIFF_TAMC */
C
      IF (calc_fluxes_X) THEN

C-     Do not compute fluxes if
C       a) needed in overlap only
C   and b) the overlap of myTile are not cube-face Edges
       IF ( .NOT.overlapOnly .OR. N_edge .OR. S_edge ) THEN

C-     Internal exchange for calculations in X
        IF ( overlapOnly ) THEN
         CALL FILL_CS_CORNER_TR_RL( 1, .FALSE.,
     &                              localTij, bi,bj, myThid )
        ENDIF

#ifdef ALLOW_AUTODIFF_TAMC
# ifndef DISABLE_MULTIDIM_ADVECTION
CADJ STORE localTij(:,:)  =
CADJ &     comlev1_bibj_k_gad_pass, key=passkey, kind=isbyte
# endif
#endif /* ALLOW_AUTODIFF_TAMC */

        IF ( advectionScheme.EQ.ENUM_UPWIND_1RST
     &     .OR. advectionScheme.EQ.ENUM_DST2 ) THEN
          CALL GAD_DST2U1_ADV_X( bi,bj,k, advectionScheme, .TRUE.,
     I                           deltaTLev(k),uTrans,uFld,localTij,
     O                           af, myThid )
        ELSEIF (advectionScheme.EQ.ENUM_FLUX_LIMIT) THEN
          CALL GAD_FLUXLIMIT_ADV_X( bi,bj,k, .TRUE., deltaTLev(k),
     I                              uTrans, uFld, maskLocW, localTij,
     O                              af, myThid )
        ELSEIF (advectionScheme.EQ.ENUM_DST3 ) THEN
          CALL GAD_DST3_ADV_X(      bi,bj,k, .TRUE., deltaTLev(k),
     I                              uTrans, uFld, maskLocW, localTij,
     O                              af, myThid )
        ELSEIF (advectionScheme.EQ.ENUM_DST3_FLUX_LIMIT ) THEN
          CALL GAD_DST3FL_ADV_X(    bi,bj,k, .TRUE., deltaTLev(k),
     I                              uTrans, uFld, maskLocW, localTij,
     O                              af, myThid )
#ifndef ALLOW_AUTODIFF_TAMC
        ELSEIF (advectionScheme.EQ.ENUM_OS7MP ) THEN
          CALL GAD_OS7MP_ADV_X(     bi,bj,k, .TRUE., deltaTLev(k),
     I                              uTrans, uFld, maskLocW, localTij,
     O                              af, myThid )
#endif
        ELSE
         STOP 'GAD_ADVECTION: adv. scheme incompatibale with multi-dim'
        ENDIF

C-     Internal exchange for next calculations in Y
        IF ( overlapOnly .AND. ipass.EQ.1 ) THEN
         CALL FILL_CS_CORNER_TR_RL( 2, .FALSE.,
     &                              localTij, bi,bj, myThid )
        ENDIF

C-     Advective flux in X : done
       ENDIF

C-     Update the local tracer field where needed:
C      use "maksInC" to prevent updating tracer field in OB regions

C      update in overlap-Only
       IF ( overlapOnly ) THEN
        iMinUpd = 1-Olx+1
        iMaxUpd = sNx+Olx-1
C- notes: these 2 lines below have no real effect (because recip_hFac=0
C         in corner region) but safer to keep them.
        IF ( W_edge ) iMinUpd = 1
        IF ( E_edge ) iMaxUpd = sNx

        IF ( S_edge ) THEN
         DO j=1-Oly,0
          DO i=iMinUpd,iMaxUpd
           localTij(i,j) = localTij(i,j)
     &      -deltaTLev(k)*recip_rhoFacC(k)
     &       *_recip_hFacC(i,j,k,bi,bj)*recip_drF(k)
     &       *recip_rA(i,j,bi,bj)*recip_deepFac2C(k)
     &       *( af(i+1,j)-af(i,j)
     &         -tracer(i,j,k,bi,bj)*(uTrans(i+1,j)-uTrans(i,j))
     &        )*maskInC(i,j,bi,bj)
          ENDDO
         ENDDO
        ENDIF
        IF ( N_edge ) THEN
         DO j=sNy+1,sNy+Oly
          DO i=iMinUpd,iMaxUpd
           localTij(i,j) = localTij(i,j)
     &      -deltaTLev(k)*recip_rhoFacC(k)
     &       *_recip_hFacC(i,j,k,bi,bj)*recip_drF(k)
     &       *recip_rA(i,j,bi,bj)*recip_deepFac2C(k)
     &       *( af(i+1,j)-af(i,j)
     &         -tracer(i,j,k,bi,bj)*(uTrans(i+1,j)-uTrans(i,j))
     &        )*maskInC(i,j,bi,bj)
          ENDDO
         ENDDO
        ENDIF

       ELSE
C      do not only update the overlap
        jMinUpd = 1-Oly
        jMaxUpd = sNy+Oly
        IF ( interiorOnly .AND. S_edge ) jMinUpd = 1
        IF ( interiorOnly .AND. N_edge ) jMaxUpd = sNy
        DO j=jMinUpd,jMaxUpd
         DO i=1-Olx+1,sNx+Olx-1
           localTij(i,j) = localTij(i,j)
     &      -deltaTLev(k)*recip_rhoFacC(k)
     &       *_recip_hFacC(i,j,k,bi,bj)*recip_drF(k)
     &       *recip_rA(i,j,bi,bj)*recip_deepFac2C(k)
     &       *( af(i+1,j)-af(i,j)
     &         -tracer(i,j,k,bi,bj)*(uTrans(i+1,j)-uTrans(i,j))
     &        )*maskInC(i,j,bi,bj)
         ENDDO
        ENDDO
C-      keep advective flux (for diagnostics)
        DO j=1-Oly,sNy+Oly
         DO i=1-Olx,sNx+Olx
          afx(i,j) = af(i,j)
         ENDDO
        ENDDO

#ifdef ALLOW_OBCS
#ifdef OBCS_MULTIDIM_OLD_VERSION
C-     Apply open boundary conditions
        IF ( useOBCS ) THEN
         IF (tracerIdentity.EQ.GAD_TEMPERATURE) THEN
          CALL OBCS_APPLY_TLOC( bi, bj, k, localTij, myThid )
         ELSEIF (tracerIdentity.EQ.GAD_SALINITY) THEN
          CALL OBCS_APPLY_SLOC( bi, bj, k, localTij, myThid )
#ifdef ALLOW_PTRACERS
         ELSEIF (tracerIdentity.GE.GAD_TR1) THEN
          CALL OBCS_APPLY_PTRACER( bi, bj, k,
     &         tracerIdentity-GAD_TR1+1, localTij, myThid )
#endif /* ALLOW_PTRACERS */
         ENDIF
        ENDIF
#endif /* OBCS_MULTIDIM_OLD_VERSION */
#endif /* ALLOW_OBCS */

C-     end if/else update overlap-Only
       ENDIF

C--   End of X direction
      ENDIF

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
C--   Y direction
cph-test
C-     Advective flux in Y
        DO j=1-Oly,sNy+Oly
         DO i=1-Olx,sNx+Olx
          af(i,j) = 0.
         ENDDO
        ENDDO
C
#ifdef ALLOW_AUTODIFF_TAMC
# ifndef DISABLE_MULTIDIM_ADVECTION
CADJ STORE localTij(:,:)  =
CADJ &     comlev1_bibj_k_gad_pass, key=passkey, kind=isbyte
CADJ STORE af(:,:)  =
CADJ &     comlev1_bibj_k_gad_pass, key=passkey, kind=isbyte
# endif
#endif /* ALLOW_AUTODIFF_TAMC */
C
      IF (calc_fluxes_Y) THEN

C-     Do not compute fluxes if
C       a) needed in overlap only
C   and b) the overlap of myTile are not cube-face edges
       IF ( .NOT.overlapOnly .OR. E_edge .OR. W_edge ) THEN

C-     Internal exchange for calculations in Y
        IF ( overlapOnly ) THEN
         CALL FILL_CS_CORNER_TR_RL( 2, .FALSE.,
     &                              localTij, bi,bj, myThid )
        ENDIF

C-     Advective flux in Y
        DO j=1-Oly,sNy+Oly
         DO i=1-Olx,sNx+Olx
          af(i,j) = 0.
         ENDDO
        ENDDO

#ifdef ALLOW_AUTODIFF_TAMC
#ifndef DISABLE_MULTIDIM_ADVECTION
CADJ STORE localTij(:,:)  =
CADJ &     comlev1_bibj_k_gad_pass, key=passkey, kind=isbyte
#endif
#endif /* ALLOW_AUTODIFF_TAMC */

        IF ( advectionScheme.EQ.ENUM_UPWIND_1RST
     &     .OR. advectionScheme.EQ.ENUM_DST2 ) THEN
          CALL GAD_DST2U1_ADV_Y( bi,bj,k, advectionScheme, .TRUE.,
     I                           deltaTLev(k),vTrans,vFld,localTij,
     O                           af, myThid )
        ELSEIF (advectionScheme.EQ.ENUM_FLUX_LIMIT) THEN
          CALL GAD_FLUXLIMIT_ADV_Y( bi,bj,k, .TRUE., deltaTLev(k),
     I                              vTrans, vFld, maskLocS, localTij,
     O                              af, myThid )
        ELSEIF (advectionScheme.EQ.ENUM_DST3 ) THEN
          CALL GAD_DST3_ADV_Y(      bi,bj,k, .TRUE., deltaTLev(k),
     I                              vTrans, vFld, maskLocS, localTij,
     O                              af, myThid )
        ELSEIF (advectionScheme.EQ.ENUM_DST3_FLUX_LIMIT ) THEN
          CALL GAD_DST3FL_ADV_Y(    bi,bj,k, .TRUE., deltaTLev(k),
     I                              vTrans, vFld, maskLocS, localTij,
     O                              af, myThid )
#ifndef ALLOW_AUTODIFF_TAMC
        ELSEIF (advectionScheme.EQ.ENUM_OS7MP ) THEN
          CALL GAD_OS7MP_ADV_Y(     bi,bj,k, .TRUE., deltaTLev(k),
     I                              vTrans, vFld, maskLocS, localTij,
     O                              af, myThid )
#endif
        ELSE
         STOP 'GAD_ADVECTION: adv. scheme incompatibale with mutli-dim'
        ENDIF

C-     Internal exchange for next calculations in X
        IF ( overlapOnly .AND. ipass.EQ.1 ) THEN
         CALL FILL_CS_CORNER_TR_RL( 1, .FALSE.,
     &                              localTij, bi,bj, myThid )
        ENDIF

C-     Advective flux in Y : done
       ENDIF

C-     Update the local tracer field where needed:
C      use "maksInC" to prevent updating tracer field in OB regions

C      update in overlap-Only
       IF ( overlapOnly ) THEN
        jMinUpd = 1-Oly+1
        jMaxUpd = sNy+Oly-1
C- notes: these 2 lines below have no real effect (because recip_hFac=0
C         in corner region) but safer to keep them.
        IF ( S_edge ) jMinUpd = 1
        IF ( N_edge ) jMaxUpd = sNy

        IF ( W_edge ) THEN
         DO j=jMinUpd,jMaxUpd
          DO i=1-Olx,0
           localTij(i,j) = localTij(i,j)
     &      -deltaTLev(k)*recip_rhoFacC(k)
     &       *_recip_hFacC(i,j,k,bi,bj)*recip_drF(k)
     &       *recip_rA(i,j,bi,bj)*recip_deepFac2C(k)
     &       *( af(i,j+1)-af(i,j)
     &         -tracer(i,j,k,bi,bj)*(vTrans(i,j+1)-vTrans(i,j))
     &        )*maskInC(i,j,bi,bj)
          ENDDO
         ENDDO
        ENDIF
        IF ( E_edge ) THEN
         DO j=jMinUpd,jMaxUpd
          DO i=sNx+1,sNx+Olx
           localTij(i,j) = localTij(i,j)
     &      -deltaTLev(k)*recip_rhoFacC(k)
     &       *_recip_hFacC(i,j,k,bi,bj)*recip_drF(k)
     &       *recip_rA(i,j,bi,bj)*recip_deepFac2C(k)
     &       *( af(i,j+1)-af(i,j)
     &         -tracer(i,j,k,bi,bj)*(vTrans(i,j+1)-vTrans(i,j))
     &        )*maskInC(i,j,bi,bj)
          ENDDO
         ENDDO
        ENDIF

       ELSE
C      do not only update the overlap
        iMinUpd = 1-Olx
        iMaxUpd = sNx+Olx
        IF ( interiorOnly .AND. W_edge ) iMinUpd = 1
        IF ( interiorOnly .AND. E_edge ) iMaxUpd = sNx
        DO j=1-Oly+1,sNy+Oly-1
         DO i=iMinUpd,iMaxUpd
           localTij(i,j) = localTij(i,j)
     &      -deltaTLev(k)*recip_rhoFacC(k)
     &       *_recip_hFacC(i,j,k,bi,bj)*recip_drF(k)
     &       *recip_rA(i,j,bi,bj)*recip_deepFac2C(k)
     &       *( af(i,j+1)-af(i,j)
     &         -tracer(i,j,k,bi,bj)*(vTrans(i,j+1)-vTrans(i,j))
     &        )*maskInC(i,j,bi,bj)
         ENDDO
        ENDDO
C-      keep advective flux (for diagnostics)
        DO j=1-Oly,sNy+Oly
         DO i=1-Olx,sNx+Olx
          afy(i,j) = af(i,j)
         ENDDO
        ENDDO

#ifdef ALLOW_OBCS
#ifdef OBCS_MULTIDIM_OLD_VERSION
C-     Apply open boundary conditions
        IF (useOBCS) THEN
         IF (tracerIdentity.EQ.GAD_TEMPERATURE) THEN
          CALL OBCS_APPLY_TLOC( bi, bj, k, localTij, myThid )
         ELSEIF (tracerIdentity.EQ.GAD_SALINITY) THEN
          CALL OBCS_APPLY_SLOC( bi, bj, k, localTij, myThid )
#ifdef ALLOW_PTRACERS
         ELSEIF (tracerIdentity.GE.GAD_TR1) THEN
          CALL OBCS_APPLY_PTRACER( bi, bj, k,
     &         tracerIdentity-GAD_TR1+1, localTij, myThid )
#endif /* ALLOW_PTRACERS */
         ENDIF
        ENDIF
#endif /* OBCS_MULTIDIM_OLD_VERSION */
#endif /* ALLOW_OBCS */

C      end if/else update overlap-Only
       ENDIF

C--   End of Y direction
      ENDIF

C--   End of ipass loop
      ENDDO

      IF ( implicitAdvection ) THEN
C-    explicit advection is done ; store tendency in gTracer:
        DO j=1-Oly,sNy+Oly
         DO i=1-Olx,sNx+Olx
          gTracer(i,j,k,bi,bj)=
     &     (localTij(i,j)-tracer(i,j,k,bi,bj))/deltaTLev(k)
         ENDDO
        ENDDO
      ELSE
C-    horizontal advection done; store intermediate result in 3D array:
        DO j=1-Oly,sNy+Oly
         DO i=1-Olx,sNx+Olx
          localTijk(i,j,k)=localTij(i,j)
         ENDDO
        ENDDO
      ENDIF

#ifdef ALLOW_DIAGNOSTICS
        IF ( doDiagAdvX ) THEN
          diagName = 'ADVx'//diagSufx
          CALL DIAGNOSTICS_FILL(afx,diagName, k,1, 2,bi,bj, myThid)
        ENDIF
        IF ( doDiagAdvY ) THEN
          diagName = 'ADVy'//diagSufx
          CALL DIAGNOSTICS_FILL(afy,diagName, k,1, 2,bi,bj, myThid)
        ENDIF
#endif

#ifdef ALLOW_DEBUG
      IF ( debugLevel .GE. debLevB
     &   .AND. tracerIdentity.EQ.GAD_TEMPERATURE
     &   .AND. k.LE.3 .AND. myIter.EQ.1+nIter0
     &   .AND. nPx.EQ.1 .AND. nPy.EQ.1
     &   .AND. useCubedSphereExchange ) THEN
        CALL DEBUG_CS_CORNER_UV( ' afx,afy from GAD_ADVECTION',
     &             afx,afy, k, standardMessageUnit,bi,bj,myThid )
      ENDIF
#endif /* ALLOW_DEBUG */

C--   End of K loop for horizontal fluxes
      ENDDO

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|

      IF ( .NOT.implicitAdvection ) THEN
C--   Start of k loop for vertical flux
       DO k=Nr,1,-1
#ifdef ALLOW_AUTODIFF_TAMC
         kkey = (igadkey-1)*Nr + (Nr-k+1)
#endif /* ALLOW_AUTODIFF_TAMC */
C--   kUp    Cycles through 1,2 to point to w-layer above
C--   kDown  Cycles through 2,1 to point to w-layer below
        kUp  = 1+MOD(k+1,2)
        kDown= 1+MOD(k,2)
c       kp1=min(Nr,k+1)
        kp1Msk=1.
        if (k.EQ.Nr) kp1Msk=0.

#ifdef ALLOW_AUTODIFF_TAMC
CADJ STORE rtrans(:,:)  =
CADJ &     comlev1_bibj_k_gad, key=kkey, kind=isbyte
cphCADJ STORE wfld(:,:)  =
cphCADJ &     comlev1_bibj_k_gad, key=kkey, kind=isbyte
#endif

C-- Compute Vertical transport
#ifdef ALLOW_AIM
C- a hack to prevent Water-Vapor vert.transport into the stratospheric level Nr
        IF ( k.EQ.1 .OR.
     &     (useAIM .AND. tracerIdentity.EQ.GAD_SALINITY .AND. k.EQ.Nr)
     &              ) THEN
#else
        IF ( k.EQ.1 ) THEN
#endif

#ifdef ALLOW_AUTODIFF_TAMC
cphmultiCADJ STORE wfld(:,:)  =
cphmultiCADJ &     comlev1_bibj_k_gad, key=kkey, kind=isbyte
#endif /* ALLOW_AUTODIFF_TAMC */

C- Surface interface :
         DO j=1-Oly,sNy+Oly
          DO i=1-Olx,sNx+Olx
           rTransKp1(i,j) = kp1Msk*rTrans(i,j)
           wFld(i,j)   = 0.
           rTrans(i,j) = 0.
           fVerT(i,j,kUp) = 0.
          ENDDO
         ENDDO

        ELSE

#ifdef ALLOW_AUTODIFF_TAMC
cphmultiCADJ STORE wfld(:,:)  =
cphmultiCADJ &     comlev1_bibj_k_gad, key=kkey, kind=isbyte
#endif /* ALLOW_AUTODIFF_TAMC */

C- Interior interface :
         DO j=1-Oly,sNy+Oly
          DO i=1-Olx,sNx+Olx
           rTransKp1(i,j) = kp1Msk*rTrans(i,j)
           wFld(i,j)   = wVel(i,j,k,bi,bj)
           rTrans(i,j) = wVel(i,j,k,bi,bj)*rA(i,j,bi,bj)
     &                 *deepFac2F(k)*rhoFacF(k)
     &                 *maskC(i,j,k-1,bi,bj)
           fVerT(i,j,kUp) = 0.
          ENDDO
         ENDDO

#ifdef ALLOW_GMREDI
C--   Residual transp = Bolus transp + Eulerian transp
         IF (useGMRedi)
     &     CALL GMREDI_CALC_WFLOW(
     U                 wFld, rTrans,
     I                 k, bi, bj, myThid )
#endif /* ALLOW_GMREDI */

#ifdef ALLOW_AUTODIFF_TAMC
cphmultiCADJ STORE localTijk(:,:,k)
cphmultiCADJ &     = comlev1_bibj_k_gad, key=kkey, kind=isbyte
cphmultiCADJ STORE rTrans(:,:)
cphmultiCADJ &     = comlev1_bibj_k_gad, key=kkey, kind=isbyte
#endif /* ALLOW_AUTODIFF_TAMC */

C-    Compute vertical advective flux in the interior:
         IF ( vertAdvecScheme.EQ.ENUM_UPWIND_1RST
     &      .OR. vertAdvecScheme.EQ.ENUM_DST2 ) THEN
           CALL GAD_DST2U1_ADV_R( bi,bj,k, advectionScheme,
     I                            deltaTLev(k),rTrans,wFld,localTijk,
     O                            fVerT(1-Olx,1-Oly,kUp), myThid )
         ELSEIF( vertAdvecScheme.EQ.ENUM_FLUX_LIMIT) THEN
           CALL GAD_FLUXLIMIT_ADV_R( bi,bj,k, deltaTLev(k),
     I                               rTrans, wFld, localTijk,
     O                               fVerT(1-Olx,1-Oly,kUp), myThid )
         ELSEIF( vertAdvecScheme.EQ.ENUM_DST3 ) THEN
           CALL GAD_DST3_ADV_R(      bi,bj,k, deltaTLev(k),
     I                               rTrans, wFld, localTijk,
     O                               fVerT(1-Olx,1-Oly,kUp), myThid )
         ELSEIF( vertAdvecScheme.EQ.ENUM_DST3_FLUX_LIMIT ) THEN
           CALL GAD_DST3FL_ADV_R(    bi,bj,k, deltaTLev(k),
     I                               rTrans, wFld, localTijk,
     O                               fVerT(1-Olx,1-Oly,kUp), myThid )
#ifndef ALLOW_AUTODIFF_TAMC
         ELSEIF (vertAdvecScheme.EQ.ENUM_OS7MP ) THEN
           CALL GAD_OS7MP_ADV_R(     bi,bj,k, deltaTLev(k),
     I                               rTrans, wFld, localTijk,
     O                               fVerT(1-Olx,1-Oly,kUp), myThid )
#endif
         ELSE
          STOP 'GAD_ADVECTION: adv. scheme incompatibale with mutli-dim'
         ENDIF

C- end Surface/Interior if bloc
        ENDIF

#ifdef ALLOW_AUTODIFF_TAMC
cphmultiCADJ STORE rTrans(:,:)
cphmultiCADJ &     = comlev1_bibj_k_gad, key=kkey, kind=isbyte
cphmultiCADJ STORE rTranskp1(:,:)
cphmultiCADJ &     = comlev1_bibj_k_gad, key=kkey, kind=isbyte
cph --- following storing of fVerT is critical for correct
cph --- gradient with multiDimAdvection
cph --- Without it, kDown component is not properly recomputed
cph --- This is a TAF bug (and no warning available)
CADJ STORE fVerT(:,:,:)
CADJ &     = comlev1_bibj_k_gad, key=kkey, kind=isbyte
#endif /* ALLOW_AUTODIFF_TAMC */

C--   Divergence of vertical fluxes
        DO j=1-Oly,sNy+Oly
         DO i=1-Olx,sNx+Olx
          localTij(i,j) = localTijk(i,j,k)
     &      -deltaTLev(k)*recip_rhoFacC(k)
     &       *_recip_hFacC(i,j,k,bi,bj)*recip_drF(k)
     &       *recip_rA(i,j,bi,bj)*recip_deepFac2C(k)
     &       *( fVerT(i,j,kDown)-fVerT(i,j,kUp)
     &         -tracer(i,j,k,bi,bj)*(rTransKp1(i,j)-rTrans(i,j))
     &        )*rkSign
          gTracer(i,j,k,bi,bj)=
     &     (localTij(i,j)-tracer(i,j,k,bi,bj))/deltaTLev(k)
         ENDDO
        ENDDO

#ifdef ALLOW_DIAGNOSTICS
        IF ( doDiagAdvR ) THEN
          diagName = 'ADVr'//diagSufx
          CALL DIAGNOSTICS_FILL( fVerT(1-Olx,1-Oly,kUp),
     &                           diagName, k,1, 2,bi,bj, myThid)
        ENDIF
#endif

C--   End of K loop for vertical flux
       ENDDO
C--   end of if not.implicitAdvection block
      ENDIF

      RETURN
      END
