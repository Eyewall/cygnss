load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "/jm13/pduran/ncl/functions/tools.ncl"

;---------------------------------------------
; process_cygnss.ncl 
; Patrick Duran
; 10 July 2018
; 
; Reads a file containing best-track information
; and interpolates each storm in the file to
; 1-second time intervals.
; Then finds the CYGNSS file that corresponds to
; each time in the best-track file and finds
; all CYGNSS Level 2 wind speed observations 
; within a user-defined radius of the storm center.
;---------------------------------------------

interpolate = 0   ;0=Do not interpolate best track; 1=Interpolate best track
dt          = 18000  ;Time spacing to interpolate best track to (seconds)
datalevel   = 2
trakfile    = "/jm13/pduran/best-tracks/hurdat2-2017.txt"
cygdir      = "/jm13/pduran/cygnss/2017/level"+datalevel+"/"
cygtimefile = "/jm13/pduran/cygnss/2017/level"+datalevel+"/cygtimes.txt"
stormdir    = "/jm13/pduran/cygnss/2017/stormfiles/"
searchradius= 300  ;Units km
ignoreblockIIF = True ;Ignore Block IIF GPS vehicles?

;--------------------------------------;
;GET LIST OF AVAILABLE CYGNSS FILES AND;
;THE TIMES OF THE OBSERVATIONS, AND    ;
;PRINT TO OUTPUT FILE.                 ;
;THIS ONLY NEEDS TO BE DONE ONCE FOR   ;
;EVERY CYGNSS DIRECTORY.               ;
;--------------------------------------;
;timeunits= "seconds since 2016-1-1 00:00:00"
;cygfilelist = systemfunc("ls "+cygdir+"*nc")
;ncygfiles = dimsizes(cygfilelist)
;mintimes = new(ncygfiles,"integer")
;maxtimes = new(ncygfiles,"integer")
;do i=0,ncygfiles-1
;   unixi = i + 1
;   print( "Processing CYGNSS file "+unixi+" of "+ncygfiles)
;   cygfile   = addfile(cygfilelist(i),"r")
;   if(datalevel.eq.1)then
;      cygtimes := cygfile->ddm_timestamp_utc
;   else if(datalevel.eq.2)then
;      cygtimes := cygfile->sample_time
;   end if
;   end if
;   ;Convert observation times of each file to a common unit
;   cygtimes_convert := round(cd_convert(cygtimes,timeunits),3)
;   mintimes(i) = min(cygtimes_convert)
;   maxtimes(i) = max(cygtimes_convert)
;end do
;;Write to output file
;header = [/"Time units: '"+timeunits+"'"/]
;header2  = [/"                                            FILENAME                                            MIN TIME  MAX TIME"/]
;outlist = [/cygfilelist,mintimes,maxtimes/]
;write_table(cygtimefile,"w",header,"%s")
;write_table(cygtimefile,"a",header2,"%s")
;write_table(cygtimefile,"a",outlist,"%s%09i%09i")
;print( "Output written to "+cygtimefile)
;
;;------------------------------------------------;
;;GET CYGNSS FILE NAME AND OBSERVATION BLOCK TIMES;
;;------------------------------------------------;
timeunits    = systemfunc("sed -n 1p "+cygtimefile+" | awk -F\' '{print $2}'")
cygfilenames = systemfunc("cat "+cygtimefile+" | sed '1,2d' | awk '{print $1}'")
cygmintimes  = toint(systemfunc("cat "+cygtimefile+" | sed '1,2d' | awk '{print $2}'"))
cygmaxtimes  = toint(systemfunc("cat "+cygtimefile+" | sed '1,2d' | awk '{print $3}'"))

;--------------------------;
;GET BEST TRACK INFORMATION;
;--------------------------;
;Get list of all storms in the file by finding all
;lines with only three columns. Then get number of
;storms in the file, storm IDs, and storm names.
system("awk 'NF==3{print}{}' "+trakfile+" > stormlist.tmp")
nstorms    = toint(systemfunc("wc stormlist.tmp | awk '{print $1}'"))
stormids   = systemfunc("awk '{print $1}' stormlist.tmp | sed 's/,//g'")
stormnames = systemfunc("awk '{print $2}' stormlist.tmp | sed 's/,//g'")

