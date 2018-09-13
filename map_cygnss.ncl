;------------------------------------------------
; map_cygnss.ncl
; Patrick Duran
; 27 August 2018
;
; Plots CYGNSS wind speed retrievals
; collected within a user-defined radius of
; a tropical cyclone and within a user-defined
; time interval.
; Plots show dots color-coded by wind speed and
; the location of the storm center.
; ---------
; ARGUMENTS
; ---------
; ID: Storm ID in the format YYYY##B (e.g. 201703L)
; basin: TC basin (e.g. NATL, EPAC, WPAC)
; YYYY: Year (string)
; MM: Month (string)
; DD: Day (string)
; HH: Hour (string)
; mm: Minutes (string)
; ss: Seconds (string)
; vmaxkt: Maximum wind speed in knots (string)
; rmw: Radius of maximum wind (string)
; r34: Maximum radius of 34-kt winds (km; float)
; r50: Maximum radius of 50-kt winds (km; float)
; r64: Maximum radius of 64-kt winds (km; float)
; stormlat: Latitude of storm center (string)
; stormlon: Longitude of storm center (string)
; radius: Maximum radius within which to search
;         for CYGNSS observations (km).
; v: CYGNSS wind speeds (m/s)
; uncert: CYGNSS wind speed uncertainties (m/s)
; lat: Latitudes of CYGNSS observations (float)
; lon: Longitudes of CYGNSS observations (float)
; v_filtered: Filtered wind speed obs (m/s)
; lats_filtered: Latitudes of filtered obs
; lons_filtered: Longitudes of filtered obs
; dt: Time within which to search for CYGNSS obs.
; uncert_limit: The uncertainty limit used to
;               filter out wind speed obs.
;------------------------------------------------

undef("map_cygnss")
procedure map_cygnss(NAME,ID,YYYY,MM,DD,HH,mm,ss,vmaxkt,rmw,r34,r50,r64,stormlat,stormlon,radius,v,uncert,lat,lon,v_filtered,lats_filtered,lons_filtered,dt,uncert_limit)
begin

print( "Plotting map of CYGNSS observations...")

dthr = tostring(dt/3600)       ;Convert dt to hours
vmax = toint(vmaxkt*0.514444)  ;Convert vmax to m/s

outdir = "/jm13/pduran/web/cygnss/maps/"+NAME+"-"+ID+"/"
montagedir = "/jm13/pduran/web/cygnss/ike-windprofiles+maps_montage/"+radius+"km/"
montagefilterdir = "/jm13/pduran/web/cygnss/filtered-windspeed-maps/"+radius+"km/"
montageuncertdir = "/jm13/pduran/web/cygnss/windspeed+uncertainty-maps/"+radius+"km/"

;If output directory doesn't exist, create it.
dirstotest = (/outdir,montagedir,montagefilterdir,montageuncertdir/)
do testdir=0,dimsizes(dirstotest)-1
   dirtest = systemfunc("test -d "+dirstotest(testdir)+"; echo $?")
   if(dirtest.eq.1)then
      system("mkdir "+dirstotest(testdir))
   end if
end do

;Convert wind radii from km to degrees
kmtodeg = 1/111.
r34 = r34 * kmtodeg
r50 = r50 * kmtodeg
r64 = r64 * kmtodeg

print( r34)
print( r50)

