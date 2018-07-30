;Set CYGNSS file to use and output directory
cygdir = "/jm13/pduran/cygnss/2018/level1/"
outdir  = "/jm13/pduran/web/cygnss/ddm/analog-power/"
;cygfilename  = "cyg01.ddmi.s20170512-000000-e20170512-235959.l1.power-brcs.a20.d20.nc"
;cygfilename  = "cyg01.ddmi.s20180319-000000-e20180319-235959.l1.power-brcs.a20.d20.nc"
;cygfilename  = "cyg03.ddmi.s20180311-000000-e20180311-235959.l1.power-brcs.a20.d20.nc"
;cygfilename = "cyg06.ddmi.s20180311-000000-e20180311-235959.l1.power-brcs.a20.d20.nc"
;cygfilename = "cyg04.ddmi.s20180406-000000-e20180406-235959.l1.power-brcs.a20.d20.nc"
;cygfilename = "cyg03.ddmi.s20180406-000000-e20180406-235959.l1.power-brcs.a20.d20.nc"
;cygfilename = "cyg05.ddmi.s20180406-000000-e20180406-235959.l1.power-brcs.a20.d20.nc"
;cygfilename = "cyg07.ddmi.s20180406-000000-e20180406-235959.l1.power-brcs.a20.d20.nc"
;cygfilename = "cyg04.ddmi.s20180413-000000-e20180413-235959.l1.power-brcs.a20.d20.nc"
cygfilename = "cyg03.ddmi.s20180413-000000-e20180413-235959.l1.power-brcs.a20.d20.nc"
hailfilename = "180413_rpts_raw_hail.csv_05"
mintime = 72047655
maxtime = 72047670
toplot = 1 ;0=Bistatic radar cross section; 1=Analog power; 2=Effective scattering area
;Ignore Block IIF satellites?
ignoreblockIIF = True
;Set minimum and maximum times and the time units
;for DDMs we want to plot.
;MIAMI
;mintime = 69832686
;maxtime = 69832751

;MOUNT EVEREST
;mintime = 69872248
;maxtime = 69872272
timeunits = "seconds since 2016-1-1 00:00:00"
;Set the location of interest
;MIAMI
lat = 25.78
lon = -80.19
;MOUNT EVEREST
;lat = 27.9881
;lon = 86.9250

system("mkdir "+outdir)

;-------------------;
;READ IN CYGNSS FILE;   
;-------------------;
satnum  = systemfunc("echo "+cygfilename+" | awk -F'/' '{print $NF}' | awk -F'.' '{print $1}'")
cygfile = addfile(cygdir+cygfilename,"r")
cygvers = cygfile@title
cygtime = cygfile->ddm_timestamp_utc
prn     = cygfile->prn_code
cyglat  = cygfile->sp_lat
cyglon  = cygfile->sp_lon
if(toplot.eq.0)then
   brcs    = cygfile->brcs
else if(toplot.eq.1)then
   brcs    = cygfile->power_analog
else if(toplot.eq.2)then
   brcs    = cygfile->eff_scatter
end if
end if
end if
spdelay = cygfile->sp_precise_delay ;Specular point delay in chips (1/1,023,000 s).
spdopp  = cygfile->sp_precise_dopp  ;Specular point Doppler in Hz.
delayres= cygfile->delay_resolution ;DDM delay bin resolution in chips.
doppres = cygfile->dopp_resolution  ;DDM Doppler bin resolution in Hz.
spdelayrow = round(cygfile->brcs_ddm_sp_bin_delay_row,3)
spdoppcol  = round(cygfile->brcs_ddm_sp_bin_dopp_col,3)
qcflags = cygfile->quality_flags

;Ignore retrievals that use BlockIIF satellites
if(ignoreblockIIF)then
   print( "Ignoring retrievals computed using Block IIF satellites.")
   toignore = (/1,3,6,8,9,10,24,25,26,27,30,32/) ;PRN codes for BlockIIF sats
   do k=0,dimsizes(toignore)-1
      cyglat = where(prn.eq.toignore(k),cyglat@_FillValue,cyglat)
      cyglon = where(prn.eq.toignore(k),cyglon@_FillValue,cyglon)
   end do
   delete(prn) ;Don't need this anymore!
end if

;Since Level 1 files have 4 specular points per satellite per timestamp time,
;we need to conform cygtime to have the same rank & dimension sizes as cyglat.
ctime_conform = round(conform(cyglat,cygtime,(/0/)),3)
ctime_conform@units = timeunits

;Make CYNGSS arrays 1-D to make them
;easier to work with
ctime1d    = ndtooned(ctime_conform)
cyglat1d   = ndtooned(cyglat)
cyglon1d   = ndtooned(cyglon)
brcs1d     = ndtooned(brcs)
spdelayrow1d = ndtooned(spdelayrow)
spdoppcol1d  = ndtooned(spdoppcol)
spdelay1d  = ndtooned(spdelay)
spdopp1d   = ndtooned(spdopp)
qcflags1d  = ndtooned(qcflags)
ctime1d@units = cygtime@units
delete([/ctime_conform,cyglat,cyglon,spdelayrow,spdoppcol,spdelay,spdopp/])

;Convert CYGNSS time to common units
ctime = round(cd_convert(ctime1d,timeunits),3)

