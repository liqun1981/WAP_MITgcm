C $Header: /u/gcmpack/MITgcm/pkg/gmredi/gmredi_diagnostics_fill.F,v 1.3 2008/05/30 02:50:16 gforget Exp $
C $Name: checkpoint62r $

#include "GMREDI_OPTIONS.h"

CStartOfInterface
      SUBROUTINE GMREDI_DIAGNOSTICS_FILL(
     I             bi, bj, myThid )
C     *==========================================================*
C     | SUBROUTINE GMREDI_DIAGNOSTICS_FILL
C     | o fill GM-Redi diagnostics
C     *==========================================================*
C     | note: formerly was part of S/R GMREDI_CALC_TENSOR
C     |       and was isolated in this S/R for TAF reasons
C     *==========================================================*
      IMPLICIT NONE

C     == Global variables ==
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "GRID.h"
#include "GMREDI.h"

C     == Routine arguments ==
C
      INTEGER bi,bj
      INTEGER myThid
#ifdef ALLOW_DIAGNOSTICS
      LOGICAL     DIAGNOSTICS_IS_ON
      EXTERNAL    DIAGNOSTICS_IS_ON
#endif /* ALLOW_DIAGNOSTICS */
CEndOfInterface

#ifdef ALLOW_GMREDI

C     == Local variables ==
#ifdef ALLOW_EDDYPSI
      INTEGER i,j,k
      _RL tmpfld3dloc (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
#endif

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|


#ifdef ALLOW_DIAGNOSTICS
      IF ( useDiagnostics ) THEN

#ifdef GM_VISBECK_VARIABLE_K
       IF ( GM_Visbeck_alpha.NE.0. ) THEN
         CALL DIAGNOSTICS_FILL(VisbeckK,'GM_VisbK',0,1,1,bi,bj,myThid)
       ENDIF
#endif
#ifdef GM_NON_UNITY_DIAGONAL
         CALL DIAGNOSTICS_FILL(Kux,'GM_Kux  ',0,Nr,1,bi,bj,myThid)
         CALL DIAGNOSTICS_FILL(Kvy,'GM_Kvy  ',0,Nr,1,bi,bj,myThid)
#endif
#ifdef GM_EXTRA_DIAGONAL
       IF ( GM_ExtraDiag ) THEN
         CALL DIAGNOSTICS_FILL(Kuz,'GM_Kuz  ',0,Nr,1,bi,bj,myThid)
         CALL DIAGNOSTICS_FILL(Kvz,'GM_Kvz  ',0,Nr,1,bi,bj,myThid)
       ENDIF
#endif
         CALL DIAGNOSTICS_FILL(Kwx,'GM_Kwx  ',0,Nr,1,bi,bj,myThid)
         CALL DIAGNOSTICS_FILL(Kwy,'GM_Kwy  ',0,Nr,1,bi,bj,myThid)
         CALL DIAGNOSTICS_FILL(Kwz,'GM_Kwz  ',0,Nr,1,bi,bj,myThid)
#ifdef GM_BOLUS_ADVEC
       IF ( GM_AdvForm ) THEN
         CALL DIAGNOSTICS_FILL(GM_PsiX,'GM_PsiX ',0,Nr,1,bi,bj,myThid)
         CALL DIAGNOSTICS_FILL(GM_PsiY,'GM_PsiY ',0,Nr,1,bi,bj,myThid)
       ENDIF
#endif

#ifdef ALLOW_EDDYPSI
       IF ( DIAGNOSTICS_IS_ON('GMEdTauX',myThid) ) THEN
        DO k = 1, Nr
         DO j = 1, sny
          DO i = 1, snx
           tmpfld3dloc(i,j,k,bi,bj) =
     &      0.5*rhoConst*fCori(i,j,bi,bj)*
     &      Kwy(i,j,k,bi,bj)
          ENDDO
         ENDDO
        ENDDO
        CALL DIAGNOSTICS_FILL(tmpfld3dloc,'GMEdTauX',
     &   0,Nr,1,bi,bj,myThid)
       ENDIF
c
       IF ( DIAGNOSTICS_IS_ON('GMEdTauY',myThid) ) THEN
        DO k = 1, Nr
         DO j = 1, sny
          DO i = 1, snx
           tmpfld3dloc(i,j,k,bi,bj) =
     &      -0.5*rhoConst*fCori(i,j,bi,bj)*
     &      Kwx(i,j,k,bi,bj)
          ENDDO
         ENDDO
        ENDDO
        CALL DIAGNOSTICS_FILL(tmpfld3dloc,'GMEdTauY',
     &   0,Nr,1,bi,bj,myThid)
       ENDIF
#endif /* ALLOW_EDDYPSI */

      ENDIF
#endif /* ALLOW_DIAGNOSTICS */

#endif /* ALLOW_GMREDI */

      RETURN
      END
