C $Header: /u/gcmpack/MITgcm/pkg/mom_fluxform/mom_fluxform.F,v 1.42 2010/03/16 00:16:50 jmc Exp $
C $Name: checkpoint62r $

CBOI
C !TITLE: pkg/mom\_advdiff
C !AUTHORS: adcroft@mit.edu
C !INTRODUCTION: Flux-form Momentum Equations Package
C
C Package "mom\_fluxform" provides methods for calculating explicit terms
C in the momentum equation cast in flux-form:
C \begin{eqnarray*}
C G^u & = & -\frac{1}{\rho} \partial_x \phi_h
C           -\nabla \cdot {\bf v} u
C           -fv
C           +\frac{1}{\rho} \nabla \cdot {\bf \tau}^x
C           + \mbox{metrics}
C \\
C G^v & = & -\frac{1}{\rho} \partial_y \phi_h
C           -\nabla \cdot {\bf v} v
C           +fu
C           +\frac{1}{\rho} \nabla \cdot {\bf \tau}^y
C           + \mbox{metrics}
C \end{eqnarray*}
C where ${\bf v}=(u,v,w)$ and $\tau$, the stress tensor, includes surface
C stresses as well as internal viscous stresses.
CEOI

#include "MOM_FLUXFORM_OPTIONS.h"

CBOP
C !ROUTINE: MOM_FLUXFORM

C !INTERFACE: ==========================================================
      SUBROUTINE MOM_FLUXFORM(
     I        bi,bj,iMin,iMax,jMin,jMax,k,kUp,kDown,
     I        KappaRU, KappaRV,
     U        fVerU, fVerV,
     O        guDiss, gvDiss,
     I        myTime, myIter, myThid)

C !DESCRIPTION:
C Calculates all the horizontal accelerations except for the implicit surface
C pressure gradient and implicit vertical viscosity.

C !USES: ===============================================================
C     == Global variables ==
      IMPLICIT NONE
#include "SIZE.h"
#include "DYNVARS.h"
#include "FFIELDS.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "GRID.h"
#include "SURFACE.h"
#ifdef ALLOW_AUTODIFF_TAMC
# include "tamc.h"
# include "tamc_keys.h"
# include "MOM_FLUXFORM.h"
#endif

