C $Header: /u/gcmpack/MITgcm/pkg/offline/offline_fields_load.F,v 1.18 2010/04/03 22:34:26 jmc Exp $
C $Name: checkpoint62r $

#include "OFFLINE_OPTIONS.h"

C     !ROUTINE: OFFLINE_FIELDS_LOAD
C     !INTERFACE:
      SUBROUTINE OFFLINE_FIELDS_LOAD( myTime, myIter, myThid )
C     *==========================================================*
C     | SUBROUTINE OFFLINE_FIELDS_LOAD
C     | o Control reading of fields from external source.
C     *==========================================================*
C     | Offline External source field loading routine.
C     | This routine is called every time we want to
C     | load a a set of external fields. The routine decides
C     | which fields to load and then reads them in.
C     | This routine needs to be customised for particular
C     | experiments.
C     | Notes
C     | =====
C     | currently the file names need to be specific lengths
C     | would like to make this more flexible QQ
C     *==========================================================*

C     !USES:
      IMPLICIT NONE
C     === Global variables ===
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "FFIELDS.h"
#include "GRID.h"
#include "DYNVARS.h"
#ifdef ALLOW_GMREDI
#include "GMREDI.h"
#include "GMREDI_TAVE.h"
#endif
#ifdef ALLOW_KPP
#include "KPP.h"
#endif
#ifdef ALLOW_OFFLINE
#include "OFFLINE.h"
#endif

C     !INPUT/OUTPUT PARAMETERS:
C     === Routine arguments ===
C     myTime  :: Simulation time
C     myIter  :: Simulation timestep number
C     myThid  :: Thread no. that called this routine.
      _RL     myTime
      INTEGER myIter
      INTEGER myThid

#ifdef ALLOW_OFFLINE
C     !FUNCTIONS:
      INTEGER  IFNBLNK, ILNBLNK
      EXTERNAL IFNBLNK, ILNBLNK

C     !LOCAL VARIABLES:
C     fn      :: Temp. for building file name.
      CHARACTER*(MAX_LEN_FNAM) fn
      INTEGER prec

C     === Local arrays ===

      INTEGER bi,bj,i,j,k,intime0,intime1
      _RL aWght,bWght,rdt
      INTEGER nForcingPeriods,Imytm,Ifprd,Ifcyc,Iftm
      INTEGER I1, I2

      prec = offlineLoadPrec

c      IF ( offlinePeriodicExternalLoad ) THEN
      IF ( .TRUE. ) THEN

C First call requires that we initialize everything to zero for safety
      IF ( myIter .EQ. nIter0 ) THEN
       CALL LEF_ZERO3( uvel0 ,myThid )
       CALL LEF_ZERO3( vvel0 ,myThid )
       CALL LEF_ZERO3( wvel0 ,myThid )
       CALL LEF_ZERO3( tave0 ,myThid )
       CALL LEF_ZERO3( save0 ,myThid )
       CALL LEF_ZERO3( conv0 ,myThid )
       CALL LEF_ZERO3( gmkx0 ,myThid )
       CALL LEF_ZERO3( gmky0 ,myThid )
       CALL LEF_ZERO3( gmkz0 ,myThid )
       CALL LEF_ZERO2( hflx0 ,myThid )
       CALL LEF_ZERO2( sflx0 ,myThid )
       CALL LEF_ZERO2( icem0 ,myThid )
       CALL LEF_ZERO3( kdfs0 ,myThid )
       CALL LEF_ZERO3( kght0 ,myThid )
       CALL LEF_ZERO3( uvel1 ,myThid )
       CALL LEF_ZERO3( vvel1 ,myThid )
       CALL LEF_ZERO3( wvel1 ,myThid )
       CALL LEF_ZERO3( tave1 ,myThid )
       CALL LEF_ZERO3( save1 ,myThid )
       CALL LEF_ZERO3( conv1 ,myThid )
       CALL LEF_ZERO3( gmkx1 ,myThid )
       CALL LEF_ZERO3( gmky1 ,myThid )
       CALL LEF_ZERO3( gmkz1 ,myThid )
       CALL LEF_ZERO2( hflx1 ,myThid )
       CALL LEF_ZERO2( sflx1 ,myThid )
       CALL LEF_ZERO2( icem1 ,myThid )
       CALL LEF_ZERO3( kdfs1 ,myThid )
       CALL LEF_ZERO3( kght1 ,myThid )
      ENDIF

