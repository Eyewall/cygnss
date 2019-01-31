;------------------------------------------------
; level2-plot-spec-points.ncl
; Patrick Duran
; 02 August 2018
;
; Plots CYGNSS wind speed retrieval locations
; collected within a user-defined radius of
; a tropical cyclone, along with the TC location.
; Reads all netCDF files in an input directory,
; which contain CYGNSS wind data and best-track
; storm data.
;------------------------------------------------


cygdir = "/raid1/pduran/jm13/cygnss/"
outdir = "/raid1/pduran/jm13/web/cygnss/stormmaps/"
year   = 2017
radius = 300      ;Search radius (km)

infiles = systemfunc("ls "+cygdir+year+"/stormfiles/"+"*nc")
nfiles = dimsizes(infiles)
do i=0,nfiles-1
   infile = infiles(i)
   storm = systemfunc("echo "+infile+" | awk -F'/' '{print $NF}' | awk -F'-' '{print $1}'")
   print( "Plotting map for "+infile)
   ncinfile = addfile(infile,"r")
   ;Get lats and lons of CYGNSS observations
   lats := ncinfile->lat
   lons := ncinfile->lon
   
   ;Get storm track data
   stormlat := ncinfile->stormlat
   stormlon := ncinfile->stormlon
   vmax     := ncinfile->vmax
   pmin     := ncinfile->pmin
   
   ;Source: https://gis.stackexchange.com/questions/201789/verifying-formula-that-will-convert-longitude-0-360-to-180-to-180
   lons = mod((lons+180),360) - 180
   
   ;Plot locations of CYGNSS observations along the storm's entire track
   mapwks = gsn_open_wks("png",outdir+storm+"-searchrad"+radius+"km.png")
   mapres = True
   mapres@gsnLeftStringFontHeightF = 0.015
   mapres@gsnLeftString = "CYGNSS wind speed retrieval locations within "+radius+"km of "+storm+" ("+year+")"
   mapres@mpMinLatF = min(lats)-0.5
   mapres@mpMinLonF = min(lons)-0.5
   mapres@mpMaxLatF = max(lats)+0.5
   mapres@mpMaxLonF = max(lons)+0.5
   mapres@gsnMaximize = True
   mapres@gsnDraw = False
   mapres@gsnFrame = False
   map := gsn_csm_map(mapwks,mapres)
   pmres = True
   pmres@gsMarkerSizeF = 20
   pmres@gsMarkerIndex = 1
   pmres@gsMarkerColor = "green"
   print( "Plotting CYGNSS points...")
   dum := gsn_add_polymarker(mapwks,map,lons,lats,pmres)
   
   ;Add storm symbols
   txres = True
   txres@txFontHeightF = 30.
   txres@txFontThicknessF = 5.
   txres@txFontColor = "red"
   tdind := ind(vmax.lt.34)
   tsind := ind(vmax.ge.34.and.vmax.lt.64)
   hurind:= ind(vmax.ge.64)
   if(.not.all(ismissing(tdind)))then
      print( "Adding TD symbols...")
      tdlats  := stormlat(tdind)
      tdlons  := stormlon(tdind)
      tdsymb  := conform(tdlats,"~F22~L",-1)
      dum1 := gsn_add_text(mapwks,map,tdsymb,tdlons,tdlats,txres)
   end if
   if(.not.all(ismissing(tsind)))then
      print( "Adding TS symbols...")
      tslats  := stormlat(tsind)
      tslons  := stormlon(tsind)
      tssymb  := conform(tslats,"~F35~m",-1)
      dum2 := gsn_add_text(mapwks,map,tssymb,tslons,tslats,txres)
   end if
   if(.not.all(ismissing(hurind)))then
      print( "Adding HURRICANE symbols...")
      hurlats := stormlat(hurind)
      hurlons := stormlon(hurind)
      hursymb  := conform(hurlats,"~F37~p",-1)
      dum2 := gsn_add_text(mapwks,map,hursymb,hurlons,hurlats,txres)
   end if
   draw(map)
   frame(mapwks)
end do
