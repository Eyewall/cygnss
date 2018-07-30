load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "/jm13/pduran/ncl/functions/tools.ncl"
load "/jm13/pduran/ncl/radar/scripts/functions/rangering.ncl"

;---------------------------------------------
; plot-spec-points-radar.ncl 
; Patrick Duran
; 18 July 2018
; 
; Reads all .txt files in an input directory
; and plots locations of CYGNSS specular
; points over radar imagery.
;---------------------------------------------

indir = "/jm13/pduran/hail-reports/"
outdir= "/jm13/pduran/web/cygnss/specpointmaps/"
raddir= "/jm13/pduran/radar/data/netcdf/"
timeunits = "seconds since 2016-1-1 00:00:00"
;url   = "http://thredds-aws.unidata.ucar.edu/thredds/radarServer/nexrad/level2/S3/"

pi        = 4.0*atan(1.0)
convert   = pi/180.

;-------------------------;
;READ NEXRAD LOCATION FILE;
;-------------------------;
nexradlocfile = "/jm13/pduran/radar/nexrad-stations.TXT"
stnid  = systemfunc("cat "+nexradlocfile+" | sed 1,2d | awk '{print $2}'")
radlat = tofloat(systemfunc("cat "+nexradlocfile+" | sed 1,2d | cut -c107-114"))
radlon = tofloat(systemfunc("cat "+nexradlocfile+" | sed 1,2d | cut -c117-126"))