C Now calculate whether it is time to update the forcing arrays
      rdt = 1. _d 0 / deltaToffline
      nForcingPeriods = NINT(offlineForcingCycle/offlineForcingPeriod)
      Imytm = NINT(myTime*rdt-offlineOffsetIter)
      Ifprd = NINT(offlineForcingPeriod*rdt)
      Ifcyc = NINT(offlineForcingCycle*rdt)
      Iftm  = MOD( Imytm+Ifcyc-Ifprd/2, Ifcyc)

      intime0= 1 + INT(Iftm/Ifprd)
      intime1= 1 + MOD(intime0,nForcingPeriods)
c     aWght = DFLOAT( Iftm-Ifprd*(intime0 - 1) ) / DFLOAT( Ifprd )
      aWght = FLOAT( Iftm-Ifprd*(intime0 - 1) )
      bWght = FLOAT( Ifprd )
      aWght =  aWght / bWght
      bWght = 1. _d 0 - aWght

      IF (
     &  Iftm-Ifprd*(intime0-1) .EQ. 0
     &  .OR. myIter .EQ. nIter0
     & ) THEN

       _BARRIER

C      If the above condition is met then we need to read in
C      data for the period ahead and the period behind myTime.
       _BEGIN_MASTER(myThid)
       WRITE(standardMessageUnit,'(A,2I5,I10,1P1E20.12)')
     &  'S/R OFFLINE_FIELDS_LOAD: Reading new data:',
     &  intime0, intime1, myIter, myTime
       _END_MASTER(myThid)

#ifdef NOT_MODEL_FILES
C if reading own files setup reading here
#else

       IF ( Uvelfile      .NE. ' '  ) THEN
        I1=IFNBLNK(Uvelfile)
        I2=ILNBLNK(Uvelfile)
        WRITE(fn,'(A,A,I10.10)') Uvelfile(I1:I2),'.',
     &        intime0*Ifprd +offlineIter0
c       print*,'OFFLINE READ', fn
        CALL READ_REC_3D_RS( fn, prec, Nr, uvel0, 1, myIter, myThid )
        WRITE(fn,'(A,A,I10.10)') Uvelfile(I1:I2),'.',
     &        intime1*Ifprd +offlineIter0
