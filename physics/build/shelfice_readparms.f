C $Header: /u/gcmpack/MITgcm/pkg/shelfice/shelfice_readparms.F,v 1.9 2010/08/24 15:09:53 jmc Exp $
C $Name: checkpoint62r $

#include "SHELFICE_OPTIONS.h"

CBOP
C !ROUTINE: SHELFICE_READPARMS

C !INTERFACE: ==========================================================
      SUBROUTINE SHELFICE_READPARMS( myThid )

C !DESCRIPTION:
C     Initialize SHELFICE parameters, read in data.shelfice

C !USES: ===============================================================
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "SHELFICE.h"
#include "PARAMS.h"
#ifdef ALLOW_MNC
# include "MNC_PARAMS.h"
#endif

C !INPUT PARAMETERS: ===================================================
C  myThid               :: thread number
      INTEGER myThid

C !OUTPUT PARAMETERS: ==================================================
C  none

#ifdef ALLOW_SHELFICE

C !LOCAL VARIABLES: ====================================================
C  iUnit                :: unit number for I/O
C  msgBuf               :: message buffer
      INTEGER iUnit
      CHARACTER*(MAX_LEN_MBUF) msgBuf
CEOP

      NAMELIST /SHELFICE_PARM01/
     &     SHELFICEheatTransCoeff,
     &     SHELFICEsaltTransCoeff,
     &     rhoShelfice, SHELFICEkappa,
     &     SHELFICElatentHeat, SHELFICEHeatCapacity_Cp,
     &     SHELFICEDragLinear, SHELFICEDragQuadratic,
     &     SHELFICEthetaSurface,
     &     useISOMIPTD, no_slip_shelfice,
     &     SHELFICEconserve, SHELFICEboundaryLayer,
     &     SHELFICEwriteState,
     &     SHELFICE_dumpFreq,
     &     SHELFICE_taveFreq,
     &     SHELFICE_tave_mnc,
     &     SHELFICE_dump_mnc,
     &     SHELFICEtopoFile, SHELFICEloadAnomalyFile,
     &     SHELFICEuseGammaFrict,
     &     shiCdrag, shiZetaN, shiRc,
     &     shiPrandtl, shiSchmidt, shiKinVisc

      _BEGIN_MASTER(myThid)

C This routine has been called by the main model so we set our
C internal flag to indicate we are in business
      SHELFICEisON=.TRUE.

C Set defaults values for parameters in SHELFICE.h
      useISOMIPTD              = .FALSE.
      SHELFICEconserve         = .FALSE.
      SHELFICEboundaryLayer    = .FALSE.
      SHELFICEloadAnomalyFile  = ' '
      SHELFICEtopoFile         = ' '
      SHELFICElatentHeat       =  334.0 _d 3
      SHELFICEHeatCapacity_Cp  = 2000.0 _d 0
      recip_SHELFICElatentHeat =    0.0 _d 0
      rhoShelfIce              =  917.0 _d 0
      SHELFICEheatTransCoeff   =    1.0 _d -04
      SHELFICEsaltTransCoeff   = UNSET_RL
      SHELFICEkappa            =   1.54 _d -06
      SHELFICEthetaSurface     = - 20.0 _d 0
      no_slip_shelfice         = no_slip_bottom
      SHELFICEDragLinear       = bottomDragLinear
      SHELFICEDragQuadratic    = bottomDragQuadratic
      SHELFICEwriteState       = .FALSE.
      SHELFICE_dumpFreq        = dumpFreq
      SHELFICE_taveFreq        = taveFreq
      SHELFICEuseGammaFrict    = .FALSE.
C these params. are default of Holland and Jenkins (1999)
      shiCdrag                 = 0.0015 _d 0
      shiZetaN                 = 0.052 _d 0
      shiRc                    = 0.2 _d 0
      shiPrandtl               = 13.8 _d 0
      shiSchmidt               = 2432.0 _d 0
      shiKinVisc               = 1.95 _d -6
#ifdef ALLOW_MNC
      SHELFICE_tave_mnc = timeave_mnc
      SHELFICE_dump_mnc = snapshot_mnc
#else
      SHELFICE_tave_mnc = .FALSE.
      SHELFICE_dump_mnc = .FALSE.
#endif

C Open and read the data.shelfice file
      WRITE(msgBuf,'(A)') ' SHELFICE_READPARMS: opening data.shelfice'
      CALL PRINT_MESSAGE(msgBuf, standardMessageUnit,
     &                   SQUEEZE_RIGHT, myThid )
      CALL OPEN_COPY_DATA_FILE(
     I                   'data.shelfice', 'SHELFICE_READPARMS',
     O                   iUnit,
     I                   myThid )
      READ(UNIT=iUnit,NML=SHELFICE_PARM01)
      WRITE(msgBuf,'(A)')
     &  ' SHELFICE_READPARMS: finished reading data.shelfice'
      CALL PRINT_MESSAGE(msgBuf, standardMessageUnit,
     &                   SQUEEZE_RIGHT, myThid )

C Close the open data file
      CLOSE(iUnit)

C Now set-up any remaining parameters that result from the input parameters
      IF ( SHELFICElatentHeat .NE. 0. _d 0 )
     &     recip_SHELFICElatentHeat = 1. _d 0/SHELFICElatentHeat
      IF ( SHELFICEsaltTransCoeff .EQ. UNSET_RL )
     &     SHELFICEsaltTransCoeff =
     &     5.05 _d -3 *SHELFICEheatTransCoeff

C-    Set Output type flags :
      SHELFICE_tave_mdsio = .TRUE.
      SHELFICE_dump_mdsio = .TRUE.
#ifdef ALLOW_MNC
      IF (useMNC) THEN
        IF ( .NOT.outputTypesInclusive
     &       .AND. SHELFICE_tave_mnc ) SHELFICE_tave_mdsio = .FALSE.
        IF ( .NOT.outputTypesInclusive
     &       .AND. SHELFICE_dump_mnc ) SHELFICE_dump_mdsio = .FALSE.
      ENDIF
#endif

      _END_MASTER(myThid)
C Everyone else must wait for the parameters to be loaded
      _BARRIER

#endif /* ALLOW_SHELFICE */

      RETURN
      END
