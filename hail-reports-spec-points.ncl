load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "/jm13/pduran/ncl/functions/tools.ncl"
load "/jm13/pduran/ncl/radar/scripts/functions/rangering.ncl"

;---------------------------------------------
; hail-reports-spec-points.ncl 
; Patrick Duran
; 16 July 2018
;
; Reads all .csv files in a given directory
; (that come from the SPC storm report archive)
; and finds any specular points that occur
; within a specified time range and distance
; from each hail report.
; Specular points come from level-1 files.
;---------------------------------------------

maxtimediff  = 10    ;Minutes  
searchradius = 50  ;km
;Ignore Block IIF GPS vehicles?
ignoreblockIIF = True
haildir = "/jm13/pduran/hail-reports/"
cygtimefile = "/jm13/pduran/cygnss/2018/level1/cygtimes.txt"
cygdir = "/jm13/pduran/cygnss/2018/level1/"

;------------------------------------------------;
;GET CYGNSS FILE NAME AND OBSERVATION BLOCK TIMES;
;------------------------------------------------;
timeunits = systemfunc("sed -n 1p "+cygtimefile+" | awk -F\' '{print $2}'")
cygfilenames = systemfunc("cat "+cygtimefile+" | sed '1,2d' | awk '{print $1}'")
cygmintimes  = toint(systemfunc("cat "+cygtimefile+" | sed '1,2d' | awk '{print $2}'"))
cygmaxtimes  = toint(systemfunc("cat "+cygtimefile+" | sed '1,2d' | awk '{print $3}'"))

;---------------------------------------;
;GET TIMES AND LOCATIONS OF ALL SPECULAR;
;POINTS IN EACH OF THE CYGNSS FILES.    ;
;---------------------------------------;
;Get number of CYGNSS files in directory and initialize arrays
cygfiles = systemfunc("ls "+cygdir+"*nc")
nfiles = dimsizes(cygfiles)
;Maximum of 86400 obs times each day; up to 4 specular points per obs time
cygvers = new(nfiles,"string")
ctime   = new((/nfiles,86400/),"double")
prn     = new((/nfiles,86400,4/),"byte")
cyglat  = new((/nfiles,86400,4/),"float")
cyglon  = new((/nfiles,86400,4/),"float")
;Loop through CYGNSS files and read variables into arrays
do i=0,nfiles-1
   unixi = i + 1
   print( "Reading CYGNSS file "+unixi+" of "+nfiles)
   cygfilename = cygfiles(i)
   satnum  = systemfunc("echo "+cygfilename+" | awk -F'/' '{print $NF}' | awk -F'.' '{print $1}'")
   cygfile = addfile(cygfilename,"r")
   cygvers(i) = cygfile@title
   nsamples= dimsizes(cygfile->sample)
   cygtime                 := cygfile->ddm_timestamp_utc
   prn    (i,:nsamples-1,:) = cygfile->prn_code    ;PRN code
   cyglat (i,:nsamples-1,:) = cygfile->sp_lat      
   cyglon (i,:nsamples-1,:) = cygfile->sp_lon
   ctime  (i,:nsamples-1)   = cd_convert(cygtime,timeunits)  ;Convert to same time units as input
end do

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

;Convert CYGNSS longitude to -180 to 180 coodinates
cyglon = 180 - cyglon

;Since Level 1 files have 4 specular points per satellite per timestamp time,
;we need to conform cygtime to have the same rank & dimension sizes as cyglat.
ctime_conform = conform(cyglat,ctime,(/0,1/))
delete(ctime)

;Make CYNGSS time, lat, and lon arrays 1-D to make
;then easier to compare to hail reports
ctime1d  = ndtooned(ctime_conform)
cyglat1d = ndtooned(cyglat)
cyglon1d = ndtooned(cyglon)
delete([/ctime_conform,cyglat,cyglon/])

;---------------------------------------;
;LOOP THROUGH HAIL REPORT FILES AND FIND;
;CYGNSS OBSERVATIONS TO FALL WITHIN THE ;
;SPECIFIED TIME AND DISTANCE CRITERIA   ;
;---------------------------------------;
maxtimediff = maxtimediff*60 ;Convert to seconds
hailfiles = systemfunc("ls "+haildir+"*csv")
nhailfiles= dimsizes(hailfiles)
do i=0,nhailfiles-1
   unixi = i + 1
   print( "Reading hail report file "+unixi+" of "+nhailfiles)
   hailfile = hailfiles(i)
   ;Date
   yymmdd := systemfunc("sed -n 1p "+hailfile+" | awk '{print $5}'")
   yyyy   := 20+systemfunc("echo "+yymmdd+" | cut -c1-2")
   mm     := systemfunc("echo "+yymmdd+" | cut -c3-4")
   dd     := systemfunc("echo "+yymmdd+" | cut -c5-6")
   ;Time
   hh   := systemfunc("cat "+hailfile+" | sed 1,2d | awk -F',' '{print $1}' | cut -c1-2")
   minu := systemfunc("cat "+hailfile+" | sed 1,2d | awk -F',' '{print $1}' | cut -c3-4")
   ss   := 0
   ;Get date/time arrays in terms of reference time
   hailtime := cd_inv_calendar(conform(hh,toint(yyyy),-1),conform(hh,toint(mm),-1),\
               conform(hh,toint(dd),-1),toint(hh),toint(minu),conform(hh,ss,-1),timeunits,0)
   ;Since the hail files go from 12 UTC on the listed date to 1159 UTC
   ;on the next day, we need to add 86400 seconds to each element of
   ;hailtime that corresponds to hours 0-11.
   hailtime = where(hh.le.11,hailtime+86400,hailtime)
   ;Latitude,Longitude
   lat := tofloat(systemfunc("cat "+hailfile+" | sed 1,2d | awk -F',' '{print $6}'"))
   lon := tofloat(systemfunc("cat "+hailfile+" | sed 1,2d | awk -F',' '{print $7}'"))
   ;Loop through each of the reports in this file and find all CYGNSS samples within
   ;the specified time and space constraints.
   nreports = dimsizes(lat)
   do j=0,nreports-1
      unixj = j + 1
      print( "Reading hail report "+unixj+" of "+nreports+" in file "+unixi+" of "+nhailfiles)
      dt := abs(hailtime(j)-ctime1d)
      dx := gc_latlon(lat(j),lon(j),cyglat1d,cyglon1d,2,4)
      indices := ind(dt.le.maxtimediff.and.dx.le.searchradius)
      if(all(ismissing(indices)))then
         continue
      end if
      print( cyglat1d(indices))
      print( cyglon1d(indices))
      print( dx(indices))
      ;Convert time back to something readable
