;Set CYGNSS file to use and output directory
cygdir = "/jm13/pduran/cygnss/2018/level1/"
;cygfilename = "cyg03.ddmi.s20180413-000000-e20180413-235959.l1.power-brcs.a20.d20.nc"
cygfilename = "cyg07.ddmi.s20180311-000000-e20180311-235959.l1.power-brcs.a20.d20.nc"
outdir = "/jm13/pduran/web/cygnss/integratedpower/"
toplot = 1 ;0=Bistatic radar cross section; 1=Analog power; 2=Effective scattering area
;Ignore Block IIF satellites?
ignoreblockIIF = True
timeunits = "seconds since 2016-1-1 00:00:00"
powerthresh = 1e-20

system("mkdir "+outdir)

;-------------------;
;READ IN CYGNSS FILE;   
;-------------------;
print( "Reading file.")
satnum  = systemfunc("echo "+cygfilename+" | awk -F'/' '{print $NF}' | awk -F'.' '{print $1}'")
cygfile = addfile(cygdir+cygfilename,"r")
cygvers = cygfile@title
sample  = cygfile->sample
ddm     = cygfile->ddm
prn     = cygfile->prn_code
cyglat  = cygfile->sp_lat
cyglon  = cygfile->sp_lon
sp_lat  = cygfile->sp_lat
sp_lon  = cygfile->sp_lon
spdelay = cygfile->sp_precise_delay ;Specular point delay in chips (1/1,023,000 s).
delayres= cygfile->delay_resolution ;DDM delay bin resolution in chips.
delay_resolution= cygfile->delay_resolution ;DDM delay bin resolution in chips.
brcs_ddm_sp_bin_delay_row = cygfile->brcs_ddm_sp_bin_delay_row
spdelayrow = round(cygfile->brcs_ddm_sp_bin_delay_row,3)
spdoppcol  = round(cygfile->brcs_ddm_sp_bin_dopp_col,3)
qcflags = cygfile->quality_flags
quality_flags = cygfile->quality_flags
ddm_timestamp_utc = cygfile->ddm_timestamp_utc
flagmasks = qcflags@flag_masks
bitmask = getbitsone(qcflags)
if(toplot.eq.0)then
   brcs    = cygfile->brcs
else if(toplot.eq.1)then
   brcs    = cygfile->power_analog
   power_analog = cygfile->power_analog
else if(toplot.eq.2)then
   brcs    = cygfile->eff_scatter
end if
end if
end if

;SET ANY NEGATIVE POWER VALUES TO MISSING
brcs = where(brcs.lt.0,brcs@_FillValue,brcs)

;Convert time to common time
cygtime = round(cd_convert(ddm_timestamp_utc,timeunits),3)

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

;Conform spdelayrow, delay_rows, and bitmask arrays to BRCS arrays
brcsdimsizes = dimsizes(brcs)
bitmaskdimsizes = dimsizes(bitmask)
bitmask_conform_dimsizes = array_append_record(brcsdimsizes,bitmaskdimsizes(2),0)
qcflags_conform = conform(brcs,qcflags,(/0,1/))
spdelayrow_conform = conform(brcs,spdelayrow,(/0,1/))
delay_rows_conform = conform(brcs,delay_rows,2)
;bitmask_conform = conform_dims(bitmask_conform_dimsizes,bitmask,(/0,1,4/))

;Source: https://gis.stackexchange.com/questions/201789/verifying-formula-that-will-convert-longitude-0-360-to-180-to-180
cyglon = mod((cyglon+180),360) - 180

;Find index where cygtime equals selected time
cygtimeind = ind(cygtime.eq.69154259)
lats = cyglat(cygtimeind,:)
lons = cyglon(cygtimeind,:)
brcsthistime = brcs(cygtimeind,3,:,:)
integratedpowethistime = dim_sum(brcsthistime)
;Get error conditions
errorstrings = systemfunc("cat /nfs/jm13/pduran/cygnss/errorconditions.txt")
bitmaskthistime = bitmask(cygtimeind,3,:)
qcflagthistime = qcflags(cygtimeind,3)
flagmasks32bit = array_append_record(flagmasks,(/0,0,0,0,0/),0)
;Reverse bitmask array so we can compare it to errorstrings
bitmaskthistime = bitmaskthistime(::-1)
;Get error strings for this DDM
errorinds = ind(bitmaskthistime.eq.1)
errors = errorstrings(errorinds)

