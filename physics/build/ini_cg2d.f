C $Header: /u/gcmpack/MITgcm/model/src/ini_cg2d.F,v 1.49 2009/12/08 00:10:26 jmc Exp $
C $Name: checkpoint62r $

#include "PACKAGES_CONFIG.h"
#include "CPP_OPTIONS.h"

CBOP
C     !ROUTINE: INI_CG2D
C     !INTERFACE:
      SUBROUTINE INI_CG2D( myThid )

C     !DESCRIPTION: \bv
C     *==========================================================*
C     | SUBROUTINE INI_CG2D
C     | o Initialise 2d conjugate gradient solver operators.
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
#include "CG2D.h"
#ifdef ALLOW_OBCS
#include "OBCS.h"
#endif

C     !INPUT/OUTPUT PARAMETERS:
C     === Routine arguments ===
C     myThid - Thread no. that called this routine.
      INTEGER myThid

C     !LOCAL VARIABLES:
C     === Local variables ===
C     bi,bj  :: tile indices
C     i,j,k  :: Loop counters
C     faceArea - Temporary used to hold cell face areas.
C     myNorm - Work variable used in calculating normalisation factor
C     sumArea - Work variable used to compute the total Domain Area
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      INTEGER bi, bj
      INTEGER i, j, k, ks
      _RL     faceArea
      _RS     myNorm
      _RS     aC, aCw, aCs
CEOP

C--   Initialize arrays in common blocs (CG2D.h) ; not really necessary
C     but safer when EXCH do not fill all the overlap regions.
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          aW2d(i,j,bi,bj) = 0. _d 0
          aS2d(i,j,bi,bj) = 0. _d 0
          aC2d(i,j,bi,bj) = 0. _d 0
          pW(i,j,bi,bj) = 0. _d 0
          pS(i,j,bi,bj) = 0. _d 0
          pC(i,j,bi,bj) = 0. _d 0
         ENDDO
        ENDDO
        DO j=1-1,sNy+1
         DO i=1-1,sNx+1
          cg2d_q(i,j,bi,bj) = 0. _d 0
          cg2d_r(i,j,bi,bj) = 0. _d 0
          cg2d_s(i,j,bi,bj) = 0. _d 0
#ifdef ALLOW_CG2D_NSA
          cg2d_z(i,j,bi,bj) = 0. _d 0
#endif /* ALLOW_CG2D_NSA */
#ifdef ALLOW_SRCG
          cg2d_y(i,j,bi,bj) = 0. _d 0
          cg2d_v(i,j,bi,bj) = 0. _d 0
#endif /*  ALLOW_SRCG */
         ENDDO
        ENDDO
       ENDDO
      ENDDO

C--   Initialise laplace operator
C     aW2d: integral in Z Ax/dX
C     aS2d: integral in Z Ay/dY
      myNorm = 0. _d 0
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1,sNy
         DO i=1,sNx
          aW2d(i,j,bi,bj) = 0. _d 0
          aS2d(i,j,bi,bj) = 0. _d 0
         ENDDO
        ENDDO
        DO k=1,Nr
         DO j=1,sNy
          DO i=1,sNx
C  deep-model: *deepFacC (faceArea), /deepFacC (recip_dx,y): => no net effect
           faceArea = _dyG(i,j,bi,bj)*drF(k)
     &               *_hFacW(i,j,k,bi,bj)
           aW2d(i,j,bi,bj) = aW2d(i,j,bi,bj)
     &              + implicSurfPress*implicDiv2DFlow
     &               *faceArea*recip_dxC(i,j,bi,bj)
           faceArea = _dxG(i,j,bi,bj)*drF(k)
     &               *_hFacS(i,j,k,bi,bj)
           aS2d(i,j,bi,bj) = aS2d(i,j,bi,bj)
     &              + implicSurfPress*implicDiv2DFlow
     &               *faceArea*recip_dyC(i,j,bi,bj)
          ENDDO
         ENDDO
        ENDDO
