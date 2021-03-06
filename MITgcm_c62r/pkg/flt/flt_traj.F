C $Header: /u/gcmpack/MITgcm/pkg/flt/flt_traj.F,v 1.12 2010/12/27 19:21:23 jmc Exp $
C $Name: checkpoint62r $

#include "FLT_OPTIONS.h"


      SUBROUTINE FLT_TRAJ (
     I                      myTime, myIter, myThid )

C     ==================================================================
C     SUBROUTINE FLT_TRAJ
C     ==================================================================
C     o This routine samples the model state at float position every
C       flt_int_traj time steps and writes output.
C     ==================================================================

C     !USES:
      IMPLICIT NONE

C     == global variables ==
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "DYNVARS.h"
#include "FLT_SIZE.h"
#include "FLT.h"
#ifdef ALLOW_EXCH2
#include "W2_EXCH2_SIZE.h"
#include "W2_EXCH2_TOPOLOGY.h"
#endif

C     == routine arguments ==
      _RL myTime
      INTEGER myIter, myThid

C     === Functions ==
      _RL FLT_MAP_K2R
      EXTERNAL FLT_MAP_K2R

C     == local variables ==
      INTEGER bi, bj, imax
      PARAMETER (imax=13)
      INTEGER ip, kp, ii
      _RL ix, jy, i0x, j0y, xx, yy, zz
      _RL uu, vv, tt, ss, pp

      _RL tmp(imax)
      _RL npart_read,npart_times
      _RS dummyRS(1)
      INTEGER fp, ioUnit, irecord
      CHARACTER*(MAX_LEN_FNAM) fn
      CHARACTER*(MAX_LEN_MBUF) msgBuf
#ifdef ALLOW_EXCH2
      INTEGER nT
#endif

C     == end of interface ==

      fn = 'float_trajectories'
      fp = writeBinaryPrec

      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)

C (1) read actual number floats from file (if exists)
         ioUnit = -2
         CALL MDS_READVEC_LOC(  fn, fp, ioUnit,
     &                          'RL', imax, tmp, dummyRS,
     &                           bi, bj, 1, myThid )
         IF ( ioUnit.GT. 0 ) THEN
            npart_read  = tmp(1)
            npart_times = tmp(5)
C-       close the read-unit (safer to use a different unit for writing)
            CLOSE( ioUnit )
         ELSE
            npart_read  = 0.
            npart_times = 0.
            tmp(2)      = myTime
         ENDIF

C the standard routine mds_writevec_loc can be used here
C (2) WRITE new actual number floats and time axis into file
C
C total number of records in this file
         tmp(1) = DBLE(npart_tile(bi,bj))+npart_read
C first time of writing floats (do not change when written)
c        tmp(2) = tmp(2)
C current time
         tmp(3) = myTime
C timestep
         tmp(4) = flt_int_traj
C total number of timesteps
         tmp(5) = npart_times + 1.
C total number of floats
         tmp(6) = max_npart
         DO ii=7,imax
            tmp(ii) = 0.
         ENDDO

         ioUnit = -1
         CALL MDS_WRITEVEC_LOC( fn, fp, ioUnit,
     &                          'RL', imax, tmp, dummyRS,
     &                           bi,bj,-1, myIter, myThid )

#ifdef ALLOW_EXCH2
         nT = W2_myTileList(bi,bj)
         i0x = DFLOAT( exch2_txGlobalo(nT) - 1 )
         j0y = DFLOAT( exch2_tyGlobalo(nT) - 1 )
#else
         i0x = DFLOAT( myXGlobalLo-1 + (bi-1)*sNx )
         j0y = DFLOAT( myYGlobalLo-1 + (bj-1)*sNy )
#endif
         DO ip=1,npart_tile(bi,bj)

            ix = ipart(ip,bi,bj)
            jy = jpart(ip,bi,bj)
            CALL FLT_MAP_IJLOCAL2XY( xx, yy,
     I                               ix, jy, bi,bj, myThid )
            zz = FLT_MAP_K2R( kpart(ip,bi,bj),bi,bj,myThid )
            kp = NINT(kpart(ip,bi,bj))
            tmp(1)  = npart(ip,bi,bj)
            tmp(2)  = myTime
            tmp(3)  = xx
            tmp(4)  = yy
            tmp(5)  = zz
            tmp(6)  = ix + i0x
            tmp(7)  = jy + j0y
            tmp(8)  = kpart(ip,bi,bj)

            IF ( ( myTime.GE.tstart(ip,bi,bj)) .AND.
     &           ( tend(ip,bi,bj).EQ.-1. .OR. myTime.LE.tend(ip,bi,bj))
     &         ) THEN

              IF ( kp.LT.1 .OR. kp.GT.Nr ) THEN
                WRITE(msgBuf,'(2A,I8)') '** WARNING ** FLT_TRAJ: ',
     &            ' illegal value for kp=',kp
                CALL PRINT_MESSAGE( msgBuf, errorMessageUnit,
     &                              SQUEEZE_RIGHT, myThid )
                WRITE(msgBuf,'(A,1P5E20.13)')
     &            ' FLT_TRAJ: ', (tmp(ii),ii=1,5)
                CALL PRINT_MESSAGE( msgBuf, errorMessageUnit,
     &                              SQUEEZE_RIGHT, myThid )
c               CALL PRINT_ERROR( msgBuf, myThid )
c               STOP 'ABNORMAL END: S/R FLT_TRAJ'
C-- jmc: not sure if this is right but added to avoid Pb in FLT_BILINEAR:
                kp = MIN( MAX(kp,1), Nr)
              ENDIF

              CALL FLT_BILINEAR  (ix,jy,uu,uVel,  kp,1,bi,bj,myThid)
              CALL FLT_BILINEAR  (ix,jy,vv,vVel,  kp,2,bi,bj,myThid)
              CALL FLT_BILINEAR2D(ix,jy,pp,etaN,     0,bi,bj,myThid)
              CALL FLT_BILINEAR  (ix,jy,tt,theta, kp,0,bi,bj,myThid)
              CALL FLT_BILINEAR  (ix,jy,ss,salt,  kp,0,bi,bj,myThid)

              tmp( 9) = pp
              tmp(10) = uu
              tmp(11) = vv
              tmp(12) = tt
              tmp(13) = ss
            ELSE
              tmp( 9) = flt_nan
              tmp(10) = flt_nan
              tmp(11) = flt_nan
              tmp(12) = flt_nan
              tmp(13) = flt_nan
            ENDIF

C (3) WRITE float positions into file
            irecord = npart_read+ip+1
            IF ( ip.NE.npart_tile(bi,bj) ) irecord = -irecord
            CALL MDS_WRITEVEC_LOC( fn, fp, ioUnit,
     &                            'RL', imax, tmp, dummyRS,
     &                             bi,bj,irecord, myIter, myThid )

         ENDDO
         CLOSE( ioUnit )

       ENDDO
      ENDDO

      RETURN
      END
