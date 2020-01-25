C $Header: /u/gcmpack/MITgcm/verification/bottom_ctrl_5x5/code_ad/CPP_OPTIONS.h,v 1.3 2008/08/21 16:03:21 jmc Exp $
C $Name: checkpoint62r $

C
C CPP flags controlling which code in included in the files that
C will be compiled.

#ifndef CPP_OPTIONS_H
#define CPP_OPTIONS_H

#include "PACKAGES_CONFIG.h"

CmlC not sure of this
Cmlcph(
Cml#define DISABLE_MOM_VECINV
Cml#define MOMVISCOSITY
Cml#define MOMADVECTION
Cmlcph)

C o Shortwave heating as extra term in external_forcing.F
#ifdef ALLOW_KPP
#define  SHORTWAVE_HEATING
#endif

C o Include/exclude phi_hyd calculation code
#define INCLUDE_PHIHYD_CALCULATION_CODE

C o Include/exclude call to S/R CONVECT
#define INCLUDE_CONVECT_CALL

C o Include/exclude call to S/R CALC_DIFFUSIVITY
#define INCLUDE_CALC_DIFFUSIVITY_CALL

C o Allow nonHydrostatic code
#undef  ALLOW_NONHYDROSTATIC

C o NEW OPTION to disable rStar (z*) code
#define DISABLE_RSTAR_CODE

C o Exact volume conservation
#define EXACT_CONSERV

c o Allow atmospheric loading
#define ATMOSPHERIC_LOADING

C o Execution environment support options
#include "CPP_EEOPTIONS.h"

#ifdef ALLOW_AUTODIFF
# include "ECCO_CPPOPTIONS.h"
#endif

C o Allow full 3D specification of vertical diffusivity
#ifdef ALLOW_DIFFKR_CONTROL
C - Need to be defined if using DIFFKR_CONTROL
C   (alternatively, could have put this in ECCO_CPPOPTIONS)
#define ALLOW_3D_DIFFKR
#else
C - otherwise, can be turned on or off hereafter:
#undef  ALLOW_3D_DIFFKR
#endif /* ALLOW_DIFFKR_CONTROL */

#endif /* CPP_OPTIONS_H */