;------------------------------------------------
; map_all.ncl
; Patrick Duran
; 14 November 2018
;
; Plots wind speed retrievals as dots
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
; vmax: Maximum wind speed in m/s (integer)
; rmw: Radius of maximum wind (string)
; R34: Maximum radius of 34-kt winds (km; float)
; R50: Maximum radius of 50-kt winds (km; float)
; R64: Maximum radius of 64-kt winds (km; float)
; stormlat: Latitude of storm center (string)
; stormlon: Longitude of storm center (string)
; radius: Maximum radius within which to search
;         for observations (km).
; sfmrv:   SFMR wind speeds (m/s)
; sfmrlat: Latitudes of SFMR observations (float)
; sfmrlon: Longitudes of SFMR observations (float)
; cygv:   CYGNSS wind speeds (m/s)
; cyglat: Latitudes of CYGNSS observations (float)
; cyglon: Longitudes of CYGNSS observations (float)
; ascv:   ASCAT wind speeds (m/s)
; asclat: Latitudes of ASCAT observations (float)
; asclon: Longitudes of ASCAT observations (float)
; dt:  Time within which to search for SFMR obs.
; searchtype: "centered", "forward", or "backward"
; outhomedir: Home directory in which to put plots
;------------------------------------------------

undef("map_all")
procedure map_all(NAME,ID,YYYY,MM,DD,HH,mm,ss,vmax,rmw,r34,r50,r64,stormlat,stormlon,radius,sfmrv,sfmrlat,sfmrlon,cygv,cyglat,cyglon,ascv,asclat,asclon,smapv,smaplat,smaplon,dt,searchtype,outhomedir)
local R34,R50,R64,sfmrvplot,sfmrlatsplot,sfmrlonsplot,cygvplot,cyglatsplot,cyglonsplot,\
      ascvplot,asclatsplot,asclonsplot,smapvplot,smaplatsplot,smaplonsplot
begin

nplots = 4

print( "Plotting map of wind observations...")

dthr = tostring(dt/3600)       ;Convert dt to hours
vmaxkt = tostring(round(vmax*1.94384,3)) ;Convert vmax to kt

;If output directory doesn't exist, create it.
outdir = outhomedir+"maps/"+searchtype+"/"+NAME+"-"+ID+"/"
dirtest = systemfunc("test -d "+outdir+"; echo $?")
if(dirtest.eq.1)then
   system("mkdir "+outdir)
end if

;Get offset in degrees so we can set extent of plotting
degtorad   = get_d2r("float")
kmtodeglon = cos(stormlat*degtorad)*110.57
lonoffset  = radius/kmtodeglon
latoffset  = radius/110.57

;Convert wind radii from km to degrees
kmtodeg = 1/kmtodeglon
R34 = r34 * kmtodeg
R50 = r50 * kmtodeg
R64 = r64 * kmtodeg

;Set mapping resources common to each observation platform
mapres = True
mapres@mpProjection = "LambertConformal"
mapres@mpLambertParallel1F = stormlat - 5
mapres@mpLambertParallel2F = stormlat + 5
mapres@mpLambertMeridianF = stormlon
mapres@mpLimitMode = "LatLon"
if(searchtype.eq."centered")then
   mapres@gsnLeftStringFontHeightF = 0.018
else
   mapres@gsnLeftStringFontHeightF = 0.017
end if
mapres@gsnLeftStringOrthogonalPosF = -0.0015
mapres@gsnPaperOrientation = "portrait"
mapres@mpDataBaseVersion = "HighRes"
mapres@mpMinLatF = stormlat-latoffset;min((/stormlat,min(latsplot)/))-0.5
mapres@mpMinLonF = stormlon-lonoffset;min((/stormlon,min(lonsplot)/))-0.5
mapres@mpMaxLatF = stormlat+latoffset;max((/stormlat,max(latsplot)/))+0.5
mapres@mpMaxLonF = stormlon+lonoffset;max((/stormlon,max(lonsplot)/))+0.5
mapres@mpGridAndLimbOn = True
mapres@mpGridLatSpacingF = 0.5
mapres@mpGridLonSpacingF = 0.5
mapres@pmTickMarkDisplayMode = "Always"
mapres@pmLabelBarHeightF = 0.4
mapres@mpGridLineColor = "gray40"
mapres@tmYROn = False
mapres@tmXTOn = False
mapres@gsnMaximize = False
mapres@gsnDraw = False
mapres@gsnFrame = False