;-------------------------------------------------;
;LOOP THROUGH HAIL FILES AND GET CYGNSS LOCATIONS.;
;FIND NEAREST RADAR STATION AND RADAR DATA TIME.  ;
;PULL RADAR DATA FROM THREDDS SERVER AND PLOT.    ;
;-------------------------------------------------;
hailfiles = systemfunc("ls "+indir+"*txt")
nhailfiles = dimsizes(hailfiles)
do i=0,nhailfiles-1
   unixi = i + 1
   print( "Reading hail file "+unixi+" of "+nhailfiles)
   print( hailfiles(i))
   report = systemfunc("sed -n 1p "+hailfiles(i))
   print( report)
   haillat = stringtofloat(systemfunc("sed -n 1p "+hailfiles(i)+" | awk -F',' '{print $6}'"))
   haillon = stringtofloat(systemfunc("sed -n 1p "+hailfiles(i)+" | awk -F',' '{print $7}'"))

   data := readAsciiTable(hailfiles(i),11,"float",4)
   year   := toint(data(:,0))
   month  := toint(data(:,1))
   day    := toint(data(:,2))
   hour   := toint(data(:,3))
   minu   := toint(data(:,4))
   sec    := toint(data(:,5))
   cyglat := data(:,6)
   cyglon := data(:,7)
   dx     := data(:,8)
   dt     := data(:,9)
   satnum := "cyg0"+tostring(toint(data(:,10)))

   ;Get strings for dates
   YYYY := tostring(year)
   MM   := tostring(month)
   DD   := tostring(day)
   HH   := tostring(hour)
   mm   := tostring(minu)
   ss   := tostring(sec)

   ;If digit is less than 10, need to add zero to beginning of string
   MM := where(month.lt.10,"0"+MM,MM)
   DD := where(day.lt.10,"0"+DD,DD)
   HH := where(hour.lt.10,"0"+HH,HH)
   mm := where(minu.lt.10,"0"+mm,mm)
   ss := where(sec.lt.10,"0"+ss,ss)

   ;Find the NEXRAD site nearest to the center cyglat,cyglon pair
   centerind = toint(ceil(dimsizes(cyglat)/2))
   dist = gc_latlon(cyglat(centerind),cyglon(centerind),radlat,radlon,2,4)
   stn  = stnid(minind(dist))
   ;Some stations have two IDs. Substitute station IDs where necessary.
   stn = where(stn.eq."KINX","KTSA",stn)  ;Tulsa (INX) listed as TSA in archive
   stn = where(stn.eq."KDGX","KJAN",stn)  ;Jackson, MS (DGX) listed as JAN in archive
   stn = where(stn.eq."KFWS","KFWD",stn)  ;Dallas (FWS) listed as FWD in archive
   stn = where(stn.eq."KTLX","KOUN",stn)  ;Oklahoma City (TLX) listed as OUN in archive
   stn = where(stn.eq."KBIX","KMOB",stn)  ;Keesler (BIX) not available for download

   ;Add all radar files from this station
   filelist := systemfunc("ls "+raddir+stn+"/*nc")
   radfiles  = addfiles(filelist,"r")
   ListSetType(radfiles,"join")

   ;Get radar dates/times
   raddattimstring := systemfunc("ls "+raddir+stn+"/*nc | awk -F'/' '{print $NF}' | awk -F'_' '{print $NF}' | sed -e 's/.nc//g'")
   raddates := toint(str_split_by_length(raddattimstring,(/4,2,2,2,2/)))
   radyear  := raddates(:,0)
   radmon   := raddates(:,1)
   radday   := raddates(:,2)
   radhour  := raddates(:,3)
   radminu  := raddates(:,4)
   radsec   := conform(raddates(:,0),0,-1)

   ;Read values from NEXRAD files
   type   := radfiles[0]@keywords_vocabulary
   if(type.eq."N0R")then
      ref = radfiles[:]->BaseReflectivity
   else if(type.eq."N0Q")then
      ref = radfiles[:]->BaseReflectivityDR
   end if
   end if
   azi    := radfiles[:]->azimuth
   gate   := radfiles[:]->gate
   radlats := radfiles[:]->latitude
   radlons := radfiles[:]->longitude

   ;Replace NaNs with missing values
   ref@_FillValue = -9999
   replace_ieeenan(ref,ref@_FillValue,0)

   ;Convert radar and CYGNSS times to common units
   cygtimes := cd_inv_calendar(year,month,day,hour,minu,sec,timeunits,0)
   radtimes := cd_inv_calendar(radyear,radmon,radday,radhour,radminu,radsec,timeunits,0)

   ;Set and create subdirectory where we will put images for this hail file
   hailfilename = systemfunc("echo "+hailfiles(i)+" | awk -F'/' '{print $NF}' | sed -e 's/.txt//g'")
   outsubdir = outdir+"/"+hailfilename+"/"
   system("mkdir "+outsubdir)

   ;Clear memory by deleting radfiles
   delete(radfiles)

   ;Loop through all CYGNSS times and plot radar image for each specular point
   ncygtimes = dimsizes(cygtimes)
   do j=0,ncygtimes-1
      unixj = j + 1
      cygtimeint = round(cygtimes(j),3)
      radind = minind(abs(cygtimeint-radtimes))
      ctrlat = radlats(radind,0)
      ctrlon = radlons(radind,0)
      reflectivity := ref(radind,:,:)
      azimuth := azi(radind,:)
      radius  := gate(radind,:)  ;Radius to start of gate (m)

      ;Convert azimuths, stationlat, and stationlon to radians
      azimuth_rad := convert*azimuth
      ctrlat_rad  := convert*ctrlat
      ctrlon_rad  := convert*ctrlon

      ;---------------------------;
      ;INTERPOLATE TO LAT,LON GRID;
      ;---------------------------;
      ;We have distances to the start of each gate; we want distances to center 
      ;of gates. First, get length of each gate, and then add half this value 
      ;to each element to get radial location of the center of each gate.
      glen   := radius(1)-radius(0)
      radius := radius+(glen/2)

      ;Loop through all of the azimuths and get x and y distances from the radar
      ;position (in metiers)
      nazis = dimsizes(azimuth)
      nrads = dimsizes(radius)
      x := new((/nazis,nrads/),"float")
      y := new((/nazis,nrads/),"float")
      do k=0,nazis-1
         x(k,:) = radius*sin(azimuth_rad(k))
         y(k,:) = radius*cos(azimuth_rad(k))
      end do

      ;First get the number of meters per degree lat and lon, then divide the x
      ;and y distances by these values to convert to degrees lat and lon.
      ;Then, add these lat,lon displacements to the station lat,lon to get a
      ;lat,lon grid
      meters_per_degree_lat = 111132.92-559.82*cos(2*ctrlat_rad)+1.175*cos(4*ctrlat_rad)
      meters_per_degree_lon = 111412.84*cos(ctrlat_rad)-93.5*cos(3*ctrlat_rad)
      y = y/meters_per_degree_lat
      x = x/meters_per_degree_lon
      lats := ctrlat+y
      lons := ctrlon+x

      ;Now we can set the coordinate variables for the reflectivity
      ;array to the lat,lon arrays and plot
      reflectivity!0 = "azimuth"
      reflectivity!1 = "radius"
      printMinMax(reflectivity,False)
      maxdbz = max(reflectivity)

      ;Delete long name and units so they don't appear on the top of the plot
      delete(reflectivity@long_name)
      delete(reflectivity@units)

      ;Get minimum and maximum lat/lons for plot
      ;radfile = radfiles[radind]
      ;minlat  = radfile@geospatial_lat_min
      ;minlon  = radfile@geospatial_lon_min
      ;maxlat  = radfile@geospatial_lat_max
      ;maxlon  = radfile@geospatial_lon_max
      ;There is an error in at least some radar files that makes the
      ;minimum longitude larger than the maximum longitude. If this
      ;is the case, switch minlon and maxlon
      ;if(minlon.gt.maxlon)then
      ;   minlontemp = minlon
      ;   minlon = maxlon
      ;   maxlon = minlontemp
      ;end if

      ;Draw the plot
      outfilename = outsubdir+tostring(cygtimeint)+".png"
      print( "Writing image to "+outfilename)
      wks = gsn_open_wks("png",outfilename)
      setvalues wks
         "wkBackgroundColor" : (/0.,0.,0./)
      end setvalues
      gsn_define_colormap(wks,"dbz_cod")

      ;Contour resources
      res = True
      res@gsnDraw = False
      res@gsnFrame = False
      res@sfXArray := lons
      res@sfYArray := lats
      res@cnFillOn = True
      res@cnLinesOn = False
      res@cnFillMode = "RasterFill"
      res@trGridType = "TriangularMesh"
      res@cnLevelSelectionMode = "ExplicitLevels"
      res@cnLevels = ispan(-10,80,1)
   ;   res@cnRasterSmoothingOn = "True"
      res@cnFillDrawOrder = "PreDraw"
      res@tiMainOn = True
      res@tiMainString = report
      res@tiMainFontHeightF = 0.008
      res@tiMainFontColor = "white"
      res@tiXAxisOn = False