c       print*,'OFFLINE READ', fn
        CALL READ_REC_3D_RS( fn, prec, Nr, uvel1, 1, myIter, myThid )
       ENDIF

       IF ( Vvelfile      .NE. ' '  ) THEN
        I1=IFNBLNK(Vvelfile)
        I2=ILNBLNK(Vvelfile)
        WRITE(fn,'(A,A,I10.10)') Vvelfile(I1:I2),'.',
     &        intime0*Ifprd +offlineIter0
        CALL READ_REC_3D_RS( fn, prec, Nr, vvel0, 1, myIter, myThid )
        WRITE(fn,'(A,A,I10.10)') Vvelfile(I1:I2),'.',
     &        intime1*Ifprd +offlineIter0
        CALL READ_REC_3D_RS( fn, prec, Nr, vvel1, 1, myIter, myThid )
       ENDIF

       IF (Wvelfile      .NE. ' '  ) THEN
        I1=IFNBLNK(Wvelfile)
        I2=ILNBLNK(Wvelfile)
        WRITE(fn,'(A,A,I10.10)') Wvelfile(I1:I2),'.',
     &        intime0*Ifprd +offlineIter0
        CALL READ_REC_3D_RS( fn, prec, Nr, wvel0, 1, myIter, myThid )
        WRITE(fn,'(A,A,I10.10)') Wvelfile(I1:I2),'.',
     &        intime1*Ifprd +offlineIter0
        CALL READ_REC_3D_RS( fn, prec, Nr, wvel1, 1, myIter, myThid )
       ENDIF

       IF (Thetfile      .NE. ' '  ) THEN
        I1=IFNBLNK(Thetfile)
        I2=ILNBLNK(Thetfile)
        WRITE(fn,'(A,A,I10.10)') Thetfile(I1:I2),'.',
     &        intime0*Ifprd +offlineIter0
        CALL READ_REC_3D_RS( fn, prec, Nr, tave0, 1, myIter, myThid )
        WRITE(fn,'(A,A,I10.10)') Thetfile(I1:I2),'.',
     &        intime1*Ifprd +offlineIter0
        CALL READ_REC_3D_RS( fn, prec, Nr, tave1, 1, myIter, myThid )
       ENDIF

       IF (Saltfile       .NE. ' ' ) THEN
        I1=IFNBLNK(Saltfile)
        I2=ILNBLNK(Saltfile)
        WRITE(fn,'(A,A,I10.10)') Saltfile(I1:I2),'.',
     &        intime0*Ifprd +offlineIter0
        CALL READ_REC_3D_RS( fn, prec, Nr, save0, 1, myIter, myThid )
        WRITE(fn,'(A,A,I10.10)') Saltfile(I1:I2),'.',
     &        intime1*Ifprd +offlineIter0
        CALL READ_REC_3D_RS( fn, prec, Nr, save1, 1, myIter, myThid )
       ENDIF

       IF (ConvFile       .NE. ' ' ) THEN
        I1=IFNBLNK(ConvFile)
        I2=ILNBLNK(ConvFile)
        WRITE(fn,'(A,A,I10.10)') ConvFile(I1:I2),'.',
     &        intime0*Ifprd +offlineIter0
        CALL READ_REC_3D_RS( fn, prec, Nr, conv0, 1, myIter, myThid )
        WRITE(fn,'(A,A,I10.10)') ConvFile(I1:I2),'.',
     &        intime1*Ifprd +offlineIter0
        CALL READ_REC_3D_RS( fn, prec, Nr, conv1, 1, myIter, myThid )
       ENDIF

#ifdef ALLOW_GMREDI
       IF (GMwxFile       .NE. ' ' ) THEN
        I1=IFNBLNK(GMwxFile)
        I2=ILNBLNK(GMwxFile)
        WRITE(fn,'(A,A,I10.10)') GMwxFile(I1:I2),'.',
     &        intime0*Ifprd +offlineIter0
        CALL READ_REC_3D_RS( fn, prec, Nr, gmkx0, 1, myIter, myThid )
        WRITE(fn,'(A,A,I10.10)') GMwxFile(I1:I2),'.',
     &        intime1*Ifprd +offlineIter0
        CALL READ_REC_3D_RS( fn, prec, Nr, gmkx1, 1, myIter, myThid )
       ENDIF

       IF (GMwyFile       .NE. ' ') THEN
        I1=IFNBLNK(GMwyFile)
        I2=ILNBLNK(GMwyFile)
        WRITE(fn,'(A,A,I10.10)') GMwyFile(I1:I2),'.',
     &        intime0*Ifprd +offlineIter0
        CALL READ_REC_3D_RS( fn, prec, Nr, gmky0, 1, myIter, myThid )
        WRITE(fn,'(A,A,I10.10)') GMwyFile(I1:I2),'.',
     &        intime1*Ifprd +offlineIter0
        CALL READ_REC_3D_RS( fn, prec, Nr, gmky1, 1, myIter, myThid )
       ENDIF

       IF (GMwzFile       .NE. ' ') THEN
        I1=IFNBLNK(GMwzFile)
        I2=ILNBLNK(GMwzFile)
        WRITE(fn,'(A,A,I10.10)') GMwzFile(I1:I2),'.',
     &        intime0*Ifprd +offlineIter0
        CALL READ_REC_3D_RS( fn, prec, Nr, gmkz0, 1, myIter, myThid )
        WRITE(fn,'(A,A,I10.10)') GMwzFile(I1:I2),'.',
     &        intime1*Ifprd +offlineIter0
        CALL READ_REC_3D_RS( fn, prec, Nr, gmkz1, 1, myIter, myThid )
       ENDIF