;But we don't want to mask out land, so don't remove where 10th-12th dimensions are flipped
;The 10th-12th elements of the bitmask arrays correspond to land masks.
;Remove all DDMs that have QC flag flipped
;brcs_flagged_removed = where(qcflags_conform.eq.1,brcs@_FillValue,brcs)
;brcs = where(bitmask_conform(:,:,:,:,1).eq.1,brcs@_FillValue,brcs)
;brcs = where(bitmask_conform(:,:,:,:,2).eq.1,brcs@_FillValue,brcs)
;brcs = where(bitmask_conform(:,:,:,:,3).eq.1,brcs@_FillValue,brcs)
;brcs = where(bitmask_conform(:,:,:,:,4).eq.1,brcs@_FillValue,brcs)
;brcs = where(bitmask_conform(:,:,:,:,5).eq.1,brcs@_FillValue,brcs)
;brcs = where(bitmask_conform(:,:,:,:,6).eq.1,brcs@_FillValue,brcs)
;brcs = where(bitmask_conform(:,:,:,:,7).eq.1,brcs@_FillValue,brcs)
;brcs = where(bitmask_conform(:,:,:,:,8).eq.1,brcs@_FillValue,brcs)
;brcs = where(bitmask_conform(:,:,:,:,9).eq.1,brcs@_FillValue,brcs)
;brcs = where(bitmask_conform(:,:,:,:,13).eq.1,brcs@_FillValue,brcs)
;brcs = where(bitmask_conform(:,:,:,:,14).eq.1,brcs@_FillValue,brcs)
;brcs = where(bitmask_conform(:,:,:,:,15).eq.1,brcs@_FillValue,brcs)
;brcs = where(bitmask_conform(:,:,:,:,16).eq.1,brcs@_FillValue,brcs)
;brcs = where(bitmask_conform(:,:,:,:,17).eq.1,brcs@_FillValue,brcs)
;brcs = where(bitmask_conform(:,:,:,:,18).eq.1,brcs@_FillValue,brcs)
;brcs = where(bitmask_conform(:,:,:,:,19).eq.1,brcs@_FillValue,brcs)
;brcs = where(bitmask_conform(:,:,:,:,20).eq.1,brcs@_FillValue,brcs)
;brcs = where(bitmask_conform(:,:,:,:,21).eq.1,brcs@_FillValue,brcs)
;brcs = where(bitmask_conform(:,:,:,:,22).eq.1,brcs@_FillValue,brcs)
;brcs = where(bitmask_conform(:,:,:,:,23).eq.1,brcs@_FillValue,brcs)
;brcs = where(bitmask_conform(:,:,:,:,24).eq.1,brcs@_FillValue,brcs)
;brcs = where(bitmask_conform(:,:,:,:,25).eq.1,brcs@_FillValue,brcs)
;brcs = where(bitmask_conform(:,:,:,:,26).eq.1,brcs@_FillValue,brcs)

;Want to make sure that we only include DDMs with specular points in similar bin numbers
;If the specular point delay row is out of the allowable range (5-7), set BRCS values missing
;brcs = where(spdelayrow_conform.lt.5.or.spdelayrow_conform.gt.7,brcs@_FillValue,brcs)

;For all delay rows at and above the specular point, set the brcs values to missing.
;We do this so that we only include BRCS values below the specular point in the integration.
brcs = where(delay_rows_conform.ge.spdelayrow_conform,brcs@_FillValue,brcs)

;Integrate power over Doppler dimension
integrated_power = dim_sum_n(brcs,3)
minintegratedpower = dim_min(integrated_power)
integrated_power@comment = "17-element vector of analog power integrated over the 11-element Doppler dimension of power array. 'Sample' corresponds to sampling times; 'DDM' corresponds to each DDM per sample time (4 per second). analog_power is the true power that would have been measured by an ideal (analog) power sensor. power_digital  is the power measured by the actual 2-bit sensor, which includes quantization effects. power_analog has been corrected for quantization effects."
integrated_power@units = "watt"
integrated_power@long_name = "DDM bin analog power integrated over the Doppler dimension"
integrated_power!0 = "sample"
integrated_power!1 = "ddm"
integrated_power!2 = "delay"

