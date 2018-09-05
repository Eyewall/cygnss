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
; rmw: Radius of maximum wind (string)
; stormlat: Storm latitude (degrees North)
; stormlon: Storm longitude (degrees East)
; radius: Maximum radius within which to search
;         for CYGNSS observations (km).
; dt: Time within which to search for CYGNSS obs.
;------------------------------------------------

undef("map_cygnss")
procedure map_cygnss(NAME,ID,YYYY,MM,DD,HH,mm,ss,vmaxkt,rmw,radius,stormlat,stormlon,dt,uncert_limit)
begin

print( "Plotting map of CYGNSS observations...")

dthr = tostring(dt/3600)       ;Convert dt to hours
vmax = toint(vmaxkt*0.514444)  ;Convert vmax to m/s

cygdir = "/jm13/pduran/cygnss/"+YYYY+"/level2/"
outdir = "/jm13/pduran/web/cygnss/maps/"+NAME+"-"+ID+"/"
montagedir = "/jm13/pduran/web/cygnss/ike-windprofiles+maps_montage/"
montagefilterdir = "/jm13/pduran/web/cygnss/filtered-windspeed-maps/"

;If output directory doesn't exist, create it.
dirtest = systemfunc("test -d "+outdir+"; echo $?")
if(dirtest.eq.1)then
   system("mkdir "+outdir)
end if

cygfilelist = systemfunc("cat "+cygdir+"cygtimes.txt | sed '1,3d' | awk '{print $1}'")
cygmintimes = toint(systemfunc("cat "+cygdir+"cygtimes.txt | sed '1,3d' | awk '{print $2}'"))
cygmaxtimes = toint(systemfunc("cat "+cygdir+"cygtimes.txt | sed '1,3d' | awk '{print $3}'"))

;Convert selected time to units of cygtime
timeunits = systemfunc("sed -n 1p "+cygdir+"cygtimes.txt | awk -F\' '{print $2}'")
time = cd_inv_calendar(toint(YYYY),toint(MM),toint(DD),toint(HH),toint(mm),toint(ss),timeunits,0)

;Get CYGNSS file name
timediffsmin := cygmintimes - time
timediffsmax := cygmaxtimes - time
cygfileind = ind(timediffsmax.ge.0.and.timediffsmin.le.0)
;If there is a CYGNSS outage, there might not be data
;at the best-track time. Check for this:
if(ismissing(cygfileind))then
   print( "map_cygnss: No CYGNSS observations available at "+YYYY+MM+DD+HH+mm+ss)
else
   infile = cygfilelist(cygfileind)
   ncinfile = addfile(infile,"r")
   ;Get time, lats, and lons of CYGNSS observations and wind speeds
   cygtimein := ncinfile->sample_time
   latsin    := ncinfile->lat
   lonsin    := ncinfile->lon
   vin       := ncinfile->yslf_nbrcs_wind_speed
   flags     := ncinfile->yslf_sample_flags
   uncertin  := ncinfile->yslf_nbrcs_wind_speed_uncertainty

   ;Convert flags array from short to binary and reverse the resulting
   ;bitmask array so we can compare it to YSLF status flags in metadata.
   bitmask = getbitsone(flags)
   bitmaskrev = bitmask(:,::-1)

   ;If the first bit is flipped, then there is a fatal error condition.
   ;If the 8th bit is flipped, then the there is a fatal high wind speed error.
   ;If the 13th bit is flipped, then there is a low range-corrected gain.
   ;If the 14th bit is flipped, then there is non-fatal low-quality GPS
   ;antenna knowledge (usually Block IIf satellites.)
   ;We will only deal with values where these bits are not flipped.
   nonerrorinds = ind(bitmaskrev(:,0).eq.0.and.bitmask(:,8).eq.0\
                      .and.bitmask(:,13).eq.0.and.bitmask(:,14).eq.0)
   cygtimeinput = cygtimein(nonerrorinds)
   lats   = latsin(nonerrorinds)
   lons   = lonsin(nonerrorinds)
   v      = vin(nonerrorinds)
   uncert = uncertin(nonerrorinds)
   
   ;Convert cygtime to common units
   cygtime = cd_convert(cygtimeinput,timeunits)
   
   ;Convert longitude from 0-360 to -180-180
   ;Source: https://gis.stackexchange.com/questions/201789/verifying-formula-that-will-convert-longitude-0-360-to-180-to-180
   lons = mod((lons+180),360) - 180
   lons@valid_range := "(-180, 180)"
   
   ;Get storm track data