#endif

       IF (HFluxFile      .NE. ' ') THEN
        I1=IFNBLNK(HFluxFile)
        I2=ILNBLNK(HFluxFile)
        WRITE(fn,'(A,A,I10.10)') HFluxFile(I1:I2),'.',
     &        intime0*Ifprd +offlineIter0
        CALL READ_REC_3D_RS( fn, prec,  1, hflx0, 1, myIter, myThid )
        WRITE(fn,'(A,A,I10.10)') HFluxFile(I1:I2),'.',
     &        intime1*Ifprd +offlineIter0
        CALL READ_REC_3D_RS( fn, prec,  1, hflx1, 1, myIter, myThid )
       ENDIF

       IF (SFluxFile      .NE. ' ') THEN
        I1=IFNBLNK(SFluxFile)
        I2=ILNBLNK(SFluxFile)
        WRITE(fn,'(A,A,I10.10)') SFluxFile(I1:I2),'.',
     &        intime0*Ifprd +offlineIter0
        CALL READ_REC_3D_RS( fn, prec,  1, sflx0, 1, myIter, myThid )
        WRITE(fn,'(A,A,I10.10)') SFluxFile(I1:I2),'.',
     &        intime1*Ifprd +offlineIter0
        CALL READ_REC_3D_RS( fn, prec,  1, sflx1, 1, myIter, myThid )
       ENDIF

       IF (IceFile      .NE. ' ') THEN
        I1=IFNBLNK(IceFile)
        I2=ILNBLNK(IceFile)
        WRITE(fn,'(A,A,I10.10)') IceFile(I1:I2),'.',
     &        intime0*Ifprd +offlineIter0
        CALL READ_REC_3D_RS( fn, prec,  1, icem0, 1, myIter, myThid )
        WRITE(fn,'(A,A,I10.10)') IceFile(I1:I2),'.',
     &        intime1*Ifprd +offlineIter0
        CALL READ_REC_3D_RS( fn, prec,  1, icem1, 1, myIter, myThid )
       ENDIF

#ifdef ALLOW_KPP
       IF (KPP_DiffSFile      .NE. ' ') THEN
        I1=IFNBLNK(KPP_DiffSFile)
        I2=ILNBLNK(KPP_DiffSFile)
        WRITE(fn,'(A,A,I10.10)') KPP_DiffSFile(I1:I2),'.',
     &        intime0*Ifprd +offlineIter0
        CALL READ_REC_3D_RS( fn, prec, Nr, kdfs0, 1, myIter, myThid )
        WRITE(fn,'(A,A,I10.10)') KPP_DiffSFile(I1:I2),'.',
     &        intime1*Ifprd +offlineIter0
        CALL READ_REC_3D_RS( fn, prec, Nr, kdfs1, 1, myIter, myThid )
       ENDIF

       IF (KPP_ghatKFile     .NE. ' ') THEN
C-- Note: assume that KPP_ghatKFile contains the product ghat*diffKzS
C         even if, for convienience, it will be loaded into array KPPghat
        I1=IFNBLNK(KPP_ghatKFile)
        I2=ILNBLNK(KPP_ghatKFile)
        WRITE(fn,'(A,A,I10.10)') KPP_ghatKFile(I1:I2),'.',
     &        intime0*Ifprd +offlineIter0
        CALL READ_REC_3D_RS( fn, prec, Nr, kght0, 1, myIter, myThid )
        WRITE(fn,'(A,A,I10.10)') KPP_ghatKFile(I1:I2),'.',
     &        intime1*Ifprd +offlineIter0
        CALL READ_REC_3D_RS( fn, prec, Nr, kght1, 1, myIter, myThid )
       ENDIF
#endif