;Integrate power over delay dimension
integrated2d = dim_sum_n(integrated_power,2)

printVarSummary( power_analog)
printVarSummary( integrated_power)
printVarSummary( ddm_timestamp_utc)
printVarSummary( quality_flags)
printVarSummary( delay_resolution)
printVarSummary( brcs_ddm_sp_bin_delay_row)
printVarSummary( sp_lat)
printVarSummary( sp_lon)

;Write first three variables to output file
ncoutfile = "/jm13/pduran/ncl/cygnss/"+cygfilename+"-"+"integrated_power.hdf"
system("rm "+ncoutfile)
fout = addfile(ncoutfile,"c")
print( "Writing output file.")
;Define variable attributes
dimNames = (/"sample","ddm","delay","doppler"/)
dimSizes = dimsizes(power_analog)
dimUnlim = (/False,False,False,False/)
var_names = (/"power_analog"/)
var_types = (/"float"/)
filedimdef(fout,dimNames,dimSizes,dimUnlim)
filevardef(fout,"sample",typeof(power_analog&sample),getvardims(power_analog&sample))
filevardef(fout,"ddm",typeof(power_analog&ddm),getvardims(power_analog&ddm))
filevardef(fout,var_names,var_types,dimNames)
filevarattdef(fout,"sample",sample)
filevarattdef(fout,"ddm",ddm)
filevarattdef(fout,"power_analog",power_analog)
fout->sample  = (/power_analog&sample/)
fout->ddm     = (/power_analog&ddm/)
fout->power_analog = (/power_analog/)

;Write next variables to output file
dimNames := (/"sample","ddm","delay"/)
dimSizes := dimsizes(integrated_power)
dimUnlim := (/False,False,False/)
var_names := (/"integrated_power"/)
var_types := (/"float"/)
filevardef(fout,var_names,var_types,dimNames)
filevarattdef(fout,"integrated_power",integrated_power)
fout->integrated_power = (/integrated_power/)

;Write next set of variables to output file
dimNames := (/"sample","ddm"/)
dimSizes := dimsizes(sp_lat)
dimUnlim := (/False,False/)
var_names := (/"sp_lat","sp_lon","brcs_ddm_sp_bin_delay_row","quality_flags"/)
var_types := (/"float","float","float","integer"/)
filevardef(fout,var_names,var_types,dimNames)
filevarattdef(fout,"sp_lat",sp_lat)
filevarattdef(fout,"sp_lon",sp_lon)
filevarattdef(fout,"brcs_ddm_sp_bin_delay_row",brcs_ddm_sp_bin_delay_row)
filevarattdef(fout,"quality_flags",quality_flags)
fout->sp_lat = (/sp_lat/)
fout->sp_lon = (/sp_lon/)
fout->brcs_ddm_sp_bin_delay_row = (/brcs_ddm_sp_bin_delay_row/)
fout->quality_flags = (/quality_flags/)

;Write next variables to output file
dimNames := (/"sample"/)
dimSizes := dimsizes(ddm_timestamp_utc)
dimUnlim := (/False/)
var_names := (/"ddm_timestamp_utc"/)
var_types := (/"double"/)
filevardef(fout,var_names,var_types,dimNames)
filevarattdef(fout,"ddm_timestamp_utc",ddm_timestamp_utc)
fout->ddm_timestamp_utc = (/ddm_timestamp_utc/)

;Write next set of variables to output file
dimNames := delay_resolution!0
dimSizes := dimsizes(delay_resolution)
dimUnlim := (/False/)
var_names := (/"delay_resolution"/)
var_types := (/"float"/)
filevardef(fout,var_names,var_types,dimNames)
filevarattdef(fout,"delay_resolution",delay_resolution)
fout->delay_resolution = (/delay_resolution/)