;Convert CYGNSS longitude to -180 to 180 coodinates
;Source: https://gis.stackexchange.com/questions/201789/verifying-formula-that-will-convert-longitude-0-360-to-180-to-180
cyglon1d = mod((cyglon1d+180),360) - 180

;----------------------------------------------------;
;LOOP THROUGH AND PLOT DDM FOR EACH SECOND IN INTERVAL;
;----------------------------------------------------;
count = 0
do time=mintime,maxtime
   time@units = timeunits
   count = count + 1
   print( "Plotting DDM "+count+" of "+tostring(maxtime-mintime))
   ;Find CYGNSS observation that matches time
   indices:= ind((time-ctime).eq.0)
   if(all(ismissing(indices)))then
      print( "CYGNSS time don't match! Moving on...")
      continue
   end if
   ;Find observation that matches location
   dist = gc_latlon(lat,lon,cyglat1d(indices),cyglon1d(indices),2,4)
   mindistind = indices(minind(dist))
   if(qcflags1d(mindistind).eq.1)then
      print( "DDM flagged as having poor overall quality. Not using...")
      continue
   end if
   brcs_conform := reshape(brcs,(/dimsizes(ctime),17,11/))
   ;Get appropriate BRCS for this sample time and DDM index
   brcsvals := brcs_conform(mindistind,:,:)
   ;Get delay and doppler values for this DDM
   delays  = new(17,"float")
   doppler = new(11,"float")
   delays = 0
   doppler = 0
   ;Set the delay and Doppler at the specular point
   thisspdelayrow = spdelayrow1d(mindistind)
   thisspdoppcol  = spdoppcol1d (mindistind)
   print( qcflags1d(mindistind))
   if(qcflags1d(mindistind).eq.262144.or.qcflags1d(mindistind).eq.524288)then
      print( "Specular point delay row and/or Doppler column out of range!")
      continue  ;The specular point delay row and/orr Doppler
   end if       ;column are out of range of the arrays!
   if(thisspdelayrow.lt.4.or.thisspdoppcol.lt.4.or.\
      thisspdelayrow.gt.8.or.thisspdoppcol.gt.6)then
      print( "Specular point delay row and/or Doppler column out of range!")
      continue
   end if
   print( thisspdelayrow)
   print( mindistind)
   delays (thisspdelayrow) = spdelay1d(mindistind)
   doppler(thisspdoppcol ) = spdopp1d (mindistind)
;   ;Set the delay and Doppler at the rest of the points
   delayinds = ispan(0,16,1)
   doppinds  = ispan(0,10,1)
   delayindsrel = delayinds - thisspdelayrow
   doppindsrel  = doppinds - thisspdoppcol
   delays = (delayindsrel*delayres)+delays(thisspdelayrow)
   doppler= (doppindsrel*doppres)+delays(thisspdoppcol)
   brcsvals!0 = "delay"
   brcsvals!1 = "doppler"
   brcsvals&delay = delays
   brcsvals&doppler = doppler/1000. ;Convert to kHz
   printMinMax(delays,0)

   ;Get time in readable format
   dattim = cd_calendar(time,0) 
   YYYY = tostring(toint(dattim(0,0)))
   MM   = tostring(toint(dattim(0,1)))
   DD   = tostring(toint(dattim(0,2)))
   HH   = tostring(toint(dattim(0,3)))
   mm   = tostring(toint(dattim(0,4)))
   ss   = tostring(toint(dattim(0,5)))
   MM = where(dattim(0,1).lt.10,"0"+MM,MM)
   DD = where(dattim(0,2).lt.10,"0"+DD,DD)
   HH = where(dattim(0,3).lt.10,"0"+HH,HH)
   mm = where(dattim(0,4).lt.10,"0"+mm,mm)
   ss = where(dattim(0,5).lt.10,"0"+ss,ss)
   dattimstring = MM+"/"+DD+"/"+YYYY+" "+HH+":"+mm+":"+ss+" "+satnum

   ;Plot the DDM!
   outsubdir = outdir+"/"+hailfilename+"/"
   system("mkdir "+outsubdir)
   filename = outsubdir+"/"+tostring(ctime(mindistind))+".png"
   print( "Writing image to output file "+filename)
   wks = gsn_open_wks("png",filename)
   gsn_define_colormap(wks,"MPL_Blues")
   res = True
   res@cnFillMode = "RasterFill"
   res@cnFillOn   = True
   res@cnLinesOn  = False
   res@cnLevelSelectionMode = "ManualLevels"
   if(toplot.eq.1)then
      res@cnMinLevelValF = 1e-20
      res@cnMaxLevelValF = 1e-18
      res@cnLevelSpacingF = 5e-20
   end if
   if(toplot.eq.2)then
      res@cnMinLevelValF = 1e6
      res@cnMaxLevelValF = 1e7
      res@cnLevelSpacingF = 5e4
   end if
   res@tiYAxisString = "Delay (chips) (1 chip = 1/1,023,000 s)"
   res@tiXAxisString = "Doppler (kHz)"
   if(toplot.eq.1)then
      res@gsnLeftString = "Analog power (W)"
   end if
   res@gsnRightString = dattimstring
   res@lbOrientation = "vertical"
   res@tmYROn = False
   res@tmXTOn = False
   res@cnInfoLabelOn = False
   res@cnLineLabelsOn = False
   res@gsnMaximize = True
   plot = gsn_csm_contour(wks,brcsvals,res)
end do   ;Loop through each time