;Set output filenames and plotting variables for each observation platform
outfilename = outdir+"windspeed-"+YYYY+MM+DD+HH+mm+ss+"-"+radius+"km-"+dthr+"h.png"
print( "Drawing map to output file "+outfilename)
sfmrvplot    = sfmrv
sfmrlatsplot = sfmrlat
sfmrlonsplot = sfmrlon
cygvplot     = cygv
cyglatsplot  = cyglat
cyglonsplot  = cyglon
ascvplot     = ascv
asclatsplot  = asclat
asclonsplot  = asclon
smapvplot     = smapv
smaplatsplot  = smaplat
smaplonsplot  = smaplon

;Set resources for each observation platform
sfmrmapres = mapres
cygmapres  = mapres
ascmapres  = mapres
smapmapres = mapres
if(searchtype.eq."centered")then
   sfmrmapres@gsnLeftString = "~F22~SFMR~F21~ winds (m s~S~-1~N~) within "+radius+"km and "+dthr+" h"; of "+NAME;+\
;                              " ("+YYYY+MM+DD+" "+HH+mm+" UTC)~C~V~B~max~N~ = "+vmax+" m s~S~-1~N~"+\
;                              " ("+vmaxkt+" kt)  RMW = "+rmw+" km"
   cygmapres@gsnLeftString = "~F22~CYGNSS~F21~ winds (m s~S~-1~N~) within "+radius+"km and "+dthr+" h"; of "+NAME;+\
;                              " ("+YYYY+MM+DD+" "+HH+mm+" UTC)~C~V~B~max~N~ = "+vmax+" m s~S~-1~N~"+\
;                              " ("+vmaxkt+" kt)  RMW = "+rmw+" km"
   ascmapres@gsnLeftString = "~F22~ASCAT~F21~ winds (m s~S~-1~N~) within "+radius+"km and "+dthr+" h"; of "+NAME;+\
;                              " ("+YYYY+MM+DD+" "+HH+mm+" UTC)~C~V~B~max~N~ = "+vmax+" m s~S~-1~N~";+\
;                              " ("+vmaxkt+" kt)  RMW = "+rmw+" km"
   smapmapres@gsnLeftString = "~F22~SMAP~F21~ winds (m s~S~-1~N~) within "+radius+"km and "+dthr+" h"; of "+NAME;+\
;                              " ("+YYYY+MM+DD+" "+HH+mm+" UTC)~C~V~B~max~N~ = "+vmax+" m s~S~-1~N~";+\
;                              " ("+vmaxkt+" kt)  RMW = "+rmw+" km"
elseif(searchtype.eq."forward")
   sfmrmapres@gsnLeftString = "~F22~SFMR~F21~ winds (m s~S~-1~N~) within "+radius+"km and "+dthr+\
                              " h after";+" ("+YYYY+MM+DD+" "+HH+mm+" UTC)~C~V~B~max~N~ = "+\
;                              vmax+" m s~S~-1~N~"+" ("+vmaxkt+" kt)  RMW = "+rmw+" km"
   cygmapres@gsnLeftString = "~F22~CYGNSS~F21~ winds (m s~S~-1~N~) within "+radius+"km and "+dthr+\
                              " h after";+" ("+YYYY+MM+DD+" "+HH+mm+" UTC)~C~V~B~max~N~ = "+\
;                              vmax+" m s~S~-1~N~"+" ("+vmaxkt+" kt)  RMW = "+rmw+" km"
   ascmapres@gsnLeftString = "~F22~ASCAT~F21~ winds (m s~S~-1~N~) within "+radius+"km and "+dthr+\
                              " h after";+" ("+YYYY+MM+DD+" "+HH+mm+" UTC)~C~V~B~max~N~ = "+\
;                              vmax+" m s~S~-1~N~"+" ("+vmaxkt+" kt)  RMW = "+rmw+" km"
   smapmapres@gsnLeftString = "~F22~SMAP~F21~ winds (m s~S~-1~N~) within "+radius+"km and "+dthr+\
                              " h after";+" ("+YYYY+MM+DD+" "+HH+mm+" UTC)~C~V~B~max~N~ = "+\