;Loop through all storms
do i=0,nstorms-1
   stormid   = stormids(i)
   stormname = stormnames(i)
   ;Get lines for the current storm by printing all lines between
   ;the current storm ID line and the next storm ID line.
   if(i.ne.(nstorms-1))then
      system("awk '/"+stormid+"/{flag=1;next}/"+stormids(i+1)+"/{flag=0}flag' "+trakfile+" > currentstorm.tmp")
   else
      system("sed -n '/"+stormid+"/,$p' "+trakfile+" | sed '/"+stormid+"/d' > currentstorm.tmp")
   end if
   ;Read best-track data for the current storm using comma delimeters
   yyyy    := toint(systemfunc("awk -F',' '{print $1}' currentstorm.tmp | cut -c 1-4"))
   mm      := toint(systemfunc("awk -F',' '{print $1}' currentstorm.tmp | cut -c 5-6"))
   dd      := toint(systemfunc("awk -F',' '{print $1}' currentstorm.tmp | cut -c 7-8"))
   hour    := toint(systemfunc("awk -F',' '{print $2}' currentstorm.tmp | sed 's/ //g' | cut -c 1-2"))
   minu    := toint(systemfunc("awk -F',' '{print $2}' currentstorm.tmp | sed 's/ //g' | cut -c 3-4"))
   landfall:= systemfunc("awk -F',' '{print $3}' currentstorm.tmp")
   stmtyp  := systemfunc("awk -F',' '{print $4}' currentstorm.tmp")
   lat     := tofloat(systemfunc("awk -F ',' '{print $5}' currentstorm.tmp"))
   lon     := tofloat(systemfunc("awk -F ',' '{print $6}' currentstorm.tmp"))
   ;Determine whether north or south latitude; east or west longitude
   norslat := systemfunc("awk '{print substr($5,5,5)}' currentstorm.tmp | sed 's/,//g'")
   eorwlon := systemfunc("awk '{print substr($6,5,5)}' currentstorm.tmp | sed 's/,//g'")
   ;Multiply any south latitudes or west longitudes by -1
   lat := where(norslat.eq."S",lat*-1,lat)
   lon := where(eorwlon.eq."W",lon*-1,lon)
   ;Get intensity estimates
   vmax    := toshort(systemfunc("awk -F ',' '{print $7}' currentstorm.tmp"))
   pmin    := toshort(systemfunc("awk -F ',' '{print $8}' currentstorm.tmp"))
   ;Get wind radii
   r34ne   := toshort(systemfunc("awk -F ',' '{print $9}' currentstorm.tmp"))
   r34se   := toshort(systemfunc("awk -F ',' '{print $10}' currentstorm.tmp"))
   r34sw   := toshort(systemfunc("awk -F ',' '{print $11}' currentstorm.tmp"))
   r34nw   := toshort(systemfunc("awk -F ',' '{print $12}' currentstorm.tmp"))
   r50ne   := toshort(systemfunc("awk -F ',' '{print $13}' currentstorm.tmp"))
   r50se   := toshort(systemfunc("awk -F ',' '{print $14}' currentstorm.tmp"))
   r50sw   := toshort(systemfunc("awk -F ',' '{print $15}' currentstorm.tmp"))
   r50nw   := toshort(systemfunc("awk -F ',' '{print $16}' currentstorm.tmp"))
   r64ne   := toshort(systemfunc("awk -F ',' '{print $17}' currentstorm.tmp"))
   r64se   := toshort(systemfunc("awk -F ',' '{print $18}' currentstorm.tmp"))
   r64sw   := toshort(systemfunc("awk -F ',' '{print $19}' currentstorm.tmp"))
   r64nw   := toshort(systemfunc("awk -F ',' '{print $20}' currentstorm.tmp"))

   ;-----------------------------;
   ;CONVERT DATES/TIMES FROM BEST; 
   ;TRACK TO A REFERENCE TIME    ;
   ;-----------------------------;
   trakcygtime := cd_inv_calendar(yyyy,mm,dd,hour,minu,conform(yyyy,0,-1),timeunits,0)
   trakcygtime := round(trakcygtime,3)
   trakcygtime@long_name = "Time of the best-track entry"
   trakcygtime@_FillValue = default_fillvalue("integer")
   trakcygtime!0 = "tracktime"

   ;-----------------------------------------;
   ;If selected, interpolate best-track times;
   ;-----------------------------------------;
   if(interpolate.eq.1)then      
      trakcygtimeint := ispan(trakcygtime(0),trakcygtime(dimsizes(trakcygtime)-1),dt)
      copy_VarAtts(trakcygtime,trakcygtimeint)
      trakcygtimeint!0 = "tracktime"
      latint   := linint1(trakcygtime,lat,False,trakcygtimeint,0)
      lonint   := linint1(trakcygtime,lon,False,trakcygtimeint,0)
      vmaxint  := toshort(linint1(trakcygtime,vmax,False,trakcygtimeint,0))
      pminint  := toshort(linint1(trakcygtime,pmin,False,trakcygtimeint,0))
      r34neint := toshort(linint1(trakcygtime,r34ne,False,trakcygtimeint,0))
      r34seint := toshort(linint1(trakcygtime,r34se,False,trakcygtimeint,0))
      r34swint := toshort(linint1(trakcygtime,r34sw,False,trakcygtimeint,0))
      r34nwint := toshort(linint1(trakcygtime,r34nw,False,trakcygtimeint,0))
      r50neint := toshort(linint1(trakcygtime,r50ne,False,trakcygtimeint,0))
      r50seint := toshort(linint1(trakcygtime,r50se,False,trakcygtimeint,0))
      r50swint := toshort(linint1(trakcygtime,r50sw,False,trakcygtimeint,0))
      r50nwint := toshort(linint1(trakcygtime,r50nw,False,trakcygtimeint,0))
      r64neint := toshort(linint1(trakcygtime,r64ne,False,trakcygtimeint,0))
      r64seint := toshort(linint1(trakcygtime,r64se,False,trakcygtimeint,0))
      r64swint := toshort(linint1(trakcygtime,r64sw,False,trakcygtimeint,0))
      r64nwint := toshort(linint1(trakcygtime,r64nw,False,trakcygtimeint,0))
   end if

   ;-----------------------------------------;
   ;LOOP THROUGH ALL BEST-TRACK TIMES FOR THE;
   ;CURRENT STORM AND FIND CYGNSS FILE THAT  ;
   ;CORRESPONDS TO EACH TIME.                ;
   ;THEN READ THE FILE AND FIND ANY SPECULAR ;
   ;POINTS THAT FALL WITHIN THE SPECIFIED    ;
   ;RADIUS AND PLOT THEM.                    ;
   ;-----------------------------------------;
   ;Initialize arrays for this storm
   if(interpolate.eq.0)then
      ntimes := dimsizes(trakcygtime)
   else
      ntimes := dimsizes(trakcygtimeint)
   end if
   time  := new((/ntimes,10000/),"integer")           ;ntimes here is # of times in best-track
   v     := new((/ntimes,10000/),"float")  ;file for this storm.
   lats  := v
   lons  := v
   timecount = 0 ;Count the number of best-track times for which the are CYGNSS obs
   do j=0,ntimes-1
      unixj = j + 1
      print( "Finding CYGNSS retrievals for entry "+unixj+" of "+ntimes+" for "+stormnames(i)+"   "+systemfunc("date"))
      ;Find the CYGNSS file that contains observations at
      ;the time of this best-track entry. This file can
      ;be identified by finding the file for which the
      ;maximum time minus the best-track time is positive
      ;and the minimum time minus the b-t time is negative.
      if(interpolate.eq.0)then
         traktime = trakcygtime(j)
      else
         traktime = trakcygtimeint(j)
      end if
      timediffsmin := cygmintimes - traktime
      timediffsmax := cygmaxtimes - traktime
      cygfileind = ind(timediffsmax.ge.0.and.timediffsmin.le.0)
      ;If there is a CYGNSS outage, there might not be data
      ;at the best-track time. Check for this:
      if(ismissing(cygfileind))then
         yyyymmddhh = tostring(yyyy)+tostring(mm)+tostring(dd)+tostring(hour)
         print( "No CYGNSS observations available at "+yyyymmddhh)
         continue
      end if
      cygfilename = cygfilenames(cygfileind)
      ;Read variables from CYGNSS file
      cygfile = addfile(cygfilename,"r")
      cygvers = cygfile@title
      prn    := cygfile->prn_code    ;PRN code
      cygtime:= cygfile->sample_time ;Mean time of DDMs used to derive wind speed
      cyglat := cygfile->lat         ;Mean of spec point lats used to derive wind
      cyglon := cygfile->lon         ;Mean of spec point lons used to derive wind
      wind_speed_yslf_nbrcs := cygfile->yslf_nbrcs_wind_speed ;Units m/s
      yslf_nbrcs_uncertainty:= cygfile->yslf_nbrcs_wind_speed_uncertainty ;Units m/s
      if(ignoreblockIIF)then  ;Ignore retrievals that use BlockIIF satellites
         print( "Ignoring retrievals computed using Block IIF satellites.")
         toignore = (/1,3,6,8,9,10,24,25,26,27,30,32/) ;PRN codes for BlockIIF sats
         do k=0,dimsizes(toignore)-1
            cyglat = where(prn.eq.toignore(k),cyglat@_FillValue,cyglat)   
            cyglon = where(prn.eq.toignore(k),cyglon@_FillValue,cyglon)   
            wind_speed_yslf_nbrcs = where(prn.eq.toignore(k),wind_speed_yslf_nbrcs@_FillValue,wind_speed_yslf_nbrcs)   
            yslf_nbrcs_uncertainty = where(prn.eq.toignore(k),yslf_nbrcs_uncertainty@_FillValue,yslf_nbrcs_uncertainty)   
         end do
      end if
      ;Compute distances between storm center and all retrieval locations
      if(interpolate.eq.0)then
         dist := gc_latlon(lat(j),lon(j),cyglat,cyglon,2,4)
      else
         dist := gc_latlon(latint(j),lonint(j),cyglat,cyglon,2,4)
      end if
      ;Get indices for retrievals where distance is within search radius
      indices := ind(dist.lt.searchradius)
      ;If there aren't any for this best-track entry, skip to end of loop
      if(all(ismissing(indices)))then
         continue
      end if
      timecount = timecount + 1 ;We have obs for this time!
      ;Get time, wind speeds, lats, lons
      ninds = dimsizes(indices)
      time(j,:ninds-1) = round(cd_convert(cygtime(indices),timeunits),3)
      v   (j,:ninds-1) = wind_speed_yslf_nbrcs(indices) 
      lats(j,:ninds-1) = cyglat(indices)
      lons(j,:ninds-1) = cyglon(indices)
   end do

   time!0 = "tracktime"
   time!1 = "cygtime"
   time&tracktime = trakcygtime
   time&cygtime = time(0,:)
   copy_VarCoords(time,v)
   copy_VarCoords(time,lats)
   copy_VarCoords(time,lons)

   time@long_name = "Time of CYGNSS retrieval"
      
   if(interpolate.eq.1)then
      lat   := latint
      lon   := lonint
      vmax  := vmaxint
      pmin  := pminint
      r34ne := r34neint 
      r34se := r34seint 
      r34sw := r34swint 
      r34nw := r34nwint 
      r50ne := r50neint 
      r50se := r50seint 
      r50sw := r50swint 
      r50nw := r50nwint 
      r64ne := r64neint 
      r64se := r64seint 
      r64sw := r64swint 
      r64nw := r64nwint 
   end if

   ;--------------------------------;
   ;DEFINE ATTRIBUTES FOR STORM DATA;
   ;--------------------------------;
   trakcygtime@units = timeunits
   time@units = timeunits
   lat@long_name = "Latitude of storm center"
   lat@units  = "degrees_north"
   lon@long_name = "Longitude of storm center"
   lon@units  = "degres_east"
   vmax@long_name = "Maximum 10-m wind speed within storm"
   vmax@units = "kt"
   pmin@long_name = "Minimum sea-level pressure within storm"
   pmin@units = "hPa"
   r34ne@long_name = "Maximum radius of 34-kt winds in NE quadrant"
   r34ne@units = "nautical miles"
   r34se@long_name = "Maximum radius of 34-kt winds in SE quadrant"
   r34se@units = "nautical miles"
   r34sw@long_name = "Maximum radius of 34-kt winds in SW quadrant"
   r34sw@units = "nautical miles"
   r34nw@long_name = "Maximum radius of 34-kt winds in NW quadrant"
   r34nw@units = "nautical miles"
   r50ne@long_name = "Maximum radius of 50-kt winds in NE quadrant"
   r50ne@units = "nautical miles"
   r50se@long_name = "Maximum radius of 50-kt winds in SE quadrant"
   r50se@units = "nautical miles"
   r50sw@long_name = "Maximum radius of 50-kt winds in SW quadrant"
   r50sw@units = "nautical miles"
   r50nw@long_name = "Maximum radius of 50-kt winds in NW quadrant"
   r50nw@units = "nautical miles"
   r64ne@long_name = "Maximum radius of 64-kt winds in NE quadrant"
   r64ne@units = "nautical miles"
   r64se@long_name = "Maximum radius of 64-kt winds in SE quadrant"
   r64se@units = "nautical miles"
   r64sw@long_name = "Maximum radius of 64-kt winds in SW quadrant"
   r64sw@units = "nautical miles"
   r64nw@long_name = "Maximum radius of 64-kt winds in NW quadrant"
   r64nw@units = "nautical miles"

   ;--------------------------------------------------;
   ;WRITE NETCDF FILE FOR THIS STORM AND SEARCH RADIUS;
   ;--------------------------------------------------;
   if(timecount.eq.0)   ;If there aren't any CYGNSS obs for this storm,
      continue          ;skip writing output file.
   end if
   if(interpolate.eq.0)then
      ncoutfile = stormdir+stormnames(i)+"-searchrad"+searchradius+"km.nc"
   else
      ncoutfile = stormdir+stormnames(i)+"-searchrad"+searchradius+"km-1minute.nc"
   end if 
   system("rm "+ncoutfile)
   fout = addfile(ncoutfile,"c")
   print( "Writing output file for "+stormnames(i)+" to "+ncoutfile)
   ;Define global attributes
   fileatts = True
   fileatts@CYGNSSversion= cygvers
   fileatts@searchradius = searchradius+" km"
   fileatts@trackfile = trakfile
   fileatts@ignoreBlockIIF = ignoreblockIIF
   if(interpolate.eq.1)then
      fileatts@comment = "HURDAT track interpolated to "+dt+"-s intervals."
   end if
   fileattdef(fout,fileatts)
   ;Write CYGNSS output
   dimNames := (/"tracktime","cygtime"/)
   dimSizes := (/ntimes,10000/)
   dimUnlim := (/False,False/)
   filedimdef(fout,dimNames,dimSizes,dimUnlim)
   var_names := (/"v","lat","lon"/)
   var_types := (/"float","float","float"/)
   if(interpolate.eq.0)then   
      filevardef(fout,"tracktime",typeof(trakcygtime),getvardims(trakcygtime))
   else
      filevardef(fout,"tracktime",typeof(trakcygtimeint),getvardims(trakcygtimeint))
   end if
   filevardef(fout,"cygtime",typeof(time),getvardims(time))
   filevardef(fout,var_names,var_types,dimNames)
   if(interpolate.eq.0)then
      filevarattdef(fout,"tracktime",trakcygtime)
   else  
      filevarattdef(fout,"tracktime",trakcygtimeint)
   end if
   filevarattdef(fout,"cygtime",time)
   filevarattdef(fout,"v",v)
   filevarattdef(fout,"lat",lats)
   filevarattdef(fout,"lon",lons)
   if(interpolate.eq.0)then
      fout->tracktime = (/trakcygtime/)
   else
      fout->tracktime = (/trakcygtimeint/)
   end if
   fout->cygtime   = (/time/)
   fout->v         = (/v/)
   fout->lat       = (/lats/)
   fout->lon       = (/lons/)
   ;Write best track output
   dimNames  := "tracktime"
   var_names := (/"stormlat","stormlon","vmax","pmin",\
                 "r34ne","r34se","r34sw","r34nw",\
                 "r50ne","r50se","r50sw","r50nw",\
                 "r64ne","r64se","r64sw","r64nw"/)
   var_types := (/"float","float","short","short",\
                 "short","short","short","short",\
                 "short","short","short","short",\
                 "short","short","short","short"/)
   filevardef(fout,var_names,var_types,dimNames)
   filevarattdef(fout,"stormlat",lat)
   filevarattdef(fout,"stormlon",lon)
   filevarattdef(fout,"vmax",vmax)
   filevarattdef(fout,"pmin",pmin)
   filevarattdef(fout,"r34ne",r34ne)
   filevarattdef(fout,"r34se",r34se)
   filevarattdef(fout,"r34sw",r34sw)
   filevarattdef(fout,"r34nw",r34nw)
   filevarattdef(fout,"r50ne",r50ne)
   filevarattdef(fout,"r50se",r50se)
   filevarattdef(fout,"r50sw",r50sw)
   filevarattdef(fout,"r50nw",r50nw)
   filevarattdef(fout,"r64ne",r64ne)
   filevarattdef(fout,"r64se",r64se)
   filevarattdef(fout,"r64sw",r64sw)
   filevarattdef(fout,"r64nw",r64nw)
   fout->stormlat  = (/lat/)
   fout->stormlon  = (/lon/) 
   fout->vmax      = (/vmax/)
   fout->pmin      = (/pmin/)
   fout->r34ne     = (/r34ne/)
   fout->r34se     = (/r34se/)
   fout->r34sw     = (/r34sw/)
   fout->r34nw     = (/r34nw/)
   fout->r50ne     = (/r50ne/)
   fout->r50se     = (/r50se/)
   fout->r50sw     = (/r50sw/)
   fout->r50nw     = (/r50nw/)
   fout->r64ne     = (/r64ne/)
   fout->r64se     = (/r64se/)
   fout->r64sw     = (/r64sw/)
   fout->r64nw     = (/r64nw/)
end do