;Plot histograms
print( "Plotting histograms.")
histwks = gsn_open_wks("png",outdir+"hist-doppintegrated.png")
res = True
;res@gsnHistogramBinIntervals = fspan(0,1e-18,101)
res@gsnHistogramBinIntervals = fspan(1e-18,1e-20,101)
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
minintegratedpower1d   = ndtooned(minintegratedpower)
print( minintegratedpower1d)
integrated2d1d = ndtooned(integrated2d)
mapinds = ind(integrated2d1d.gt.powerthresh)
mapinds1d = ind(minintegratedpower1d.gt.powerthresh)
lats1d = cyglat1d(mapinds1d)
lons1d = cyglon1d(mapinds1d)
lats = cyglat1d(mapinds)
lons = cyglon1d(mapinds)

print( "Plotting maps")
mapwks = gsn_open_wks("png",outdir+"map2dintegral.png")
mapres = True
mapres@tiMainString = "Specular points where integrated power~C~below specular point > "+powerthresh+" W"
mapres@gsnMaximize = True
mapres@gsnDraw = False
mapres@gsnFrame = False
mapres@gsnPaperOrientation = "landscape"
mapres@tmYROn = False
mapres@tmXTOn = False
mapres@mpLimitMode = "LatLon"
mapres@mpMinLatF = 31.57 
mapres@mpMaxLatF = 33.03
mapres@mpMinLonF = -95.63
mapres@mpMaxLonF = -93.73
mapres@mpDataBaseVersion           = "MediumRes"
mapres@mpDataSetName               = "Earth..4"
mapres@mpGeophysicalLineColor      = "red"
mapres@mpGeophysicalLineThicknessF = 5.0
mapres@mpProvincialLineThicknessF = 5.0
mapres@mpCountyLineThicknessF = 2.5
mapres@mpCountyLineColor = mapres@mpGeophysicalLineColor
mapres@mpOutlineBoundarySets       = "GeophysicalAndUSStates"
mapres@mpOutlineOn                 = True
mapres@mpUSStateLineColor          = mapres@mpGeophysicalLineColor
mapres@mpOutlineSpecifiers = (/"United States : Counties"/)
mapres@mpGridAndLimbDrawOrder = "Postdraw"
mapres@mpLabelsOn             = False
mapres@mpPerimOn              = True
mapres@mpFillOn               = False
mapres@mpOutlineOn            = True
mapres@mpOutlineDrawOrder     = "Draw"
mapres@mpFillDrawOrder        = "PreDraw"
map = gsn_csm_map(mapwks,mapres)

pmres = True
pmres@gsMarkerSizeF = 20
pmres@gsMarkerIndex = 1
pmres@gsMarkerColor = "red"
dum = gsn_add_polymarker(mapwks,map,lons,lats,pmres)
draw(map)
frame(mapwks)

mapwks = gsn_open_wks("png",outdir+"map1dintegral.png")
mapres = True
;mapresi@tiMainString = "Specular points where minimum of power integrated~C~across Doppler bins below specular point > "+powerthresh+" W"
mapres@tiMainString = "Power integrated across Doppler~C~bins below specular point ("+powerthresh+" W)"
mapres@gsnMaximize = True
mapres@gsnDraw = False
mapres@gsnFrame = False
mapres@gsnPaperOrientation = "landscape"
map = gsn_csm_map(mapwks,mapres)
pmres = True
pmres@gsMarkerSizeF = 20
pmres@gsMarkerIndex = 1
pmres@gsMarkerColor = "red"
;dum = gsn_add_polymarker(mapwks,map,cyglon1d,cyglat1d,pmres)
text = tostring(round(minintegratedpower1d/powerthresh,3))
txres = True
txres@txFontHeightF = 0.01
txres@txFontColor = "black"
;Subset text and lats,lons so plotting will be faster
lonsonmapinds = ind(cyglon1d.le.mapres@mpMaxLonF.and.cyglon1d.ge.mapres@mpMinLonF)
lonsonmap = cyglon1d(lonsonmapinds)
latsonmap = cyglat1d(lonsonmapinds)
textonmap = text(lonsonmapinds)
printVarSummary( textonmap)
dum = gsn_add_text(mapwks,map,textonmap,lonsonmap,latsonmap,txres)
draw(map)
frame(mapwks)
