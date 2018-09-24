;------------------------------------------------
; map_sfmr.ncl
; Patrick Duran
; 21 September 2018
;
; Plots SFMR wind speed retrievals as dots
; color-coded by wind speed.
; Plots also depict the location of storm center.
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
; R34: Maximum radius of 34-kt winds (km; float)
; R50: Maximum radius of 50-kt winds (km; float)
; R64: Maximum radius of 64-kt winds (km; float)
; stormlat: Latitude of storm center (string)
; stormlon: Longitude of storm center (string)
; radius: Maximum radius within which to search
;         for SFMR observations (km).
; v: SFMR wind speeds (m/s)
; lat: Latitudes of SFMR observations (float)
; lon: Longitudes of SFMR observations (float)
; dt: Time within which to search for SFMR obs.
;------------------------------------------------

undef("map_sfmr")
procedure map_sfmr(NAME,ID,YYYY,MM,DD,HH,mm,ss,vmaxkt,rmw,r34,r50,r64,stormlat,stormlon,radius,v,lat,lon,dt,searchtype)
local R34, R50, R64, vplot, latsplot, lonsplot
begin

print( "Plotting map of SFMR observations...")

dthr = tostring(dt/3600)       ;Convert dt to hours
vmax = toint(vmaxkt*0.514444)  ;Convert vmax to m/s

outdir = "/jm13/pduran/web/sfmr/maps/"+searchtype+"/"+NAME+"-"+ID+"/"

;If output directory doesn't exist, create it.
dirtest = systemfunc("test -d "+outdir+"; echo $?")
if(dirtest.eq.1)then
   system("mkdir "+outdir)
end if

;Convert wind radii from km to degrees
kmtodeg = 1/111.
R34 = r34 * kmtodeg
R50 = r50 * kmtodeg
R64 = r64 * kmtodeg

mapres = True
;Plot locations of SFMR observations color-coded by wind speed 
outfilename = outdir+"windspeed-"+YYYY+MM+DD+HH+mm+ss+"-"+radius+"km-"+dthr+"h.png"
windoutfilename = outfilename
print( "Writing to outout file "+outfilename)
vplot    = v
latsplot = lat
lonsplot = lon
if(searchtype.eq."centered")then
   mapres@gsnLeftString = "SFMR winds (m s~S~-1~N~) within "+radius+"km and "+dthr+" h of "+NAME+\
                       " ("+YYYY+MM+DD+" "+HH+mm+" UTC)~C~V~B~max~N~ = "+vmax+" m s~S~-1~N~"+\
                       " ("+vmaxkt+" kt)  RMW = "+rmw+" km"
else if(searchtype.eq."forward")
   mapres@gsnLeftString = "SFMR winds (m s~S~-1~N~) within "+radius+"km and within "+dthr+\
                          " h after "+NAME+" ("+YYYY+MM+DD+" "+HH+mm+" UTC)~C~V~B~max~N~ = "+\
                          vmax+" m s~S~-1~N~"+" ("+vmaxkt+" kt)  RMW = "+rmw+" km"
else if(searchtype.eq."backward")
   mapres@gsnLeftString = "SFMR winds (m s~S~-1~N~) within "+radius+"km and within "+dthr+\
                          " h prior to "+NAME+" ("+YYYY+MM+DD+" "+HH+mm+" UTC)~C~V~B~max~N~ = "+\
                          vmax+" m s~S~-1~N~"+" ("+vmaxkt+" kt)  RMW = "+rmw+" km"
end if
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
;mapres@mpMinLatF = 21.5 
;mapres@mpMinLonF = -75.5
;mapres@mpMaxLatF = 22.5
;mapres@mpMaxLonF = -74.0
mapres@mpGridAndLimbOn = True
mapres@mpGridLatSpacingF = 0.5
mapres@mpGridLonSpacingF = 0.5
mapres@pmTickMarkDisplayMode = "Always"
mapres@pmLabelBarHeightF = 0.4
mapres@mpGridLineColor = "gray40"
mapres@gsnMaximize = False
mapres@gsnDraw = False
mapres@gsnFrame = False
map = gsn_csm_map(mapwks,mapres)
pmres = True
pmres@gsMarkerSizeF = 30.
pmres@gsMarkerIndex = 1

;Loop through wind speed thresholds and plot dots for each threshold
colors = (/"lightcyan","lightcyan3","cyan","deepskyblue3",\
           "blue","gold","gold2","orange","orange3",\
           "orangered","red","red4","orchid","orchid3",\
           "magenta","magenta4","purple4","black"/)
vthresh = (/0,5,10,15,20,25,30,35,40,45,50,55,60,65,70,75,80,85,90/)
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
   dum(i) = gsn_add_polymarker(mapwks,map,lonsplot(indices),latsplot(indices),pmres)
end do

;Attach label bar representing the colored dots
;Get some values of the map coords so we can place the color bar properly
getvalues map
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
R34latsne = new(360,"float")
R34latsse = new(360,"float")
R34latssw = new(360,"float")
R34latsnw = new(360,"float")
R50latsne = new(360,"float")
R50latsse = new(360,"float")
R50latssw = new(360,"float")
R50latsnw = new(360,"float")
R64latsne = new(360,"float")
R64latsse = new(360,"float")
R64latssw = new(360,"float")
R64latsnw = new(360,"float")
R34lonsne = new(360,"float")
R34lonsse = new(360,"float")
R34lonssw = new(360,"float")
R34lonsnw = new(360,"float")
R50lonsne = new(360,"float")
R50lonsse = new(360,"float")
R50lonssw = new(360,"float")
R50lonsnw = new(360,"float")
R64lonsne = new(360,"float")
R64lonsse = new(360,"float")
R64lonssw = new(360,"float")
R64lonsnw = new(360,"float")
;Compute lats and lons that correspond to the radius of each wind quadrant
;The circles are "drawn" counter-clockwise starting S of the storm center,
;such that subscripts 0-90 are the SE quadrant, 90-180 the NE quadrant, etc.
if(R34(0).ne.0)then
   nggcog(stormlat,stormlon,R34(0),R34latsne,R34lonsne)