;   trackfilename = systemfunc("ls /jm13/pduran/cygnss/"+YYYY+"/stormfiles/"+NAME+"-searchrad300km.nc") 
;   trackfile = addfile(trackfilename,"r")
;   tracktimes:= trackfile->tracktime
;   stormlats := trackfile->stormlat
;   stormlons := trackfile->stormlon
;   vmaxs     := trackfile->vmax
;   pmins     := trackfile->pmin
;   
;   ;Get the observation at the selected time
;   stormlat = stormlats({time})
;   stormlon = stormlons({time})
;   vmax     = vmaxs({time})
;   pmin     = pmins({time})
   
   ;Find distance between storm center and each CYGNSS retrieval
   dist = gc_latlon(stormlat,stormlon,lats,lons,2,4)
   
   ;Get only CYGNSS wind speed retrievals within time interval and search radius
   mintime = time - dt
   maxtime = time + dt
   selectioninds = ind(cygtime.ge.mintime.and.cygtime.le.maxtime.and.dist.le.radius)
   selectioninds_filtered = ind(cygtime.ge.mintime.and.cygtime.le.maxtime.and.dist.le.radius.and.uncert.lt.uncert_limit)

   if(all(ismissing(selectioninds)))then
      print( "map_cygnss: No CYGNSS observations within the selected time interval and search radius.")
   else
      uncertplot = uncert(selectioninds)
      ;Make plotted uncertainty a percentage of the observed wind speed
      ;NOTE: Doesn't seem like the best option...There are some obviously erroneous
      ;      high wind speed that have a low % uncertainty.
      ;uncertplot = uncert(selectioninds)/vplot*100.
      map = new(2,"graphic")
      do j=0,1
         if(j.eq.0)then
            ;Plot locations of CYGNSS observations color-coded by wind speed 
            outfilename = outdir+"windspeed-"+YYYY+MM+DD+HH+mm+ss+"-"+radius+"km-"+dthr+"h.png"
            windoutfilename = outfilename ;Needed for montaging
            print( "Writing to outout file "+outfilename)
            vplot    = v(selectioninds)
            latsplot = lats(selectioninds)
            lonsplot = lons(selectioninds)
         else
            ;Plot locations of filtered CYGNSS observations
            outfilename = outdir+"filtered-"+YYYY+MM+DD+HH+mm+ss+"-"+radius+"km-"+dthr+"h.png"
            print( "Writing to outout file "+outfilename)
            vplot    := v(selectioninds_filtered)
            latsplot := lats(selectioninds_filtered)
            lonsplot := lons(selectioninds_filtered)
         end if
         mapwks = gsn_open_wks("png",outfilename)
         mapres = True
         mapres@gsnLeftStringFontHeightF = 0.013
         if(j.eq.0)then
            mapres@gsnLeftString = "Winds (m s~S~-1~N~) within "+radius+"km and "+dthr+" h of "+NAME+\
                                " ("+YYYY+MM+DD+" "+HH+mm+" UTC)~C~V~B~max~N~ = "+vmax+" m s~S~-1~N~"+\
                                " ("+vmaxkt+" kt)  RMW = "+rmw+" km"
         else
            mapres@gsnLeftString = "Filtered winds (m s~S~-1~N~) [All obs with uncertainty > "+uncert_limit+" m s~S~-1~N~ removed]"
         end if 
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
         colors = (/"lightcyan","lightcyan3","cyan","lightskyblue","deepskyblue3",\
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
            pmres@gsMarkerColor = colors(i)
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
         ;lbres@lbOrientation = "horizontal"
         ;gsn_labelbar_ndc(mapwks,nthresh,tostring(vthresh),0.3,0.3,lbres)
         lbres@lbOrientation = "vertical"
;         if(j.eq.0)then
;            lbres@lbTitleString = "m s~S~-1"
;         else
;            lbres@lbTitleString = "%"
;         end if 
         lbres@lbTitleFontHeightF = 0.02
         lbres@lbTitleJust = "BottomCenter"
         gsn_labelbar_ndc(mapwks,nthresh,tostring(vthresh),vpx+vpw-0.25,0.72,lbres)
;         gsn_labelbar_ndc(mapwks,nthresh,tostring(vthresh),0.50,0.50,lbres)
         
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
;         maximize_output(mapwks,False)  ;Automatically draws map and advances wks
         draw(map(j))
         frame(mapwks)

         ;Montage wind profile and map plots
         profiledir = "/jm13/pduran/web/cygnss/ike-windprofiles/"+NAME+"-"+ID+"/"
         profilefilename = profiledir+YYYY+MM+DD+HH+mm+ss+"-"+radius+"km-"+dthr+"h.png"
         if(j.eq.0)then
            montageoutdir = montagedir+NAME+"-"+ID+"/"
         else
            montageoutdir = montagefilterdir+NAME+"-"+ID+"/"
         end if
         ;If output directory doesn't exist, create it.
         dirtest = systemfunc("test -d "+montageoutdir+"; echo $?")
         if(dirtest.eq.1)then
            system("mkdir "+montageoutdir)
         end if
         montagefilename = montageoutdir+YYYY+MM+DD+HH+mm+ss+"-"+radius+"km-"+dthr+"h.png"
         print( "Writing montage to "+montagefilename)
         if(j.eq.0)then
            system("montage "+profilefilename+" "+windoutfilename+" -trim -tile 2x1 -bordercolor white -border 5 -geometry +0+0 "+montagefilename)
         else
            system("montage "+windoutfilename+" "+outfilename+" -trim -tile 1x2 -bordercolor white -border 5 -geometry +0+0 "+montagefilename)
         end if
      end do   ;j loop (j=0:Wind speed; j=1:Uncertainty)
   end if   ;selectioninds
end if   ;cygfileind

end