map = new(3,"graphic")
do j=0,2
   mapres = True
   if(j.eq.0)then
      ;Plot locations of CYGNSS observations color-coded by wind speed 
      outfilename = outdir+"windspeed-"+YYYY+MM+DD+HH+mm+ss+"-"+radius+"km-"+dthr+"h.png"
      windoutfilename = outfilename
      print( "Writing to outout file "+outfilename)
      vplot    = v
      latsplot = lat
      lonsplot = lon
      mapres@gsnLeftString = "Winds (m s~S~-1~N~) within "+radius+"km and "+dthr+" h of "+NAME+\
                          " ("+YYYY+MM+DD+" "+HH+mm+" UTC)~C~V~B~max~N~ = "+vmax+" m s~S~-1~N~"+\
                          " ("+vmaxkt+" kt)  RMW = "+rmw+" km"
   else if(j.eq.1)then
      ;Plot locations of filtered CYGNSS observations
      outfilename = outdir+"filtered-"+YYYY+MM+DD+HH+mm+ss+"-"+radius+"km-"+dthr+"h.png"
      filtoutfilename = outfilename
      print( "Writing to outout file "+outfilename)
      vplot    := v_filtered
      latsplot := lats_filtered
      lonsplot := lons_filtered
      mapres@gsnLeftString = "Filtered winds (m s~S~-1~N~) [All obs with uncertainty > "+uncert_limit+" m s~S~-1~N~ removed]"
   else
      outfilename = outdir+"uncertainty-"+YYYY+MM+DD+HH+mm+ss+"-"+radius+"km-"+dthr+"h.png"
      uncertoutfilename = outfilename
      print( "Writing to outout file "+outfilename)
      vplot    := uncert
      latsplot := lat
      lonsplot := lon
      mapres@gsnLeftString = "YSLF NBRCS wind speed uncertainty (m s~S~-1~N~)"
   end if
   end if
   mapwks = gsn_open_wks("png",outfilename)
   mapres = True
   mapres@gsnLeftStringFontHeightF = 0.013
   mapres@gsnLeftStringFontHeightF = 0.013
   mapres@gsnLeftStringOrthogonalPosF = -0.0015
   mapres@gsnPaperOrientation = "portrait"
   mapres@mpDataBaseVersion = "HighRes"
   mapres@mpMinLatF = min((/stormlat,min(latsplot)/))-0.5
   mapres@mpMinLonF = min((/stormlon,min(lonsplot)/))-0.5
   mapres@mpMaxLatF = max((/stormlat,max(latsplot)/))+0.5
   mapres@mpMaxLonF = max((/stormlon,max(lonsplot)/))+0.5
   mapres@mpGridAndLimbOn = True
   mapres@mpGridLatSpacingF = 0.5
   mapres@mpGridLonSpacingF = 0.5
   mapres@pmTickMarkDisplayMode = "Always"
   mapres@pmLabelBarHeightF = 0.4
   mapres@mpGridLineColor = "gray40"
   mapres@gsnMaximize = False
   mapres@gsnDraw = False
   mapres@gsnFrame = False
   map(j) = gsn_csm_map(mapwks,mapres)
   pmres = True
   pmres@gsMarkerSizeF = 40
   pmres@gsMarkerIndex = 1

   ;Loop through wind speed thresholds and plot dots for each threshold
   if(j.eq.0.or.j.eq.1)then   ;Set colors for wind speed plots
      colors = (/"lightcyan","lightcyan3","cyan","deepskyblue3",\
                 "blue","gold","gold2","orange","orange3",\
                 "orangered","red","red4","orchid","orchid3",\
                 "magenta","magenta4","purple4","black"/)
      vthresh = (/0,5,10,15,20,25,30,35,40,45,50,55,60,65,70,75,80,85,90/)
   else   ;Set colors for uncertainty plot