;                              vmax+" m s~S~-1~N~"+" ("+vmaxkt+" kt)  RMW = "+rmw+" km"
elseif(searchtype.eq."backward")
   sfmrmapres@gsnLeftString = "~F22~SFMR~F21~ winds (m s~S~-1~N~) within "+radius+"km and "+dthr+\
                              " h prior";+YYYY+MM+DD+" "+HH+mm+" UTC)~C~V~B~max~N~ = "+\
;                              vmax+" m s~S~-1~N~"+" ("+vmaxkt+" kt)  RMW = "+rmw+" km"
   cygmapres@gsnLeftString = "~F22~CYGNSS~F21~ winds (m s~S~-1~N~) within "+radius+"km and "+dthr+\
                              " h prior"; ("+YYYY+MM+DD+" "+HH+mm+" UTC)~C~V~B~max~N~ = "+\
;                              vmax+" m s~S~-1~N~"+" ("+vmaxkt+" kt)  RMW = "+rmw+" km"
   ascmapres@gsnLeftString = "~F22~ASCAT~F21~ winds (m s~S~-1~N~) within "+radius+"km and "+dthr+\
                              " h prior"; ("+YYYY+MM+DD+" "+HH+mm+" UTC)~C~V~B~max~N~ = "+\
;                              vmax+" m s~S~-1~N~"+" ("+vmaxkt+" kt)  RMW = "+rmw+" km"
   smapmapres@gsnLeftString = "~F22~SMAP~F21~ winds (m s~S~-1~N~) within "+radius+"km and "+dthr+\
                              " h prior"; ("+YYYY+MM+DD+" "+HH+mm+" UTC)~C~V~B~max~N~ = "+\
;                              vmax+" m s~S~-1~N~"+" ("+vmaxkt+" kt)  RMW = "+rmw+" km"
end if

;Open workstations for each observation platform and plot
wks  = gsn_open_wks("png",outfilename)
sfmrmap = gsn_csm_map(wks,sfmrmapres)
cygmap  = gsn_csm_map(wks,cygmapres)
ascmap  = gsn_csm_map(wks,ascmapres)
smapmap = gsn_csm_map(wks,smapmapres)

;Set resources for wind speed dot plotting
pmres = True
pmres@gsMarkerSizeF = 30.
pmres@gsMarkerIndex = 1
;Loop through wind speed thresholds and plot dots for each threshold
;colors = (/"lightcyan","lightcyan3","cyan","deepskyblue3",\
;           "blue","gold","gold2","orange","orange3",\
;           "orangered","red","red4","orchid","orchid3",\
;           "magenta","magenta4","purple4","black"/)
colors = (/"lightcyan3","cyan","deepskyblue3",\
           "blue","orange","red","red4",\
           "orchid","magenta","purple4","black"/)
;vthresh = (/0,5,10,15,20,25,30,35,40,45,50,55,60,65,70,75,80,85/)
vthresh = (/0,5,10,17.9,25.7,32.9,35,40,45,50,55/)
;vthresh = (/0,5,10,15,20,25,30,35,40,45,50,55/)
nthresh = dimsizes(vthresh)
sfmrdum := new(nthresh,"graphic")
cygdum  := new(nthresh,"graphic")
ascdum  := new(nthresh,"graphic")
smapdum := new(nthresh,"graphic")
do i=0,nthresh-1
   sfmrplotflag = True
   cygplotflag  = True
   ascplotflag  = True
   smapplotflag = True
   if(i.ne.nthresh-1)then
      sfmrindices := ind(sfmrvplot.ge.vthresh(i).and.sfmrvplot.lt.vthresh(i+1))
      cygindices  := ind(cygvplot.ge.vthresh(i).and.cygvplot.lt.vthresh(i+1))
      ascindices  := ind(ascvplot.ge.vthresh(i).and.ascvplot.lt.vthresh(i+1))
      smapindices := ind(smapvplot.ge.vthresh(i).and.smapvplot.lt.vthresh(i+1))
   else
      sfmrindices := ind(sfmrvplot.ge.vthresh(i))
      cygindices  := ind(cygvplot.ge.vthresh(i))
      ascindices  := ind(ascvplot.ge.vthresh(i))
      smapindices := ind(smapvplot.ge.vthresh(i))
   end if
   if(all(ismissing(sfmrindices)))then
      sfmrplotflag = False
   end if
   if(all(ismissing(cygindices)))then
      cygplotflag = False
   end if
   if(all(ismissing(ascindices)))then
      ascplotflag = False
   end if
   if(all(ismissing(smapindices)))then
      smapplotflag = False
   end if
   pmres@gsMarkerColor := colors(i)
   if(sfmrplotflag)then
      sfmrdum(i) = gsn_add_polymarker(wks,sfmrmap,sfmrlonsplot(sfmrindices),\
                                      sfmrlatsplot(sfmrindices),pmres)
   end if
   if(cygplotflag)then
      cygdum(i) = gsn_add_polymarker(wks,cygmap,cyglonsplot(cygindices),\
                                     cyglatsplot(cygindices),pmres)
   end if
   if(ascplotflag)then
      ascdum(i) = gsn_add_polymarker(wks,ascmap,asclonsplot(ascindices),\
                                     asclatsplot(ascindices),pmres)
   end if
   if(smapplotflag)then
      smapdum(i) = gsn_add_polymarker(wks,smapmap,smaplonsplot(smapindices),\
                                     smaplatsplot(smapindices),pmres)
   end if