#endif /* else NOT_MODEL_FILES */

       CALL EXCH_UV_XYZ_RS( uvel0, vvel0, .TRUE., myThid )
       CALL EXCH_UV_XYZ_RS( uvel1, vvel1, .TRUE., myThid )
       _EXCH_XYZ_RS(wvel0, myThid )
       _EXCH_XYZ_RS(wvel1, myThid )
       _EXCH_XYZ_RS(tave0 , myThid )
       _EXCH_XYZ_RS(tave1 , myThid )
       _EXCH_XYZ_RS(save0, myThid )
       _EXCH_XYZ_RS(save1, myThid )
       _EXCH_XYZ_RS(conv0, myThid )
       _EXCH_XYZ_RS(conv1, myThid )
       CALL EXCH_UV_AGRID_3D_RS( gmkx0, gmky0, .FALSE., Nr, myThid )
       CALL EXCH_UV_AGRID_3D_RS( gmkx1, gmky1, .FALSE., Nr, myThid )
       _EXCH_XYZ_RS(gmkz0, myThid )
       _EXCH_XYZ_RS(gmkz1, myThid )
       _EXCH_XY_RS(hflx0 , myThid )
       _EXCH_XY_RS(hflx1 , myThid )
       _EXCH_XY_RS(sflx0, myThid )
       _EXCH_XY_RS(sflx1, myThid )
       _EXCH_XY_RS(icem0, myThid )
       _EXCH_XY_RS(icem1, myThid )
       _EXCH_XYZ_RS(kdfs0 , myThid )
       _EXCH_XYZ_RS(kdfs1 , myThid )
       _EXCH_XYZ_RS(kght0, myThid )
       _EXCH_XYZ_RS(kght1, myThid )

      ENDIF

C--   Interpolate uvel, vvel, wvel
      DO bj = myByLo(myThid), myByHi(myThid)
      DO bi = myBxLo(myThid), myBxHi(myThid)
       DO k=1,Nr
        DO j=1-Oly,sNy+Oly
         DO i=1-Olx,sNx+Olx
          Uvel(i,j,k,bi,bj)   = bWght*uvel0(i,j,k,bi,bj)
     &                       +aWght*uvel1(i,j,k,bi,bj)
          Vvel(i,j,k,bi,bj)    = bWght*vvel0(i,j,k,bi,bj)
     &                       +aWght*vvel1(i,j,k,bi,bj)
          Wvel(i,j,k,bi,bj)    =  bWght*wvel0(i,j,k,bi,bj)
     &                       +aWght*wvel1(i,j,k,bi,bj)
          theta(i,j,k,bi,bj)    = bWght*tave0(i,j,k,bi,bj)
     &                       +aWght*tave1(i,j,k,bi,bj)
          salt(i,j,k,bi,bj)    =  bWght*save0(i,j,k,bi,bj)
     &                       +aWght*save1(i,j,k,bi,bj)
          ConvectCount(i,j,k,bi,bj) =  bWght*conv0(i,j,k,bi,bj)
     &                       +aWght*conv1(i,j,k,bi,bj)
          IVDConvCount(i,j,k,bi,bj) =  bWght*conv0(i,j,k,bi,bj)
     &                       +aWght*conv1(i,j,k,bi,bj)
#ifdef ALLOW_GMREDI
          Kwx(i,j,k,bi,bj)    =  bWght*gmkx0(i,j,k,bi,bj)
     &                       +aWght*gmkx1(i,j,k,bi,bj)
          Kwy(i,j,k,bi,bj)    =  bWght*gmky0(i,j,k,bi,bj)
     &                       +aWght*gmky1(i,j,k,bi,bj)
          Kwz(i,j,k,bi,bj)    =  bWght*gmkz0(i,j,k,bi,bj)
     &                       +aWght*gmkz1(i,j,k,bi,bj)
#endif
#ifdef ALLOW_KPP
          KPPdiffKzS(i,j,k,bi,bj) = bWght*kdfs0(i,j,k,bi,bj)
     &                       +aWght*kdfs1(i,j,k,bi,bj)
C-- Note: for convenience, the array KPPghat will contain
C         the product ghat*diffKzS (and not ghat alone).
          KPPghat(i,j,k,bi,bj) = bWght*kght0(i,j,k,bi,bj)
     &                       +aWght*kght1(i,j,k,bi,bj)
