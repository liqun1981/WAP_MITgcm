C $Header: /u/gcmpack/MITgcm/pkg/atm2d/atm2d_init_vars.F,v 1.5 2009/09/17 15:27:46 jscott Exp $
C $Name: checkpoint62r $

#include "ctrparam.h"
C
      SUBROUTINE ATM2D_INIT_VARS(myThid)
C     |==========================================================|
C     | Initialization steps which depend on pickups loading.    |
C     \==========================================================/
      IMPLICIT NONE

#include "ATMSIZE.h"
#include "DRIVER.h"

C     !INPUT/OUTPUT PARAMETERS:
C     == Routine arguments ==
C     myThid - thread number for this instance of the routine.
      INTEGER myThid

C     === Local variables ===
      INTEGER j
#ifdef CPL_CHEM
        print *,' Before eppaemission'
        CALL eppaemission (0)
#endif

      CALL atmosphere(0,0)   ! initialize the atmospheric model

#ifdef CLM
      CALL clm4mit2d           ! initialize CLM
#endif

#ifdef ML_2D
C    2D mixed layer model  initialization
      CALL ocean_ml(dtocn*3600.,dtatm*3600.)
#  ifdef CPL_OCEANCO2
      CALL zerogary
#  endif
#endif

#ifdef CPL_TEM
      PRINT *,' Start of tem_init'
      aocuav=0.0
      nepav=0.0
#  ifdef DATA4TEM
      nfile=1
#  endif
#  ifdef CPL_NEM
      PRINT *,' Reading climate data to run NEM during '
      PRINT *, '  TEM iInitialization'
!     CALL rd_rstrt_nem
#  endif
c      call tem_init(inyear,lyear)
      CALL temclm_init
      CALL lcluc_init
      CALL updatelcluc(0)
      CALL tem_init
      adupt=0.0
      PRINT *,' TEM initialization finished'
#  ifdef CPL_NEM
!     CALL tem2climate(0,11)
      PRINT *,'CH4'
      PRINT *,(temch4(j),j=1,jm0)
      PRINT *,'N2O'
      PRINT *,(temn2o(j),j=1,jm0)
      PRINT *,'CO2'
      PRINT *,(temco2(j),j=1,jm0)
#  endif
#endif

#ifdef OCEAN_3D
      CALL ATM2D_READ_PICKUP(myThid)
#endif

      RETURN
      END