;      colors  := (/"lightcyan3","cyan","blue","orange","red","magenta","purple4","black"/)
;      vthresh := (/1.0,1.5,2.0,2.5,3.0,3.5,4.0,4.5/)
      colors  := (/"lightcyan3","cyan","blue","orange","magenta","black"/)
      vthresh := (/2.0,2.5,3.0,3.5,4.0,4.5/)
   end if
   nthresh = dimsizes(vthresh)
   dum := new(nthresh,"graphic")
   do i=0,nthresh-1
      if(i.ne.nthresh-1)then
         indices := ind(vplot.ge.vthresh(i).and.vplot.lt.vthresh(i+1))
      else
         indices := ind(vplot.ge.vthresh(i))
      end if
      if(all(ismissing(indices)))then
         continue
      end if
      pmres@gsMarkerColor := colors(i)
      dum(i) = gsn_add_polymarker(mapwks,map(j),lonsplot(indices),latsplot(indices),pmres)
   end do
   
   ;Attach label bar representing the colored dots
   ;Get some values of the map coords so we can place the color bar properly
   getvalues map(j)
      "vpXF"      : vpx
      "vpYF"      : vpy
      "vpHeightF" : vph
      "vpWidthF"  : vpw
   end getvalues
   lbres = True
   lbres@lbFillColors := colors
   lbres@lbMonoFillPattern = True
   lbres@lbFillPattern = 0
   ;lbres@lbBoxEndCapStyle = "TriangleBothEnds"
   ;lbres@vpWidthF  = 0.4*vpw
   lbres@vpHeightF = 0.45;0.5*vph
   lbres@lbBoxMinorExtentF = 0.05
   lbres@lbLabelAlignment = "ExternalEdges"
   lbres@lbLabelStrings := array_append_record(vthresh,(vthresh(nthresh-1)+vthresh(1)-vthresh(0)),0)
   lbres@lbLabelFontHeightF = 0.014
   lbres@lbLabelOffsetF = 0.01
   lbres@lbLabelAutoStride = False
   lbres@lbLabelStride = 1
   lbres@lbOrientation = "vertical"
   lbres@lbTitleFontHeightF = 0.02
   lbres@lbTitleJust = "BottomCenter"
   gsn_labelbar_ndc(mapwks,nthresh,tostring(vthresh),vpx+vpw-0.25,0.72,lbres)

   ;PLOT BEST-TRACK WIND RADII INDICATORS
   ;Create arrays to store lats and lons of wind radii quadrants
   r34latsne = new(360,"float")
   r34latsse = new(360,"float")
   r34latssw = new(360,"float")
   r34latsnw = new(360,"float")
   r50latsne = new(360,"float")
   r50latsse = new(360,"float")
   r50latssw = new(360,"float")
   r50latsnw = new(360,"float")
   r64latsne = new(360,"float")
   r64latsse = new(360,"float")
   r64latssw = new(360,"float")
   r64latsnw = new(360,"float")
   r34lonsne = new(360,"float")
   r34lonsse = new(360,"float")
   r34lonssw = new(360,"float")
   r34lonsnw = new(360,"float")
   r50lonsne = new(360,"float")
   r50lonsse = new(360,"float")
   r50lonssw = new(360,"float")
   r50lonsnw = new(360,"float")
   r64lonsne = new(360,"float")
   r64lonsse = new(360,"float")
   r64lonssw = new(360,"float")
   r64lonsnw = new(360,"float")
   ;Compute lats and lons that correspond to the radius of each wind quadrant
   ;The circles are "drawn" counter-clockwise starting S of the storm center,
   ;such that subscripts 0-90 are the SE quadrant, 90-180 the NE quadrant, etc.
   if(r34(0).ne.0)then
      nggcog(stormlat,stormlon,r34(0),r34latsne,r34lonsne)
   end if
   if(r34(1).ne.0)then
      nggcog(stormlat,stormlon,r34(1),r34latsse,r34lonsse)
   end if
   if(r34(2).ne.0)then
      nggcog(stormlat,stormlon,r34(2),r34latssw,r34lonssw)
   end if
   if(r34(3).ne.0)then
      nggcog(stormlat,stormlon,r34(3),r34latsnw,r34lonsnw)
   end if
   if(r50(0).ne.0)then
      nggcog(stormlat,stormlon,r50(0),r50latsne,r50lonsne)
   end if
   if(r50(1).ne.0)then
      nggcog(stormlat,stormlon,r50(1),r50latsse,r50lonsse)
   end if
   if(r50(2).ne.0)then
      nggcog(stormlat,stormlon,r50(2),r50latssw,r50lonssw)
   end if
   if(r50(3).ne.0)then
      nggcog(stormlat,stormlon,r50(3),r50latsnw,r50lonsnw)
   end if
    if(r64(0).ne.0)then
      nggcog(stormlat,stormlon,r64(0),r64latsne,r64lonsne)
   end if
   if(r64(1).ne.0)then
      nggcog(stormlat,stormlon,r64(1),r64latsse,r64lonsse)
   end if
   if(r64(2).ne.0)then
      nggcog(stormlat,stormlon,r64(2),r64latssw,r64lonssw)
   end if
   if(r64(3).ne.0)then
      nggcog(stormlat,stormlon,r64(3),r64latsnw,r64lonsnw)
   end if

   ;Plot wind radii on map
   radres = True
   radres@gsLineThicknessF = 7.

   ;34-kt wind radii
   if(.not.all(r34.eq.0))then
      radres@gsLineColor = "blue"
      raddum1  = gsn_add_polyline(mapwks,map(j),\
                 array_append_record(stormlon,array_append_record(r34lonsse(0:90),stormlon,0),0),\
                 array_append_record(stormlat,array_append_record(r34latsse(0:90),stormlat,0),0),radres)
      raddum2  = gsn_add_polyline(mapwks,map(j),\
                 array_append_record(stormlon,array_append_record(r34lonsne(90:180),stormlon,0),0),\
                 array_append_record(stormlat,array_append_record(r34latsne(90:180),stormlat,0),0),radres)
      raddum3  = gsn_add_polyline(mapwks,map(j),\
                 array_append_record(stormlon,array_append_record(r34lonsnw(180:267),stormlon,0),0),\
                 array_append_record(stormlat,array_append_record(r34latsnw(180:267),stormlat,0),0),radres)
      raddum4  = gsn_add_polyline(mapwks,map(j),\
                 array_append_record(stormlon,array_append_record(r34lonssw(267:359),stormlon,0),0),\
                 array_append_record(stormlat,array_append_record(r34latssw(267:359),stormlat,0),0),radres)
   end if

   ;50-kt wind radii
   if(.not.all(r50.eq.0))then
      radres@gsLineColor = "orange"
      raddum5  = gsn_add_polyline(mapwks,map(j),\
                 array_append_record(stormlon,array_append_record(r50lonsse(0:90),stormlon,0),0),\
                 array_append_record(stormlat,array_append_record(r50latsse(0:90),stormlat,0),0),radres)
      raddum6  = gsn_add_polyline(mapwks,map(j),\
                 array_append_record(stormlon,array_append_record(r50lonsne(90:180),stormlon,0),0),\
                 array_append_record(stormlat,array_append_record(r50latsne(90:180),stormlat,0),0),radres)
      raddum7  = gsn_add_polyline(mapwks,map(j),\
                 array_append_record(stormlon,array_append_record(r50lonsnw(180:267),stormlon,0),0),\
                 array_append_record(stormlat,array_append_record(r50latsnw(180:267),stormlat,0),0),radres)
      raddum8  = gsn_add_polyline(mapwks,map(j),\
                 array_append_record(stormlon,array_append_record(r50lonssw(267:359),stormlon,0),0),\
                 array_append_record(stormlat,array_append_record(r50latssw(267:359),stormlat,0),0),radres)
   end if

   ;64-kt wind radii
   if(.not.all(r64.eq.0))then
      radres@gsLineColor = "red"
      raddum9  = gsn_add_polyline(mapwks,map(j),\
                 array_append_record(stormlon,array_append_record(r64lonsse(0:90),stormlon,0),0),\
                 array_append_record(stormlat,array_append_record(r64latsse(0:90),stormlat,0),0),radres)
      raddum10 = gsn_add_polyline(mapwks,map(j),\
                 array_append_record(stormlon,array_append_record(r64lonsne(90:180),stormlon,0),0),\
                 array_append_record(stormlat,array_append_record(r64latsne(90:180),stormlat,0),0),radres)
      raddum11 = gsn_add_polyline(mapwks,map(j),\
                 array_append_record(stormlon,array_append_record(r64lonsnw(180:267),stormlon,0),0),\
                 array_append_record(stormlat,array_append_record(r64latsnw(180:267),stormlat,0),0),radres)
      raddum12 = gsn_add_polyline(mapwks,map(j),\
                 array_append_record(stormlon,array_append_record(r64lonssw(267:359),stormlon,0),0),\
                 array_append_record(stormlat,array_append_record(r64latssw(267:359),stormlat,0),0),radres)
   end if

  
   ;Add storm symbol
   txres = True
   txres@txFontHeightF = 30.
   
   txres@txFontThicknessF = 5.
   txres@txFontColor = "red"
   if(vmax.lt.17.49)then
      symb  = "~F22~L"
   else if(vmax.ge.17.49.and.vmax.lt.32.92)then
      symb  = "~F35~m"
   else if(vmax.ge.32.92)then
      symb  = "~F37~p"
   end if
   end if
   end if
   dum1 := gsn_add_text(mapwks,map(j),symb,stormlon,stormlat,txres)
   draw(map(j))
   frame(mapwks)

   ;Montage the images
   if(j.eq.1)then
      ;Montage wind speed and filtered wind speed maps
      montageoutdir = montagefilterdir+NAME+"-"+ID+"/"
      ;If output directory doesn't exist, create it.
      dirtest = systemfunc("test -d "+montageoutdir+"; echo $?")
      if(dirtest.eq.1)then
         system("mkdir "+montageoutdir)
      end if
      montagefilename = montageoutdir+YYYY+MM+DD+HH+mm+ss+"-"+radius+"km-"+dthr+"h.png"
      print( "Writing montage to "+montagefilename)
      system("montage "+windoutfilename+" "+filtoutfilename+" -trim -tile 1x2 -bordercolor white -border 5 -geometry +0+0 "+montagefilename)
   else if(j.eq.2) 
      ;Montage wind speed and uncertainty maps
      montageoutdir = montageuncertdir+NAME+"-"+ID+"/"
      montagefilename = montageoutdir+YYYY+MM+DD+HH+mm+ss+"-"+radius+"km-"+dthr+"h.png"
      ;If output directory doesn't exist, create it.
      dirtest = systemfunc("test -d "+montageoutdir+"; echo $?")
      if(dirtest.eq.1)then
         system("mkdir "+montageoutdir)
      end if
      system("montage "+windoutfilename+" "+uncertoutfilename+" -trim -tile 1x2 -bordercolor white -border 5 -geometry +0+0 "+montagefilename)
   end if
   end if
end do

end
