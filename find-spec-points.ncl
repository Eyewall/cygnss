load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "/jm13/pduran/ncl/functions/tools.ncl"
load "/jm13/pduran/ncl/radar/scripts/functions/rangering.ncl"

;---------------------------------------------
; find-spec-points.ncl 
; Patrick Duran
; 13 July 2018
; 
; READS LEVEL-1 FILES
; Finds any specular points that fall within a
; user-defined time interval and within a
; search radius from a user-defined lat,lon.
;---------------------------------------------

datalevel = 1
;Beginning of time period
yyyy1  = "2018"
  mm1  = "03"
  dd1  = "19"
  hh1  = "00"
  min1 = "00"
;End of time period
yyyy2  = "2018"
  mm2  = "03"
  dd2  = "20"
  hh2  = "00"
  min2 = "00"
;Location of search center and search radius. Must be floating-point.
lat = 34.0
lon = -87.0
searchradius= 500  ;Units km
;Ignore Block IIF GPS vehicles?
ignoreblockIIF = True
cygtimefile = "/jm13/pduran/cygnss/"+yyyy1+"/level"+datalevel+"/cygtimes.txt"
outdir = "/jm13/pduran/web/cygnss/specpointmaps/"

;------------------------------------------------;
;GET CYGNSS FILE NAME AND OBSERVATION BLOCK TIMES;
;------------------------------------------------;
timeunits    = systemfunc("sed -n 1p "+cygtimefile+" | awk -F\' '{print $2}'")
cygfilenames = systemfunc("cat "+cygtimefile+" | sed '1,2d' | awk '{print $1}'")
cygmintimes  = toint(systemfunc("cat "+cygtimefile+" | sed '1,2d' | awk '{print $2}'"))
cygmaxtimes  = toint(systemfunc("cat "+cygtimefile+" | sed '1,2d' | awk '{print $3}'"))

;-------------------------------------------;
;CONVERT INPUT DATES/TIMES TO REFERENCE TIME;
;-------------------------------------------;
year1 := toint(yyyy1)
mon1  := toint(mm1)
day1  := toint(dd1)
hour1 := toint(hh1)
minu1 := toint(min1)
year2 := toint(yyyy2)
mon2  := toint(mm2)
day2  := toint(dd2)
hour2 := toint(hh2)
minu2 := toint(min2)

;-------------------------------------;
;CONVERT DATES/TIMES TO REFERENCE TIME;
;-------------------------------------;
time1 := cd_inv_calendar(year1,mon1,day1,hour1,minu1,conform(year1,0,-1),timeunits,0)
time2 := cd_inv_calendar(year2,mon2,day2,hour2,minu2,conform(year2,0,-1),timeunits,0)

