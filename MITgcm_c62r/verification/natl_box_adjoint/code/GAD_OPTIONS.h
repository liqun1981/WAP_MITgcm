C $Header: /u/gcmpack/MITgcm/verification/natl_box_adjoint/code/GAD_OPTIONS.h,v 1.2 2003/11/06 22:30:59 heimbach Exp $
C $Name: checkpoint62r $

CBOP
C !ROUTINE: GAD_OPTIONS.h

C !INTERFACE:
C #include "GAD_OPTIONS.h" 

C !DESCRIPTION:
C Contains CPP macros/flags for controlling optional features of package.
CEOP

C CPP options file for GAD (Generic Advection Diffusion) package
C
C Use this file for selecting options within the GAD package

#ifndef GAD_OPTIONS_H
#define GAD_OPTIONS_H
#include "PACKAGES_CONFIG.h"
#ifndef DISABLE_GENERIC_ADVDIFF

#include "CPP_OPTIONS.h"

C The selects the form of COSINE(lat) scaling of bi-harmonic term.
C *only for use on a lat-lon grid*
#define COSINEMETH_III

C The selects isotropic scaling of bi-harmonic term when
C using the COSINE(lat) scaling.
#undef  ISOTROPIC_COS_SCALING

C As of checkpoint41, the inclusion of multi-dimensional advection
C introduces excessive recomputation/storage for the adjoint.
C We can disable it here using CPP because run-time flags are insufficient.
#define  DISABLE_MULTIDIM_ADVECTION

#else

C If GAD is disabled then so is multi-dimensional advection
#define DISABLE_MULTIDIM_ADVECTION

#endif /* DISABLE_GENERIC_ADVDIFF */
#endif /* GAD_OPTIONS_H */
