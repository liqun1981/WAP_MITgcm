C $Header: /u/gcmpack/MITgcm/model/src/ini_model_io.F,v 1.41 2011/01/21 01:19:59 gforget Exp $
C $Name: checkpoint62r $

#include "PACKAGES_CONFIG.h"
#include "CPP_OPTIONS.h"

CBOP
C     !ROUTINE: INI_MODEL_IO

C     !INTERFACE:
      SUBROUTINE INI_MODEL_IO( myThid )

C     !DESCRIPTION:
C     Initialisation and setting of I/O:
C     - Check size and initialise global I/O buffer
C     - Initialise flags for pickup and for mdsio/rw.
C     - Do MNC model-IO initialisation
C     - Do Monitor-IO initialisation

C     !USES:
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "EESUPPORT.h"
#include "PARAMS.h"
#include "RESTART.h"
#ifdef ALLOW_EXCH2
# include "W2_EXCH2_SIZE.h"
# include "W2_EXCH2_TOPOLOGY.h"
# include "W2_EXCH2_PARAMS.h"
#endif /* ALLOW_EXCH2 */
#include "EEBUFF_SCPU.h"

C     !INPUT/OUTPUT PARAMETERS:
C     myThid :: my Thread Id number
      INTEGER myThid

C     !FUNCTIONS
      INTEGER  ILNBLNK
      EXTERNAL ILNBLNK

C     !LOCAL VARIABLES:
C     msgBuf :: Informational/error message buffer
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      CHARACTER*(MAX_LEN_FNAM) namBuf
      INTEGER i, iL, pIL
      LOGICAL useGlobalBuff
#ifdef ALLOW_EXCH2
      INTEGER xySize
#endif /* ALLOW_EXCH2 */
#ifdef ALLOW_USE_MPI
      INTEGER iG,jG,np
#endif /* ALLOW_USE_MPI */
CEOP

C-    Safety check:
      IF ( nPx*nPy.NE.1 .AND. globalFiles
     &                  .AND. .NOT.useSingleCpuIO ) THEN
        _BEGIN_MASTER( myThid )
c       WRITE(msgBuf,'(2A)')
c    &   'INI_MODEL_IO: globalFiles=TRUE is not safe',
c    &   ' in Multi-processors (MPI) run'
c       CALL PRINT_ERROR( msgBuf , myThid)
c       WRITE(msgBuf,'(2A)')
c    &   'INI_MODEL_IO: use instead "useSingleCpuIO=.TRUE."'
c       CALL PRINT_ERROR( msgBuf , myThid)
c       STOP 'ABNORMAL END: S/R INI_MODEL_IO'
C------
C   GlobalFiles option with Multi-processors execution (with MPI) is not
C   safe: dependending on the platform & compiler, it may produce:
C    - incomplete output files (wrong size)
C    - wrong isolated values in some output files
C    - missing tiles (all zeros) in some output files.
C   A safe alternative is to set "useSingleCpuIO=.TRUE." in file "data",
C     namelist PARAM01  (and to keep the default value of globalFiles=FALSE)
C   or if you are really sure that the globalFile works well on our platform
C     & compiler, comment out the above "stop"
C-----
        WRITE(msgBuf,'(2A)')
     &   '** WARNING ** INI_MODEL_IO: globalFiles=TRUE is not safe',
     &   ' in Multi-processors (MPI) run'
        CALL PRINT_MESSAGE( msgBuf, errorMessageUnit,
     &                      SQUEEZE_RIGHT, myThid )
        WRITE(msgBuf,'(2A)') '** WARNING ** INI_MODEL_IO:',
     &   ' use instead "useSingleCpuIO=.TRUE."'
        CALL PRINT_MESSAGE( msgBuf, errorMessageUnit,
     &                      SQUEEZE_RIGHT, myThid )
        _END_MASTER( myThid )
      ENDIF

C-    Check size of IO buffers:
      useGlobalBuff = useSingleCpuIO
#ifdef CG2D_SINGLECPU_SUM
      useGlobalBuff = .TRUE.
#endif /* CG2D_SINGLECPU_SUM */
#ifdef ALLOW_EXCH2
      IF ( useGlobalBuff ) THEN
        xySize = exch2_global_Nx*exch2_global_Ny
#ifndef CG2D_SINGLECPU_SUM
        IF ( .NOT.W2_useE2ioLayOut ) xySize = Nx*Ny
#endif /* ndef CG2D_SINGLECPU_SUM */
        IF ( xySize.GT.W2_ioBufferSize ) THEN
          WRITE(msgBuf,'(A,2(I10,A))')
     &       'W2_ioBufferSize=', W2_ioBufferSize,
     &       ' <', xySize, ' = Size of Global 2-D map'
          CALL PRINT_ERROR( msgBuf, myThid )
          WRITE(msgBuf,'(2A)')
     &       'INI_MODEL_IO: increase W2_ioBufferSize',
     &       ' in "W2_EXCH2_SIZE.h" + recompile'
          CALL PRINT_ERROR( msgBuf, myThid )
          STOP 'ABNORMAL END: S/R INI_MODEL_IO (buffer size)'
        ENDIF
      ENDIF
