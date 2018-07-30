;Set CYGNSS file to use and output directory
cygdir = "/jm13/pduran/cygnss/2018/level1/"
cygfilename = "cyg03.ddmi.s20180413-000000-e20180413-235959.l1.power-brcs.a20.d20.nc"
outdir = "/jm13/pduran/web/cygnss/integratedpower/"
toplot = 1 ;0=Bistatic radar cross section; 1=Analog power; 2=Effective scattering area
;Ignore Block IIF satellites?
ignoreblockIIF = True
timeunits = "seconds since 2016-1-1 00:00:00"
powerthresh = 1e-15

system("mkdir "+outdir)

;-------------------;
;READ IN CYGNSS FILE;   
;-------------------;
print( "Reading file.")
satnum  = systemfunc("echo "+cygfilename+" | awk -F'/' '{print $NF}' | awk -F'.' '{print $1}'")
cygfile = addfile(cygdir+cygfilename,"r")
cygvers = cygfile@title
prn     = cygfile->prn_code
cyglat  = cygfile->sp_lat
cyglon  = cygfile->sp_lon
spdelay = cygfile->sp_precise_delay ;Specular point delay in chips (1/1,023,000 s).
delayres= cygfile->delay_resolution ;DDM delay bin resolution in chips.
spdelayrow = round(cygfile->brcs_ddm_sp_bin_delay_row,3)
if(toplot.eq.0)then
   brcs    = cygfile->brcs
else if(toplot.eq.1)then
   brcs    = cygfile->power_analog
else if(toplot.eq.2)then
   brcs    = cygfile->eff_scatter
end if
end if
end if

print( "Processing arrays.")

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

;Create array of delay rows
delay_rows = ispan(0,16,1)

;Conform spdelayrow and delay_rows arrays to BRCS arrays
spdelayrow_conform = conform(brcs,spdelayrow,(/0,1/))
delay_rows_conform = conform(brcs,delay_rows,2)

;Source: https://gis.stackexchange.com/questions/201789/verifying-formula-that-will-convert-longitude-0-360-to-180-to-180
cyglon = mod((cyglon+180),360) - 180

;If the specular point delay row is out of the allowable range (0-16), set BRCS values missing
brcs = where(spdelayrow_conform.lt.0.or.spdelayrow_conform.gt.16,brcs@_FillValue,brcs)

;For all delay rows at and above the specular point, set the brcs values to missing.
;We do this so that we only include BRCS values below the specular point in the integration.
brcs = where(delay_rows_conform.ge.spdelayrow_conform,brcs@_FillValue,brcs)

;Integrate power over Doppler dimension
integrated = dim_sum_n(brcs,3)

;Integrate power over delay dimension
integrated2d = dim_sum_n(integrated,2)

;Plot histograms
print( "Plotting histograms.")
histwks = gsn_open_wks("png",outdir+"hist-doppintegrated.png")
res = True
;res@gsnHistogramBinIntervals = fspan(0,1e-18,101)
res@gsnHistogramBinIntervals = fspan(1e-18,1e-16,101)
res@tmXBLabelStride = 10
res@tmXBLabelAngleF = 45
res@tiMainString = "Histogram of received power integrated over ~C~Doppler bins at delays below specular point"
res@tiXAxisString = "Received Power (W) integrated over ~C~Doppler bins"
res@tmXTOn = False
res@tmYROn = False
res@gsnMaximize = True
hist = gsn_histogram(histwks,ndtooned(integrated),res)

histwks = gsn_open_wks("png",outdir+"hist-delay+doppintegrated.png")
res@tiMainString = "Histogram of received power integrated over ~C~Doppler and Delay bins at delays below specular point"
res@tiXAxisString = "Received Power (W) integrated over ~C~delay and Doppler bins"
hist = gsn_histogram(histwks,ndtooned(integrated2d),res)

;Plot map of locations where returned power is greater than the threhold value
;at delays below the threshold delay value.
print( "Finding lats and lons of specular points that meet the criteria.")
cyglat1d = ndtooned(cyglat)
cyglon1d = ndtooned(cyglon)
integrated2d1d = ndtooned(integrated2d)
mapinds = ind(integrated2d1d.gt.powerthresh)
lats = cyglat1d(mapinds)
lons = cyglon1d(mapinds)

print( "Plotting map")
mapwks = gsn_open_wks("png",outdir+"map.png")
mapres = True
mapres@tiMainString = "Specular points where integrated power below specular point > 1~S~-15~N~ W"
mapres@gsnMaximize = True
mapres@gsnDraw = False
mapres@gsnFrame = False
mapres@gsnPaperOrientation = "landscape"
map = gsn_csm_map(mapwks,mapres)
pmres = True
pmres@gsMarkerSizeF = 20
pmres@gsMarkerIndex = 1
pmres@gsMarkerColor = "red"
dum = gsn_add_polymarker(mapwks,map,lons,lats,pmres)
draw(map)
frame(mapwks)