#ifdef ALLOW_OBCS
        IF (useOBCS) THEN
         DO i=1,sNx
          IF (OB_Jn(i,bi,bj).NE.0) aS2d(i, OB_Jn(i,bi,bj), bi,bj)=0.
          IF (OB_Jn(i,bi,bj).NE.0) aS2d(i,OB_Jn(i,bi,bj)+1,bi,bj)=0.
          IF (OB_Js(i,bi,bj).NE.0) aS2d(i,OB_Js(i,bi,bj)+1,bi,bj)=0.
          IF (OB_Js(i,bi,bj).NE.0) aS2d(i, OB_Js(i,bi,bj), bi,bj)=0.
         ENDDO
         DO j=1,sNy
          IF (OB_Ie(j,bi,bj).NE.0) aW2d(OB_Ie(j,bi,bj), j, bi,bj)=0.
          IF (OB_Ie(j,bi,bj).NE.0) aW2d(OB_Ie(j,bi,bj)+1,j,bi,bj)=0.
          IF (OB_Iw(j,bi,bj).NE.0) aW2d(OB_Iw(j,bi,bj)+1,j,bi,bj)=0.
          IF (OB_Iw(j,bi,bj).NE.0) aW2d(OB_Iw(j,bi,bj), j, bi,bj)=0.
         ENDDO
        ENDIF
#endif
        DO j=1,sNy
         DO i=1,sNx
          myNorm = MAX(ABS(aW2d(i,j,bi,bj)),myNorm)
          myNorm = MAX(ABS(aS2d(i,j,bi,bj)),myNorm)
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      _GLOBAL_MAX_RS( myNorm, myThid )
      IF ( myNorm .NE. 0. _d 0 ) THEN
       myNorm = 1. _d 0/myNorm
      ELSE
       myNorm = 1. _d 0
      ENDIF
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1,sNy
         DO i=1,sNx
          aW2d(i,j,bi,bj) = aW2d(i,j,bi,bj)*myNorm
          aS2d(i,j,bi,bj) = aS2d(i,j,bi,bj)*myNorm
         ENDDO
        ENDDO
       ENDDO
      ENDDO

C--   Update overlap regions
CcnhDebugStarts
C     CALL PLOT_FIELD_XYRS( aW2d, 'AW2D INI_CG2D.1' , 1, myThid )
C     CALL PLOT_FIELD_XYRS( aS2d, 'AS2D INI_CG2D.1' , 1, myThid )
CcnhDebugEnds
      CALL EXCH_UV_XY_RS( aW2d, aS2d, .FALSE., myThid )
CcnhDebugStarts
C     CALL PLOT_FIELD_XYRS( aW2d, 'AW2D INI_CG2D.2' , 1, myThid )
C     CALL PLOT_FIELD_XYRS( aS2d, 'AS2D INI_CG2D.2' , 1, myThid )
CcnhDebugEnds

      _BEGIN_MASTER(myThid)
C-- set global parameter in common block:
      cg2dNorm = myNorm
C-- Define the solver tolerance in the appropriate Unit :
      cg2dNormaliseRHS = cg2dTargetResWunit.LE.0.
      IF (cg2dNormaliseRHS) THEN
C-  when using a normalisation of RHS, tolerance has no unit => no conversion
        cg2dTolerance = cg2dTargetResidual
      ELSE
C-  convert Target-Residual (in W unit) to cg2d-solver residual unit [m^2/s^2]
        cg2dTolerance = cg2dNorm * cg2dTargetResWunit
     &                           * globalArea / deltaTmom
      ENDIF
      _END_MASTER(myThid)

