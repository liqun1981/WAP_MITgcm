C $Header: /u/gcmpack/MITgcm/pkg/atm_ocn_coupler/CPL_MAP2GRIDS.h,v 1.3 2006/06/15 23:29:17 jmc Exp $
C $Name: checkpoint62r $

C     *==========================================================*
C     | CPL_MAP2GRIDS.h 
C     |   Declare arrays used for mapping coupling fields from
C     |     one grid (atmos., ocean) to the other grid
C     *==========================================================*

      INTEGER ROsize
      PARAMETER (ROsize=Nx_atm*Ny_atm)

C--   COMMON / RUNOFF_MAP/: to map runoff from atmos. grid to ocean grid
C     nROmap :: Nunber of connected grid points.
C     ijROatm :: index of land grid point that runoff to the ocean
C     ijROocn :: index of ocean grid point where the runoff ends
C     arROmap :: fraction of the land runoff ijROatm that go to ijROocn
C     runoffmapFile :: Input file for setting runoffmap
      COMMON / RUNOFF_MAP_I / nROmap, ijROocn, ijROatm
      INTEGER nROmap
      INTEGER ijROocn(ROsize), ijROatm(ROsize)
      COMMON / RUNOFF_MAP_R / arROmap
      _RL arROmap(ROsize)
      COMMON / RUNOFF_MAP_C / runoffmapFile
      CHARACTER*80 runoffmapFile

