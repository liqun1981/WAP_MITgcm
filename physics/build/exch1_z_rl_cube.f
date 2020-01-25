C $Header: /u/gcmpack/MITgcm/eesupp/src/exch1_z_rx_cube.template,v 1.1 2010/05/19 01:46:11 jmc Exp $
C $Name: checkpoint62r $

#include "CPP_EEOPTIONS.h"

CBOP

C     !ROUTINE: EXCH1_Z_RL_CUBE

C     !INTERFACE:
      SUBROUTINE EXCH1_Z_RL_CUBE(
     U                 array,
     I                 withSigns,
     I                 myOLw, myOLe, myOLs, myOLn, myNz,
     I                 exchWidthX, exchWidthY,
     I                 cornerMode, myThid )

C     !DESCRIPTION:
C     *==========================================================*
C     | SUBROUTINE EXCH1_Z_RL_CUBE
C     | o Forward-mode edge exchanges for RL array on CS config:
C     |   Fill overlap region through tile exchanges,
C     |   according to CS topology,
C     |   for a Zeta-located, scalar field RL arrays.
C     *==========================================================*
C     | Controlling routine for exchange of XY edges of an array
C     | distributed in X and Y. The routine interfaces to
C     | communication routines that can use messages passing
C     | exchanges, put type exchanges or get type exchanges.
C     |  This allows anything from MPI to raw memory channel to
C     | memmap segments to be used as a inter-process and/or
C     | inter-thread communiation and synchronisation
C     | mechanism.
C     | Notes --
C     | 1. Some low-level mechanisms such as raw memory-channel
C     | or SGI/CRAY shmem put do not have direct Fortran bindings
C     | and are invoked through C stub routines.
C     | 2. Although this routine is fairly general but it does
C     | require nSx and nSy are the same for all innvocations.
C     | There are many common data structures ( myByLo,
C     | westCommunicationMode, mpiIdW etc... ) tied in with
C     | (nSx,nSy). To support arbitray nSx and nSy would require
C     | general forms of these.
C     | 3. zeta coord exchange operation for cube sphere grid
C     *==========================================================*

C     !USES:
      IMPLICIT NONE

C     == Global data ==
#include "SIZE.h"
#include "EEPARAMS.h"

C     !INPUT/OUTPUT PARAMETERS:
C     == Routine arguments ==
C     array       :: Array with edges to exchange.
C     withSigns   :: Flag controlling whether field sign depends on orientation
C                 :: (signOption not yet implemented but needed for SM exch)
C     myOLw,myOLe :: West  and East  overlap region sizes.
C     myOLs,myOLn :: South and North overlap region sizes.
C     exchWidthX  :: Width of data region exchanged in X.
C     exchWidthY  :: Width of data region exchanged in Y.
C                    Note --
C                    1. In theory one could have a send width and
C                    a receive width for each face of each tile. The only
C                    restriction would be that the send width of one
C                    face should equal the receive width of the sent to
C                    tile face. Dont know if this would be useful. I
C                    have left it out for now as it requires additional
C                    bookeeping.
C     cornerMode  :: Flag indicating whether corner updates are needed.
C     myThid      :: my Thread Id number

      INTEGER myOLw, myOLe, myOLs, myOLn, myNz
      _RL     array( 1-myOLw:sNx+myOLe,
     &               1-myOLs:sNy+myOLn,
     &               myNz, nSx, nSy )
      LOGICAL withSigns
      INTEGER exchWidthX
      INTEGER exchWidthY
      INTEGER cornerMode
      INTEGER myThid

C     !LOCAL VARIABLES:
C     == Local variables ==
C     theSimulationMode :: Holds working copy of simulation mode
C     theCornerMode     :: Holds working copy of corner mode
C     I,J,K,repeat      :: Loop counters and index
C     bl,bt,bn,bs,be,bw :: tile indices
c     INTEGER theSimulationMode
c     INTEGER theCornerMode
      INTEGER I,J,K,repeat
      INTEGER bl,bt,bn,bs,be,bw
      CHARACTER*(MAX_LEN_MBUF) msgBuf

