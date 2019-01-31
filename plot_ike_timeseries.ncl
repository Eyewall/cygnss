load "$NCARG_ROOT/lib/ncarg/nclscripts/contrib/cd_string.ncl"

;----------------------------------------------------
; plot-ike-timeseries.ncl
; Patrick Duran
; 19 October 2018
;
; Plots a time series of IKE and a histogram of obs
; density for each storm.
;
; ---------
; ARGUMENTS
; ---------
; NAME: Storm name.
; ID: Storm ID in the format YYYY##B (e.g. 201703L)
; YYYY: Years (numeric)
; MM: Months (numeric)
; DD: Days (numeric)
; HH: Hours (numeric)
; mm: Minutes (numeric)
; ss: Seconds (numeric)
; opt:   Valid options: "full" or "quadrant".
;        "quadrant" will create 4-panel plot with each
;        quadrant's wind profile & IKE contribution plus a plot
;        for the total IKE.
;        "full" will plot only one panel (since it's a full azimuthal avg)
; searchtype: Type of search (forward,backward,centered)
; radius: Maximum search radius (km)
; dt: Time within which to search (hr)
; times: Times since a reference time. Must have units attriute.
; ikeNE, ikeSE, ikeSW, ikeNW: IKE in each quadrant
; nsfmr: Number of SFMR observations at each time
; ncygnss: Number of CYGNSS observations at each time
; nsmap: Number of SMAP observations at each time
; outhomedir: Home directory in which to put plots
;----------------------------------------------------

;RIGHT NOW, THIS CODE ONLY SUPPORTS opt="quadrant"

undef("plot_ike_timeseries")
procedure plot_ike_timeseries(NAME:string,ID:string,YYYY:numeric,MM:numeric,DD:numeric,\
                              HH:numeric,mm:numeric,ss:numeric,opt:string,searchtype:string,\
                              radius:numeric,dt:numeric,ike_sfmr:numeric,ike_init:numeric,\
                              nsfmr:numeric,ncygnss:numeric,nsmap:numeric,obs_density:numeric,\
                              outhomedir:string)
begin

;If output directory doesn't exist, create it.
outdir = outhomedir+"/ike-timeseries/"
dirtest = systemfunc("test -d "+outdir+"; echo $?")
if(dirtest.eq.1)then
   system("mkdir "+outdir)
end if
outdir = outhomedir+"/ike-timeseries/"+opt+"/"
dirtest = systemfunc("test -d "+outdir+"; echo $?")
if(dirtest.eq.1)then
   system("mkdir "+outdir)
end if

;Compute times since a reference time
timeunits = "seconds since 2016-1-1 00:00:00"
times = round(cd_inv_calendar(YYYY,MM,DD,HH,mm,ss,timeunits,0),3)
times@units = timeunits

;Get formatted string for time
timestr = cd_string(times,"%H UTC %D %c")

;If any of the IKE values are missing, replace them with zeroes
ike_sfmr = where(ismissing(ike_sfmr),0,ike_sfmr)
ike_init = where(ismissing(ike_init),0,ike_init)

;Compute total IKE
ikeTOTAL_sfmr = dim_sum(ike_sfmr);keNE_sfmr+ikeSE_sfmr+ikeSW_sfmr+ikeNW_sfmr
ikeTOTAL_init = dim_sum(ike_init);keNE_init+ikeSE_init+ikeSW_init+ikeNW_init

;Plot time series of IKE for each quadrant
outfilename = outdir+NAME+"-"+ID+"-quadrants.png"
res = True
res@trYMinF = 0
res@trYMaxF = max((/ike_sfmr,ike_init/))
res@gsnLeftStringFontHeightF = 0.02
res@tiXAxisString = "Date and Time (UTC)"
res@tiYAxisString = "IKE (TJ)"
res@tiXAxisFontHeightF = .02
res@tiYAxisFontHeightF = .02
res@tmXBMode = "Explicit"
res@tmXBValues = times
res@tmXBLabels = timestr
res@tmXBLabelFontHeightF = .015
res@tmXBLabelAngleF = 40.
res@xyLineColor = "blue"
res@xyLineThicknessF = 8.
res@xyMarkerThicknessF = 5.
res@xyMarkerSizeF = 15.
res@xyMarkerColor = "blue"
res@xyMarkLineMode = "Lines"
res@tmXTOn = False
res@tmYROn = False
res@gsnDraw = False
res@gsnFrame = False
if(dimsizes(ikeTOTAL_sfmr).le.12)then
   res@tmXBLabelStride = 6
else if(dimsizes(ikeTOTAL_sfmr).gt.12.and.dimsizes(ikeTOTAL_sfmr.le.24))then
   res@tmXBLabelStride = 12
else
   res@tmXBLabelStride = 24
end if
end if
print( "Writing time series to "+outfilename)
wks = gsn_open_wks("png",outfilename)
plots     = new(4,"graphic")
initline = plots
do i=0,3
   if(i.eq.0)then
      res@gsnLeftString = "Time series of IKE for NE quadrant"
      res@tiXAxisString = " "
      res@tiYAxisString = " "
   else if(i.eq.1)then
      res@gsnLeftString = "Time series of IKE for SE quadrant"
      res@tiXAxisString = "Date and Time (UTC)"
      res@tiYAxisString = " "
   else if(i.eq.2)then
      res@gsnLeftString = "Time series of IKE for SW quadrant"
      res@tiXAxisString = "Date and Time (UTC)"
      res@tiYAxisString = "IKE (TJ)"
   else if(i.eq.3)then
      res@gsnLeftString = "Time series of IKE for NW quadrant"
      res@tiXAxisString = " "
      res@tiYAxisString = "IKE (TJ)"
   end if
   end if
   end if
   end if
   plots(i) = gsn_csm_xy(wks,times,ike_sfmr(:,i),res)
   ;Attach init line to plot
   polyres = True
   polyres@gsLineColor = "orange"
   polyres@gsLineThicknessF = res@xyLineThicknessF
   polyres@gsLineDashPattern = 14
   initline(i) = gsn_add_polyline(wks,plots(i),times,ike_init(:,i),polyres)
end do
panelres = True
panelres@gsnMaximize = True
;Panel the plots out of order so that the 4 panels correspond spatially with the 4 quadrants.
gsn_panel(wks,(/plots(3),plots(0),plots(2),plots(1)/),(/2,2/),panelres)

;Draw total IKE plot
outfilename_tot = outdir+NAME+"-"+ID+"-total.png"
print( "Writing TOTAL IKE time series to "+outfilename_tot)
totalwks = gsn_open_wks("png",outfilename_tot)
;drawNDCGrid(totalwks)
res@trYMaxF = max((/ikeTOTAL_sfmr,ikeTOTAL_init/))
res@tiXAxisString = "Date and Time (UTC)"
res@xyMarkerColor = "red"
res@gsnDraw = True
res@gsnDraw = False
res@gsnFrame = False
res@gsnLeftString = "Total IKE (sum of 4 quadrants) - "+NAME
res@vpXF = 0.4
res@vpYF = 0.97
totalplot = gsn_csm_xy(totalwks,times,ikeTOTAL_sfmr,res)

;Attach init line to plot
initline = gsn_add_polyline(totalwks,totalplot,times,ikeTOTAL_init,polyres)

;Attach legend
lgtop  = 0.2
lgleft = 0.4
linecolors = (/"orange","blue"/)
lgtx = (/"Best track only","Best track+obs"/)
nlines = dimsizes(linecolors)
lglineres = True
lglineres@gsLineThicknessF = res@xyLineThicknessF
lgtxres = True
lgtxres@txFontHeightF = .02
lgtxres@txJust = "CenterLeft"
do i=0,nlines-1
   ip1 = i + 1
   lglineres@gsLineColor = linecolors(i)
   if(linecolors(i).eq."blue")then
      lglineres@gsLineDashPattern = 0
   else
      lglineres@gsLineDashPattern = 14
   end if
   gsn_polyline_ndc(totalwks,(/lgleft+0.02,lgleft+0.07/),(/lgtop-0.04*ip1,lgtop-0.04*ip1/),lglineres)
   gsn_text_ndc(totalwks,lgtx(i),lgleft+0.08,lgtop-0.04*ip1,lgtxres)
end do
;Draw box around legend
boxres = True
boxres@gsLineColor = "black"
boxres@gsLineThicknessF = 2.
gsn_polyline_ndc(totalwks,(/0.4,0.4,0.7,0.7,0.4/),(/0.19,0.1,0.1,0.19,0.19/),boxres)

draw(totalplot)
frame(totalwks)

;Montage the quadrant IKE panel plot with total IKE plot
outfilename_montage = outdir+NAME+"-"+ID+"-montage.png"
;system("montage -tile 2x2 -bordercolor white -border 15 "+outfilename+" "+outfilename_tot+" -geometry +0+0 "+outfilename_montage)
system("montage -tile 2x2 -bordercolor white -border 15 "+outfilename_tot+" "+outfilename+" -geometry +0+0 "+outfilename_montage)
system("convert -trim "+outfilename_montage+" "+outfilename_montage)

;Plot histogram of observation density
outfilename_obsdensity = outdir+NAME+"-"+ID+"-obs_density.png"
wks = gsn_open_wks("png",outfilename_obsdensity)
histres = True
histres@gsnMaximize = True
histres@tmYROn = False
histres@gsnHistogramBinIntervals = fspan(0,0.05,11)
histres@tiMainString = "Histogram of observation density (#obs km~S~-2~N~) for "+ID+" ("+NAME+")"
histres@tiXAxisFontHeightF = 0.015
histres@tiYAxisFontHeightF = 0.015
histres@tiMainFontHeightF = 0.015
histres@tmXBLabelFontHeightF = 0.015
histres@tmYLLabelFontHeightF = 0.015
histres@tmXBLabelAngleF = 45.
hist = gsn_histogram(wks,obs_density,histres)

end