;      cygdattims := round(cd_calendar(time,0),3)

;      ;-----------------------------;
;      ;PLOT SPECULAR POINT LOCATIONS;
;      ;-----------------------------;
;      ;Get date/time strings for specular points 
;      yearstring := tostring(cygdattims(:,0))
;      monstring  := tostring(cygdattims(:,1))
;      daystring  := tostring(cygdattims(:,2))
;      hrstring   := tostring(cygdattims(:,3))
;      minstring  := tostring(cygdattims(:,4))
;      secstring  := tostring(cygdattims(:,5))
;      monstring  := where(cygdattims(:,1).lt.10,"0"+monstring,monstring)
;      daystring  := where(cygdattims(:,2).lt.10,"0"+daystring,daystring)
;      hrstring   := where(cygdattims(:,3).lt.10,"0"+hrstring,hrstring)
;      minstring  := where(cygdattims(:,4).lt.10,"0"+minstring,minstring)
;      secstring  := where(cygdattims(:,5).lt.10,"0"+secstring,secstring)
;      dattimstring := yearstring+monstring+daystring+"_"+hrstring+minstring+secstring
;      ndattims = dimsizes(dattimstring)
;      ;Set filename and open workstation 
;      filename = outdir+"specpoints_lat"+lat+"_lon"+lon+"_searchrad"+searchradius+"km_"+dattimstring(0)+"-"+dattimstring(ndattims-1)
;      wks = gsn_open_wks("png",filename)
;      ;Determine minimum and maximum extent of plot area (approximate 111 km per degree lat/lon)
;      centerlatrad = lat*(2*3.141592/360.)
;      range_lat = searchradius/111.
;      range_lon = searchradius/(110.567*cos(centerlatrad))
;      scale     = range_lon/range_lat
;      degextent = searchradius/111.
;      minlat = lat-range_lat 
;      maxlat = lat+range_lat
;      minlon = lon-range_lon
;      maxlon = lon+range_lon
;      res = True
;      res@gsnDraw = False
;      res@gsnFrame = False
;      res@mpDataBaseVersion           = "MediumRes"
;      res@mpDataSetName               = "Earth..4"
;      res@mpGeophysicalLineColor      = "black"
;      res@mpGeophysicalLineThicknessF = 5.0
;      res@mpProvincialLineThicknessF = 5.0
;      res@mpCountyLineThicknessF = 2.5
;      res@mpCountyLineColor = res@mpGeophysicalLineColor
;      res@mpOutlineBoundarySets       = "GeophysicalAndUSStates"
;      res@mpOutlineOn                 = True
;      res@mpUSStateLineColor          = res@mpGeophysicalLineColor
;      res@mpOutlineSpecifiers = (/"United States : Counties"/)
;      res@mpGridAndLimbDrawOrder = "Postdraw"
;      res@mpLabelsOn             = False
;      res@mpPerimOn              = True
;      res@mpFillOn               = False
;      res@mpOutlineOn            = True
;      res@mpOutlineDrawOrder     = "Draw"
;      res@mpFillDrawOrder        = "PreDraw"
;      res@gsnLeftString = monstring(0)+"/"+daystring(0)+"/"+yearstring(0)+" "\
;                          +hrstring(0)+":"+minstring(0)+" - "\
;                          +monstring(ndattims-1)+"/"+daystring(ndattims-1)+"/"\
;                          +yearstring(ndattims-1)+" "+hrstring(ndattims-1)\
;                          +":"+minstring(ndattims-1)+" UTC"
;      res@gsnRightString = satnum
;      res@gsnLeftStringFontHeightF = 0.015
;      res@gsnRightStringFontHeightF = 0.015
;      res@gsnLeftStringOrthogonalPosF = 0.005;-0.0001
;      res@gsnRightStringOrthogonalPosF = 0.005;-0.0001
;      res@mpLimitMode            = "LatLon"
;      res@mpMinLatF = minlat
;      res@mpMaxLatF = maxlat
;      res@mpMinLonF = minlon
;      res@mpMaxLonF = maxlon
;      res@tmXTOn = False
;      res@tmYROn = False
;      res@gsnMaximize = True
;      map = gsn_csm_map(wks,res)
;      ;Add range ring
;      ringres = True
;      ringres@Scale = scale
;      ringres@gsLineThicknessF = 10.
;      circle_ll(wks,map,lon,lat,range_lat,ringres)
;      ;Add dots representing CYGNSS observations
;      dotres = True
;      dotres@tfPolyDrawOrder = "PreDraw"
;      dotres@gsMarkerIndex = 1
;      dotres@gsMarkerThicknessF = 10.
;      dotres@gsMarkerColor = "red"
;      gsn_polymarker(wks,map,lons,lats,dotres)
;      draw(map)
;      frame(wks)
   end do   ;Individual hail report loop
end do   ;Hail report file loop