C !INPUT PARAMETERS: ===================================================
C  bi,bj                :: tile indices
C  iMin,iMax,jMin,jMAx  :: loop ranges
C  k                    :: vertical level
C  kUp                  :: =1 or 2 for consecutive k
C  kDown                :: =2 or 1 for consecutive k
C  KappaRU              :: vertical viscosity
C  KappaRV              :: vertical viscosity
C  fVerU                :: vertical flux of U, 2 1/2 dim for pipe-lining
C  fVerV                :: vertical flux of V, 2 1/2 dim for pipe-lining
C  guDiss               :: dissipation tendency (all explicit terms), u component
C  gvDiss               :: dissipation tendency (all explicit terms), v component
C  myTime               :: current time
C  myIter               :: current time-step number
C  myThid               :: thread number
      INTEGER bi,bj,iMin,iMax,jMin,jMax
      INTEGER k,kUp,kDown
      _RL KappaRU(1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr)
      _RL KappaRV(1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr)
      _RL fVerU(1-OLx:sNx+OLx,1-OLy:sNy+OLy,2)
      _RL fVerV(1-OLx:sNx+OLx,1-OLy:sNy+OLy,2)
      _RL guDiss(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL gvDiss(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL     myTime
      INTEGER myIter
      INTEGER myThid

C !OUTPUT PARAMETERS: ==================================================
C None - updates gU() and gV() in common blocks

C !LOCAL VARIABLES: ====================================================
C  i,j                  :: loop indices
C  vF                   :: viscous flux
C  v4F                  :: bi-harmonic viscous flux
C  cF                   :: Coriolis acceleration
C  mT                   :: Metric terms
C  fZon                 :: zonal fluxes
C  fMer                 :: meridional fluxes
C  fVrUp,fVrDw          :: vertical viscous fluxes at interface k-1 & k
      INTEGER i,j
#ifdef ALLOW_AUTODIFF_TAMC
      INTEGER imomkey
#endif
      _RL vF(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL v4F(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL cF(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL mT(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL fZon(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL fMer(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL fVrUp(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL fVrDw(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
C     afFacMom     :: Tracer parameters for turning terms on and off.
C     vfFacMom
C     pfFacMom        afFacMom - Advective terms
C     cfFacMom        vfFacMom - Eddy viscosity terms
C     mtFacMom        pfFacMom - Pressure terms
C                     cfFacMom - Coriolis terms
C                     foFacMom - Forcing
C                     mtFacMom - Metric term
C     uDudxFac, AhDudxFac, etc ... individual term parameters for switching terms off
      _RS    hFacZ(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RS  r_hFacZ(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RS      xA(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RS      yA(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL  uTrans(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL  vTrans(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL  uFld(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL  vFld(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL  rTransU(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL  rTransV(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL KE(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL viscAh_D(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL viscAh_Z(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL viscA4_D(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL viscA4_Z(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL vort3(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL hDiv(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL strain(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL tension(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL  uDudxFac
      _RL  AhDudxFac
      _RL  vDudyFac
      _RL  AhDudyFac
      _RL  rVelDudrFac
      _RL  ArDudrFac
      _RL  fuFac
      _RL  mtFacU
      _RL  mtNHFacU
      _RL  uDvdxFac
      _RL  AhDvdxFac
      _RL  vDvdyFac
      _RL  AhDvdyFac
      _RL  rVelDvdrFac
      _RL  ArDvdrFac
      _RL  fvFac
      _RL  mtFacV
      _RL  mtNHFacV
      _RL  sideMaskFac
      LOGICAL bottomDragTerms,harmonic,biharmonic,useVariableViscosity
CEOP
#ifdef MOM_BOUNDARY_CONSERVE
      COMMON / MOM_FLUXFORM_LOCAL / uBnd, vBnd
      _RL  uBnd(1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL  vBnd(1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
#endif /* MOM_BOUNDARY_CONSERVE */

#ifdef ALLOW_AUTODIFF_TAMC
          act0 = k - 1
          max0 = Nr
          act1 = bi - myBxLo(myThid)
          max1 = myBxHi(myThid) - myBxLo(myThid) + 1
          act2 = bj - myByLo(myThid)
          max2 = myByHi(myThid) - myByLo(myThid) + 1
          act3 = myThid - 1
          max3 = nTx*nTy
          act4 = ikey_dynamics - 1
          imomkey = (act0 + 1)
     &                    + act1*max0
     &                    + act2*max0*max1
     &                    + act3*max0*max1*max2
     &                    + act4*max0*max1*max2*max3
#endif /* ALLOW_AUTODIFF_TAMC */

C     Initialise intermediate terms
      DO j=1-OLy,sNy+OLy
       DO i=1-OLx,sNx+OLx
        vF(i,j)   = 0.
        v4F(i,j)  = 0.
        cF(i,j)   = 0.
        mT(i,j)   = 0.
        fZon(i,j) = 0.
        fMer(i,j) = 0.
        fVrUp(i,j)= 0.
        fVrDw(i,j)= 0.
        rTransU(i,j)= 0.
        rTransV(i,j)= 0.
c       KE(i,j)     = 0.
        hDiv(i,j)   = 0.
        vort3(i,j)  = 0.
        strain(i,j) = 0.
        tension(i,j)= 0.
        guDiss(i,j) = 0.
        gvDiss(i,j) = 0.
       ENDDO
      ENDDO

C--   Term by term tracer parmeters
C     o U momentum equation
      uDudxFac     = afFacMom*1.
      AhDudxFac    = vfFacMom*1.
      vDudyFac     = afFacMom*1.
      AhDudyFac    = vfFacMom*1.
      rVelDudrFac  = afFacMom*1.
      ArDudrFac    = vfFacMom*1.
      mtFacU       = mtFacMom*1.
      mtNHFacU     = 1.
      fuFac        = cfFacMom*1.
C     o V momentum equation
      uDvdxFac     = afFacMom*1.
      AhDvdxFac    = vfFacMom*1.
      vDvdyFac     = afFacMom*1.
      AhDvdyFac    = vfFacMom*1.
      rVelDvdrFac  = afFacMom*1.
      ArDvdrFac    = vfFacMom*1.
      mtFacV       = mtFacMom*1.
      mtNHFacV     = 1.
      fvFac        = cfFacMom*1.

      IF (implicitViscosity) THEN
        ArDudrFac  = 0.
        ArDvdrFac  = 0.
      ENDIF

C note: using standard stencil (no mask) results in under-estimating
C       vorticity at a no-slip boundary by a factor of 2 = sideDragFactor
      IF ( no_slip_sides ) THEN
        sideMaskFac = sideDragFactor
      ELSE
        sideMaskFac = 0. _d 0
      ENDIF

      IF (     no_slip_bottom
     &    .OR. bottomDragQuadratic.NE.0.
     &    .OR. bottomDragLinear.NE.0.) THEN
       bottomDragTerms=.TRUE.
      ELSE
       bottomDragTerms=.FALSE.
      ENDIF

C--   Calculate open water fraction at vorticity points
      CALL MOM_CALC_HFACZ(bi,bj,k,hFacZ,r_hFacZ,myThid)

C---- Calculate common quantities used in both U and V equations
C     Calculate tracer cell face open areas
      DO j=1-OLy,sNy+OLy
       DO i=1-OLx,sNx+OLx
        xA(i,j) = _dyG(i,j,bi,bj)*deepFacC(k)
     &          *drF(k)*_hFacW(i,j,k,bi,bj)
        yA(i,j) = _dxG(i,j,bi,bj)*deepFacC(k)
     &          *drF(k)*_hFacS(i,j,k,bi,bj)
       ENDDO
      ENDDO

C     Make local copies of horizontal flow field
      DO j=1-OLy,sNy+OLy
       DO i=1-OLx,sNx+OLx
        uFld(i,j) = uVel(i,j,k,bi,bj)
        vFld(i,j) = vVel(i,j,k,bi,bj)
       ENDDO
      ENDDO

C     Calculate velocity field "volume transports" through tracer cell faces.
C     anelastic: transports are scaled by rhoFacC (~ mass transport)
      DO j=1-OLy,sNy+OLy
       DO i=1-OLx,sNx+OLx
        uTrans(i,j) = uFld(i,j)*xA(i,j)*rhoFacC(k)
        vTrans(i,j) = vFld(i,j)*yA(i,j)*rhoFacC(k)
       ENDDO
      ENDDO

      CALL MOM_CALC_KE(bi,bj,k,2,uFld,vFld,KE,myThid)
      IF ( momViscosity) THEN
        CALL MOM_CALC_HDIV(bi,bj,k,2,uFld,vFld,hDiv,myThid)
        CALL MOM_CALC_RELVORT3(bi,bj,k,uFld,vFld,hFacZ,vort3,myThid)
        CALL MOM_CALC_TENSION(bi,bj,k,uFld,vFld,tension,myThid)
        CALL MOM_CALC_STRAIN(bi,bj,k,uFld,vFld,hFacZ,strain,myThid)
        DO j=1-Oly,sNy+Oly
         DO i=1-Olx,sNx+Olx
           IF ( hFacZ(i,j).EQ.0. ) THEN
             vort3(i,j)  = sideMaskFac*vort3(i,j)
             strain(i,j) = sideMaskFac*strain(i,j)
           ENDIF
         ENDDO
        ENDDO
#ifdef ALLOW_DIAGNOSTICS
        IF ( useDiagnostics ) THEN
          CALL DIAGNOSTICS_FILL(hDiv,   'momHDiv ',k,1,2,bi,bj,myThid)
          CALL DIAGNOSTICS_FILL(vort3,  'momVort3',k,1,2,bi,bj,myThid)
          CALL DIAGNOSTICS_FILL(tension,'Tension ',k,1,2,bi,bj,myThid)
          CALL DIAGNOSTICS_FILL(strain, 'Strain  ',k,1,2,bi,bj,myThid)
        ENDIF
#endif
      ENDIF

C---  First call (k=1): compute vertical adv. flux fVerU(kUp) & fVerV(kUp)
      IF (momAdvection.AND.k.EQ.1) THEN

#ifdef MOM_BOUNDARY_CONSERVE
        CALL MOM_UV_BOUNDARY( bi, bj, k,
     I                        uVel, vVel,
     O                        uBnd(1-OLx,1-OLy,k,bi,bj),
     O                        vBnd(1-OLx,1-OLy,k,bi,bj),
     I                        myTime, myIter, myThid )
#endif /* MOM_BOUNDARY_CONSERVE */

C-    Calculate vertical transports above U & V points (West & South face):

#ifdef ALLOW_AUTODIFF_TAMC
# ifdef NONLIN_FRSURF
#  ifndef DISABLE_RSTAR_CODE
CADJ STORE dwtransc(:,:,bi,bj) =
CADJ &     comlev1_bibj_k, key = imomkey, byte = isbyte
CADJ STORE dwtransu(:,:,bi,bj) =
CADJ &     comlev1_bibj_k, key = imomkey, byte = isbyte
CADJ STORE dwtransv(:,:,bi,bj) =
CADJ &     comlev1_bibj_k, key = imomkey, byte = isbyte
#  endif
# endif /* NONLIN_FRSURF */
#endif /* ALLOW_AUTODIFF_TAMC */
        CALL MOM_CALC_RTRANS( k, bi, bj,
     O                        rTransU, rTransV,
     I                        myTime, myIter, myThid)

C-    Free surface correction term (flux at k=1)
        CALL MOM_U_ADV_WU( bi,bj,k,uVel,wVel,rTransU,
     O                     fVerU(1-OLx,1-OLy,kUp), myThid )

        CALL MOM_V_ADV_WV( bi,bj,k,vVel,wVel,rTransV,
     O                     fVerV(1-OLx,1-OLy,kUp), myThid )

C---  endif momAdvection & k=1
      ENDIF


C---  Calculate vertical transports (at k+1) below U & V points :
      IF (momAdvection) THEN
        CALL MOM_CALC_RTRANS( k+1, bi, bj,
     O                        rTransU, rTransV,
     I                        myTime, myIter, myThid)
      ENDIF

#ifdef MOM_BOUNDARY_CONSERVE
      IF ( momAdvection .AND. k.LT.Nr ) THEN
        CALL MOM_UV_BOUNDARY( bi, bj, k+1,
     I                        uVel, vVel,
     O                        uBnd(1-OLx,1-OLy,k+1,bi,bj),
     O                        vBnd(1-OLx,1-OLy,k+1,bi,bj),
     I                        myTime, myIter, myThid )
      ENDIF
#endif /* MOM_BOUNDARY_CONSERVE */

      IF (momViscosity) THEN
       CALL MOM_CALC_VISC(
     I        bi,bj,k,
     O        viscAh_Z,viscAh_D,viscA4_Z,viscA4_D,
     O        harmonic,biharmonic,useVariableViscosity,
     I        hDiv,vort3,tension,strain,KE,hFacZ,
     I        myThid)
      ENDIF

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|

C---- Zonal momentum equation starts here

      IF (momAdvection) THEN
C---  Calculate mean fluxes (advection)   between cells for zonal flow.

#ifdef MOM_BOUNDARY_CONSERVE
        CALL MOM_U_ADV_UU( bi,bj,k,uTrans,uBnd(1-OLx,1-OLy,k,bi,bj),
     O                     fZon,myThid )
        CALL MOM_U_ADV_VU( bi,bj,k,vTrans,uBnd(1-OLx,1-OLy,k,bi,bj),
     O                     fMer,myThid )
        CALL MOM_U_ADV_WU(
     I                     bi,bj,k+1,uBnd,wVel,rTransU,
     O                     fVerU(1-OLx,1-OLy,kDown), myThid )
#else /* MOM_BOUNDARY_CONSERVE */
C--   Zonal flux (fZon is at east face of "u" cell)
C     Mean flow component of zonal flux -> fZon
        CALL MOM_U_ADV_UU(bi,bj,k,uTrans,uFld,fZon,myThid)

C--   Meridional flux (fMer is at south face of "u" cell)
C     Mean flow component of meridional flux -> fMer
        CALL MOM_U_ADV_VU(bi,bj,k,vTrans,uFld,fMer,myThid)

C--   Vertical flux (fVer is at upper face of "u" cell)
C     Mean flow component of vertical flux (at k+1) -> fVer
        CALL MOM_U_ADV_WU(
     I                     bi,bj,k+1,uVel,wVel,rTransU,
     O                     fVerU(1-OLx,1-OLy,kDown), myThid )
#endif /* MOM_BOUNDARY_CONSERVE */

C--   Tendency is minus divergence of the fluxes + coriolis + pressure term
        DO j=jMin,jMax
         DO i=iMin,iMax
          gU(i,j,k,bi,bj) =
#ifdef OLD_UV_GEOM
     &     -_recip_hFacW(i,j,k,bi,bj)*recip_drF(k)/
     &      ( 0.5 _d 0*(rA(i,j,bi,bj)+rA(i-1,j,bi,bj)) )
#else
     &     -_recip_hFacW(i,j,k,bi,bj)*recip_drF(k)
     &     *recip_rAw(i,j,bi,bj)*recip_deepFac2C(k)*recip_rhoFacC(k)
#endif
     &     *( ( fZon(i,j  )     - fZon(i-1,j) )*uDudxFac
     &       +( fMer(i,j+1)     - fMer(i,  j) )*vDudyFac
     &       +(fVerU(i,j,kDown) - fVerU(i,j,kUp))*rkSign*rVelDudrFac
     &     )
         ENDDO
        ENDDO

#ifdef ALLOW_DIAGNOSTICS
        IF ( useDiagnostics ) THEN
          CALL DIAGNOSTICS_FILL(fZon,'ADVx_Um ',k,1,2,bi,bj,myThid)
          CALL DIAGNOSTICS_FILL(fMer,'ADVy_Um ',k,1,2,bi,bj,myThid)
          CALL DIAGNOSTICS_FILL(fVerU(1-Olx,1-Oly,kUp),
     &                               'ADVrE_Um',k,1,2,bi,bj,myThid)
        ENDIF
#endif

#ifdef NONLIN_FRSURF
C-- account for 3.D divergence of the flow in rStar coordinate:
# ifndef DISABLE_RSTAR_CODE
        IF ( select_rStar.GT.0 ) THEN
         DO j=jMin,jMax
          DO i=iMin,iMax
           gU(i,j,k,bi,bj) = gU(i,j,k,bi,bj)
     &     - (rStarExpW(i,j,bi,bj) - 1. _d 0)/deltaTfreesurf
     &       *uVel(i,j,k,bi,bj)
          ENDDO
         ENDDO
        ENDIF
        IF ( select_rStar.LT.0 ) THEN
         DO j=jMin,jMax
          DO i=iMin,iMax
           gU(i,j,k,bi,bj) = gU(i,j,k,bi,bj)
     &     - rStarDhWDt(i,j,bi,bj)*uVel(i,j,k,bi,bj)
          ENDDO
         ENDDO
        ENDIF
# endif /* DISABLE_RSTAR_CODE */
#endif /* NONLIN_FRSURF */

      ELSE
C-    if momAdvection / else
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
           gU(i,j,k,bi,bj) = 0. _d 0
         ENDDO
        ENDDO

C-    endif momAdvection.
      ENDIF

      IF (momViscosity) THEN
C---  Calculate eddy fluxes (dissipation) between cells for zonal flow.

C     Bi-harmonic term del^2 U -> v4F
        IF (biharmonic)
     &  CALL MOM_U_DEL2U(bi,bj,k,uFld,hFacZ,v4f,myThid)

C     Laplacian and bi-harmonic terms, Zonal  Fluxes -> fZon
        CALL MOM_U_XVISCFLUX(bi,bj,k,uFld,v4F,fZon,
     I    viscAh_D,viscA4_D,myThid)

C     Laplacian and bi-harmonic termis, Merid Fluxes -> fMer
        CALL MOM_U_YVISCFLUX(bi,bj,k,uFld,v4F,hFacZ,fMer,
     I    viscAh_Z,viscA4_Z,myThid)

C     Eddy component of vertical flux (interior component only) -> fVrUp & fVrDw
       IF (.NOT.implicitViscosity) THEN
        CALL MOM_U_RVISCFLUX(bi,bj, k, uVel,KappaRU,fVrUp,myThid)
        CALL MOM_U_RVISCFLUX(bi,bj,k+1,uVel,KappaRU,fVrDw,myThid)
       ENDIF

C--   Tendency is minus divergence of the fluxes
C     anelastic: hor.visc.fluxes are not scaled by rhoFac (by vert.visc.flx is)
        DO j=jMin,jMax
         DO i=iMin,iMax
          guDiss(i,j) =
#ifdef OLD_UV_GEOM
     &     -_recip_hFacW(i,j,k,bi,bj)*recip_drF(k)/
     &      ( 0.5 _d 0*(rA(i,j,bi,bj)+rA(i-1,j,bi,bj)) )
#else
     &     -_recip_hFacW(i,j,k,bi,bj)*recip_drF(k)
     &     *recip_rAw(i,j,bi,bj)*recip_deepFac2C(k)
#endif
     &     *( ( fZon(i,j  ) - fZon(i-1,j) )*AhDudxFac
     &       +( fMer(i,j+1) - fMer(i,  j) )*AhDudyFac
     &       +( fVrDw(i,j)  - fVrUp(i,j)  )*rkSign*ArDudrFac
     &                                     *recip_rhoFacC(k)
     &     )
         ENDDO
        ENDDO

#ifdef ALLOW_DIAGNOSTICS
        IF ( useDiagnostics ) THEN
          CALL DIAGNOSTICS_FILL(fZon, 'VISCx_Um',k,1,2,bi,bj,myThid)
          CALL DIAGNOSTICS_FILL(fMer, 'VISCy_Um',k,1,2,bi,bj,myThid)
          IF (.NOT.implicitViscosity)
     &    CALL DIAGNOSTICS_FILL(fVrUp,'VISrE_Um',k,1,2,bi,bj,myThid)
        ENDIF
#endif

C-- No-slip and drag BCs appear as body forces in cell abutting topography
        IF (no_slip_sides) THEN
C-     No-slip BCs impose a drag at walls...
         CALL MOM_U_SIDEDRAG(
     I        bi,bj,k,
     I        uFld, v4f, hFacZ,
     I        viscAh_Z,viscA4_Z,
     I        harmonic,biharmonic,useVariableViscosity,
     O        vF,
     I        myThid)
         DO j=jMin,jMax
          DO i=iMin,iMax
           gUdiss(i,j) = gUdiss(i,j) + vF(i,j)
          ENDDO
         ENDDO
        ENDIF
C-    No-slip BCs impose a drag at bottom
        IF (bottomDragTerms) THEN
         CALL MOM_U_BOTTOMDRAG(bi,bj,k,uFld,KE,KappaRU,vF,myThid)
         DO j=jMin,jMax
          DO i=iMin,iMax
           gUdiss(i,j) = gUdiss(i,j) + vF(i,j)
          ENDDO
         ENDDO
        ENDIF

#ifdef ALLOW_SHELFICE
        IF (useShelfIce) THEN
         CALL SHELFICE_U_DRAG(bi,bj,k,uFld,KE,KappaRU,vF,myThid)
         DO j=jMin,jMax
          DO i=iMin,iMax
           gUdiss(i,j) = gUdiss(i,j) + vF(i,j)
          ENDDO
         ENDDO
        ENDIF
#endif /* ALLOW_SHELFICE */

C-    endif momViscosity
      ENDIF

C--   Forcing term (moved to timestep.F)
c     IF (momForcing)
c    &  CALL EXTERNAL_FORCING_U(
c    I     iMin,iMax,jMin,jMax,bi,bj,k,
c    I     myTime,myThid)

C--   Metric terms for curvilinear grid systems
      IF (useNHMTerms) THEN
C      o Non-Hydrostatic (spherical) metric terms
       CALL MOM_U_METRIC_NH(bi,bj,k,uFld,wVel,mT,myThid)
       DO j=jMin,jMax
        DO i=iMin,iMax
         gU(i,j,k,bi,bj) = gU(i,j,k,bi,bj)+mtNHFacU*mT(i,j)
        ENDDO
       ENDDO
      ENDIF
      IF ( usingSphericalPolarGrid .AND. metricTerms ) THEN
C      o Spherical polar grid metric terms
       CALL MOM_U_METRIC_SPHERE(bi,bj,k,uFld,vFld,mT,myThid)
       DO j=jMin,jMax
        DO i=iMin,iMax
         gU(i,j,k,bi,bj) = gU(i,j,k,bi,bj)+mtFacU*mT(i,j)
        ENDDO
       ENDDO
      ENDIF
      IF ( usingCylindricalGrid .AND. metricTerms ) THEN
C      o Cylindrical grid metric terms
       CALL MOM_U_METRIC_CYLINDER(bi,bj,k,uFld,vFld,mT,myThid)
       DO j=jMin,jMax
        DO i=iMin,iMax
         gU(i,j,k,bi,bj) = gU(i,j,k,bi,bj)+mtFacU*mT(i,j)
        ENDDO
       ENDDO
      ENDIF

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|

C---- Meridional momentum equation starts here

      IF (momAdvection) THEN

#ifdef MOM_BOUNDARY_CONSERVE
        CALL MOM_V_ADV_UV( bi,bj,k,uTrans,vBnd(1-OLx,1-OLy,k,bi,bj),
     O                     fZon,myThid )
        CALL MOM_V_ADV_VV( bi,bj,k,vTrans,vBnd(1-OLx,1-OLy,k,bi,bj),
     O                     fMer,myThid )
        CALL MOM_V_ADV_WV(
     I                     bi,bj,k+1,vBnd,wVel,rTransV,
     O                     fVerV(1-OLx,1-OLy,kDown), myThid )
#else /* MOM_BOUNDARY_CONSERVE */
C---  Calculate mean fluxes (advection)   between cells for meridional flow.
C     Mean flow component of zonal flux -> fZon
        CALL MOM_V_ADV_UV(bi,bj,k,uTrans,vFld,fZon,myThid)

C--   Meridional flux (fMer is at north face of "v" cell)
C     Mean flow component of meridional flux -> fMer
        CALL MOM_V_ADV_VV(bi,bj,k,vTrans,vFld,fMer,myThid)

C--   Vertical flux (fVer is at upper face of "v" cell)
C     Mean flow component of vertical flux (at k+1) -> fVerV
        CALL MOM_V_ADV_WV(
     I                     bi,bj,k+1,vVel,wVel,rTransV,
     O                     fVerV(1-OLx,1-OLy,kDown), myThid )
#endif /* MOM_BOUNDARY_CONSERVE */

C--   Tendency is minus divergence of the fluxes + coriolis + pressure term
        DO j=jMin,jMax
         DO i=iMin,iMax
          gV(i,j,k,bi,bj) =
#ifdef OLD_UV_GEOM
     &     -_recip_hFacS(i,j,k,bi,bj)*recip_drF(k)/
     &      ( 0.5 _d 0*(_rA(i,j,bi,bj)+_rA(i,j-1,bi,bj)) )
#else
     &     -_recip_hFacS(i,j,k,bi,bj)*recip_drF(k)
     &     *recip_rAs(i,j,bi,bj)*recip_deepFac2C(k)*recip_rhoFacC(k)
#endif
     &     *( ( fZon(i+1,j)     - fZon(i,j  ) )*uDvdxFac
     &       +( fMer(i,  j)     - fMer(i,j-1) )*vDvdyFac
     &       +(fVerV(i,j,kDown) - fVerV(i,j,kUp))*rkSign*rVelDvdrFac
     &     )
         ENDDO
        ENDDO

#ifdef ALLOW_DIAGNOSTICS
        IF ( useDiagnostics ) THEN
          CALL DIAGNOSTICS_FILL(fZon,'ADVx_Vm ',k,1,2,bi,bj,myThid)
          CALL DIAGNOSTICS_FILL(fMer,'ADVy_Vm ',k,1,2,bi,bj,myThid)
          CALL DIAGNOSTICS_FILL(fVerV(1-Olx,1-Oly,kUp),
     &                               'ADVrE_Vm',k,1,2,bi,bj,myThid)
        ENDIF
#endif

#ifdef NONLIN_FRSURF
C-- account for 3.D divergence of the flow in rStar coordinate:
# ifndef DISABLE_RSTAR_CODE
        IF ( select_rStar.GT.0 ) THEN
         DO j=jMin,jMax
          DO i=iMin,iMax
           gV(i,j,k,bi,bj) = gV(i,j,k,bi,bj)
     &     - (rStarExpS(i,j,bi,bj) - 1. _d 0)/deltaTfreesurf
     &       *vVel(i,j,k,bi,bj)
          ENDDO
         ENDDO
        ENDIF
        IF ( select_rStar.LT.0 ) THEN
         DO j=jMin,jMax
          DO i=iMin,iMax
           gV(i,j,k,bi,bj) = gV(i,j,k,bi,bj)
     &     - rStarDhSDt(i,j,bi,bj)*vVel(i,j,k,bi,bj)
          ENDDO
         ENDDO
        ENDIF
# endif /* DISABLE_RSTAR_CODE */
#endif /* NONLIN_FRSURF */

      ELSE
C-    if momAdvection / else
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
           gV(i,j,k,bi,bj) = 0. _d 0
         ENDDO
        ENDDO

C-    endif momAdvection.
      ENDIF

      IF (momViscosity) THEN
C---  Calculate eddy fluxes (dissipation) between cells for meridional flow.
C     Bi-harmonic term del^2 V -> v4F
        IF (biharmonic)
     &  CALL MOM_V_DEL2V(bi,bj,k,vFld,hFacZ,v4f,myThid)

C     Laplacian and bi-harmonic terms, Zonal  Fluxes -> fZon
        CALL MOM_V_XVISCFLUX(bi,bj,k,vFld,v4f,hFacZ,fZon,
     I    viscAh_Z,viscA4_Z,myThid)

C     Laplacian and bi-harmonic termis, Merid Fluxes -> fMer
        CALL MOM_V_YVISCFLUX(bi,bj,k,vFld,v4f,fMer,
     I    viscAh_D,viscA4_D,myThid)

C     Eddy component of vertical flux (interior component only) -> fVrUp & fVrDw
       IF (.NOT.implicitViscosity) THEN
        CALL MOM_V_RVISCFLUX(bi,bj, k, vVel,KappaRV,fVrUp,myThid)
        CALL MOM_V_RVISCFLUX(bi,bj,k+1,vVel,KappaRV,fVrDw,myThid)
       ENDIF

C--   Tendency is minus divergence of the fluxes + coriolis + pressure term
C     anelastic: hor.visc.fluxes are not scaled by rhoFac (by vert.visc.flx is)
        DO j=jMin,jMax
         DO i=iMin,iMax
          gvDiss(i,j) =
#ifdef OLD_UV_GEOM
     &     -_recip_hFacS(i,j,k,bi,bj)*recip_drF(k)/
     &      ( 0.5 _d 0*(_rA(i,j,bi,bj)+_rA(i,j-1,bi,bj)) )
#else
     &     -_recip_hFacS(i,j,k,bi,bj)*recip_drF(k)
     &      *recip_rAs(i,j,bi,bj)*recip_deepFac2C(k)
#endif
     &     *( ( fZon(i+1,j)  - fZon(i,j  ) )*AhDvdxFac
     &       +( fMer(i,  j)  - fMer(i,j-1) )*AhDvdyFac
     &       +( fVrDw(i,j)   - fVrUp(i,j) )*rkSign*ArDvdrFac
     &                                     *recip_rhoFacC(k)
     &     )
         ENDDO
        ENDDO

#ifdef ALLOW_DIAGNOSTICS
        IF ( useDiagnostics ) THEN
          CALL DIAGNOSTICS_FILL(fZon, 'VISCx_Vm',k,1,2,bi,bj,myThid)
          CALL DIAGNOSTICS_FILL(fMer, 'VISCy_Vm',k,1,2,bi,bj,myThid)
          IF (.NOT.implicitViscosity)
     &    CALL DIAGNOSTICS_FILL(fVrUp,'VISrE_Vm',k,1,2,bi,bj,myThid)
        ENDIF
#endif

C-- No-slip and drag BCs appear as body forces in cell abutting topography
        IF (no_slip_sides) THEN
C-     No-slip BCs impose a drag at walls...
         CALL MOM_V_SIDEDRAG(
     I        bi,bj,k,
     I        vFld, v4f, hFacZ,
     I        viscAh_Z,viscA4_Z,
     I        harmonic,biharmonic,useVariableViscosity,
     O        vF,
     I        myThid)
         DO j=jMin,jMax
          DO i=iMin,iMax
           gvDiss(i,j) = gvDiss(i,j) + vF(i,j)
          ENDDO
         ENDDO
        ENDIF
C-    No-slip BCs impose a drag at bottom
        IF (bottomDragTerms) THEN
         CALL MOM_V_BOTTOMDRAG(bi,bj,k,vFld,KE,KappaRV,vF,myThid)
         DO j=jMin,jMax
          DO i=iMin,iMax
           gvDiss(i,j) = gvDiss(i,j) + vF(i,j)
          ENDDO
         ENDDO
        ENDIF

#ifdef ALLOW_SHELFICE
        IF (useShelfIce) THEN
         CALL SHELFICE_V_DRAG(bi,bj,k,vFld,KE,KappaRU,vF,myThid)
         DO j=jMin,jMax
          DO i=iMin,iMax
           gvDiss(i,j) = gvDiss(i,j) + vF(i,j)
          ENDDO
         ENDDO
        ENDIF
#endif /* ALLOW_SHELFICE */

C-    endif momViscosity
      ENDIF

C--   Forcing term (moved to timestep.F)
c     IF (momForcing)
c    & CALL EXTERNAL_FORCING_V(
c    I     iMin,iMax,jMin,jMax,bi,bj,k,
c    I     myTime,myThid)

C--   Metric terms for curvilinear grid systems
      IF (useNHMTerms) THEN
C      o Non-Hydrostatic (spherical) metric terms
       CALL MOM_V_METRIC_NH(bi,bj,k,vFld,wVel,mT,myThid)
       DO j=jMin,jMax
        DO i=iMin,iMax
         gV(i,j,k,bi,bj) = gV(i,j,k,bi,bj)+mtNHFacV*mT(i,j)
        ENDDO
       ENDDO
      ENDIF
      IF ( usingSphericalPolarGrid .AND. metricTerms ) THEN
C      o Spherical polar grid metric terms
       CALL MOM_V_METRIC_SPHERE(bi,bj,k,uFld,mT,myThid)
       DO j=jMin,jMax
        DO i=iMin,iMax
         gV(i,j,k,bi,bj) = gV(i,j,k,bi,bj)+mtFacV*mT(i,j)
        ENDDO
       ENDDO
      ENDIF
      IF ( usingCylindricalGrid .AND. metricTerms ) THEN
C      o Cylindrical grid metric terms
       CALL MOM_V_METRIC_CYLINDER(bi,bj,k,uFld,vFld,mT,myThid)
       DO j=jMin,jMax
        DO i=iMin,iMax
         gV(i,j,k,bi,bj) = gV(i,j,k,bi,bj)+mtFacV*mT(i,j)
        ENDDO
       ENDDO
      ENDIF

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|

C--   Coriolis term
C     Note. As coded here, coriolis will not work with "thin walls"
c     IF (useCDscheme) THEN
c       CALL MOM_CDSCHEME(bi,bj,k,dPhiHydX,dPhiHydY,myThid)
c     ELSE
      IF (.NOT.useCDscheme) THEN
        CALL MOM_U_CORIOLIS(bi,bj,k,vFld,cf,myThid)
        DO j=jMin,jMax
         DO i=iMin,iMax
          gU(i,j,k,bi,bj) = gU(i,j,k,bi,bj)+fuFac*cf(i,j)
         ENDDO
        ENDDO
#ifdef ALLOW_DIAGNOSTICS
        IF ( useDiagnostics )
     &    CALL DIAGNOSTICS_FILL(cf,'Um_Cori ',k,1,2,bi,bj,myThid)
#endif
        CALL MOM_V_CORIOLIS(bi,bj,k,uFld,cf,myThid)
        DO j=jMin,jMax
         DO i=iMin,iMax
          gV(i,j,k,bi,bj) = gV(i,j,k,bi,bj)+fvFac*cf(i,j)
         ENDDO
        ENDDO
#ifdef ALLOW_DIAGNOSTICS
        IF ( useDiagnostics )
     &    CALL DIAGNOSTICS_FILL(cf,'Vm_Cori ',k,1,2,bi,bj,myThid)
#endif
      ENDIF

C--   3.D Coriolis term (horizontal momentum, Eastward component: -fprime*w)
      IF ( use3dCoriolis ) THEN
        CALL MOM_U_CORIOLIS_NH(bi,bj,k,wVel,cf,myThid)
        DO j=jMin,jMax
         DO i=iMin,iMax
          gU(i,j,k,bi,bj) = gU(i,j,k,bi,bj)+fuFac*cf(i,j)
         ENDDO
        ENDDO
       IF ( usingCurvilinearGrid ) THEN
C-     presently, non zero angleSinC array only supported with Curvilinear-Grid
        CALL MOM_V_CORIOLIS_NH(bi,bj,k,wVel,cf,myThid)
        DO j=jMin,jMax
         DO i=iMin,iMax
          gV(i,j,k,bi,bj) = gV(i,j,k,bi,bj)+fvFac*cf(i,j)
         ENDDO
        ENDDO
       ENDIF
      ENDIF

C--   Set du/dt & dv/dt on boundaries to zero
      DO j=jMin,jMax
       DO i=iMin,iMax
        gU(i,j,k,bi,bj) = gU(i,j,k,bi,bj)*_maskW(i,j,k,bi,bj)
        guDiss(i,j)     = guDiss(i,j)    *_maskW(i,j,k,bi,bj)
        gV(i,j,k,bi,bj) = gV(i,j,k,bi,bj)*_maskS(i,j,k,bi,bj)
        gvDiss(i,j)     = gvDiss(i,j)    *_maskS(i,j,k,bi,bj)
       ENDDO
      ENDDO

#ifdef ALLOW_DIAGNOSTICS
      IF ( useDiagnostics ) THEN
        CALL DIAGNOSTICS_FILL(KE,    'momKE   ',k,1,2,bi,bj,myThid)
        CALL DIAGNOSTICS_FILL(gU(1-Olx,1-Oly,k,bi,bj),
     &                               'Um_Advec',k,1,2,bi,bj,myThid)
        CALL DIAGNOSTICS_FILL(gV(1-Olx,1-Oly,k,bi,bj),
     &                               'Vm_Advec',k,1,2,bi,bj,myThid)
       IF (momViscosity) THEN
        CALL DIAGNOSTICS_FILL(guDiss,'Um_Diss ',k,1,2,bi,bj,myThid)
        CALL DIAGNOSTICS_FILL(gvDiss,'Vm_Diss ',k,1,2,bi,bj,myThid)
       ENDIF
      ENDIF
#endif /* ALLOW_DIAGNOSTICS */

      RETURN
      END