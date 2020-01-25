C $Header: /u/gcmpack/MITgcm/pkg/ptracers/ptracers_fields_blocking_exchanges.F,v 1.10 2010/11/08 17:33:10 jmc Exp $
C $Name: checkpoint62r $

#include "PTRACERS_OPTIONS.h"
#include "GAD_OPTIONS.h"

CBOP
C !ROUTINE: PTRACERS_FIELDS_BLOCKING_EXCHANGES

C !INTERFACE: ==========================================================
      SUBROUTINE PTRACERS_FIELDS_BLOCKING_EXCH( myThid )

C !DESCRIPTION:
C     Exchange data to update overlaps for passive tracers

C !USES: ===============================================================
#include "PTRACERS_MOD.h"
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "PTRACERS_SIZE.h"
#include "PTRACERS_PARAMS.h"
#include "PTRACERS_FIELDS.h"

C !INPUT PARAMETERS: ===================================================
C  myThid         :: thread number
      INTEGER myThid

C !OUTPUT PARAMETERS: ==================================================
C  none

#ifdef ALLOW_PTRACERS

C !LOCAL VARIABLES: ====================================================
C  iTracer        :: loop indices
C  bi, bj         :: tile indices
      INTEGER iTracer
#ifdef ALLOW_OBCS
      INTEGER bi, bj
#endif /* ALLOW_OBCS */
CEOP

C Loop over passive tracers
      DO iTracer=1,PTRACERS_numInUse

C Exchange overlaps
        CALL EXCH_3D_RL( pTracer(1-Olx,1-Oly,1,1,1,iTracer),
     &                   Nr, myThid )
#ifdef PTRACERS_ALLOW_DYN_STATE
        IF ( PTRACERS_SOM_Advection(iTracer) ) THEN
          CALL GAD_EXCH_SOM( _Ptracers_som(:,:,:,:,:,:,iTracer),
     &                       Nr, myThid )
        ENDIF
#endif /* PTRACERS_ALLOW_DYN_STATE */

#ifdef ALLOW_OBCS
      IF ( useOBCS ) THEN
       DO bj = myByLo(myThid), myByHi(myThid)
        DO bi = myBxLo(myThid), myBxHi(myThid)
         CALL OBCS_COPY_TRACER( pTracer(1-Olx,1-Oly,1,bi,bj,iTracer),
     I                          Nr, bi, bj, myThid )
        ENDDO
       ENDDO
      ENDIF
#endif /* ALLOW_OBCS */

C End of tracer loop
      ENDDO

#endif /* ALLOW_PTRACERS */

      RETURN
      END