#endif /* ALLOW_EXCH2 */
C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|

C-    Only Master-thread updates IO-parameter in Common blocks:
      _BEGIN_MASTER( myThid )

C-    Initialise AB starting level
C      notes: those could be modified when reading a pickup that does
C             not correspond to what is actually needed.
      tempStartAB = nIter0
      saltStartAB = nIter0
      mom_StartAB = nIter0
      nHydStartAB = nIter0
      IF ( startFromPickupAB2 ) tempStartAB = MIN( nIter0 , 1 )
      saltStartAB = tempStartAB
      mom_StartAB = tempStartAB
      nHydStartAB = tempStartAB
      dPhiNHstatus= 0

C-    Initialise Alternating pickup-suffix
      nCheckLev         = 1
      checkPtSuff(1)    = 'ckptA'
      checkPtSuff(2)    = 'ckptB'

C-    Flags specific to RW and MDSIO (and PLOT_FIELDS)
      printDomain = debugLevel.GE.debLevA

C-    now we make local directories with myProcessStr appended
      IF ( mdsioLocalDir .NE. ' ' ) THEN
        iL = ILNBLNK( mdsioLocalDir )
        WRITE(namBuf,'(3A)')
     &         ' mkdir -p ', mdsioLocalDir(1:iL),myProcessStr(1:4)
        pIL = 1 + ILNBLNK( namBuf )
        WRITE(standardMessageUnit,'(3A)')
     &  '==> SYSTEM CALL (from INI_MODEL_IO): >',namBuf(1:pIL),'<'
        CALL SYSTEM( namBuf(1:pIL) )
        namBuf(1:iL) = mdsioLocalDir(1:iL)
        WRITE(mdsioLocalDir,'(3A)') namBuf(1:iL),myProcessStr(1:4),'/'
      ENDIF

C     append "/", if necessay
      IF ( adTapeDir .NE. ' ' ) THEN
       iL = ILNBLNK( adTapeDir )
       IF ( iL .LT. MAX_LEN_FNAM .AND. adTapeDir(iL:iL) .NE. '/' ) THEN
        namBuf(1:iL) = adTapeDir(1:iL)
        WRITE(adTapeDir(1:iL+1),'(2A)') namBuf(1:iL),'/'
       ENDIF
      ENDIF

C-    Initialise MFLDS variables in common block
      CALL READ_MFLDS_INIT( myThid )

C     Set globalFiles flag for READ_WRITE_FLD package
      CALL SET_WRITE_GLOBAL_FLD( globalFiles )
C     Set globalFiles flag for READ_WRITE_REC package
      CALL SET_WRITE_GLOBAL_REC( globalFiles )
C     Set globalFiles flag for READ_WRITE_SEC package
      IF ( useOBCS .AND. globalFiles ) THEN
        WRITE(msgBuf,'(2A)') '** WARNING ** INI_MODEL_IO:',
     &   ' use tiled-files to write sections (for OBCS)'
        CALL PRINT_MESSAGE( msgBuf, errorMessageUnit,
     &                      SQUEEZE_RIGHT, myThid )
        CALL SET_WRITE_GLOBAL_SEC( .FALSE. )
      ELSE
        CALL SET_WRITE_GLOBAL_SEC( globalFiles )
      ENDIF
C     Set globalFiles flag for READ_WRITE_PICKUP
      CALL SET_WRITE_GLOBAL_PICKUP( globalFiles )

      _END_MASTER( myThid )
C-    Everyone else must wait for the IO-parameters to be set
      _BARRIER

C-    Global IO-buffers initialisation
      IF ( useGlobalBuff ) THEN
        _BEGIN_MASTER( myThid )
        DO i=1,xyBuffer_size
          xy_buffer_r8(i) = 0. _d 0
          xy_buffer_r4(i) = 0.
        ENDDO
        _END_MASTER( myThid )
      ENDIF

C-    MNC model-io initialisation

#ifdef ALLOW_MNC
      IF (useMNC) THEN

C-    Initialize look-up tables for MNC
        CALL MNC_INIT( myThid )
        CALL MNC_CW_INIT( sNx,sNy,OLx,OLy,nSx,nSy,nPx,nPy,
     &                    Nr,myThid )
CEH3       IF ( mnc_echo_gvtypes ) THEN
CEH3       CALL MNC_CW_DUMP( myThid )
CEH3       ENDIF

C       Write units/set precision/etc for I/O of variables/arrays
C       belonging to the core dynamical model
        CALL INI_MNC_VARS( myThid )

      ENDIF
#endif /* ALLOW_MNC */

#ifdef ALLOW_AUTODIFF
        CALL AUTODIFF_INI_MODEL_IO( myThid )
#endif

#ifdef ALLOW_MONITOR
C--   Initialise MONITOR I/O streams so we can report config. info
      CALL MON_INIT( myThid )
#endif

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|

      RETURN
      END