C     == Statement function ==
      INTEGER tilemod
      tilemod(I)=1+mod(I-1+6,6)
CEOP

c     theSimulationMode = FORWARD_SIMULATION
c     theCornerMode     = cornerMode

c     IF ( simulationMode.EQ.REVERSE_SIMULATION ) THEN
c       WRITE(msgBuf,'(A)')'EXCH1_Z_RL_CUBE: AD mode not implemented'
c       CALL PRINT_ERROR( msgBuf, myThid )
c       STOP 'ABNORMAL END: EXCH1_Z_RL_CUBE: no AD code'
c     ENDIF
      IF ( sNx.NE.sNy .OR.
     &     nSx.NE.6 .OR. nSy.NE.1 .OR.
     &     nPx.NE.1 .OR. nPy.NE.1 ) THEN
        WRITE(msgBuf,'(2A)') 'EXCH1_Z_RL_CUBE: Wrong Tiling'
        CALL PRINT_ERROR( msgBuf, myThid )
        WRITE(msgBuf,'(2A)') 'EXCH1_Z_RL_CUBE: ',
     &   'works only with sNx=sNy & nSx=6 & nSy=nPx=nPy=1'
        CALL PRINT_ERROR( msgBuf, myThid )
        STOP 'ABNORMAL END: EXCH1_Z_RL_CUBE: Wrong Tiling'
      ENDIF

C     For now tile<->tile exchanges are sequentialised through
C     thread 1. This is a temporary feature for preliminary testing until
C     general tile decomposistion is in place (CNH April 11, 2001)
      CALL BAR2( myThid )
      IF ( myThid .EQ. 1 ) THEN

       DO repeat=1,2

       DO bl = 1, 5, 2

        bt = bl
        bn=tilemod(bt+2)
        bs=tilemod(bt-1)
        be=tilemod(bt+1)
        bw=tilemod(bt-2)

        DO K = 1, myNz
         DO J = 1, sNy+1
          DO I = 0, exchWidthX-1

C          Tile Odd:Odd+2 [get] [North<-West]
           array(J,sNy+I+1,K,bt,1) = array(I+1,sNy+2-J,K,bn,1)
C          Tile Odd:Odd+1 [get] [East<-West]
           array(sNx+I+1,J,K,bt,1) = array(I+1,J,K,be,1)

cs- these above loop should really have the same range the lower one
          ENDDO
          DO I = 1, exchWidthX-0
cs- but this replaces the missing I/O routines for now

C          Tile Odd:Odd-1 [get] [South<-North]
           array(J,1-I,K,bt,1) = array(J,sNy+1-I,K,bs,1)
C          Tile Odd:Odd-2 [get] [West<-North]
           array(1-I,J,K,bt,1) = array(sNx+2-J,sNy+1-I,K,bw,1)

          ENDDO
         ENDDO
        ENDDO

        bt = bl+1
        bn=tilemod(bt+1)
        bs=tilemod(bt-2)
        be=tilemod(bt+2)
        bw=tilemod(bt-1)

        DO K = 1, myNz
         DO J = 1, sNy+1
          DO I = 0, exchWidthX-1

C          Tile Even:Even+1 [get] [North<-South]
           array(J,sNy+I+1,K,bt,1) = array(J,I+1,K,bn,1)
C          Tile Even:Even+2 [get] [East<-South]
           array(sNx+I+1,J,K,bt,1) = array(sNx+2-J,I+1,K,be,1)

cs- these above loop should really have the same range the lower one
          ENDDO
          DO I = 1, exchWidthX-0
cs- but this replaces the missing I/O routines for now

C          Tile Even:Even-2 [get] [South<-East]
           array(J,1-I,K,bt,1) = array(sNx+1-I,sNy+2-J,K,bs,1)
C          Tile Even:Even-1 [get] [West<-East]
           array(1-I,J,K,bt,1) = array(sNx+1-I,J,K,bw,1)

          ENDDO
         ENDDO
        ENDDO

       ENDDO

       ENDDO

      ENDIF
      CALL BAR2(myThid)

      RETURN
      END