;      res@trYMinF = minlat
;      res@trYMaxF = maxlat
;      res@trXMinF = minlon
;      res@trXMaxF = maxlon
      res@lbOrientation = "Vertical"
      res@lbTitleString = "dBZ"
      res@lbTitlePosition = "Bottom"
      res@lbLabelAutoStride = False
      res@lbLabelStride = 5
      res@lbLabelFontHeightF = 0.008
      res@lbLabelFontColor = "white"
      res@pmLabelBarOrthogonalPosF = -0.06
      res@pmLabelBarWidthF = 0.05
      res@lbTitleFontHeightF = 0.012
      res@lbBottomMarginF = -1.0
      res@gsnMaximize = True
      res@gsnPaperOrientation = "landscape"
      res@tmXBOn = False
      res@tmXTOn = False
      res@tmYROn = False
      res@tmYLOn = False
   
      ;Map resources
      mapres = True
      mapres@gsnDraw = False
      mapres@gsnFrame = False
      mapres@mpDataBaseVersion           = "MediumRes"
      mapres@mpDataSetName               = "Earth..4"
      mapres@mpGeophysicalLineColor      = "yellow"
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
      mapres@mpLimitMode            = "LatLon"
      mapres@mpMinLatF              =  min(cyglat)-0.5
      mapres@mpMaxLatF              =  max(cyglat)+0.5
      mapres@mpMinLonF              =  min(cyglon)-0.5
      mapres@mpMaxLonF              =  max(cyglon)+0.5
      mapres@tiMainOn               = False
      mapres@tiXAxisOn              = False
      mapres@gsnLeftString = "Specular Point Time: "+MM(j)+"/"+DD(j)+"/"+YYYY(j)+" "+HH(j)+":"+mm(j)+":"+ss(j)+"  "+satnum(j)
      mapres@gsnLeftStringFontHeightF = 0.008
      mapres@gsnLeftStringOrthogonalPosF = -0.003
      mapres@gsnLeftStringFontColor = "white"
      mapres@gsnRightString = stn+" Radar Time: "+raddattimstring(radind)
      mapres@gsnRightStringFontHeightF = 0.008
      mapres@gsnRightStringOrthogonalPosF = 0.002
      mapres@gsnRightStringFontColor = "white"
      mapres@gsnMaximize = True
      mapres@gsnPaperOrientation = "landscape"
      mapres@tmXBOn = False
      mapres@tmXTOn = False
      mapres@tmYROn = False
      mapres@tmYLOn = False
      map     = gsn_csm_map(wks,mapres)
      contour = gsn_csm_contour(wks,reflectivity,res)
      overlay(map,contour)

      ;Attach hail report location
      pmres = True
      pmres@gsMarkerSizeF = 20
      pmres@gsMarkerThicknessF = 20
      pmres@gsMarkerIndex = 8
      pmres@gsMarkerColor = "green"
      dum1 = gsn_add_polymarker(wks,map,haillon,haillat,pmres)
      
      ;Attach CYGNSS specular points
      pmres@gsMarkerSizeF = 9
      pmres@gsMarkerThicknessF = 20
      pmres@gsMarkerIndex = 1
      pmres@gsMarkerColor = "cyan"
      dum2 := gsn_add_polymarker(wks,map,cyglon,cyglat,pmres)
      pmres@gsMarkerColor = "blue"
      dum3 := gsn_add_polymarker(wks,map,cyglon(j),cyglat(j),pmres)
      draw(map)
      frame(wks)
   end do
   delete(ref)
end do