end do

;Attach label bar representing the colored dots
;Get some values of the map coords so we can place the color bar properly
;getvalues sfmrmap
;   "vpXF"      : vpx
;   "vpYF"      : vpy
;   "vpHeightF" : vph
;   "vpWidthF"  : vpw
;end getvalues
lbres = True
lbres@lbFillColors := colors
lbres@lbMonoFillPattern = True
lbres@lbFillPattern = 0
lbres@vpHeightF = 0.45;0.5*vph
lbres@lbBoxMinorExtentF = 0.05
lbres@lbLabelAlignment = "ExternalEdges"
lbres@lbLabelStrings := array_append_record(vthresh,(vthresh(nthresh-1)+vthresh(1)-vthresh(0)),0)
lbres@lbLabelFontHeightF = 0.014
lbres@lbLabelOffsetF = 0.01
lbres@lbLabelAutoStride = False
lbres@lbLabelStride = 1
lbres@lbTitleFontHeightF = 0.02
lbres@lbTitleJust = "CenterRight"
;lbres@lbTitleString = "m s~S~-1~N~"
lbres@lbOrientation = "vertical"
if(nplots.eq.4)then
   lbres@lbOrientation = "horizontal"
end if

if(nplots.eq.1)then
   gsn_labelbar_ndc(wks,nthresh,tostring(vthresh),vpx+vpw-0.25,0.72,lbres)
elseif(nplots.eq.2)then
   gsn_labelbar_ndc(wks,nthresh,tostring(vthresh),0.43,0.977,lbres)
   gsn_labelbar_ndc(wks,nthresh,tostring(vthresh),0.43,0.477,lbres)
elseif(nplots.eq.3)then
   gsn_labelbar_ndc(wks,nthresh,tostring(vthresh),0.49,0.472,lbres)
elseif(nplots.eq.4)then
   gsn_labelbar_ndc(wks,nthresh,tostring(vthresh),0.226,0.244,lbres)
end if

;PLOT BEST-TRACK WIND RADII INDICATORS
;Set all missing values equal to zero
R34 = where(ismissing(R34),0,R34)
R50 = where(ismissing(R50),0,R50)
R64 = where(ismissing(R64),0,R64)
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
;suich that subscripts 0-90 are the SE quadrant, 90-180 the NE quadrant, etc.
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