;------------------------------------------;
;FIND SPECULAR POINTS WITHIN TIME RANGE AND;
;SEARCH RADIUS.                            ;
;------------------------------------------;
cygfiles = systemfunc("ls /jm13/pduran/cygnss/"+yyyy1+"/level"+datalevel+"/*nc")
nfiles = dimsizes(cygfiles)
;Loop through CYGNSS files
do i=0,nfiles-1
   ;Read variables from CYGNSS file
   cygfilename = cygfiles(i)
   satnum  = systemfunc("echo "+cygfilename+" | awk -F'/' '{print $NF}' | awk -F'.' '{print $1}'")
   cygfile = addfile(cygfilename,"r")
   cygvers = cygfile@title
   prn    := cygfile->prn_code    ;PRN code
   cygtime:= cygfile->ddm_timestamp_utc
   cyglat := cygfile->sp_lat      
   cyglon := cygfile->sp_lon
   ;Since Level 1 files have 4 specular points per satellite per timestamp time,
   ;we need to conform cygtime to have the same rank & dimension sizes as cyglat.
   ctime  := cd_convert(cygtime,timeunits)  ;Convert to same time units as input
   ctime_conform := conform(cyglat,ctime,0)
   ctime@units = timeunits
   if(ignoreblockIIF)then  ;Ignore retrievals that use BlockIIF satellites
      print( "Ignoring retrievals computed using Block IIF satellites.")
      toignore = (/1,3,6,8,9,10,24,25,26,27,30,32/) ;PRN codes for BlockIIF sats
      do k=0,dimsizes(toignore)-1
         cyglat = where(prn.eq.toignore(k),cyglat@_FillValue,cyglat)   
         cyglon = where(prn.eq.toignore(k),cyglon@_FillValue,cyglon)   
      end do
   end if
   ;Compute distances between selected location and all retrieval locations
   dist := gc_latlon(lat,lon,cyglat,cyglon,2,4)
   ;Get indices for retrievals where distance is within search radius
   dist1d := ndtooned(dist)
   ctime1d:= ndtooned(ctime_conform)
   lats1d := ndtooned(cyglat)
   lons1d := ndtooned(cyglon)
   indices := ind(dist1d.lt.searchradius.and.ctime1d.ge.time1.and.ctime1d.le.time2)
   ;If there aren't any for this search radius, skip to end of loop
   if(all(ismissing(indices)))then
      print( "No observations found within search radius between the specified time in file "+cygfilename)
      continue
   end if
   ;Get time, lats, lons
   ninds = dimsizes(indices)
   time := ctime1d(indices)
   lats := lats1d(indices)
   lons := lons1d(indices) - 360
   ;Convert time back to something readable
   time@units = timeunits 
   cygdattims := round(cd_calendar(time,0),3)
   ;-----------------------------;
   ;PLOT SPECULAR POINT LOCATIONS;
   ;-----------------------------;
   ;Get date/time strings for specular points 
   yearstring := tostring(cygdattims(:,0))
   monstring  := tostring(cygdattims(:,1))
   daystring  := tostring(cygdattims(:,2))
   hrstring   := tostring(cygdattims(:,3))
   minstring  := tostring(cygdattims(:,4))
   secstring  := tostring(cygdattims(:,5))
   monstring  := where(cygdattims(:,1).lt.10,"0"+monstring,monstring)
   daystring  := where(cygdattims(:,2).lt.10,"0"+daystring,daystring)
   hrstring   := where(cygdattims(:,3).lt.10,"0"+hrstring,hrstring)
   minstring  := where(cygdattims(:,4).lt.10,"0"+minstring,minstring)
   secstring  := where(cygdattims(:,5).lt.10,"0"+secstring,secstring)
   dattimstring := yearstring+monstring+daystring+"_"+hrstring+minstring+secstring
   ndattims = dimsizes(dattimstring)
   ;Set filename and open workstation 
   filename = outdir+"specpoints_lat"+lat+"_lon"+lon+"_searchrad"+searchradius+"km_"+dattimstring(0)+"-"+dattimstring(ndattims-1)
   wks = gsn_open_wks("png",filename)
   ;Determine minimum and maximum extent of plot area (approximate 111 km per degree lat/lon)
   centerlatrad = lat*(2*3.141592/360.)
   range_lat = searchradius/111.
   range_lon = searchradius/(110.567*cos(centerlatrad))
   scale     = range_lon/range_lat
   degextent = searchradius/111.
   minlat = lat-range_lat 
   maxlat = lat+range_lat
   minlon = lon-range_lon
   maxlon = lon+range_lon
   res = True
   res@gsnDraw = False
   res@gsnFrame = False
   res@mpDataBaseVersion           = "MediumRes"
   res@mpDataSetName               = "Earth..4"
   res@mpGeophysicalLineColor      = "black"
   res@mpGeophysicalLineThicknessF = 5.0
   res@mpProvincialLineThicknessF = 5.0
   res@mpCountyLineThicknessF = 2.5
   res@mpCountyLineColor = res@mpGeophysicalLineColor
   res@mpOutlineBoundarySets       = "GeophysicalAndUSStates"
   res@mpOutlineOn                 = True
   res@mpUSStateLineColor          = res@mpGeophysicalLineColor
   res@mpOutlineSpecifiers = (/"United States : Counties"/)
   res@mpGridAndLimbDrawOrder = "Postdraw"
   res@mpLabelsOn             = False
   res@mpPerimOn              = True
   res@mpFillOn               = False
   res@mpOutlineOn            = True
   res@mpOutlineDrawOrder     = "Draw"
   res@mpFillDrawOrder        = "PreDraw"
   res@gsnLeftString = monstring(0)+"/"+daystring(0)+"/"+yearstring(0)+" "\
                       +hrstring(0)+":"+minstring(0)+" - "\
                       +monstring(ndattims-1)+"/"+daystring(ndattims-1)+"/"\
                       +yearstring(ndattims-1)+" "+hrstring(ndattims-1)\
                       +":"+minstring(ndattims-1)+" UTC"
   res@gsnRightString = satnum
   res@gsnLeftStringFontHeightF = 0.015
   res@gsnRightStringFontHeightF = 0.015
   res@gsnLeftStringOrthogonalPosF = 0.005;-0.0001
   res@gsnRightStringOrthogonalPosF = 0.005;-0.0001
   res@mpLimitMode            = "LatLon"
   res@mpMinLatF = minlat
   res@mpMaxLatF = maxlat
   res@mpMinLonF = minlon
   res@mpMaxLonF = maxlon
   res@tmXTOn = False
   res@tmYROn = False
   res@gsnMaximize = True
   map = gsn_csm_map(wks,res)
   ;Add range ring
   ringres = True
   ringres@Scale = scale
   ringres@gsLineThicknessF = 10.
   circle_ll(wks,map,lon,lat,range_lat,ringres)
   ;Add dots representing CYGNSS observations
   dotres = True
   dotres@tfPolyDrawOrder = "PreDraw"
   dotres@gsMarkerIndex = 1
   dotres@gsMarkerThicknessF = 10.
   dotres@gsMarkerColor = "red"
   gsn_polymarker(wks,map,lons,lats,dotres)
   draw(map)
   frame(wks)
end do
