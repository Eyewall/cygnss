;Set CYGNSS file to use and output directory
cygdir = "/raid1/pduran/jm13/cygnss/2018/level1/"
cygfilename = "cyg03.ddmi.s20180413-000000-e20180413-235959.l1.power-brcs.a20.d20.nc"
outdir = "/raid1/pduran/jm13/web/cygnss/histogram/"
toplot = 1 ;0=Bistatic radar cross section; 1=Analog power; 2=Effective scattering area
;Ignore Block IIF satellites?
ignoreblockIIF = True
timeunits = "seconds since 2016-1-1 00:00:00"
delaythres = -1.5  ;Delay threshold (in chips) under which we will include values in the distribution
powerthres = 1e-16

system("mkdir "+outdir)

;-------------------;
;READ IN CYGNSS FILE;   
;-------------------;
print( "Reading file.")
satnum  = systemfunc("echo "+cygfilename+" | awk -F'/' '{print $NF}' | awk -F'.' '{print $1}'")
cygfile = addfile(cygdir+cygfilename,"r")
cygvers = cygfile@title
;cygtime = cygfile->ddm_timestamp_utc
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
delayres= cygfile->delay_resolution ;DDM delay bin resolution in chips.
spdelayrow = round(cygfile->brcs_ddm_sp_bin_delay_row,3)

print( "Processing arrays.")
;Create array of delays
delays = new(dimsizes(brcs),"float")
spdelay_conform = conform(brcs,spdelay,(/0,1/))
spdelayrow_conform = conform(brcs,spdelayrow,(/0,1/))
nrows = 17
do i=0,nrows-1
   delays(:,:,i,:) = spdelay_conform(:,:,i,:)+delayres*(i-spdelayrow_conform(:,:,i,:))
end do

delays1d = ndtooned(delays)

;Ignore retrievals that use BlockIIF satellites
;if(ignoreblockIIF)then
;   print( "Ignoring retrievals computed using Block IIF satellites.")
;   toignore = (/1,3,6,8,9,10,24,25,26,27,30,32/) ;PRN codes for BlockIIF sats
;   do k=0,dimsizes(toignore)-1
;      cyglat = where(prn.eq.toignore(k),cyglat@_FillValue,cyglat)
;      cyglon = where(prn.eq.toignore(k),cyglon@_FillValue,cyglon)
;   end do
;   delete(prn) ;Don't need this anymore!
;end if

;Conform lat and lon arrays to BRCS arrays
cyglat_conform  = conform(brcs,cyglat,(/0,1/))
cyglon_conform  = conform(brcs,cyglon,(/0,1/))

;Make CYNGSS arrays 1-D to make them
;easier to work with
spdelay1d  = ndtooned(spdelay_conform)
cyglat1d   = ndtooned(cyglat_conform)
cyglon1d   = ndtooned(cyglon_conform)
brcs1d     = ndtooned(brcs)

;Source: https://gis.stackexchange.com/questions/201789/verifying-formula-that-will-convert-longitude-0-360-to-180-to-180
cyglon1d = mod((cyglon1d+180),360) - 180

;Find all indices for delays below the threshold
indices = ind(delays1d.lt.delaythres)

;Find BRCS values for this subset of delays
brcs_subset = brcs1d(indices)

;Plot histogram
print( "Plotting histogram.")
mapwks = gsn_open_wks("png",outdir+"hist.png")
res = True
;res@gsnHistogramBinIntervals = fspan(0,1e-18,101)
res@gsnHistogramBinIntervals = fspan(0,1e-17,101)
res@tmXBLabelStride = 10
res@tmXBLabelAngleF = 45
res@tiMainString = "Histogram of received power at delay < "+delaythres+" chips"
res@tiXAxisString = "Received Power (W)"
res@tmXTOn = False
res@tmYROn = False
res@gsnMaximize = True
hist = gsn_histogram(mapwks,brcs_subset,res)

;Plot map of locations where returned power is greater than the threhold value
;at delays below the threshold delay value.
print( "Finding lats and lons of specular points that meet the criteria.")
mapinds = ind(delays1d.lt.delaythres.and.brcs1d.gt.powerthres)
lats = cyglat1d(mapinds)
lons = cyglon1d(mapinds)
printVarSummary( lats)
printVarSummary( lons)

print( "Plotting!")
mapwks = gsn_open_wks("png",outdir+"map.png")
mapres = True
mapres@tiMainString = "Specular points where delay < -1.5 chips and power > 1~S~-16~N~ W"
mapres@gsnMaximize = True
mapres@gsnDraw = False
mapres@gsnFrame = False
map = gsn_csm_map(mapwks,mapres)
pmres = True
pmres@gsMarkerSizeF = 20
pmres@gsMarkerIndex = 1
pmres@gsMarkerColor = "red"
dum = gsn_add_polymarker(mapwks,map,lons,lats,pmres)
draw(map)
frame(mapwks)