;Set plotting coordinates for each wind radius in each quadrant
r34sex = array_append_record(stormlon,array_append_record(R34lonsse(0:90),stormlon,0),0)
r34sey = array_append_record(stormlat,array_append_record(R34latsse(0:90),stormlat,0),0)
r34nex = array_append_record(stormlon,array_append_record(R34lonsne(90:180),stormlon,0),0)
r34ney = array_append_record(stormlat,array_append_record(R34latsne(90:180),stormlat,0),0)
r34nwx = array_append_record(stormlon,array_append_record(R34lonsnw(180:267),stormlon,0),0)
r34nwy = array_append_record(stormlat,array_append_record(R34latsnw(180:267),stormlat,0),0)
r34swx = array_append_record(stormlon,array_append_record(R34lonssw(267:359),stormlon,0),0)
r34swy = array_append_record(stormlat,array_append_record(R34latssw(267:359),stormlat,0),0)
r50sex = array_append_record(stormlon,array_append_record(R50lonsse(0:90),stormlon,0),0)
r50sey = array_append_record(stormlat,array_append_record(R50latsse(0:90),stormlat,0),0)
r50nex = array_append_record(stormlon,array_append_record(R50lonsne(90:180),stormlon,0),0)
r50ney = array_append_record(stormlat,array_append_record(R50latsne(90:180),stormlat,0),0)
r50nwx = array_append_record(stormlon,array_append_record(R50lonsnw(180:267),stormlon,0),0)
r50nwy = array_append_record(stormlat,array_append_record(R50latsnw(180:267),stormlat,0),0)
r50swx = array_append_record(stormlon,array_append_record(R50lonssw(267:359),stormlon,0),0)
r50swy = array_append_record(stormlat,array_append_record(R50latssw(267:359),stormlat,0),0)
r64sex = array_append_record(stormlon,array_append_record(R64lonsse(0:90),stormlon,0),0)
r64sey = array_append_record(stormlat,array_append_record(R64latsse(0:90),stormlat,0),0)
r64nex = array_append_record(stormlon,array_append_record(R64lonsne(90:180),stormlon,0),0)
r64ney = array_append_record(stormlat,array_append_record(R64latsne(90:180),stormlat,0),0)
r64nwx = array_append_record(stormlon,array_append_record(R64lonsnw(180:267),stormlon,0),0)
r64nwy = array_append_record(stormlat,array_append_record(R64latsnw(180:267),stormlat,0),0)
r64swx = array_append_record(stormlon,array_append_record(R64lonssw(267:359),stormlon,0),0)
r64swy = array_append_record(stormlat,array_append_record(R64latssw(267:359),stormlat,0),0)

;Plot wind radii on map
radres = True
radres@gsLineThicknessF = 7.
;34-kt wind radii
if(.not.all(R34.eq.0))then
   radres@gsLineColor = "blue"
   sfmrraddum1 = gsn_add_polyline(wks,sfmrmap,r34sex,r34sey,radres)
   sfmrraddum2 = gsn_add_polyline(wks,sfmrmap,r34nex,r34ney,radres)
   sfmrraddum3 = gsn_add_polyline(wks,sfmrmap,r34nwx,r34nwy,radres)
   sfmrraddum4 = gsn_add_polyline(wks,sfmrmap,r34swx,r34swy,radres)
   cygraddum1  = gsn_add_polyline(wks,cygmap,r34sex,r34sey,radres)
   cygraddum2  = gsn_add_polyline(wks,cygmap,r34nex,r34ney,radres)
   cygraddum3  = gsn_add_polyline(wks,cygmap,r34nwx,r34nwy,radres)
   cygraddum4  = gsn_add_polyline(wks,cygmap,r34swx,r34swy,radres)
   ascraddum1  = gsn_add_polyline(wks,ascmap,r34sex,r34sey,radres)
   ascraddum2  = gsn_add_polyline(wks,ascmap,r34nex,r34ney,radres)
   ascraddum3  = gsn_add_polyline(wks,ascmap,r34nwx,r34nwy,radres)
   ascraddum4  = gsn_add_polyline(wks,ascmap,r34swx,r34swy,radres)
   smapraddum1 = gsn_add_polyline(wks,smapmap,r34sex,r34sey,radres)
   smapraddum2 = gsn_add_polyline(wks,smapmap,r34nex,r34ney,radres)
   smapraddum3 = gsn_add_polyline(wks,smapmap,r34nwx,r34nwy,radres)
   smapraddum4 = gsn_add_polyline(wks,smapmap,r34swx,r34swy,radres)
