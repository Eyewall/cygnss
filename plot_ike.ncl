load "/raid1/pduran/jm13/ncl/cygnss/parametric-model-morris+ruf.ncl"
load "/raid1/pduran/jm13/ncl/cygnss/ike.ncl"
load "/raid1/pduran/jm13/ncl/cygnss/azimuthal_avg.ncl"

;----------------------------------------------------
; plot-ike.ncl
; Patrick Duran
; 24 August 2018
;
; Computes and plots a radial wind profile and 
; integrated kinetic energy asssociated with the
; wind profile.
; Also plots all of the wind speed observations
; that went into computing the radial wind
; profile on a map.
; ARGUMENTS
; ---------
; NAME: Storm name.
; ID: Storm ID in the format YYYY##B (e.g. 201703L)
; YYYY: Year (string)
; MM: Month (string)
; DD: Day (string)
; HH: Hour (string)
; mm: Minutes (string)
; ss: Seconds (string)
; vmax: Maximum wind speed from best track (m/s)
; rmw: Radius of maximum wind (m/s)
; radius: Maximum radius within which to search
;         for CYGNSS observations (km). Keep in
;         mind that the algorithm will only use 
;         obs within the 34-kt wind radius as
;         determined by the wind profile computation.
; dt:    Time within which to search for CYGNSS obs.
; type:  Azimuthal average (0), or Morris and Ruf models (2 or 3)?
; dr:    If type=0, width of radial bins.
; vavg:  Mean wind speed(s) that was used to compute IKE
; vavg_nonfilled: Average wind speed that contains missing values
;                 where obs are unavailable. Used to plot gray
;                 shading where obs are missing.
; ikeTJ: Integrated kinetic energy (TJ)
; Vobs:  Raw SFMR observations that will be plotted as a scatterplot.
; opt:   Valid options: "full" or "quadrant".
;        "quadrant" will create 4-panel plot with each
;        quadrant's wind profile & IKE contribution.
;        "full" will plot one panel (since it's a full azimuthal avg)
; init: Initial guess wind profile
; outhomedir: Home directory in which to put plots
;----------------------------------------------------

undef("plot_ike")
procedure plot_ike(NAME:string,ID:string,YYYY:string,MM:string,DD:string,\
                   HH:string,mm:string,ss:string,vmax:numeric,rmw:numeric,\
                   radius:numeric,dt:numeric,type:integer,dr:numeric,\
                   vavg:numeric,vavg_nonfilled:numeric,ikeTJ:numeric,\
                   Vobs:numeric,opt:string,init:numeric,outhomedir:string)
begin

;If output directory doesn't exist, create it.
outdir = outhomedir+"ike-windprofiles/"
dirtest = systemfunc("test -d "+outdir+"; echo $?")
if(dirtest.eq.1)then
   system("mkdir "+outdir)
end if
outdir = outdir+opt+"/"
dirtest = systemfunc("test -d "+outdir+"; echo $?")
if(dirtest.eq.1)then
   system("mkdir "+outdir)
end if
outdir = outdir+NAME+"-"+ID+"/"
dirtest = systemfunc("test -d "+outdir+"; echo $?")
if(dirtest.eq.1)then
   system("mkdir "+outdir)
end if

dthr = tostring(dt/3600)

;If any of the IKE values are missing, replace them with zeroes
ikeTJ = where(ismissing(ikeTJ),0,ikeTJ)

;Plot wind profile with IKE value printed on the plot
outfilename = outdir+YYYY+MM+DD+HH+mm+ss+"-"+radius+"km-"+dthr+"h.png"
print( "Writing wind profiles to "+outfilename)
wks = gsn_open_wks("png",outfilename)
res = True
res@gsnLeftStringFontHeightF = 0.013
res@xyMarkLineMode = "Markers"
res@xyMarkers = 1
res@xyMarkerColor = "black"
res@xyMarkerSizeF = 0.02
res@tiYAxisString = "Wind speed (m s~S~-1~N~)"
res@tiXAxisString = "Radius (km)"
res@tiYAxisFontHeightF = 0.015
res@tiXAxisFontHeightF = 0.015
res@tmXBLabelFontHeightF = 0.015
res@tmYLLabelFontHeightF = 0.015
res@tmYLMode = "Manual"
res@tmYLTickStartF = 0.
res@tmYLTickEndF = 100.
res@tmYLTickSpacingF = 5.
res@tmYLMinorOn = False
res@trXMinF = 0.
res@trXMaxF = radius
res@trYMinF = 0.
res@trYMaxF = max((/max(Vobs),max(vavg)/))
res@tmYROn = False
res@tmXTOn = False
res@tfPolyDrawOrder = "Draw"
res@gsnDraw = False
res@gsnFrame = False
 
if(opt.eq."full")then   ;Only one wind profile; produce one plot
   plot = gsn_csm_xy(wks,Vobs@radii,Vobs,res)
   lineres = True
   lineres@gsLineColor = "orange"
   lineres@gsLineThicknessF = 10.
   lineres@tfPolyDrawOrder = "PostDraw"
   gsn_polyline(wks,plot,vavg&radius,vavg,lineres)

   text = "IKE~B~34~N~ = "+ikeTJ+" TJ"
   txres = True
   txres@txFontHeightF = 30.
   txres@txFontThicknessF = 3.
   txres@txFontColor = "red"
   txres@txJust = "TopRight"
   txdum = gsn_add_text(wks,plot,text,res@trXMaxF-10,res@trYMaxF-1,txres)
elseif(opt.eq."quadrant")then   ;Four wind profiles; produce 4-panel plot
   plots     = new(4,"graphic")
   avglines  = new(1000,"graphic")
   initlines = new(4,"graphic")
   windlines = new(4,"graphic")
   avglinei = 0
   do i=0,3
      blankplot = False
      initblank = False
      if(i.eq.0)then
         obsind := ind(Vobs@azimuths.ge.0.and.Vobs@azimuths.lt.90)
         res@gsnLeftString = "Observations (dots) and azi-averaged wind (line) for NE quadrant"
      elseif(i.eq.1)then
         obsind := ind(Vobs@azimuths.ge.90.and.Vobs@azimuths.lt.180)
         res@gsnLeftString = "Observations (dots) and azi-averaged wind (line) for SE quadrant"
      elseif(i.eq.2)then
         obsind := ind(Vobs@azimuths.ge.180.and.Vobs@azimuths.lt.270)
         res@gsnLeftString = "Observations (dots) and azi-averaged wind (line) for SW quadrant"
      elseif(i.eq.3)then
         obsind := ind(Vobs@azimuths.ge.270.and.Vobs@azimuths.lt.360)
         res@gsnLeftString = "Observations (dots) and azi-averaged wind (line) for NW quadrant"
      end if
      if(dimsizes(.not.ismissing(obsind)).gt.1)then
         if(.not.all(ismissing(Vobs(obsind))).and..not.all(ismissing(vavg(i,:))))then
            ;res@trYMaxF = max((/max(Vobs(obsind)),max(vavg(i,:))/))
            res@trYMaxF = max((/max(Vobs),max(vavg),max(init)/))
            plots(i) = gsn_csm_xy(wks,Vobs@radii(obsind),Vobs(obsind),res)
            ;Add lines marking average wind speed. If there is a spatial separation between
            ;observations, two lines might be generated by gsn_add_polyline. We will check
            ;for that and attach the lines one-by-one, in such cases.
            lineres = True
            lineres@gsLineColor = "dodgerblue"
            lineres@gsLineThicknessF = 10.
            lineres@gsLineDashPattern = 0
            lineres@tfPolyDrawOrder = "PostDraw"
            line := gsn_add_polyline(wks,plots(i),vavg&radius,vavg(i,:),lineres)
            nlines = dimsizes(line)
            if(nlines.eq.1)then
               avglines(avglinei) = line
               avglinei = avglinei + 1
            else
               do k=0,nlines-1
                  avglines(avglinei) = line(k)
                  avglinei = avglinei + 1
               end do
            end if
         else
            blankplot = True
         end if
      else
         blankplot = True
      end if
      ;If we don't have an initial wind profile for this quadrant, set flag for text indicator.
      if(all(ismissing(init(i,:))))then
         initblank = True
      end if

      blankres = True
      blankres@gsnLeftString = res@gsnLeftString
      blankres@gsnLeftStringFontHeightF = 0.013
      blankres@tiYAxisString = "Wind speed (m s~S~-1~N~)"
      blankres@tiXAxisString = "Radius (km)"
      blankres@tiYAxisFontHeightF = 0.02
      blankres@tiXAxisFontHeightF = 0.02
      blankres@tmXBLabelFontHeightF = 0.02
      blankres@tmYLLabelFontHeightF = 0.02
      blankres@tmYLMode = "Manual"
      blankres@tmYLTickStartF = 0.
      blankres@tmYLTickEndF = 100.
      blankres@tmYLTickSpacingF = 5.
      blankres@tmYLMinorOn = False
      blankres@trXMinF = 0.
      blankres@trXMaxF = radius
      blankres@trYMinF = 0.
      blankres@trYMaxF = max((/max(Vobs),max(vavg),max(init)/))
      blankres@tmYROn = False
      blankres@tmXTOn = False
      blankres@gsnDraw = False
      blankres@gsnFrame = False
      blankres = True
      blankres@xyLineColor = "dodgerblue"
      blankres@xyLineThicknessF = 10
      blankres@xyDashPattern = 0
      if(blankplot.eq.True)then
         vavg(i,:) = -100.
         plots(i) = gsn_csm_xy(wks,vavg&radius,vavg(i,:),blankres)
         missingtext = "NO OBSERVATIONS AVAILABLE."
         missingtextres = True
         missingtextres@txFontHeightF = 20.
         missingtextres@txFontColor = "black"
         missingtextplot = gsn_add_text(wks,plots(i),missingtext,radius/2,blankres@trYMaxF-5,missingtextres)
      end if
      ;If we don't have r34 in this quadrant, add text to plot.
      if(initblank.eq.True)then
         missingtext = "NO 34-KT WIND RADIUS IN BEST TRACK"
         missingtextres = True
         missingtextres@txFontHeightF = 20.
         missingtextres@txFontColor = "black"
         moremissingtext = gsn_add_text(wks,plots(i),missingtext,radius/2,blankres@trYMaxF-7,missingtextres)
      end if
   end do   
   ;Attach features common to all plots
   do i=0,3
      ;Add line indicating initial guess wind profile, if we have one
      if(.not.all(ismissing(init(i,:))))then
         lineres = True
         lineres@gsLineColor = "black"
         lineres@gsLineColor = "orange"
         lineres@gsLineThicknessF = 5.
         lineres@gsLineDashPattern = 14
         initlines(i) = gsn_add_polyline(wks,plots(i),vavg&radius,init(i,:),lineres) 
      end if

      ;Add text indicating IKE value
      text = "IKE~B~34~N~ = "+ikeTJ(i)+" TJ"
      txres = True
      txres@txFontHeightF = 30.
      txres@txFontThicknessF = 3.
      txres@txFontColor = "red"
      txres@txJust = "TopRight"
      txdum = gsn_add_text(wks,plots(i),text,res@trXMaxF-10,res@trYMaxF-1,txres)
    
      ;Add line marking 34-kt (17.49 m/s) wind
      lineres@gsLineColor = "darkgreen"
      lineres@gsLineThicknessF = 5.
      lineres@gsLineDashPattern = 16
      windlines(i) = gsn_add_polyline(wks,plots(i),(/res@trXMinF,res@trXMaxF/),(/17.49,17.49/),lineres)

      ;Add polygons to mark radii at which observations are missing.
;      vavg_nonfilledrads = vavg_nonfilled@radius
;      do j=0,nrads-1
;         interior = vavg_nonfilledrads(j)
;         if(.not.ismissing(vavg_nonfilled(i,j)))then
;            
;      end do
   end do
 
   panelres = True
   panelres@gsnMaximize = True
   ;Panel the plots out of order so that the 4 panels correspond spatially with the 4 quadrants.
   gsn_panel(wks,(/plots(3),plots(0),plots(2),plots(1)/),(/2,2/),panelres)
end if

end
