C $Header: /u/gcmpack/MITgcm/pkg/atm2d/DRIVER.h,v 1.6 2009/09/02 16:19:27 jscott Exp $
C $Name: checkpoint62r $

      COMMON /DRIVER_VARS/
     &        dtcouple, dtatm, dtocn, startYear, endYear, taveDump,
     &        ncall_atm, ncall_ocean
       INTEGER dtcouple  ! coupling period (hrs)
       INTEGER dtatm     ! atmos time step (hrs)
       INTEGER dtocn     ! ocean time step (hrs)
       INTEGER startYear ! starting year of simulation (jan 1)
       INTEGER endYear   ! ending year of simulation (dec 31)
       INTEGER taveDump  ! frequency of tave dumps for atm2ocn fluxes (yrs)
       INTEGER ncall_atm ! number of atm steps in a coupling period
       INTEGER ncall_ocean ! number of ocn steps in a coupling period


      COMMON /DRIVER_FILENAMES/
     &         caruptfile, fnememiss, last_nep
      CHARACTER*120 caruptfile, fnememiss, last_nep

#ifdef CPL_TEM
      COMMON /DRIVER_VAR_TEM/
     &          nepan, nepav, n2oann, n2omn, nepmn,
     &          aocuav, ch4ann, ch4mn, xco2ann, nfile
       REAL*8 nepan, nepav, n2oann, n2omn, nepmn
       REAL*8 aocuav, ch4ann, ch4mn, xco2ann
       INTEGER nfile
#endif

#ifdef CPL_OCEANCO2
#  include "OCM.h"
      COMMON /DRIVER_VAR_CO2/
     &         ocumn, ocuptp, fluxco2mn
       REAL*8 ocumn
       REAL*8 ocuptp
       REAL*8 fluxco2mn(jm0)

      COMMON /GARYFLUX/pC_atm, wind_amp, fluxco2
       REAL*8 pC_atm(jm0)
       REAL*8 wind_amp
       REAL*8 fluxco2(jm0)
#endif

#ifdef IPCC_EMI
      COMMON /DRIVER_VAR_IPCC/nemis
       INTEGER nemis

      COMMON/ BACKGRGHG/ghgbgr
       REAL*8 ghgbgr(5)
#endif

#ifdef CLM
#  include "CLM.h"
#  ifdef CPL_TEM
#    include "TEM.h"
      external tem2climate,updatelcluc,tem,tem_init,lcluc_init,
     &   temclm_init
#  endif
#endif