end if
;50-kt wind radii
if(.not.all(R50.eq.0))then
   radres@gsLineColor = "orange"
   sfmrraddum5 = gsn_add_polyline(wks,sfmrmap,r50sex,r50sey,radres)
   sfmrraddum6 = gsn_add_polyline(wks,sfmrmap,r50nex,r50ney,radres)
   sfmrraddum7 = gsn_add_polyline(wks,sfmrmap,r50nwx,r50nwy,radres)
   sfmrraddum8 = gsn_add_polyline(wks,sfmrmap,r50swx,r50swy,radres)
   cygraddum5  = gsn_add_polyline(wks,cygmap,r50sex,r50sey,radres)
   cygraddum6  = gsn_add_polyline(wks,cygmap,r50nex,r50ney,radres)
   cygraddum7  = gsn_add_polyline(wks,cygmap,r50nwx,r50nwy,radres)
   cygraddum8  = gsn_add_polyline(wks,cygmap,r50swx,r50swy,radres)
   ascraddum5  = gsn_add_polyline(wks,ascmap,r50sex,r50sey,radres)
   ascraddum6  = gsn_add_polyline(wks,ascmap,r50nex,r50ney,radres)
   ascraddum7  = gsn_add_polyline(wks,ascmap,r50nwx,r50nwy,radres)
   ascraddum8  = gsn_add_polyline(wks,ascmap,r50swx,r50swy,radres)
   smapraddum5 = gsn_add_polyline(wks,smapmap,r50sex,r50sey,radres)
   smapraddum6 = gsn_add_polyline(wks,smapmap,r50nex,r50ney,radres)
   smapraddum7 = gsn_add_polyline(wks,smapmap,r50nwx,r50nwy,radres)
   smapraddum8 = gsn_add_polyline(wks,smapmap,r50swx,r50swy,radres)
end if
;64-kt wind radii
if(.not.all(R64.eq.0))then
   radres@gsLineColor = "red"
   sfmrraddum9  = gsn_add_polyline(wks,sfmrmap,r64sex,r64sey,radres)
   sfmrraddum10 = gsn_add_polyline(wks,sfmrmap,r64nex,r64ney,radres)
   sfmrraddum11 = gsn_add_polyline(wks,sfmrmap,r64nwx,r64nwy,radres)
   sfmrraddum12 = gsn_add_polyline(wks,sfmrmap,r64swx,r64swy,radres)
   cygraddum9   = gsn_add_polyline(wks,cygmap,r64sex,r64sey,radres)
   cygraddum10  = gsn_add_polyline(wks,cygmap,r64nex,r64ney,radres)
   cygraddum11  = gsn_add_polyline(wks,cygmap,r64nwx,r64nwy,radres)
   cygraddum12  = gsn_add_polyline(wks,cygmap,r64swx,r64swy,radres)
   ascraddum9   = gsn_add_polyline(wks,ascmap,r64sex,r64sey,radres)
   ascraddum10  = gsn_add_polyline(wks,ascmap,r64nex,r64ney,radres)
   ascraddum11  = gsn_add_polyline(wks,ascmap,r64nwx,r64nwy,radres)
   ascraddum12  = gsn_add_polyline(wks,ascmap,r64swx,r64swy,radres)
   smapraddum9  = gsn_add_polyline(wks,smapmap,r64sex,r64sey,radres)
   smapraddum10 = gsn_add_polyline(wks,smapmap,r64nex,r64ney,radres)
   smapraddum11 = gsn_add_polyline(wks,smapmap,r64nwx,r64nwy,radres)
   smapraddum12 = gsn_add_polyline(wks,smapmap,r64swx,r64swy,radres)
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
dum1 := gsn_add_text(wks,sfmrmap,symb,stormlon,stormlat,txres)
dum2 := gsn_add_text(wks,cygmap,symb,stormlon,stormlat,txres)
dum3 := gsn_add_text(wks,ascmap,symb,stormlon,stormlat,txres)
dum4 := gsn_add_text(wks,smapmap,symb,stormlon,stormlat,txres)

;Add range rings
;circles = geolocation_circle(stormlat,stormlon,ispan(10,200,10),1,360,False)
;circlats = circles[0]
;circlons = circles[1]
;circdims = dimsizes(circlats)
;ncircs = circdims(1)
;circdum = new(ncircs,"graphic")
;do i=0,ncircs-1
;   circres = True
;   circres@gsLineThicknessF = 2.
;   circdum(i) = gsn_add_polyline(mapwks,map,circlons(0,i,:),circlats(0,i,:),circres)
;end do

;Panel the plots
panelres = True
panelres@gsnMaximize = False
panelres@gsnPanelBottom = 0.05
vmaxstr = sprintf("%4.1f",vmax)
panelres@gsnPanelMainString = "~F22~"+NAME+" | "+MM+"/"+DD+"/"+YYYY+" "+HH+":"+mm+" UTC | V~B~max~N~ "+\
                              vmaxstr+" m s~S~-1~N~ ("+vmaxkt+" kt) | RMW "+rmw+" km"
gsn_panel(wks,(/cygmap,sfmrmap,ascmap,smapmap/),(/2,2/),panelres)

end
