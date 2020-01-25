C$Header: /csys/software/cvsroot/REcoM/pkg/recom/recom_sms.F,v 1.61 2007/10/03 06:15:18 mlosch Exp $
C$Name:  $
#include "PTRACERS_OPTIONS.h"
#include "GCHEM_OPTIONS.h"
#include "RECOM_OPTIONS.h"
CBOP
C !ROUTINE: RECOM_SMS
C !INTERFACE:
      subroutine REcoM_sms(
     &     iMin, iMax, jMin, jMax, bi, bj,
     &     Nz, kLowC, bgc_num, ndiags3d, ndiags2d, delta_t, 
     &     maskC, hFacC, recip_hFacC, drF, recip_drF, recip_drC,
     &     temp, dicFlux_loc, 
     &     surf_light,cobeta, 
     &     state,
     &     benthos,
     &     sms, diags3d, diags2d ) 
C !DESCRIPTION:
C=====================================================================
C Carbon and Nitrogen Regulated Ecosystem Model (CN-REcoM)            
C version 2 (2 Phytoplankton size classes)
C NOTE: Phytoplankton growth equations                                
C       mainly derived from Geider et al., (1998) L&O                 
C                                                                     
C Model code started by Markus Schartau (AWI Bremerhaven, October 2002)
C Maintained by Martin Losch, Martin.Losch@awi.de
C=====================================================================    
C
C     The field state(Nz,bgc_num) contains all biological tracers,
C     with the following units and typical values in the open ocean
C     (coastal regions may differ):
C
C     state(:,1): DIN (dissolved nitrate NO3)
C                 units: mmol/m^3, typical range: 0 < DIN < 54 
C
C     state(:,2): DIC (dissolved inorganic carbon, sometimes TCO2)
C                 units: mmol/m^3, typical range 2000 < DIC < 2400
C
C     state(:,3): alk (alkalinity)
C                 units: mmol/m^3, typical range 2000 < alk < 2500
C
C     state(:,4): phyN (small phytoplankton nitrogen)
C                 units: mmol/m^3, 
C                 typical range: 0 < phyN < 5 (open ocean)
C                                         < 10 (some coastal regions)
C
C     state(:,5): phyC (small phytoplankton carbon)
C                 units: mmol/m^3:
C                 typical range: 0 < phyC < 35 (open ocean)
C                                0 < phyC < 70 (coastal regions)
C
C     state(:,6): CHLA (small phytoplankton chlorophyll a)
C                 units: mg/m^3, typical range: 0 < CHLA < 4
C
C     state(:,7): detN (nitrate-based detritus)
C                 units: mmol/m^3
C                 typical range: 0 < detN < (hmm, can't really tell... approx.) 10
C     
C     state(:,8): detC (carbon-based detritus)
C                 units: mmol/m^3
C                 typical range: 0 < detC < (even worse to tell... approx.) 70
C
C     state(:,9): hetN (heterotrophic zooplankton on N-basis)
C                 units: mmol/m^3 
C                 typical range: 0 < hetN < (depends on size classes)
C     
C     state(:,10): hetC (heterotrophic zooplankton on C-basis)
C                  units: mmol/m^3 
C                  typical range: 0 < hetC < (depends on size classes)
C
C     state(:,11): DON (extracellular dissolved organic nitrogen)
C                  units: mmol/m^3
C                  typical range: model considers only "fresh" DON, which can range from
C                                 5-20, background values are 10-20
C     
C     state(:,12): EOC (extracellular dissolved organic carbon)
C                  units: mmol/m^3
C                  typical range: 0 < EOC < 100
C     (this refers to "fresh" labile DOC); however, in the model part 
C     of of EOC is particulate material (POC); we call the remaining EOC,
C     which does not contain any polysaccharides (PCHO), "residual DOC".
C     EOC=DOC+TEPC=PCHO+residual EOC+TEPC 
C
C     state(:,13): diaN (diatom nitrogen)
C                 units: mmol/m^3, 
C                 typical range: 0 < phyN < 5 (open ocean)
C                                         < 10 (some coastal regions)
C
C     state(:,14): diaC (diatom carbon)
C                 units: mmol/m^3:
C                 typical range: 0 < phyC < 35 (open ocean)
C                                0 < phyC < 70 (coastal regions)
C
C     state(:,15): DiaCHL (diatom chlorophyll a)
C                 units: mg/m^3, typical range: 0 < CHLA < 4
C
C     state(:,16): diaSi (diatom silica)
C                  units: mmol/m^3
C                  typical range: 0-??
C     
C     state(:,17): detSi (silica-based detritus)
C                  units: mmol/m^3
C                  typical range: 0-??
C
C     state(:,18): Si (disolved silicate)
C                  units: mmol/m^3
C                  typical range: 0 < Si < 170
C
C     state(:,19): Fe (disolved iron)
C                  units: mumol/m^3
C                  typical range: 0.1 < Fe < 0.6 
C
#ifdef RECOM_CALCIFICATION
C     state(:,20): phyCalc (phytoplankton calcium carbonate)
C                  units: mumol/m^3
C                  typical range: 0.0 < phyCalc < 1.0 
C
C     state(:,21): detCalc (detritus calcium carbonate)
C                  units: mumol/m^3
C                  typical range: 0.1 < detCalc < 1.0 
C
#endif

C !USES:
C --- definitions
#ifdef ALLOW_MODULES
      use mod_REcoM_para_def      
      implicit none
#else /* not ALLOW_MODULES */
      implicit none
#include "RECOM_PARAMS.h"
#ifdef ALLOW_MITGCM
#include "SIZE.h"
#endif
C---------- 
CCV The next two lines are necessary to use the pointers to 
CCV  biogeochemical tracers, defined in RECOM.h
#include "EEPARAMS.h"
#include "RECOM.h"
#include "SEAICE.h"
C---------- 
#endif /* not ALLOW_MODULES */
C
C !INPUT/OUTPUT PARAMETERS:
C
C     loop boundaries
      integer iMin, iMax, jMin, jMax, bi, bj
C     external timestep in seconds (physics !)
      _RL     delta_t 
C     number of layers
      integer Nz
      integer n
C Parameters M and MM introduced by Cristina Schultz to account for non-linearities
C of PAR
      integer MM
      parameter (MM=8)
      integer M
      parameter (M=7)
C     number of tracers passed
      integer bgc_num
C     number of diagnostics
      integer ndiags3d, ndiags2d, ndiags3d_used
C     
      integer kLowC  (1-Olx:sNx+Olx,1-Oly:sNy+Oly,nSx,nSy)
C     thickness of grid boxes  
      _RS drF(Nz), recip_drF(Nz), recip_drC(Nz)
      _RS maskC      (1-Olx:sNx+Olx,1-Oly:sNy+Oly,Nz,nSx,nSy)
      _RS hFacC      (1-Olx:sNx+Olx,1-Oly:sNy+Oly,Nz,nSx,nSy)
      _RS recip_hFacC(1-Olx:sNx+Olx,1-Oly:sNy+Oly,Nz,nSx,nSy)

C     temperature profile (in degC)
      _RL temp(1-Olx:sNx+Olx,1-Oly:sNy+Oly,Nz,nSx,nSy)
C     atmospheric CO2 flux
      _RL dicFlux_loc(1-Olx:sNx+Olx,1-Oly:sNy+Oly,nSx,nSy)
C     radiation at surface
C Had an extra dimension (MM) introduced by Cristina Schultz  
      _RL surf_light(1-Olx:sNx+Olx,1-Oly:sNy+Oly,MM)
C-----
      _RL cobeta(1-Olx:sNx+Olx,1-Oly:sNy+Oly)
C-----
      _RL state  (1-Olx:sNx+Olx,1-Oly:sNy+Oly,Nz,nSx,nSy,bgc_num)
#ifdef RECOM_CALCIFICATION    
      _RL benthos(1-Olx:sNx+Olx,1-Oly:sNy+Oly,4)
C-----
C     auxillary variables for the flux into the benthic layer
      _RL wFluxDet(4)
      _RL wFluxPhy(4)
      _RL wFluxDia(4)
      _RL decayBenthos(4)
#else
      _RL benthos(1-Olx:sNx+Olx,1-Oly:sNy+Oly,3)
C-----
C     auxillary variables for the flux into the benthic layer
      _RL wFluxDet(3)
      _RL wFluxPhy(3)
      _RL wFluxDia(3)
      _RL decayBenthos(3)
#endif
C     [mmol m^{-3}]
      _RL sms    (1-Olx:sNx+Olx,1-Oly:sNy+Oly,Nz,nSx,nSy,bgc_num) 
C-----
C     generic array for diagnostics
      _RL diags3d  (1-Olx:sNx+Olx,1-Oly:sNy+Oly,Nz,ndiags3d) 
      _RL diags2d  (1-Olx:sNx+Olx,1-Oly:sNy+Oly,ndiags2d) 
C !LOCAL VARIABLES:
      integer kLoc
C     sinking velocities are positive downwards
      _RL vSinkPhy(1-Olx:sNx+Olx,1-Oly:sNy+Oly,1:Nz)
      _RL vSinkDia(1-Olx:sNx+Olx,1-Oly:sNy+Oly,1:Nz)
      _RL vSinkDet(1-Olx:sNx+Olx,1-Oly:sNy+Oly,1:Nz)
C     tendency due to sinking
      _RL sink    (1-Olx:sNx+Olx,1-Oly:sNy+Oly,1:Nz) ! [mmol m^{-3}]
#ifdef RECOM_EXPORT_DIAGNOSTICS
C diagnostic dummy variable for calculating vertical export fluxes
      _RL export  (1-Olx:sNx+Olx,1-Oly:sNy+Oly)
#endif
#ifdef RECOM_MAREMIP
      _RL export3d(1-Olx:sNx+Olx,1-Oly:sNy+Oly,1:Nz)
#endif

      _RL arrFunc, rTloc, rTref

C-----
C small phytoplankton process variables
C-----
C     carbon specific rate of photosynthesis [d^{-1}] 
      _RL C_phot 
C     maximum photosynthetic rate
      _RL pMax
C     carbon specific nitrogen utilization rate [mmol N mmol C^{-1} d^{-1}]
      _RL N_assim 
C     CHL a synthesis regulation term [mg CHL mmol N^{-1}]
      _RL chlSynth
C     molar cell quota [mmol N mmol C^{-1}]
      _RL quota, recipQuota
C     cellular CHL a : carbon/nitrogen ratio [mg CHL mmol C/N^{-1}]
      _RL CHL2C, CHL2N
C     phytoplankton respiration rate [d^{-1}]
      _RL phyRespRate 

C-----
C diatom process variables
C-----
C     carbon specific rate of photosynthesis [d^{-1}] 
      _RL C_phot_dia
C Variable with size MM in this section created by Cristina Schultz
C to store values calculated for different sea ice categories prior
C to averaging
      _RL Limphy_mult(MM)
      _RL Limdia_mult(MM)
      _RL Limphy
      _RL Limdia
      _RL PARtemp(MM) 
C     maximum photosynthetic rate
      _RL pMax_dia
C     carbon specific nitrogen utilization rate [mmol N mmol C^{-1} d^{-1}]
      _RL N_assim_dia 
C     CHL a synthesis regulation term [mg CHL mmol N^{-1}]
      _RL chlSynth_dia
C     molar cell quota [mmol N mmol C^{-1}]
      _RL quota_dia, recipQuota_dia
C     cellular CHL a : carbon/nitrogen ratio [mg CHL mmol C/N^{-1}]
      _RL CHL2C_dia, CHL2N_dia
C     phytoplankton respiration rate [d^{-1}]
      _RL phyRespRate_dia 
C     carbon specific silicate uptake rate  [mmol Si mmol C^{-1} d^{-1}]
      _RL Si_assim
C     molar cell quotas [mmol Si mmol N^{-1} and mmol Si mmol C^{-1}]  
      _RL qSiN, qSiC
C-----
C zooplankton process variables
C-----
C     inverse molar cell quota of zooplankton [(mmol N mmol C^{-1})^{-1}]
      _RL recipQZoo
C     grazing flux [mmol N m^{-3} d^{-1}]
#ifdef RECOM_2CLASSES
      _RL fdiaN
#ifdef RECOM_GRAZING_VARIABLE_PREFERENCE
      _RL varpzdia, diaNsq
#endif
#endif
      _RL grazingFlux
      _RL grazingFlux_dia, grazingFlux_phy, food, foodsq
C     zooplankton respiration 
      _RL hetRespFlux
C     zooplankton mortality (quadratic loss)
      _RL hetLossFlux
C     aggregationRate (of nitrogen) [d^{-1}]
      _RL aggregationRate
C     tendency due to carbon air-sea flux 
      _RL dicSurfTend
C     averaged photosynthetic available radiation (PAR)
C variable PARavem created by Cristina Schultz to store 
C PAR under each sea ice category prior to averaging
      _RL PARavem(MM)
      _RL PARave 
C     cumulative vertical integral of kappa (light attenuation)
      _RL kdzUpper(1-Olx:sNx+Olx,1-Oly:sNy+Oly) 
      _RL kdzLower, upper_light, lower_light
      _RL kappa, kappaStar

      _RL din, dic, alk, phyN, phyC, CHL
      _RL detN, detC, hetN, hetC, DON, eoC
      _RL diaN, diaC, diaCHL, diaSi, detSi, Si, Fe, freeFe
      _RL calc_diss

C     temperature dependent remineralisation rate of Si
      _RL reminSiT


C     some loop parameters
      integer i, j, k, step, ii
      _RL dt

C     light limitation variables
      _RL qLimitFac, qLimitFacTmp, feLimitFac
C     downregulation of metabolic processes
      _RL limitFacN
      _RL limitFacN_dia, limitFacSi

C     Temperature dependent maximum of C-specific nitrogen uptake 
C     [mmol N (mmol C)^{-1} d^{-1}]
      _RL V_cm              
C     Limiter function
      _RL recom_limiter
      external recom_limiter

C     external function to compute free iron
      _RL iron_chemistry
      external iron_chemistry
#ifdef RECOM_CALCIFICATION
      _RL phyCalc, detCalc
      _RL calcification, calc_loss_agg, calc_loss_gra
#endif
#ifdef RECOM_MANY_LIGANDS
C     iron uptake per timestep (needed only for ligand dynamics)
      _RL fe_uptake
C     local ligand concentrations
      _RL rlig1, rlig2, rlig3, rlig4, rlig5
#endif
#ifdef RECOM_LENA
      _RL P1, P2, Q0, Pslope, flena
#endif
CEOP

C     check some parameters
#ifdef RECOM_CALCIFICATION
#ifdef RECOM_MANY_LIGANDS
      if ( bgc_num .ne. 26 ) then
       write(*,*) 'S/R REcoM_sms: bgc_num does not have the '//
     &      'correct value (26) for REcoM2 with calcite'
       write(*,*) 'feLimit = ', feLimit, ', bgc_num = ', bgc_num
       stop 'UNEXPECTED IN RECOM_SMS'
      endif
#else
      if ( bgc_num .ne. 21 ) then
       write(*,*) 'S/R REcoM_sms: bgc_num does not have the '//
     &      'correct value (21) for REcoM2 with calcite'
       write(*,*) 'feLimit = ', feLimit, ', bgc_num = ', bgc_num
       stop 'UNEXPECTED IN RECOM_SMS'
      endif
#endif
#else
      if ( bgc_num .ne. 19 ) then
       write(*,*) 'S/R REcoM_sms: bgc_num does not have the '//
     &      'correct value (19) for REcoM2'
       write(*,*) 'feLimit = ', feLimit, ', bgc_num = ', bgc_num
       stop 'UNEXPECTED IN RECOM_SMS'
      endif
#endif
CML      if ( bgc_num .ne. 12 ) then
CML       write(*,*) 'S/R REcoM_para_read: bgc_num does not have the '//
CML     &      'correct value (12) for C/N-REcoM'
CML       stop 'UNEXPECTED IN RECOM_PARA_READ'
CML      endif
C
C---- INITIAL set to zero ------------------------------------------
C     
#ifdef RECOM_CALCIFICATION
      DO k = 1,4
       wFluxDet(k)     = 0.
       wFluxPhy(k)     = 0.
       wFluxDia(k)     = 0.
       decayBenthos(k) = 0.
      ENDDO
C      calc_diss_rate = 20.0/(3500*86400)

#else
      DO k = 1,3
       wFluxDet(k)     = 0.
       wFluxPhy(k)     = 0.
       wFluxDia(k)     = 0.
       decayBenthos(k) = 0.
      ENDDO
#endif
      quota          = c0                  
      CHL2C          = c0                  
      CHL2N          = c0                  
      recipQuota     = c0                  
      qSiN           = c0
      qSiC           = c0

      dicSurfTend    = c0                   
      N_assim        = c0                 
      C_phot         = c0                 
      chlSynth       = c0                  
      aggregationRate= c0
      phyRespRate    = c0
      hetRespFlux    = c0
      grazingFlux    = c0
      PARave         = c0                 
      do ii=1,bgc_num
       do k=1,Nz
        do j=jMin,jMax
         do i=iMin,iMax
          sms(i,j,k,bi,bj,ii)    = c0
         enddo
        enddo
       enddo
      enddo
c---
      do k=1,Nz
       do j=jMin,jMax
        do i=iMin,iMax
         sink(i,j,k)      = c0
        enddo
       enddo
      enddo
c---
      do ii=1,ndiags3d
       do k=1,Nz
        do j=jMin,jMax
         do i=iMin,iMax
          diags3d(i,j,k,ii)  = c0
         enddo
        enddo
       enddo
      enddo
c---
      do ii=1,ndiags2d
       do j=jMin,jMax
        do i=iMin,iMax
         diags2d(i,j,ii)  = c0
        enddo
       enddo
      enddo
c---
      do j=jMin,jMax
       do i=iMin,iMax
        vSinkPhy(i,j,1)  = c0
        vSinkDia(i,j,1)  = c0
        vSinkDet(i,j,1)  = c0
       enddo
      enddo
      do k=2,Nz
       do j=jMin,jMax
        do i=iMin,iMax
         vSinkPhy(i,j,k) = Vphy*maskC(i,j,k,bi,bj)
         vSinkDia(i,j,k) = Vdia*maskC(i,j,k,bi,bj)
CTW increased sinking speed
#ifdef ALLOW_SINK_INCREASE
         vSinkDet(i,j,k) = Vdetfast(k)*maskC(i,j,k,bi,bj)
#else
         vSinkDet(i,j,k) = Vdet*maskC(i,j,k,bi,bj)
#endif /* ALLOW_SINK_INCREASE */
        enddo
       enddo
      enddo

C                                                                       
C BIOLOGICAL LOOP ------------------------------------------------------------
C        
      rTref = c1/recom_Tref

      dt = one_day/delta_t
      dt = c1/(dt*real(bio_step)) ! time increment unit 'day'
      
      do step = 1, bio_step  

C     before starting the vertical loop, set light attenuation, 
C     integral(kappa*dz), to zero at the surface 
       do j = jMin, jMax
        do i = iMin, iMax
         kdzUpper(i,j) = 0.
        end do
       end do
C     set tiny tendencies to zero to avoid numerical problems 
C     (is this really necessary?) 
       do ii = 1, bgc_num
        do k = 1, Nz
         do j = jMin, jMax
          do i = iMin, iMax
           if (abs(sms(i,j,k,bi,bj,ii)).le.tiny) sms(i,j,k,bi,bj,ii)=0.
          end do  
         end do
        end do
       end do
       do k = 1, Nz
       do j = jMin, jMax
       do i = iMin, iMax
C friendly attachment of state variables to names, avoid divisions
C by zero by setting a lower limit
C state: 1. DIN,  2. DIC, 3. ALK,   4. PhyN,  5. PhyC, 6. Chl, 
C        7. DetN, 8.DetC, 9. HetN, 10. HetC, 11. DON, 12. EOC  
C        13. DiaN, 14. DiaC, 15. DiaCHL, 16.DiaSi, 17. DetSi, 18. Si 19. Fe
        din  = max(tiny,state(i,j,k,bi,bj,idin)  + 
     &         sms(i,j,k,bi,bj, idin))  
        dic  = max(tiny,state(i,j,k,bi,bj,idic)  +  
     &         sms(i,j,k,bi,bj, idic))  
        alk  = max(tiny,state(i,j,k,bi,bj,ialk)  + 
     &         sms(i,j,k,bi,bj, ialk))   
        phyN = max(tiny,state(i,j,k,bi,bj,iphyn) + 
     &         sms(i,j,k,bi,bj, iphyn))   
        phyC = max(tiny,state(i,j,k,bi,bj,iphyc) + 
     &         sms(i,j,k,bi,bj, iphyc))  
        CHL  = max(tiny,state(i,j,k,bi,bj,ipchl) + 
     &         sms(i,j,k,bi,bj, ipchl))  
        detN = max(tiny,state(i,j,k,bi,bj,idetn) + 
     &         sms(i,j,k,bi,bj, idetn))  
        detC = max(tiny,state(i,j,k,bi,bj,idetc) + 
     &         sms(i,j,k,bi,bj, idetc))  
        hetN = max(tiny,state(i,j,k,bi,bj,ihetn) + 
     &         sms(i,j,k,bi,bj, ihetn))  
        hetC = max(tiny,state(i,j,k,bi,bj,ihetc) + 
     &         sms(i,j,k,bi,bj, ihetc)) 
        DON  = max(tiny,state(i,j,k,bi,bj,idon)  + 
     &         sms(i,j,k,bi,bj, idon))
        eoC  = max(tiny,state(i,j,k,bi,bj,idoc)  + 
     &         sms(i,j,k,bi,bj, idoc))
        diaN = max(tiny,state(i,j,k,bi,bj,idian) + 
     &         sms(i,j,k,bi,bj,idian))
        diaC = max(tiny,state(i,j,k,bi,bj,idiac) +
     &         sms(i,j,k,bi,bj,idiac))
        diaChl = max(tiny,state(i,j,k,bi,bj,idchl) +
     &         sms(i,j,k,bi,bj,idchl))
        diaSi= max(tiny,state(i,j,k,bi,bj,idiasi) +
     &         sms(i,j,k,bi,bj,idiasi))
        detSi= max(tiny,state(i,j,k,bi,bj,idetsi) +
     &         sms(i,j,k,bi,bj,idetsi))
        Si   = max(tiny,state(i,j,k,bi,bj,isi)+sms(i,j,k,bi,bj,isi))
        Fe   = max(tiny,state(i,j,k,bi,bj,ife)+sms(i,j,k,bi,bj,ife))    
        freeFe = 0.
#ifdef RECOM_CALCIFICATION
        phyCalc = max(tiny,state(i,j,k,bi,bj,iphycalc) + 
     &         sms(i,j,k,bi,bj,iphycalc))
        detCalc = max(tiny,state(i,j,k,bi,bj,idetcalc) + 
     &         sms(i,j,k,bi,bj,idetcalc))
CJH calc_diss_rate was initilaized for constant sinking speed of 20m/d
CJH with increasing sinking speed we have to correct for that to obtain
CJH the same profile
        calc_diss = calc_diss_rate * vSinkDet(i,j,k) /20 
#endif
#ifdef RECOM_MANY_LIGANDS
        rlig1 = max(tiny,state(i,j,k,bi,bj,ilig1) + 
     &         sms(i,j,k,bi,bj,ilig1))
        rlig2 = max(tiny,state(i,j,k,bi,bj,ilig2) + 
     &         sms(i,j,k,bi,bj,ilig2))
        rlig3 = max(tiny,state(i,j,k,bi,bj,ilig3) + 
     &         sms(i,j,k,bi,bj,ilig3))
        rlig4 = max(tiny,state(i,j,k,bi,bj,ilig4) + 
     &         sms(i,j,k,bi,bj,ilig4))
        rlig5 = max(tiny,state(i,j,k,bi,bj,ilig5) + 
     &         sms(i,j,k,bi,bj,ilig5))
#endif

C-----
C small phytoplankton, diatom and zooplankton cell quotas
C-----
        quota = phyN / phyC 
        recipQuota = 1./quota
        CHL2C = CHL  / phyC
        CHL2N = CHL  / phyN
        
        quota_dia = diaN / diaC 
        recipQuota_dia = 1./quota_dia
        CHL2C_dia = diaCHL  / diaC
        CHL2N_dia = diaCHL  / diaN
        qSiC  = diaSi / diaC
        qSiN  = diaSi / diaN
        
        recipQZoo  = hetC / hetN
C-----              
C temperature dependence of rates 
C-----
        rTloc = c1/(temp(i,j,k,bi,bj) + recom_celsius2K)
        arrFunc = exp( -Ae * ( rTloc - rTref ) )*maskC(i,j,k,bi,bj)
C     silicate remineralisation has a different temperature dependence
        reminSiT = reminSi*arrFunc
        if ( useReminSiT ) 
     &       reminSiT = min(1.32E16*exp(-11200.*rTloc),reminSi)
     &       *maskC(i,j,k,bi,bj)

C----- upper boundary condition for carbon: exchange with atmopshere  
C----- mmol C m^{-2} d^{-1} --> mmol C m^{-3} d^{-1}
        dicSurfTend = dicFlux_loc(i,j,bi,bj)
     &       *recip_drF(k)*recip_hfacc(i,j,k,bi,bj) * max( 2-k, 0 )
CML        if (k.eq.1) then 
CML         dicSurfTend=dicFlux_loc*recip_drF(k)*recip_hfacc(i,j,k,bi,bj)
CML        else
CML         dicSurfTend=c0
CML        end if         
C-------------------------------------------------------------------------

C---- photosynthesis section, light parameters and rates

C----
C small phytoplankton pMax
C----
        qLimitFac = recom_limiter(NMinSlope,NCmin,quota)
        if (FeLimit) then 
         feLimitFac = Fe/(k_Fe + Fe)
         qLimitFac = min(qLimitFac,feLimitFac)
        end if
#ifdef RECOM_LENA
        P2 = P_cm
        P1 = 0.0
        Q0 = 0.04
        Pslope = 100.0
        flena = (P1 + P2)*0.5 + Pslope*(quota - Q0)
        flena = max(P1,flena)
        flena = min(P2,flena)
        pMax = flena*qLimitFac*arrFunc
#else
        pMax = P_cm*qLimitFac*arrFunc
#endif
C----
C diatom pMax
C----
        qLimitFac = recom_limiter(NMinSlope,NCmin_d,quota_dia)
        qLimitFacTmp = recom_limiter(SiMinSlope,SiCmin,qSiC)
        qLimitFac    = min(qLimitFac,qLimitFacTmp)
        if (FeLimit) then 
         feLimitFac = Fe/(k_Fe_d + Fe)
         qLimitFac = min(qLimitFac,feLimitFac)
        end if
#ifdef RECOM_LENA
        P2 = P_cm_d
        P1 = 0.0
        Q0 = 0.04
        Pslope = 100.0
        flena = (P1 + P2)*0.5 + Pslope*(quota_dia - Q0)
        flena = max(P1,flena)
        flena = min(P2,flena)
        pMax_dia = flena*qLimitFac*arrFunc
#else
        pMax_dia = P_cm_d * qLimitFac * arrFunc
#endif

C----
C light
C----
C  attenuation coefficient 
        kappa =  k_w + a_chl*(CHL + diaCHL)
        kappaStar = kappa/cobeta(i,j)

C     vertical light profile, averaged over grid cell
C     - first, integrate kappaStar*deltaZ for a another layer
        kdzLower = kdzUpper(i,j) + kappaStar*drF(k)*hFacC(i,j,k,bi,bj)
C     - compute available light at upper and lower face of current layer
C Loop added by Cristina Schultz to calculate the average PAR under each 
C sea ice category and store it in PARavem
        DO n=1,MM
         IF (k.gt.10) THEN
          upper_light=tiny
          lower_light=tiny
         ELSE
          upper_light = -QSWM(i,j,n,bi,bj)*0.5*exp( -kdzUpper(i,j) )
          lower_light = -QSWM(i,j,n,bi,bj)*0.5*exp( -kdzLower )
         ENDIF
C     - vertical average over box
         PARavem(n) = max(tiny,(upper_light-lower_light)/kappaStar
     &       * recip_drF(k)*recip_hfacc(i,j,k,bi,bj))
        ENDDO
C     - store kdzLower for next layer
         kdzUpper(i,j) = kdzLower

C The photosynthesis rate section was changed by Cristina Schultz to account
C for the non-linearities of PAR based on the scheme proposed by Long et al (2015)
C the light limitation terms for phytoplankton growth is calculated for PAR 
C available under each sea ice category and multiplied by the fraction of the cell
C covered by each category. The results are then summed and used for the growth 
C calculations. 
C Long, Lindsay and Holland (2015). Modeling photosynthesis in sea ice-covered
C waters. Journal of Advances in Modeling Earth Systems.        
C---- 
C small phytoplankton photosynthesis rate
C---- 
        DO n=1,M
         Limphy_mult(n) = (c1 - exp(-alpha * CHL2C * PARavem(n)/pMax)) 
     &       * (AREA(i,j,bi,bj)/7.0)
        ENDDO
        Limphy_mult(MM)= (c1 - exp(-alpha * CHL2C *
     &        PARavem(MM)/pMax)) * (1.0 - AREA(i,j,bi,bj)) 
        Limphy = sum(Limphy_mult)    
        if (pMax .lt. tiny) then 
          C_phot = c0
        else
          C_phot = pMax * Limphy  
        end if
        if (C_phot .lt. tiny) C_phot = c0       
C---- 
C diatom photosynthesis rate
C---- 
        DO n=1,M
         Limdia_mult(n) = (c1 - exp(-alpha_d * CHL2C_dia * PARavem(n) /
     &       pMax_dia)) * (AREA(i,j,bi,bj)/7.0)
         PARtemp(n) = PARavem(n) * (AREA(i,j,bi,bj)/7.0)
        ENDDO
        PARtemp(MM) = PARavem(MM) * (1.0 - AREA(i,j,bi,bj))
        Limdia_mult(MM)= (c1 - exp(-alpha_d * CHL2C_dia * PARavem(MM)
     &       / pMax_dia)) * (1.0 - AREA(i,j,bi,bj))
        Limdia = sum(Limdia_mult)
        if (pMax_dia .lt. tiny) then 
          C_phot_dia = c0
        else
          C_phot_dia = pMax_dia * Limdia  
        end if
        if (C_phot_dia .lt. tiny) C_phot_dia = c0       
        PARave = sum(PARtemp)
C---- end of photosynthesis section
C-------------------------------------------------------------------------

C     assimilation section
C---- Geider et al. 1998 L&O -------------- 
C      N_assim = V_cm * ( 
C     &     (Qmax - q)/(Qmax - Qmin) 
C     &     )**.05 * T_func(Temp) 
C--------------------------------------

C     compute assimilation rates
#ifdef RECOM_LENA
        P2 = V_cm_fact
        P1 = 0.05
        Q0 = 0.1
        Pslope = 200.0
        flena = (P1 + P2)*0.5 + Pslope*(quota - Q0)
        flena = max(P1,flena)
        flena = min(P2,flena)
        V_cm = flena 
#else
        V_cm = V_cm_fact
#endif
        limitFacN  = recom_limiter(NMaxSlope,quota,NCmax)
        N_assim  = V_cm*pMax        * NCuptakeRatio*limitFacN  
     &       * ( DIN/( DIN + k_din ) ) 

#ifdef RECOM_LENA
        P2 = V_cm_fact_d
        P1 = 0.05
        Q0 = 0.1
        Pslope = 200.0
        flena = (P1 + P2)*0.5 + Pslope*(quota_dia - Q0)
        flena = max(P1,flena)
        flena = min(P2,flena)
        V_cm = flena 
#else
        V_cm = V_cm_fact_d
#endif
        limitFacN_dia  = recom_limiter(NMaxSlope,quota_dia,NCmax_d)
        N_assim_dia  = V_cm * pMax_dia * NCuptakeRatio_d * limitFacN_dia  
     &       * ( DIN/( DIN + k_din_d ) ) 

        limitFacSi = recom_limiter(SiMaxSlope,qSiC,SiCmax) * 
     &           limitFacN_dia
        Si_assim = V_cm * P_cm_d * arrFunc * SiCuptakeRatio * limitFacSi
     &       *  ( Si/( Si + k_si ) )
C     end of assimilation section

C     iron chemistry
        if ( FeLimit ) then
           freeFe=iron_chemistry( Fe, totalLigand, ligandStabConst )
        endif
C     end iron chemistry

C     Chlorophyll synthesis (needs to know about light and assimilation
C     of nitrogen)
        chlSynth = c0
        if ( PARave .ge. tiny ) chlSynth = N_assim
     &       *CHL_N_max*min( c1, C_phot/(alpha*CHL2C*PARave) )

        chlSynth_dia = c0
        if ( PARave .ge. tiny ) chlSynth_dia = N_assim_dia
     &       *CHL_N_max_d * min( c1, 
     &          C_phot_dia / (alpha_d * CHL2C_dia * PARave) )

C     phytoplankton respiration rate
#ifdef RECOM_LENA
        P2 = biosynth
        P1 = 5.0
        Q0 = 0.17
        Pslope = -500.0
        flena = (P1 + P2)*0.5 + Pslope*(quota - Q0)
        flena = min(P1,flena)
        flena = max(P2,flena)
        Phyresprate     = res_phy * limitFacN + flena*N_assim

        flena = (P1 + P2)*0.5 + Pslope*(quota_dia - Q0)
        flena = min(P1,flena)
        flena = max(P2,flena)
        phyRespRate_dia = res_phy_d * limitFacN_dia + 
     &       flena * N_assim_dia + biosynthSi * Si_assim
#else
        phyRespRate     = res_phy * limitFacN + biosynth*N_assim
        phyRespRate_dia = res_phy_d * limitFacN_dia + 
     &       biosynth * N_assim_dia + biosynthSi * Si_assim
#endif

C-----
C Zooplankton grazing on small phytoplankton and diatoms
C at the moment there is no preference for one or the other food. 
C change this!
C-----
#ifdef RECOM_2CLASSES
#ifdef RECOM_GRAZING_VARIABLE_PREFERENCE
        diaNsq = diaN*diaN
        varpzdia = pzdia * diaNsq / (sdiasq + diaNsq)  
        fdiaN = varpzdia*diaN
#else
        fdiaN = pzdia*diaN
#endif
        food = phyN + fdiaN
        foodsq = food*food
        grazingFlux = (graz_max*foodsq) / (epsilon+foodsq) *
     &       hetN * arrFunc
        grazingFlux_phy = grazingFlux * phyN/food
        grazingFlux_dia = grazingFlux * fdiaN/food
#else
        foodsq = phyN*phyN
        grazingFlux_phy = (graz_max*foodsq) / (epsilon+foodsq) * 
     &       hetN * arrFunc
#endif

C old grazing for just one phytoplankton
C        grazingFlux = (graz_max*phyN*phyN) / (epsilon+phyN*phyN) * hetN

C-----
C heterotrophic respiration is assumed to drive zooplankton back to Redfield C:N
C if their C:N becomes higher than Redfield 
C-----
        hetRespFlux = recip_res_het*arrFunc*(recipQZoo - redfield)*hetC
CCV:
C changes results, but is needed: otherwise heterotrophs take up inorganic carbon
C when their C:N becomes lower than Redfield
        hetRespFlux = MAX(0. _d 0,hetRespFlux)
C-----
C quadratic zooplankton mortality
C-----
        hetLossFlux = loss_het * hetN * hetN

C-----
C phytoplanton and detritus aggregation
C-----
        aggregationRate = ( agg_PD*DetN  + agg_PP*PhyN + agg_PP*diaN )
        if (TEPaggregation) aggregationRate
     &       = aggregationRate * f_TEP*eoC/(45.+f_TEP*eoC)

#ifdef RECOM_CALCIFICATION
C-----
C Terms required for the formation and dissolution of CaCO3
C-----
        calcification = calc_prod_ratio * C_phot * phyC
        calc_loss_agg = aggregationRate * phyCalc 
        calc_loss_gra = grazingFlux_phy * 
     &                  recipQuota / (phyC+tiny) * phyCalc
#endif
C--------------------------------------------------------------------------
C 
C source minus sink (sms)    
C____________________
C
C DIN _______________
        sms(i,j,k,bi,bj,idin) = maskC(i,j,k,bi,bj)*( 
     &       - N_assim                        * phyC
     &       - N_assim_dia                    * diaC
     &       + rho_N  * arrFunc               * DON 
     &                     ) * dt             + sms(i,j,k,bi,bj,idin) 
C__________________________________________________________________________
C        
C DIC _______________      
        sms(i,j,k,bi,bj,idic) = maskC(i,j,k,bi,bj)*( 
     &       - C_phot                         * phyC
     &       + phyRespRate                    * phyC
     &       - C_phot_dia                     * diaC
     &       + phyRespRate_dia                * diaC
     &       + rho_C1  * arrFunc * (c1-f_TEP) * eoC
     &       + hetRespFlux
     &       + dicSurfTend 
#ifdef RECOM_CALCIFICATION
     &       + calc_diss*detCalc 
     &       + calc_loss_gra * calc_diss_guts 
     &       - calcification
#endif
     &                     ) * dt             + sms(i,j,k,bi,bj,idic)
C__________________________________________________________________________
C
C ALK _______________(assumed that N:P follows a constant Redfield ratio) 
C N_assimC     1.0625 = c1/16. + c1
        sms(i,j,k,bi,bj,ialk) = maskC(i,j,k,bi,bj)*(
     &       + 1.0625 * ( N_assim            * phyC
     &       + N_assim_dia                   * diaC
     &       - rho_N * arrFunc               * DON) 
#ifdef RECOM_CALCIFICATION
     &       + 2.0 * (calc_diss*detCalc 
     &       + calc_loss_gra * calc_diss_guts 
     &       - calcification) 
#endif
     &                     ) * dt            + sms(i,j,k,bi,bj,ialk)
CCV: Note/Check: Does Si uptake contribute to alkalinity? I believe yes!

C__________________________________________________________________________
C
C PHYTOPLANKTON N ___
        sms(i,j,k,bi,bj,iphyn) = maskC(i,j,k,bi,bj)*(
     &       + N_assim                       * phyC
     &       - lossN*limitFacN               * phyN
     &       - aggregationRate               * phyN
     &       - grazingFlux_phy
     &                     ) * dt            + sms(i,j,k,bi,bj,iphyn)   
C__________________________________________________________________________
C
C PHYTOPLANKTON C ___
        sms(i,j,k,bi,bj,iphyc) = maskC(i,j,k,bi,bj)*(
     &       + C_phot                        * phyC 
     &       - lossC*limitFacN               * phyC
     &       - phyRespRate                   * phyC
     &       - aggregationRate               * phyC
     &       - grazingFlux_phy * recipQuota
     &                     )  * dt           + sms(i,j,k,bi,bj,iphyc)  
C__________________________________________________________________________
C
C PHYTOPLANKTON CHL ___
        sms(i,j,k,bi,bj,ipchl) = maskC(i,j,k,bi,bj)*(
     &       + chlSynth                      * phyC
     &       - deg_CHL                       * CHL
     &       - aggregationRate               * CHL
     &       - grazingFlux_phy * CHL2N
     &                     ) * dt            + sms(i,j,k,bi,bj,ipchl)
C__________________________________________________________________________
C
C DET N _______________
        sms(i,j,k,bi,bj,idetn) = maskC(i,j,k,bi,bj)*(      
     &       + grazingFlux * (1.-grazEff)
     &       + aggregationRate               * phyN 
     &       + aggregationRate               * diaN 
     &       + hetLossFlux
     &       - reminN * arrFunc              * detN 
     &                     ) * dt            + sms(i,j,k,bi,bj,idetn)
C__________________________________________________________________________
C
C DET C _______________
        sms(i,j,k,bi,bj,idetc) = maskC(i,j,k,bi,bj)*( 
     &       + (grazingFlux_phy * recipQuota +
     &          grazingFlux_dia * recipQuota_dia) * (1.-grazEff)
     &       + aggregationRate               * phyC
     &       + aggregationRate               * diaC
     &       + hetLossFlux   * recipQZoo
     &       - reminC * arrFunc              * detC   
     &       + rho_c2                        * f_TEP*eoC 
     &                     ) * dt            + sms(i,j,k,bi,bj,idetc)
C__________________________________________________________________________
C
C HET N
        sms(i,j,k,bi,bj,ihetn) = maskC(i,j,k,bi,bj)*(
     &      + grazingFlux * grazEff
     &      - hetLossFlux
     &      - lossN_z                        * hetN
     &                     ) * dt            + sms(i,j,k,bi,bj,ihetn)
C_________________________________________________________________________
C
C HET C
        sms(i,j,k,bi,bj,ihetc) = maskC(i,j,k,bi,bj)*(
     &       + (grazingFlux_phy * recipQuota +
     &          grazingFlux_dia * recipQuota_dia) * grazEff
     &       - hetLossFlux * recipQZoo
     &       - lossC_z                       * hetC
     &       - hetRespFlux
     &                     ) * dt            + sms(i,j,k,bi,bj,ihetc)
C_________________________________________________________________________
C
C EXTRACELLULAR ORGANIC N
        sms(i,j,k,bi,bj,idon) = maskC(i,j,k,bi,bj)*( 
     &       + lossN*limitFacN               * phyN
     &       + lossN_d*limitFacN_dia         * diaN
     &       + reminN * arrFunc              * detN 
     &       + lossN_z                       * hetN
     &       - rho_N  * arrFunc              * DON 
     &                    ) * dt             + sms(i,j,k,bi,bj,idon) 
C_________________________________________________________________________
C 
C EXTRACELLULAR ORGANIC C 
        sms(i,j,k,bi,bj,idoc) = maskC(i,j,k,bi,bj)*( 
     &       + lossC*limitFacN               * phyC
     &       + lossC_d*limitFacN_dia         * diaC
     &       + reminC * arrFunc              * detC 
     &       + lossC_z                       * hetC
     &       - rho_C1 * arrFunc              * (c1-f_TEP)*eoC  
     &       - rho_c2                        * f_TEP*eoC 
     &                    )  * dt            + sms(i,j,k,bi,bj,idoc) 
C_________________________________________________________________________
C
C DIATOM N ___
        sms(i,j,k,bi,bj,idian) = maskC(i,j,k,bi,bj)*(
     &       + N_assim_dia                   * diaC
     &       - lossN_d*limitFacN_dia         * diaN
     &       - aggregationRate               * diaN
     &       - grazingFlux_dia
     &                     ) * dt            + sms(i,j,k,bi,bj,idian)   
C__________________________________________________________________________
C
C DIATOM C ___
        sms(i,j,k,bi,bj,idiac) = maskC(i,j,k,bi,bj)*(
     &       + C_phot_dia                    * diaC 
     &       - lossC_d*limitFacN_dia         * diaC
     &       - phyRespRate_dia               * diaC
     &       - aggregationRate               * diaC
     &       - grazingFlux_dia * recipQuota_dia
     &                     )  * dt           + sms(i,j,k,bi,bj,idiac)  
C__________________________________________________________________________
C
C DIATOM CHL ___
        sms(i,j,k,bi,bj,idchl) = maskC(i,j,k,bi,bj)*(
     &       + chlSynth_dia                  * diaC
     &       - deg_CHL_d                     * diaCHL
     &       - aggregationRate               * diaCHL
     &       - grazingFlux_dia * CHL2N_dia
     &                     ) * dt            + sms(i,j,k,bi,bj,idchl)
C__________________________________________________________________________
C
C DIATOM Si ___
        sms(i,j,k,bi,bj,idiasi) = maskC(i,j,k,bi,bj)*(
     &       + Si_assim                      * diaC 
     &       - lossN_d*limitFacN_dia         * diaSi
     &       - aggregationRate               * diaSi
     &       - grazingFlux_dia * qSiN
     &                      ) * dt           + sms(i,j,k,bi,bj,idiasi)   
C_________________________________________________________________________
C 
C DET Si_______________
        sms(i,j,k,bi,bj,idetsi) = maskC(i,j,k,bi,bj)*(      
     &       + aggregationRate               * diaSi
     &       + lossN_d*limitFacN_dia         * diaSi
     &       + grazingFlux_dia * qSiN
     &       - reminSiT                      * detSi 
     &                      ) * dt           + sms(i,j,k,bi,bj,idetsi)
C_________________________________________________________________________
C
C Silicate _______________
        sms(i,j,k,bi,bj,isi) = maskC(i,j,k,bi,bj)*( 
     &       - Si_assim                      * diaC
     &       + reminSiT                      * detSi 
     &                     ) * dt            + sms(i,j,k,bi,bj,isi) 
C_________________________________________________________________________
C
C Fe
        if (FeLimit) then
#ifdef RECOM_CONSTANT_FE2N
C constant Fe:N ratio
         sms(i,j,k,bi,bj,ife) = maskC(i,j,k,bi,bj)*(
     &        Fe2N * ( 
     &       - N_assim                       *phyC 
     &       - N_assim_dia                   * diaC 
#ifdef RECOM_FE_RECYCLING_SHORT
     &       + lossN*limitFacN               * phyN
     &       + lossN_d*limitFacN_dia         * diaN
     &       + reminN * arrFunc              * detN 
     &       + lossN_z                       * hetN
#else
     &       + rho_N * arrFunc               * DON
#endif
     &                )
     &       - kScavFe     *detC             * freeFe
     &                      ) * dt           + sms(i,j,k,bi,bj,ife)
#else
C constant Fe:C ratio
         sms(i,j,k,bi,bj,ife) = maskC(i,j,k,bi,bj)*(
     &        Fe2C * ( 
     &       - C_phot                        * phyC 
     &       - C_phot_dia                    * diaC 
     &       + phyRespRate                   *phyC
     &       + phyRespRate_dia               * diaC
#ifdef RECOM_FE_RECYCLING_SHORT
     &       + lossC*limitFacN               * phyC
     &       + lossC_d*limitFacN_dia         * diaC
     &       + reminC * arrFunc              * detC 
     &       + lossC_z                       * hetC
#else
     &       + rho_C1 * arrFunc * (c1-f_TEP) * eoC
#endif
     &       + hetRespFlux 
     &                )
     &       - kScavFe     *detC             * freeFe
     &                      ) * dt           + sms(i,j,k,bi,bj,ife)
#endif
        else
         sms(i,j,k,bi,bj,iFe) = c0
        end if
#ifdef RECOM_CALCIFICATION
C__________________________________________________________________________
C
C SMALL PHYTOPLANKTON CALCITE ___
        sms(i,j,k,bi,bj,iphycalc) = maskC(i,j,k,bi,bj)*(
     &       calcification 
     &       - (lossC * limitFacN + phyRespRate) * phyCalc
     &       - calc_loss_agg - calc_loss_gra 
     &                     )  * dt           + sms(i,j,k,bi,bj,iphycalc) 

C__________________________________________________________________________
C
C DETRITUS CALCITE ___
        sms(i,j,k,bi,bj,idetcalc) = maskC(i,j,k,bi,bj) * (
     &       (lossC * limitFacN + phyRespRate) * phyCalc
     &       + calc_loss_agg
     &       + calc_loss_gra * (1.0 - calc_diss_guts)
     &       - calc_diss * detCalc
     &                     )  * dt           + sms(i,j,k,bi,bj,idetcalc) 

#endif 
#ifdef RECOM_MANY_LIGANDS
#ifdef RECOM_CONSTANT_FE2N
        fe_uptake =  Fe2N * (N_assim * phyC + N_assim_dia *diaC) * dt
#else
        fe_uptake =  Fe2C * (C_phot * phyC + C_phot_dia * diaC) * dt
#endif
        sms(i,j,k,bi,bj,ilig1) = maskC(i,j,k,bi,bj) * (
     &       lig2n(1) * reminN * arrFunc    * detN
     &       + lig2n2(1) * (lossN*limitFacN    * phyN
     &       + lossN_d*limitFacN_dia           * diaN
     &       + lossN_z                         * hetN)
     &       - (remlig(1) * arrFunc)        * rlig1
     &       - lig_phred(1) * PARave*rIRmax * rlig1
     &                     )  * dt  
     &       - lig_upt(1)*min( fe_uptake, rlig1)        
     &       + sms(i,j,k,bi,bj,ilig1) 
        sms(i,j,k,bi,bj,ilig2) = maskC(i,j,k,bi,bj) * (
     &       lig2n(2) * reminN * arrFunc    * detN
     &       + lig2n2(2) * (lossN*limitFacN    * phyN
     &       + lossN_d*limitFacN_dia           * diaN
     &       + lossN_z                         * hetN)
     &       - (remlig(2) * arrFunc)        * rlig2
     &       - lig_phred(2) * PARave*rIRmax * rlig2
     &                     )  * dt      
     &       - lig_upt(2)*min( fe_uptake, rlig2)        
     &       + sms(i,j,k,bi,bj,ilig2) 
        sms(i,j,k,bi,bj,ilig3) = maskC(i,j,k,bi,bj) * (
     &       lig2n(3) * reminN * arrFunc    * detN
     &       + lig2n2(3) * (lossN*limitFacN    * phyN
     &       + lossN_d*limitFacN_dia           * diaN
     &       + lossN_z                         * hetN)
     &       - (remlig(3) * arrFunc)        * rlig3
     &       - lig_phred(3) * PARave*rIRmax * rlig3
     &                     )  * dt   
     &       - lig_upt(3)*min( fe_uptake, rlig3)        
     &       + sms(i,j,k,bi,bj,ilig3) 
        sms(i,j,k,bi,bj,ilig4) = maskC(i,j,k,bi,bj) * (
     &       lig2n(4) * reminN * arrFunc    * detN
     &       + lig2n2(4) * (lossN*limitFacN    * phyN
     &       + lossN_d*limitFacN_dia           * diaN
     &       + lossN_z                         * hetN)
     &       - (remlig(4) * arrFunc)        * rlig4
     &       - lig_phred(4) * PARave*rIRmax * rlig4
     &                     )  * dt   
     &       - lig_upt(4)*min( fe_uptake, rlig4)        
     &       + sms(i,j,k,bi,bj,ilig4) 
        sms(i,j,k,bi,bj,ilig5) = maskC(i,j,k,bi,bj) * (
     &       lig2n(5) * reminN * arrFunc    * detN
     &       + lig2n2(5) * (lossN*limitFacN    * phyN
     &       + lossN_d*limitFacN_dia           * diaN
     &       + lossN_z                         * hetN)
     &       - (remlig(5) * arrFunc)        * rlig5
     &       - lig_phred(5) * PARave*rIRmax * rlig5
     &                     )  * dt     
     &       - lig_upt(5)*min( fe_uptake, rlig5)        
     &       + sms(i,j,k,bi,bj,ilig5) 
#endif
C_________________________________________________________________________
C
C_________________________________________________________________________


C averaged rates (relevant for community production) 
C     net primary production [mmol C m^{-3} d^{-1}]
#ifdef RECOM_2CLASSES
        IF ( nDiags3d .GT. 0 )
     &   diags3d(i,j,k,1) = diags3d(i,j,k,1) + 1./real(bio_step) * (
     &       ( 
     &       C_phot 
     &       - phyRespRate
     &       )*phyC 
     &       ) 
        IF ( nDiags3d .GT. 1 )
     &   diags3d(i,j,k,2) = diags3d(i,j,k,2) + 1./real(bio_step) * (
     &       ( 
     &       C_phot_dia
     &       - phyRespRate_dia
     &       )*diaC 
     &       ) 
#else
        IF ( nDiags3d .GT. 0 )
     &   diags3d(i,j,k,1) = diags3d(i,j,k,1) + 1./real(bio_step) * (
     &       ( 
     &       C_phot 
     &       - phyRespRate
     &       )*phyC 
     &       ) 
#endif

C     gross primary production
#ifdef RECOM_2CLASSES
        IF ( nDiags3d .GT. 2 )
     &  diags3d(i,j,k,3) = diags3d(i,j,k,3) +  1./real(bio_step) * (
     &       C_phot *phyC 
     &       ) 
        IF ( nDiags3d .GT. 3 )
     &  diags3d(i,j,k,4) = diags3d(i,j,k,4) +  1./real(bio_step) * (
     &       C_phot_dia *diaC 
     &       ) 
#else
        IF ( nDiags3d .GT. 1 )
     &  diags3d(i,j,k,2) = diags3d(i,j,k,2) +  1./real(bio_step) * (
     &       C_phot *phyC 
     &       ) 
#endif  
C     net nitrogen assimilation
#ifdef RECOM_2CLASSES
        IF ( nDiags3d .GT. 4 )
     &  diags3d(i,j,k,5) = diags3d(i,j,k,5) +  1./real(bio_step) * (
     &       + N_assim                       * phyC
     &       - lossN*limitFacN               * phyN)
        IF ( nDiags3d .GT. 5 )
     &  diags3d(i,j,k,6) = diags3d(i,j,k,6) +  1./real(bio_step) * (
     &       + N_assim_dia                   * diaC
     &       - lossN*limitFacN_dia           * diaN)
#else
        IF ( nDiags3d .GT. 2 )
     &  diags3d(i,j,k,3) = diags3d(i,j,k,3) +  1./real(bio_step) * (
     &       + N_assim                       * phyC
     &       - lossN*limitFacN               * phyN)
#endif
C     gross nitrogen assimilation
#ifdef RECOM_2CLASSES
        IF ( nDiags3d .GT. 6 )
     &  diags3d(i,j,k,7) = diags3d(i,j,k,7) +  1./real(bio_step) * (
     &       + N_assim                       * phyC)
        IF ( nDiags3d .GT. 7 )
     &  diags3d(i,j,k,8) = diags3d(i,j,k,8) +  1./real(bio_step) * (
     &       + N_assim_dia * diaC )
#else
        IF ( nDiags3d .GT. 3 )
     &  diags3d(i,j,k,4) = diags3d(i,j,k,4) +  1./real(bio_step) * (
     &       + N_assim                       * phyC)
#endif

#ifdef RECOM_MAREMIP
C----------------------------------------------------------------------
C     Additional diagnostics for the MAREMIP data analysis
C----------------------------------------------------------------------
        ndiags3d_used = 8
        if ( nDiags3d .ge. (ndiags3d_used+24) ) then
C - DOC remineralization
           diags3d(i,j,k,ndiags3d_used+1) = 
     &       diags3d(i,j,k,ndiags3d_used+1) + 1./real(bio_step) * (
     &       rho_C1  * arrFunc * (c1-f_TEP) * eoC)
C - total ZOO grazing
           diags3d(i,j,k,ndiags3d_used+2) = 
     &       diags3d(i,j,k,ndiags3d_used+2) + 1./real(bio_step) * (
     &       grazingFlux_dia * recipQuota_dia +
     &       grazingFlux_phy * recipQuota)
C - total respiration
           diags3d(i,j,k,ndiags3d_used+3) = 
     &       diags3d(i,j,k,ndiags3d_used+3) + 1./real(bio_step) * (
     &       phyRespRate * PhyC + phyRespRate_dia * DiaC + 
     &       hetRespFlux )
C - calcite production
           diags3d(i,j,k,ndiags3d_used+4) = 
     &       diags3d(i,j,k,ndiags3d_used+4) + 1./real(bio_step) * (
     &       calcification )
C - calcite dissolution
           diags3d(i,j,k,ndiags3d_used+5) = 
     &       diags3d(i,j,k,ndiags3d_used+5) + 1./real(bio_step) * (
     &       calc_diss * detCalc + calc_loss_gra * calc_diss_guts )
C - DOC production by Zooplankton
           diags3d(i,j,k,ndiags3d_used+6) = 
     &       diags3d(i,j,k,ndiags3d_used+6) + 1./real(bio_step) * (
     &       lossC_z * hetC )
C - POC production by Zooplankton
           diags3d(i,j,k,ndiags3d_used+7) = 
     &       diags3d(i,j,k,ndiags3d_used+7) + 1./real(bio_step) * (
     &       hetLossFlux * recipQZoo )
C - POC production by Diatoms
           diags3d(i,j,k,ndiags3d_used+8) = 
     &       diags3d(i,j,k,ndiags3d_used+8) + 1./real(bio_step) * (
     &       aggregationRate * diaC + 
     &       grazingFlux_dia * recipQuota_dia * ( 1. - grazEff ) )
C - POC production by small Phytoplankton
           diags3d(i,j,k,ndiags3d_used+9) = 
     &       diags3d(i,j,k,ndiags3d_used+9) + 1./real(bio_step) * (
     &       aggregationRate * phyC + 
     &       grazingFlux_phy * recipQuota * ( 1. - grazEff ) )
C - DOC production by Diatoms
           diags3d(i,j,k,ndiags3d_used+10) = 
     &       diags3d(i,j,k,ndiags3d_used+10) + 1./real(bio_step) * (
     &       lossC_d * limitFacN_dia * diaC )
C - DOC production by small Phytoplankton
           diags3d(i,j,k,ndiags3d_used+11) = 
     &       diags3d(i,j,k,ndiags3d_used+11) + 1./real(bio_step) * (
     &       lossC * limitFacN * phyC )
C - respiration by Diatoms
           diags3d(i,j,k,ndiags3d_used+12) = 
     &       diags3d(i,j,k,ndiags3d_used+12) + 1./real(bio_step) * (
     &       phyRespRate_dia * DiaC )
C - respiration by small Phytoplankton
           diags3d(i,j,k,ndiags3d_used+13) = 
     &       diags3d(i,j,k,ndiags3d_used+13) + 1./real(bio_step) * (
     &       phyRespRate * PhyC )
C - respiration by Zooplankton
           diags3d(i,j,k,ndiags3d_used+14) = 
     &       diags3d(i,j,k,ndiags3d_used+14) + 1./real(bio_step) * (
     &       hetRespFlux )
C - grazing on Diatoms by Zooplankton
           diags3d(i,j,k,ndiags3d_used+15) = 
     &       diags3d(i,j,k,ndiags3d_used+15) + 1./real(bio_step) * (
     &       grazingFlux_dia * recipQuota_dia * grazEff )
C - grazing on small Phytoplankton by Zooplankton
           diags3d(i,j,k,ndiags3d_used+16) = 
     &       diags3d(i,j,k,ndiags3d_used+16) + 1./real(bio_step) * (
     &       grazingFlux_phy * recipQuota * grazEff )
C - 3-dimensional PAR
           diags3d(i,j,k,ndiags3d_used+17) = 
     &       diags3d(i,j,k,ndiags3d_used+17) + 1./real(bio_step) * (
     &       PARave )
C - diatom nitrogen growth limitation 
           diags3d(i,j,k,ndiags3d_used+18) = 
     &       diags3d(i,j,k,ndiags3d_used+18) + 1./real(bio_step) * (
     &       recom_limiter(NMinSlope, NCmin_d, quota_dia) )
C - small phytoplankton nitrogen growth limitation 
           diags3d(i,j,k,ndiags3d_used+19) = 
     &       diags3d(i,j,k,ndiags3d_used+19) + 1./real(bio_step) * (
     &       recom_limiter(NMinSlope, NCmin, quota) )
C - diatom light limitation 
           if (Pmax_dia .ge. tiny) then
              diags3d(i,j,k,ndiags3d_used+20) = 
     &          diags3d(i,j,k,ndiags3d_used+20) + 1./real(bio_step) * (
     &          c1 - exp(-alpha_d * CHL2C_dia * PARave / pMax_dia) )
           endif
C - small phytoplankton light limitation 
           if (Pmax .ge. tiny) then
              diags3d(i,j,k,ndiags3d_used+21) = 
     &          diags3d(i,j,k,ndiags3d_used+21) + 1./real(bio_step) * (
     &          c1 - exp(-alpha * CHL2C * PARave / pMax) )
           endif
C - diatom iron limitation 
           diags3d(i,j,k,ndiags3d_used+22) = 
     &       diags3d(i,j,k,ndiags3d_used+22) + 1./real(bio_step) * (
     &       fe / (k_Fe_d + fe) )
C - small phytoplankton iron limitation
           diags3d(i,j,k,ndiags3d_used+23) = 
     &       diags3d(i,j,k,ndiags3d_used+23) + 1./real(bio_step) * (
     &       fe / (k_Fe + fe) )
C - diatom silica growth limitation 
           diags3d(i,j,k,ndiags3d_used+24) = 
     &       diags3d(i,j,k,ndiags3d_used+24) + 1./real(bio_step) * (
     &       recom_limiter(SiMinSlope, SiCmin, qSiC) )
        endif
#endif

       end do ! i-loop
       end do ! j-loop
       end do ! depth loop 

       if ( benthicLayer ) then
        do j = jMin, jMax
         do i = iMin, iMax
C     in the benthic layer, detritus (and phytoplankton) is 
C     remineralized into DIN/DIC/Si and instantly diffused into
C     the bottom wet cell 
          kLoc = MAX(kLowC(i,j,bi,bj),1)
          decayBenthos(1) = decayRateBenN*benthos(i,j,1)
          decayBenthos(2) = decayRateBenC*benthos(i,j,2)
          benthos(i,j,1)  = benthos(i,j,1) - decayBenthos(1)*dt
          benthos(i,j,2)  = benthos(i,j,2) - decayBenthos(2)*dt
C change of inorganic N 
          sms(i,j,kLoc,bi,bj,idin)  = sms(i,j,kLoc,bi,bj,idin)
     &         + decayBenthos(1) * dt * maskC(i,j,kLoc,bi,bj) * 
     &           recip_drF(kLoc)*recip_hfacc(i,j,kLoc,bi,bj)
C change of alkalinity with remineralization of organic N
          sms(i,j,kLoc,bi,bj,ialk)  = sms(i,j,kLoc,bi,bj,ialk)
     &         - 1.0625 * decayBenthos(1)*dt*maskC(i,j,kLoc,bi,bj) * 
     &           recip_drF(kLoc)*recip_hfacc(i,j,kLoc,bi,bj)
C change of DIC with remin of organic C
          sms(i,j,kLoc,bi,bj,idic)  = sms(i,j,kLoc,bi,bj,idic)
     &         + decayBenthos(2)*dt*maskC(i,j,kLoc,bi,bj) * 
     &           recip_drF(kLoc)*recip_hfacc(i,j,kLoc,bi,bj)
#ifdef RECOM_CONSTANT_FE2N
C change of Fe with remin of organic N
#ifdef RECOM_IRON_BENTHOS
          sms(i,j,kLoc,bi,bj,ife)   = sms(i,j,kLoc,bi,bj,ife)
     &         + Fe2N_benthos * decayBenthos(1) * dt * 
     &           maskC(i,j,kLoc,bi,bj) * recip_drF(kLoc) *
     &           recip_hfacc(i,j,kLoc,bi,bj)
#else
          sms(i,j,kLoc,bi,bj,ife)   = sms(i,j,kLoc,bi,bj,ife)
     &         + Fe2N * decayBenthos(1)*dt*maskC(i,j,kLoc,bi,bj) * 
     &           recip_drF(kLoc)*recip_hfacc(i,j,kLoc,bi,bj)
#endif
#else
C change of Fe with remin of organic C
#ifdef RECOM_IRON_BENTHOS
          sms(i,j,kLoc,bi,bj,ife)   = sms(i,j,kLoc,bi,bj,ife)
     &         + Fe2C_benthos * decayBenthos(2) * dt * 
     &           maskC(i,j,kLoc,bi,bj) * recip_drF(kLoc) *
     &           recip_hfacc(i,j,kLoc,bi,bj)
#else
          sms(i,j,kLoc,bi,bj,ife)   = sms(i,j,kLoc,bi,bj,ife)
     &         + Fe2C * decayBenthos(2)*dt*maskC(i,j,kLoc,bi,bj) * 
     &           recip_drF(kLoc)*recip_hfacc(i,j,kLoc,bi,bj)
#endif
#endif
          decayBenthos(3) = decayRateBenSi*benthos(i,j,3)
          benthos(i,j,3)  = benthos(i,j,3) - decayBenthos(3)*dt
C change of silicate
          sms(i,j,kLoc,bi,bj,isi)   = sms(i,j,kLoc,bi,bj,isi)  
     &         + decayBenthos(3)*dt*maskC(i,j,kLoc,bi,bj) * 
     &           recip_drF(kLoc)*recip_hfacc(i,j,kLoc,bi,bj)
#ifdef RECOM_CALCIFICATION
C          decayBenthos(4) = calc_diss * benthos(i,j,4)
          decayBenthos(4) = decayRateBenCa * benthos(i,j,4)
          benthos(i,j,4)  = benthos(i,j,4) - decayBenthos(4)*dt
C change of DIC with dissolutionof CaCO3
          sms(i,j,kLoc,bi,bj,idic)   = sms(i,j,kLoc,bi,bj,idic)  
     &         + decayBenthos(4) * dt * maskC(i,j,kLoc,bi,bj) *
     &           recip_drF(kLoc)*recip_hfacc(i,j,kLoc,bi,bj)
C change of Alkalinity with dissolution of CaCO3
          sms(i,j,kLoc,bi,bj,ialk)   = sms(i,j,kLoc,bi,bj,ialk)  
     &         + 2.0 * decayBenthos(4) * dt * maskC(i,j,kLoc,bi,bj) *
     &           recip_drF(kLoc)*recip_hfacc(i,j,kLoc,bi,bj)
#endif
#ifdef RECOM_MANY_LIGANDS
C change of ligands (proportional to change in N)
          sms(i,j,kLoc,bi,bj,ilig1)  = sms(i,j,kLoc,bi,bj,ilig1)
     &      + lig2n(1) * decayBenthos(1) * dt * maskC(i,j,kLoc,bi,bj) * 
     &        recip_drF(kLoc)*recip_hfacc(i,j,kLoc,bi,bj)
          sms(i,j,kLoc,bi,bj,ilig2)  = sms(i,j,kLoc,bi,bj,ilig2)
     &      + lig2n(2) * decayBenthos(1) * dt * maskC(i,j,kLoc,bi,bj) * 
     &        recip_drF(kLoc)*recip_hfacc(i,j,kLoc,bi,bj)
          sms(i,j,kLoc,bi,bj,ilig3)  = sms(i,j,kLoc,bi,bj,ilig3)
     &      + lig2n(3) * decayBenthos(1) * dt * maskC(i,j,kLoc,bi,bj) * 
     &        recip_drF(kLoc)*recip_hfacc(i,j,kLoc,bi,bj)
          sms(i,j,kLoc,bi,bj,ilig4)  = sms(i,j,kLoc,bi,bj,ilig4)
     &      + lig2n(4) * decayBenthos(1) * dt * maskC(i,j,kLoc,bi,bj) * 
     &        recip_drF(kLoc)*recip_hfacc(i,j,kLoc,bi,bj)
          sms(i,j,kLoc,bi,bj,ilig5)  = sms(i,j,kLoc,bi,bj,ilig5)
     &      + lig2n(5) * decayBenthos(1) * dt * maskC(i,j,kLoc,bi,bj) * 
     &        recip_drF(kLoc)*recip_hfacc(i,j,kLoc,bi,bj)
#endif
C------------------------------------
C Diagnostics for diagenetic fluxes from sediment into water
C------------------------------------
          if (ndiags2D .ge. 9) then
C diagenetic N flux
           diags2d(i,j,5) = diags2d(i,j,5) + 1./real(bio_step) * 
     &                      decayBenthos(1)
C diagenetic C flux
           diags2d(i,j,6) = diags2d(i,j,6) + 1./real(bio_step) * (
     &                      decayBenthos(2) 
#ifdef RECOM_CALCIFICATION
     &                      + decayBenthos(4)
#endif
     &                      )
C diagenetic Alk flux
           diags2d(i,j,7) = diags2d(i,j,7) + 1./real(bio_step) * (
     &                      -1.0625 * decayBenthos(1)
#ifdef RECOM_CALCIFICATION
     &                      + 2.0 * decayBenthos(4)
#endif
     &                      )
C diagenetic Si flux
           diags2d(i,j,8) = diags2d(i,j,8) + 1./real(bio_step) *
     &                      decayBenthos(3)
C diagenetic Fe flux
#ifdef RECOM_CONSTANT_FE2N
#ifdef RECOM_IRON_BENTHOS
           diags2d(i,j,9) = diags2d(i,j,9) + 1./real(bio_step) *
     &                      Fe2N_benthos * decayBenthos(1)
#else
           diags2d(i,j,9) = diags2d(i,j,9) + 1./real(bio_step) *
     &                      Fe2N * decayBenthos(1)
#endif
#else
#ifdef RECOM_IRON_BENHTOS
           diags2d(i,j,9) = diags2d(i,j,9) + 1./real(bio_step) *
     &                      Fe2C_benthos * decayBenthos(2)
#else
           diags2d(i,j,9) = diags2d(i,j,9) + 1./real(bio_step) *
     &                      Fe2C * decayBenthos(2)
#endif
#endif
          endif
         end do
        end do
       endif

      end do                    ! time loop
 
C--------------------------------------------------------------------- 

      dt=delta_t/one_day        ! hourly timestep given in unit days 
      if ( Vphy .gt. c0 ) then
 
C----------------------------------------------------------------------
C Sinking of small phytoplankton
C----------------------------------------------------------------------
       call recom_sinking(dt,recip_drF,recip_drC,recip_hFacC,maskC, 
     &      vSinkPhy,state(1-Olx,1-Oly,1,1,1,iphyn),sink,
#ifdef RECOM_EXPORT_DIAGNOSTICS
     &      export,
#endif
#ifdef RECOM_MAREMIP
     &      export3d,
#endif
     &      Nz,iMin,iMax,jMin,jMax,bi,bj) ! PhyN
       do k = 1,Nz
        do j = jMin,jMax
         do i = iMin,iMax
          sms(i,j,k,bi,bj,iphyn) = sms(i,j,k,bi,bj,iphyn) + sink(i,j,k)
         enddo
        enddo
       enddo
#ifdef RECOM_EXPORT_DIAGNOSTICS
       do j = jMin,jMax
          do i = iMin,iMax
             diags2d(i,j,10) = diags2d(i,j,10) + export(i,j)
          enddo
       enddo
#endif
#ifdef RECOM_MAREMIP
C - sinking flux of PON 
       do k = 1,Nz
          do j = jMin,jMax
             do i = iMin,iMax
                diags3d(i,j,k,ndiags3d_used+25) = 
     &          diags3d(i,j,k,ndiags3d_used+25) + 
     &               export3d(i,j,k)
             enddo
          enddo
       enddo
#endif

       call recom_sinking(dt,recip_drF,recip_drC,recip_hFacC,maskC, 
     &      vSinkPhy,state(1-Olx,1-Oly,1,1,1,iphyc),sink,
#ifdef RECOM_EXPORT_DIAGNOSTICS
     &      export,
#endif
#ifdef RECOM_MAREMIP
     &      export3d,
#endif
     &      Nz,iMin,iMax,jMin,jMax,bi,bj) ! PhyC
       do k = 1,Nz
        do j = jMin,jMax
         do i = iMin,iMax
          sms(i,j,k,bi,bj,iphyc) = sms(i,j,k,bi,bj,iphyc) + sink(i,j,k)
         enddo
        enddo
       enddo
#ifdef RECOM_EXPORT_DIAGNOSTICS
       do j = jMin,jMax
          do i = iMin,iMax
             diags2d(i,j,11) = diags2d(i,j,11) + export(i,j)
          enddo
       enddo
#endif
#ifdef RECOM_MAREMIP
C - sinking flux of POC 
       do k = 1,Nz
          do j = jMin,jMax
             do i = iMin,iMax
                diags3d(i,j,k,ndiags3d_used+26) = 
     &          diags3d(i,j,k,ndiags3d_used+26) + 
     &               export3d(i,j,k)
             enddo
          enddo
       enddo
#endif

       call recom_sinking(dt,recip_drF,recip_drC,recip_hFacC,maskC, 
     &      vSinkPhy,state(1-Olx,1-Oly,1,1,1,ipchl),sink,
#ifdef RECOM_EXPORT_DIAGNOSTICS
     &      export,
#endif
#ifdef RECOM_MAREMIP
     &      export3d,
#endif
     &      Nz,iMin,iMax,jMin,jMax,bi,bj) ! CHL
       do k = 1,Nz
        do j = jMin,jMax
         do i = iMin,iMax
          sms(i,j,k,bi,bj,ipchl) = sms(i,j,k,bi,bj,ipchl) + sink(i,j,k)
         enddo
        enddo
       enddo
#ifdef RECOM_CALCIFICATION
       call recom_sinking(dt,recip_drF,recip_drC,recip_hFacC,maskC, 
     &      vSinkPhy,state(1-Olx,1-Oly,1,1,1,iphycalc),sink,
#ifdef RECOM_EXPORT_DIAGNOSTICS
     &      export,
#endif
#ifdef RECOM_MAREMIP
     &      export3d,
#endif
     &      Nz,iMin,iMax,jMin,jMax,bi,bj) ! PhyCalc
       do k = 1,Nz
        do j = jMin,jMax
         do i = iMin,iMax
          sms(i,j,k,bi,bj,iphycalc) = sms(i,j,k,bi,bj,iphycalc) 
     &                              + sink(i,j,k)
         enddo
        enddo
       enddo
#ifdef RECOM_EXPORT_DIAGNOSTICS
       do j = jMin,jMax
          do i = iMin,iMax
             diags2d(i,j,12) = diags2d(i,j,12) + export(i,j)
          enddo
       enddo
#endif
#ifdef RECOM_MAREMIP
C - sinking flux of CaCO3 
       do k = 1,Nz
          do j = jMin,jMax
             do i = iMin,iMax
                diags3d(i,j,k,ndiags3d_used+28) = 
     &          diags3d(i,j,k,ndiags3d_used+28) + 
     &               export3d(i,j,k)
             enddo
          enddo
       enddo
#endif
#endif
      endif
C----------------------------------------------------------------------
C Sinking of diatoms
C----------------------------------------------------------------------

      if ( Vdia .gt. c0 ) then
       call recom_sinking(dt,recip_drF,recip_drC,recip_hFacC,maskC, 
     &      vSinkDia,state(1-Olx,1-Oly,1,1,1,idian),sink,
#ifdef RECOM_EXPORT_DIAGNOSTICS
     &      export,
#endif
#ifdef RECOM_MAREMIP
     &      export3d,
#endif
     &      Nz,iMin,iMax,jMin,jMax,bi,bj)
       do k = 1,Nz
        do j = jMin,jMax
         do i = iMin,iMax
          sms(i,j,k,bi,bj,idian)= sms(i,j,k,bi,bj,idian) + sink(i,j,k)
         enddo
        enddo
       enddo
#ifdef RECOM_EXPORT_DIAGNOSTICS
       do j = jMin,jMax
          do i = iMin,iMax
             diags2d(i,j,10) = diags2d(i,j,10) + export(i,j)
          enddo
       enddo
#endif
#ifdef RECOM_MAREMIP
C - sinking flux of PON 
       do k = 1,Nz
          do j = jMin,jMax
             do i = iMin,iMax
                diags3d(i,j,k,ndiags3d_used+25) = 
     &          diags3d(i,j,k,ndiags3d_used+25) + 
     &               export3d(i,j,k)
             enddo
          enddo
       enddo
#endif

       call recom_sinking(dt,recip_drF,recip_drC,recip_hFacC,maskC, 
     &      vSinkDia,state(1-Olx,1-Oly,1,1,1,idiac),sink,
#ifdef RECOM_EXPORT_DIAGNOSTICS
     &      export,
#endif
#ifdef RECOM_MAREMIP
     &      export3d,
#endif
     &      Nz,iMin,iMax,jMin,jMax,bi,bj)
       do k = 1,Nz
        do j = jMin,jMax
         do i = iMin,iMax
          sms(i,j,k,bi,bj,idiac)= sms(i,j,k,bi,bj,idiac) + sink(i,j,k)
         enddo
        enddo
       enddo
#ifdef RECOM_EXPORT_DIAGNOSTICS
       do j = jMin,jMax
          do i = iMin,iMax
             diags2d(i,j,11) = diags2d(i,j,11) + export(i,j)
          enddo
       enddo
#endif
#ifdef RECOM_MAREMIP
C - sinking flux of POC 
       do k = 1,Nz
          do j = jMin,jMax
             do i = iMin,iMax
                diags3d(i,j,k,ndiags3d_used+26) = 
     &          diags3d(i,j,k,ndiags3d_used+26) + 
     &               export3d(i,j,k)
             enddo
          enddo
       enddo
#endif
       call recom_sinking(dt,recip_drF,recip_drC,recip_hFacC,maskC, 
     &      vSinkDia,state(1-Olx,1-Oly,1,1,1,idchl),sink,
#ifdef RECOM_EXPORT_DIAGNOSTICS
     &      export,
#endif
#ifdef RECOM_MAREMIP
     &      export3d,
#endif
     &      Nz,iMin,iMax,jMin,jMax,bi,bj) 
       do k = 1,Nz
        do j = jMin,jMax
         do i = iMin,iMax
          sms(i,j,k,bi,bj,idchl)= sms(i,j,k,bi,bj,idchl) + sink(i,j,k)
         enddo
        enddo
       enddo
       call recom_sinking(dt,recip_drF,recip_drC,recip_hFacC,maskC, 
     &      vSinkDia,state(1-Olx,1-Oly,1,1,1,idiasi),sink,
#ifdef RECOM_EXPORT_DIAGNOSTICS
     &      export,
#endif
#ifdef RECOM_MAREMIP
     &      export3d,
#endif
     &      Nz,iMin,iMax,jMin,jMax,bi,bj) 
       do k = 1,Nz
        do j = jMin,jMax
         do i = iMin,iMax
          sms(i,j,k,bi,bj,idiasi)= sms(i,j,k,bi,bj,idiasi) + sink(i,j,k)
         enddo
        enddo
       enddo
      endif
#ifdef RECOM_EXPORT_DIAGNOSTICS
       do j = jMin,jMax
          do i = iMin,iMax
             diags2d(i,j,13) = diags2d(i,j,13) + export(i,j)
          enddo
       enddo
#endif
#ifdef RECOM_MAREMIP
C - sinking flux of BSi 
       do k = 1,Nz
          do j = jMin,jMax
             do i = iMin,iMax
                diags3d(i,j,k,ndiags3d_used+27) = 
     &          diags3d(i,j,k,ndiags3d_used+27) + 
     &               export3d(i,j,k)
             enddo
          enddo
       enddo
#endif

C----------------------------------------------------------------------
C Sinking of detritus
C----------------------------------------------------------------------
CTW increased sinking speed
#ifdef ALLOW_SINK_INCREASE
      if ( Vdetfast(2) .gt. c0 ) then
#else
      if ( Vdet .gt. c0 ) then
#endif /* ALLOW_SINK_INCREASE */
C         advect detritus with a different velocity
       call recom_sinking(dt,recip_drF,recip_drC,recip_hFacC,maskC, 
     &      vSinkDet,state(1-Olx,1-Oly,1,1,1,idetn),sink,
#ifdef RECOM_EXPORT_DIAGNOSTICS
     &      export,
#endif
#ifdef RECOM_MAREMIP
     &      export3d,
#endif
     &      Nz,iMin,iMax,jMin,jMax,bi,bj) ! DetN
       do k = 1,Nz
        do j = jMin,jMax
         do i = iMin,iMax
          sms(i,j,k,bi,bj,idetn) = sms(i,j,k,bi,bj,idetn) + sink(i,j,k)
         enddo
        enddo
       enddo
#ifdef RECOM_EXPORT_DIAGNOSTICS
       do j = jMin,jMax
          do i = iMin,iMax
             diags2d(i,j,10) = diags2d(i,j,10) + export(i,j)
          enddo
       enddo
#endif
#ifdef RECOM_MAREMIP
C - sinking flux of PON 
       do k = 1,Nz
          do j = jMin,jMax
             do i = iMin,iMax
                diags3d(i,j,k,ndiags3d_used+25) = 
     &          diags3d(i,j,k,ndiags3d_used+25) + 
     &               export3d(i,j,k)
             enddo
          enddo
       enddo
#endif

       call recom_sinking(dt,recip_drF,recip_drC,recip_hFacC,maskC, 
     &      vSinkDet,state(1-Olx,1-Oly,1,1,1,idetc),sink,
#ifdef RECOM_EXPORT_DIAGNOSTICS
     &      export,
#endif
#ifdef RECOM_MAREMIP
     &      export3d,
#endif
     &      Nz,iMin,iMax,jMin,jMax,bi,bj) ! DetC
       do k = 1,Nz
        do j = jMin,jMax
         do i = iMin,iMax
          sms(i,j,k,bi,bj,idetc) = sms(i,j,k,bi,bj,idetc) + sink(i,j,k)
         enddo
        enddo
       enddo
#ifdef RECOM_EXPORT_DIAGNOSTICS
       do j = jMin,jMax
          do i = iMin,iMax
             diags2d(i,j,11) = diags2d(i,j,11) + export(i,j)
          enddo
       enddo
#endif
#ifdef RECOM_MAREMIP
C - sinking flux of POC 
       do k = 1,Nz
          do j = jMin,jMax
             do i = iMin,iMax
                diags3d(i,j,k,ndiags3d_used+26) = 
     &          diags3d(i,j,k,ndiags3d_used+26) + 
     &               export3d(i,j,k)
             enddo
          enddo
       enddo
#endif

       call recom_sinking(dt,recip_drF,recip_drC,recip_hFacC,maskC, 
     &      vSinkDet,state(1-Olx,1-Oly,1,1,1,idetsi),sink,
#ifdef RECOM_EXPORT_DIAGNOSTICS
     &      export,
#endif
#ifdef RECOM_MAREMIP
     &      export3d,
#endif
     &      Nz,iMin,iMax,jMin,jMax,bi,bj) ! DetSi
       do k = 1,Nz
        do j = jMin,jMax
         do i = iMin,iMax
          sms(i,j,k,bi,bj,idetsi) = sms(i,j,k,bi,bj,idetsi) + 
     &      sink(i,j,k)
         enddo
        enddo
       enddo
      endif
#ifdef RECOM_EXPORT_DIAGNOSTICS
       do j = jMin,jMax
          do i = iMin,iMax
             diags2d(i,j,13) = diags2d(i,j,13) + export(i,j)
          enddo
       enddo
#endif
#ifdef RECOM_MAREMIP
C - sinking flux of BSi 
       do k = 1,Nz
          do j = jMin,jMax
             do i = iMin,iMax
                diags3d(i,j,k,ndiags3d_used+27) = 
     &          diags3d(i,j,k,ndiags3d_used+27) + 
     &               export3d(i,j,k)
             enddo
          enddo
       enddo
#endif

#ifdef RECOM_CALCIFICATION
       call recom_sinking(dt,recip_drF,recip_drC,recip_hFacC,maskC, 
     &      vSinkDet,state(1-Olx,1-Oly,1,1,1,idetcalc),sink,
#ifdef RECOM_EXPORT_DIAGNOSTICS
     &      export,
#endif
#ifdef RECOM_MAREMIP
     &      export3d,
#endif
     &      Nz,iMin,iMax,jMin,jMax,bi,bj) ! DetCalc
       do k = 1,Nz
        do j = jMin,jMax
         do i = iMin,iMax
          sms(i,j,k,bi,bj,idetcalc) = sms(i,j,k,bi,bj,idetcalc) 
     &                              + sink(i,j,k)
         enddo
        enddo
       enddo
#ifdef RECOM_EXPORT_DIAGNOSTICS
       do j = jMin,jMax
          do i = iMin,iMax
             diags2d(i,j,12) = diags2d(i,j,12) + export(i,j)
          enddo
       enddo
#endif
#ifdef RECOM_MAREMIP
C - sinking flux of CaCO3
       do k = 1,Nz
          do j = jMin,jMax
             do i = iMin,iMax
                diags3d(i,j,k,ndiags3d_used+28) = 
     &          diags3d(i,j,k,ndiags3d_used+28) + 
     &               export3d(i,j,k)
             enddo
          enddo
       enddo
#endif
#endif

C
C detritus and phytoplankton sink into the benthic layer and are lost from the water column
C (but remineralized and re-released in dissolved form later)
C 
      if ( benthicLayer ) then
       do j = jMin, jMax
       do i = iMin, iMax
C vSinkDet and vSinkPhy are positive downward velocities and flux
C detritus and phytoplankton from the bottom wet cell into
C the benthic layer
       kLoc = MAX(kLowC(i,j,bi,bj),1)
       wFluxDet(1)  = vSinkDet(i,j,kLoc)*state(i,j,kLoc,bi,bj,idetn)
       wFluxDet(2)  = vSinkDet(i,j,kLoc)*state(i,j,kLoc,bi,bj,idetc)
       wFluxPhy(1)  = vSinkPhy(i,j,kLoc)*state(i,j,kLoc,bi,bj,iphyn) 
       wFluxPhy(2)  = vSinkPhy(i,j,kLoc)*state(i,j,kLoc,bi,bj,iphyc)
       wFluxDia(1)  = vSinkDia(i,j,kLoc)*state(i,j,kLoc,bi,bj,idian)
       wFluxDia(2)  = vSinkDia(i,j,kLoc)*state(i,j,kLoc,bi,bj,idiac)
       sms(i,j,kLoc,bi,bj,idetn) = sms(i,j,kLoc,bi,bj,idetn) 
     &      - wFluxDet(1)*dt
     &      *recip_drF(kLoc)*recip_hfacc(i,j,kLoc,bi,bj)
       sms(i,j,kLoc,bi,bj,iphyn) = sms(i,j,kLoc,bi,bj,iphyn) 
     &      - wFluxPhy(1)*dt
     &      *recip_drF(kLoc)*recip_hfacc(i,j,kLoc,bi,bj)
       sms(i,j,kLoc,bi,bj,idian) = sms(i,j,kLoc,bi,bj,idian) 
     &      - wFluxDia(1)*dt
     &      *recip_drF(kLoc)*recip_hfacc(i,j,kLoc,bi,bj)
       sms(i,j,kLoc,bi,bj,idetc) = sms(i,j,kLoc,bi,bj,idetc) 
     &      - wFluxDet(2)*dt
     &      *recip_drF(kLoc)*recip_hfacc(i,j,kLoc,bi,bj)
        sms(i,j,kLoc,bi,bj,iphyc) = sms(i,j,kLoc,bi,bj,iphyc) 
     &      - wFluxPhy(2)*dt
     &      *recip_drF(kLoc)*recip_hfacc(i,j,kLoc,bi,bj)
        sms(i,j,kLoc,bi,bj,idiac) = sms(i,j,kLoc,bi,bj,idiac) 
     &      - wFluxDia(2)*dt
     &      *recip_drF(kLoc)*recip_hfacc(i,j,kLoc,bi,bj)

       wFluxDet(3) = vSinkDet(i,j,kLoc) * state(i,j,kLoc,bi,bj,idetsi) 
       wFluxPhy(3) = c0
       wFluxDia(3) = vSinkDia(i,j,kLoc) * state(i,j,kLoc,bi,bj,idiasi)
       sms(i,j,kLoc,bi,bj,idetsi)  = sms(i,j,kLoc,bi,bj,idetsi) 
     &      - wFluxDet(3)*dt
     &      *recip_drF(kLoc)*recip_hfacc(i,j,kLoc,bi,bj)
       sms(i,j,kLoc,bi,bj,idiasi)  = sms(i,j,kLoc,bi,bj,idiasi) 
     &      - wFluxDia(3)*dt
     &      *recip_drF(kLoc)*recip_hfacc(i,j,kLoc,bi,bj)
#ifdef RECOM_CALCIFICATION
       wFluxDet(4) = vSinkDet(i,j,kLoc)*state(i,j,kLoc,bi,bj,idetcalc) 
       wFluxPhy(4) = vSinkPhy(i,j,kLoc)*state(i,j,kLoc,bi,bj,iphycalc)
       wFluxDia(4) = c0
      sms(i,j,kLoc,bi,bj,idetcalc)  = sms(i,j,kLoc,bi,bj,idetcalc) 
     &      - wFluxDet(4)*dt
     &      *recip_drF(kLoc)*recip_hfacc(i,j,kLoc,bi,bj)
       sms(i,j,kLoc,bi,bj,iphycalc)  = sms(i,j,kLoc,bi,bj,iphycalc) 
     &      - wFluxPhy(4)*dt
     &      *recip_drF(kLoc)*recip_hfacc(i,j,kLoc,bi,bj)
C Now put everything into sediment layer
       do ii=1,4
        benthos(i,j,ii)     = benthos(i,j,ii) 
     &       + (wFluxDet(ii)+wFluxPhy(ii)+wFluxDia(ii))*dt
CCV: Changed unit of benthos variables from a density (mmol/m^3) to a depth-integrated
CCV  density (mmol/m^2)
C     &       *recip_drF(kLoc)*recip_hfacc(i,j,kLoc,bi,bj)
       enddo
       if (ndiags2d .ge. 4) then
          do ii=1,4
             diags2d(i,j,ii) = (wFluxDet(ii)+wFluxPhy(ii)+wFluxDia(ii))
          enddo
       endif
#else
C Now put everything into sediment layer
       do ii=1,3
        benthos(i,j,ii)     = benthos(i,j,ii) 
     &       + (wFluxDet(ii)+wFluxPhy(ii)+wFluxDia(ii))*dt
CCV: Changed unit of benthos variables from a density (mmol/m^3) to a depth-integrated
CCV  density (mmol/m^2)
C     &       *recip_drF(kLoc)*recip_hfacc(i,j,kLoc,bi,bj)
       enddo
       if (ndiags2d .ge. 4) then
          do ii=1,3
             diags2d(i,j,ii) = (wFluxDet(ii)+wFluxPhy(ii)+wFluxDia(ii))
          enddo
       endif
#endif

       enddo ! i-loop
       enddo ! j-loop
      endif
C---------------------------------------------------------------------

      RETURN
      END

CBOP
C !ROUTINE: RECOM_LIMITER
C !INTERFACE:
      _RL FUNCTION RECOM_LIMITER(
     I     slope, qa, qb )
C !DESCRIPTION:
C Computes the limiting factor based on slope and limiting quotas.
C This short piece of code is put into a separate function in order
C make switching between different limiting functions simpler.
C We assume that for for qa < qb the limiter is NOT limiting.

C !USES:
      implicit none

C !INPUT/OUTPUT PARAMETERS:
C     slope  - slope parameter for limiting function
C     qa, qb - two quotas, for qa < qb, recom_limiter > 0
      _RL slope
      _RL qa, qb

C !LOCAL VARIABLES
      _RL dq
CEOP
      dq = qa - qb 
#ifdef RECOM_GEIDER_LIMITER
      recom_limiter = MAX( MIN( -slope*dq, 1.0 ), 0.0 )
#else
      recom_limiter = 1.D0 - exp( - slope*( abs(dq)-dq )**2 )
#endif

      RETURN
      END

      _RL FUNCTION IRON_CHEMISTRY( Fe, totalLigand, ligandStabConst )
C
C     compute free iron that is available for scavenging according
C     to Parekh etal, Modelling the global iron cycle, 
C     GBC, Vol.18(1), doi:10.1029/2003GB002061, 2004.
C

C     input variables
      _RL Fe
C     total free ligand [mumol m^{-3}] [order 1]
      _RL totalLigand
C     ligand-free iron stability constanty [m^{3}/mumol] [order 100]
      _RL ligandStabConst
C     output variables
      _RL freeFe

C     local variables
      _RL ligand, FeL, a, b, c, discrim

C     abbreviations
      a = ligandStabConst
      b = ligandStabConst*(Fe-totalLigand) + 1.D0
      c = -totalLigand
      discrim = b*b-4.*a*c

      if ( a .ne. 0. .and. discrim .ge. 0. ) then
       ligand = ( -b + SQRT(discrim) )/(2.*a)
       FeL=totalLigand - ligand
       freeFe = Fe - FeL
      else
C     no free iron
       freeFe = 0.
      endif

      iron_chemistry = freeFe

      RETURN
      END
