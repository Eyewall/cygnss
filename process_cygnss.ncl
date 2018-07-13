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

trakfile    = "/jm13/pduran/best-tracks/hurdat2-2017.txt"
cygdir      = "/jm13/pduran/cygnss/2017/"
cygtimefile = "/jm13/pduran/cygnss/2017/cygtimes.txt"
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
;   cygtimes := cygfile->sample_time
;   ;Convert observation times of each file to a common unit
;   cygtimes_convert := round(cd_convert(cygtimes,timeunits),3)
;   mintimes(i) = min(cygtimes_convert)
;   maxtimes(i) = max(cygtimes_convert)
;end do
;Write to output file
;header = [/"Time units: '"+timeunits+"'"/]
;header2  = [/"                                            FILENAME                                            MIN TIME  MAX TIME"/]
;outlist = [/cygfilelist,mintimes,maxtimes/]
;write_table(cygtimefile,"w",header,"%s")
;write_table(cygtimefile,"a",header2,"%s")
;write_table(cygtimefile,"a",outlist,"%s%09i%09i")
;print( "Output written to "+cygtimefile)
;exit

;------------------------------------------------;
;GET CYGNSS FILE NAME AND OBSERVATION BLOCK TIMES;
;------------------------------------------------;
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
print( stormnames)

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
   vmax    := tofloat(systemfunc("awk -F ',' '{print $7}' currentstorm.tmp"))
   pmin    := tofloat(systemfunc("awk -F ',' '{print $8}' currentstorm.tmp"))
   ;Get wind radii
   r34ne   := tofloat(systemfunc("awk -F ',' '{print $9}' currentstorm.tmp"))
   r34se   := tofloat(systemfunc("awk -F ',' '{print $10}' currentstorm.tmp"))
   r34sw   := tofloat(systemfunc("awk -F ',' '{print $11}' currentstorm.tmp"))
   r34nw   := tofloat(systemfunc("awk -F ',' '{print $12}' currentstorm.tmp"))
   r50ne   := tofloat(systemfunc("awk -F ',' '{print $13}' currentstorm.tmp"))
   r50se   := tofloat(systemfunc("awk -F ',' '{print $14}' currentstorm.tmp"))
   r50sw   := tofloat(systemfunc("awk -F ',' '{print $15}' currentstorm.tmp"))
   r50nw   := tofloat(systemfunc("awk -F ',' '{print $16}' currentstorm.tmp"))
   r64ne   := tofloat(systemfunc("awk -F ',' '{print $17}' currentstorm.tmp"))
   r64se   := tofloat(systemfunc("awk -F ',' '{print $18}' currentstorm.tmp"))
   r64sw   := tofloat(systemfunc("awk -F ',' '{print $19}' currentstorm.tmp"))
   r64nw   := tofloat(systemfunc("awk -F ',' '{print $20}' currentstorm.tmp"))

   ;-----------------------------;
   ;CONVERT DATES/TIMES FROM BEST; 
   ;TRACK TO A REFERENCE TIME    ;
   ;-----------------------------;
   trakcygtime := cd_inv_calendar(yyyy,mm,dd,hour,minu,conform(yyyy,0,-1),timeunits,0)
   trakcygtime@long_name = "Time of the best-track entry"
   trakcygtime!0 = "tracktime"
   ;-----------------------------------------;
   ;LOOP THROUGH ALL BEST-TRACK TIMES FOR THE;
   ;CURRENT STORM AND FIND CYGNSS FILE THAT  ;
   ;CORRESPONDS TO EACH TIME.                ;
   ;THEN READ THE FILE AND FIND ANY SPECULAR ;
   ;POINTS THAT FALL WITHIN THE SPECIFIED    ;
   ;RADIUS AND PLOT THEM.                    ;
   ;-----------------------------------------;
   ;Initialize arrays for this storm
   ntimes = dimsizes(trakcygtime)
   time  := new(10000,"double")            ;ntimes here is # of times in best-track
   v     := new((/ntimes,10000/),"float")  ;file for this strom.
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
      traktime  = trakcygtime(j)
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
      dist := gc_latlon(lat(j),lon(j),cyglat,cyglon,2,4)
      ;Get indices for retrievals where distance is within search radius
      indices := ind(dist.lt.searchradius)
      ;If there aren't any for this best-track entry, skip to end of loop
      if(all(ismissing(indices)))then
         continue
      end if
      timecount = timecount + 1 ;We have obs for this time!
      ;Get time, wind speeds, lats, lons
      ninds = dimsizes(indices)
      time(:ninds-1) = cd_convert(cygtime(indices),timeunits)
      v   (j,:ninds-1) = wind_speed_yslf_nbrcs(indices) 
      lats(j,:ninds-1) = cyglat(indices)
      lons(j,:ninds-1) = cyglon(indices)

      time@long_name = "Time of CYGNSS retrieval"
   end do
   ;--------------------------------------------------;
   ;WRITE NETCDF FILE FOR THIS STORM AND SEARCH RADIUS;
   ;--------------------------------------------------;
   if(timecount.eq.0)   ;If there aren't any CYGNSS obs for this storm,
      continue          ;skip writing output file.
   end if
   ncoutfile = stormdir+stormnames(i)+"-searchrad"+searchradius+"km.nc"
   system("rm "+ncoutfile)
   fout = addfile(ncoutfile,"c")
   print( "Writing output file for "+stormnames(i)+" to "+ncoutfile)
   ;Define coordinate variables
   time!0 = "cygtime"
   v!0    = "track time"
   v!1    = "CYGNSS obs time"
   ;Define global attributes
   fileatts = True
   fileatts@CYGNSSversion= cygvers
   fileatts@searchradius = searchradius+" km"
   fileatts@trackfile = trakfile
   fileatts@ignoreBlockIIF = ignoreblockIIF
   fileattdef(fout,fileatts)
   ;Define variable attributes
   dimNames = (/"tracktime","cygtime"/)
   dimSizes = (/ntimes,10000/)
   dimUnlim = (/False,False/)
   var_names = (/"v","lat","lon"/)
   var_types = (/"float","float","float"/)
   filedimdef(fout,dimNames,dimSizes,dimUnlim)
   filevardef(fout,"tracktime",typeof(trakcygtime),getvardims(trakcygtime))
   filevardef(fout,"cygtime",typeof(time),getvardims(time))
   filevardef(fout,var_names,var_types,dimNames)
   filevarattdef(fout,"tracktime",trakcygtime)
   filevarattdef(fout,"cygtime",time)
   filevarattdef(fout,"v",v)
   filevarattdef(fout,"lat",lats)
   filevarattdef(fout,"lon",lons)
   ;Write variables to netCDF file
   fout->tracktime = (/traktime/)
   fout->cygtime   = (/time/)
   fout->v         = (/v/)
   fout->lat       = (/lats/)
   fout->lon       = (/lons/)
end do