#endif
         ENDDO
        ENDDO
       ENDDO
       DO j=1-Oly,sNy+Oly
        DO i=1-Olx,sNx+Olx
          surfaceForcingT(i,j,bi,bj) = bWght*hflx0(i,j,bi,bj)
     &                       +aWght*hflx1(i,j,bi,bj)
          surfaceForcingT(i,j,bi,bj) = surfaceForcingT(i,j,bi,bj)
     &                      *recip_Cp*mass2rUnit
          surfaceForcingS(i,j,bi,bj) =  bWght*sflx0(i,j,bi,bj)
     &                       +aWght*sflx1(i,j,bi,bj)
          surfaceForcingS(i,j,bi,bj) = surfaceForcingS(i,j,bi,bj)
     &                               *mass2rUnit

          ICEM(i,j,bi,bj) =  bWght*icem0(i,j,bi,bj)
     &                       +aWght*icem1(i,j,bi,bj)
        ENDDO
       ENDDO
C--   end bi,bj loops
      ENDDO
      ENDDO

CC-- Diagnostics
C      IF (myThid.EQ.1 .AND. myTime.LT.62208000.) THEN
C        write(*,'(a,1p5e12.4,3i6,2e12.4)')
C     &   'time,U,V,W,i0,i1,a,b = ',
C     &   myTime,
C     &   Uvel(1,sNy,1,1,1),Vvel(1,sNy,1,1,1),
C     &   Wvel(1,sNy,1,1,1),
C     &   intime0,intime1,aWght,bWght
C        write(*,'(a,1p4e12.4,2e12.4)')
C     &   'time,uvel0,uvel1,U = ',
C     &   myTime,
C     &   uvel0(1,sNy,1,1,1),uvel1(1,sNy,1,1,1),Uvel(1,sNy,1,1,1),
C     &   aWght,bWght
C      ENDIF

C endif for periodicForcing
      ENDIF

#endif /* ALLOW_OFFLINE */

      RETURN
      END

C     !ROUTINE: LEF_ZERO3
C     !INTERFACE:
      SUBROUTINE LEF_ZERO3( arr ,myThid )
C     !DESCRIPTION: \bv
C     This routine simply sets the argument array to zero
C     Used only by EXTERNAL_FIELDS_LOAD
C     \ev
C     !USES:
      IMPLICIT NONE
C     === Global variables ===
#include "SIZE.h"
#include "EEPARAMS.h"
C     !INPUT/OUTPUT PARAMETERS:
C     === Arguments ===
      _RS  arr (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      INTEGER myThid
C     !LOCAL VARIABLES:
C     === Local variables ===
      INTEGER i,j,bi,bj,k
CEOP

      DO bj = myByLo(myThid), myByHi(myThid)
       DO bi = myBxLo(myThid), myBxHi(myThid)
        do k=1,Nr
        DO j=1-Oly,sNy+Oly
         DO i=1-Olx,sNx+Olx
          arr(i,j,k,bi,bj)=0.
         ENDDO
        ENDDO
        enddo
       ENDDO
      ENDDO

      RETURN
      END

C     !ROUTINE: LEF_ZERO2
C     !INTERFACE:
      SUBROUTINE LEF_ZERO2( arr ,myThid )
C     !DESCRIPTION: \bv
C     This routine simply sets the argument array to zero
C     Used only by EXTERNAL_FIELDS_LOAD
C     \ev
C     !USES:
      IMPLICIT NONE
C     === Global variables ===
#include "SIZE.h"
#include "EEPARAMS.h"
C     !INPUT/OUTPUT PARAMETERS:
C     === Arguments ===
      _RS  arr (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      INTEGER myThid
C     !LOCAL VARIABLES:
C     === Local variables ===
      INTEGER i,j,bi,bj
CEOP
      DO bj = myByLo(myThid), myByHi(myThid)
       DO bi = myBxLo(myThid), myBxHi(myThid)
        DO j=1-Oly,sNy+Oly
         DO i=1-Olx,sNx+Olx
          arr(i,j,bi,bj)=0.
         ENDDO
        ENDDO
       ENDDO
      ENDDO

      RETURN
      END