CcnhDebugStarts
      _BEGIN_MASTER( myThid )
       WRITE(msgBuf,'(2A,1PE23.16)') 'INI_CG2D: ',
     &      'CG2D normalisation factor = ', cg2dNorm
       CALL PRINT_MESSAGE( msgBuf,standardMessageUnit,SQUEEZE_RIGHT,1)
       IF (.NOT.cg2dNormaliseRHS) THEN
        WRITE(msgBuf,'(2A,1PE22.15,A,1PE16.10,A)') 'INI_CG2D: ',
     &      'cg2dTolerance =', cg2dTolerance, ' (Area=',globalArea,')'
        CALL PRINT_MESSAGE(msgBuf,standardMessageUnit,SQUEEZE_RIGHT,1)
       ENDIF
       WRITE(msgBuf,*) ' '
       CALL PRINT_MESSAGE( msgBuf,standardMessageUnit,SQUEEZE_RIGHT,1)
      _END_MASTER( myThid )
CcnhDebugEnds

C--   Initialise preconditioner
C     Note. 20th May 1998
C           I made a weird discovery! In the model paper we argue
C           for the form of the preconditioner used here ( see
C           A Finite-volume, Incompressible Navier-Stokes Model
C           ...., Marshall et. al ). The algebra gives a simple
C           0.5 factor for the averaging of ac and aCw to get a
C           symmettric pre-conditioner. By using a factor of 0.51
C           i.e. scaling the off-diagonal terms in the
C           preconditioner down slightly I managed to get the
C           number of iterations for convergence in a test case to
C           drop form 192 -> 134! Need to investigate this further!
C           For now I have introduced a parameter cg2dpcOffDFac which
C           defaults to 0.51 but can be set at runtime.
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
C-    calculate and store solver main diagonal :
        DO j=0,sNy+1
         DO i=0,sNx+1
           ks = ksurfC(i,j,bi,bj)
           aC2d(i,j,bi,bj) = -(
     &       aW2d(i,j,bi,bj) + aW2d(i+1,j, bi,bj)
     &      +aS2d(i,j,bi,bj) + aS2d( i,j+1,bi,bj)
     &      +freeSurfFac*myNorm*recip_Bo(i,j,bi,bj)*deepFac2F(ks)
     &                  *rA(i,j,bi,bj)/deltaTMom/deltaTfreesurf
     &                        )
         ENDDO
        ENDDO
        DO j=1,sNy
         DO i=1,sNx
           aC  = aC2d( i, j, bi,bj)
           aCs = aC2d( i,j-1,bi,bj)
           aCw = aC2d(i-1,j, bi,bj)
           IF ( aC .EQ. 0. ) THEN
            pC(i,j,bi,bj) = 1. _d 0
           ELSE
            pC(i,j,bi,bj) =  1. _d 0 / aC
           ENDIF
           IF ( aC + aCw .EQ. 0. ) THEN
            pW(i,j,bi,bj) = 0.
           ELSE
            pW(i,j,bi,bj) =
     &         -aW2d(i,j,bi,bj)/((cg2dpcOffDFac *(aCw+aC))**2 )
           ENDIF
           IF ( aC + aCs .EQ. 0. ) THEN
            pS(i,j,bi,bj) = 0.
           ELSE
            pS(i,j,bi,bj) =
     &         -aS2d(i,j,bi,bj)/((cg2dpcOffDFac *(aCs+aC))**2 )
           ENDIF
C          pC(i,j,bi,bj) = 1.
C          pW(i,j,bi,bj) = 0.
C          pS(i,j,bi,bj) = 0.
         ENDDO
        ENDDO
       ENDDO
      ENDDO
C--   Update overlap regions
      CALL EXCH_XY_RS( pC, myThid )
      CALL EXCH_UV_XY_RS( pW, pS, .FALSE., myThid )
CcnhDebugStarts
C     CALL PLOT_FIELD_XYRS( pC, 'pC   INI_CG2D.2' , 1, myThid )
C     CALL PLOT_FIELD_XYRS( pW, 'pW   INI_CG2D.2' , 1, myThid )
C     CALL PLOT_FIELD_XYRS( pS, 'pS   INI_CG2D.2' , 1, myThid )
CcnhDebugEnds

      RETURN
      END