end if
if(R34(1).ne.0)then
   nggcog(stormlat,stormlon,R34(1),R34latsse,R34lonsse)
end if
if(R34(2).ne.0)then
   nggcog(stormlat,stormlon,R34(2),R34latssw,R34lonssw)
end if
if(R34(3).ne.0)then
   nggcog(stormlat,stormlon,R34(3),R34latsnw,R34lonsnw)
end if
if(R50(0).ne.0)then
   nggcog(stormlat,stormlon,R50(0),R50latsne,R50lonsne)
end if
if(R50(1).ne.0)then
   nggcog(stormlat,stormlon,R50(1),R50latsse,R50lonsse)
end if
if(R50(2).ne.0)then
   nggcog(stormlat,stormlon,R50(2),R50latssw,R50lonssw)
end if
if(R50(3).ne.0)then
   nggcog(stormlat,stormlon,R50(3),R50latsnw,R50lonsnw)
end if
 if(R64(0).ne.0)then
   nggcog(stormlat,stormlon,R64(0),R64latsne,R64lonsne)
end if
if(R64(1).ne.0)then
   nggcog(stormlat,stormlon,R64(1),R64latsse,R64lonsse)
end if
if(R64(2).ne.0)then
   nggcog(stormlat,stormlon,R64(2),R64latssw,R64lonssw)
end if
if(R64(3).ne.0)then
   nggcog(stormlat,stormlon,R64(3),R64latsnw,R64lonsnw)
end if

;Plot wind radii on map
radres = True
radres@gsLineThicknessF = 7.

;34-kt wind radii
if(.not.all(R34.eq.0))then
   radres@gsLineColor = "blue"
   raddum1  = gsn_add_polyline(mapwks,map,\
              array_append_record(stormlon,array_append_record(R34lonsse(0:90),stormlon,0),0),\
              array_append_record(stormlat,array_append_record(R34latsse(0:90),stormlat,0),0),radres)
   raddum2  = gsn_add_polyline(mapwks,map,\
              array_append_record(stormlon,array_append_record(R34lonsne(90:180),stormlon,0),0),\
              array_append_record(stormlat,array_append_record(R34latsne(90:180),stormlat,0),0),radres)
   raddum3  = gsn_add_polyline(mapwks,map,\
              array_append_record(stormlon,array_append_record(R34lonsnw(180:267),stormlon,0),0),\
              array_append_record(stormlat,array_append_record(R34latsnw(180:267),stormlat,0),0),radres)
   raddum4  = gsn_add_polyline(mapwks,map,\
              array_append_record(stormlon,array_append_record(R34lonssw(267:359),stormlon,0),0),\
              array_append_record(stormlat,array_append_record(R34latssw(267:359),stormlat,0),0),radres)
end if

;50-kt wind radii
if(.not.all(R50.eq.0))then
   radres@gsLineColor = "orange"
   raddum5  = gsn_add_polyline(mapwks,map,\
              array_append_record(stormlon,array_append_record(R50lonsse(0:90),stormlon,0),0),\
              array_append_record(stormlat,array_append_record(R50latsse(0:90),stormlat,0),0),radres)
   raddum6  = gsn_add_polyline(mapwks,map,\
              array_append_record(stormlon,array_append_record(R50lonsne(90:180),stormlon,0),0),\
              array_append_record(stormlat,array_append_record(R50latsne(90:180),stormlat,0),0),radres)
   raddum7  = gsn_add_polyline(mapwks,map,\
              array_append_record(stormlon,array_append_record(R50lonsnw(180:267),stormlon,0),0),\
              array_append_record(stormlat,array_append_record(R50latsnw(180:267),stormlat,0),0),radres)
   raddum8  = gsn_add_polyline(mapwks,map,\
              array_append_record(stormlon,array_append_record(R50lonssw(267:359),stormlon,0),0),\
              array_append_record(stormlat,array_append_record(R50latssw(267:359),stormlat,0),0),radres)
end if

;64-kt wind radii
if(.not.all(R64.eq.0))then
   radres@gsLineColor = "red"
   raddum9  = gsn_add_polyline(mapwks,map,\
              array_append_record(stormlon,array_append_record(R64lonsse(0:90),stormlon,0),0),\
              array_append_record(stormlat,array_append_record(R64latsse(0:90),stormlat,0),0),radres)
   raddum10 = gsn_add_polyline(mapwks,map,\
              array_append_record(stormlon,array_append_record(R64lonsne(90:180),stormlon,0),0),\
              array_append_record(stormlat,array_append_record(R64latsne(90:180),stormlat,0),0),radres)
   raddum11 = gsn_add_polyline(mapwks,map,\
              array_append_record(stormlon,array_append_record(R64lonsnw(180:267),stormlon,0),0),\
              array_append_record(stormlat,array_append_record(R64latsnw(180:267),stormlat,0),0),radres)
   raddum12 = gsn_add_polyline(mapwks,map,\
              array_append_record(stormlon,array_append_record(R64lonssw(267:359),stormlon,0),0),\
              array_append_record(stormlat,array_append_record(R64latssw(267:359),stormlat,0),0),radres)
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
dum1 := gsn_add_text(mapwks,map,symb,stormlon,stormlat,txres)
draw(map)
frame(mapwks)

end
