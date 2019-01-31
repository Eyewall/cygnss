undef("filter_cygnss")
function filter_cygnss(YYYY,MM,DD,HH,mm,ss,eyediam,rmw,r34,r50,r64,radius,lat,lon,\
                       dt,searchtype,uncert_limit,wind_rad_compare_limit)
begin

print( "Searching for CYGNSS data...")

;Get list of CYGNSS files and the times contained within each of them
cygdir = "/raid1/pduran/jm13/cygnss/"+YYYY+"/level2/"
info = readAsciiTable(cygdir+"cygtimes.txt",1,"string",2)
infosplit = str_split_csv(info(:,0)," ",0)
filenames = infosplit(:,0)
mintimes     = toint(infosplit(:,1))
maxtimes     = toint(infosplit(:,2))

;Convert selected time to units of cygtime
timeunits = systemfunc("sed -n 1p "+cygdir+"cygtimes.txt | awk -F\' '{print $2}'")
bttime = toint(cd_inv_calendar(toint(YYYY),toint(MM),toint(DD),toint(HH),toint(mm),toint(ss),timeunits,0))

;Get CYGNSS file names that corresponds to the best-track time.
if(searchtype.eq."centered")then
   mintime = bttime - dt
   maxtime = bttime + dt
elseif(searchtype.eq."forward")then
   mintime = bttime
   maxtime = bttime + dt
elseif(searchtype.eq."backward")then
   mintime = bttime - dt
   maxtime = bttime
end if

;Find the index of the file that contains data at the beginning of the search period
mintimediff = mintimes - mintime
maxtimediff = maxtimes - mintime
begselectioninds = min(ind(mintimediff.le.0.and.maxtimediff.ge.0))

;Find the index of the file that contains data at the end of the search period
mintimediff = mintimes - maxtime
maxtimediff = maxtimes - maxtime
endselectioninds = max(ind(mintimediff.le.0.and.maxtimediff.ge.0))

if(all(ismissing(begselectioninds)).and.all(ismissing(endselectioninds)))then
   print( "   No CYGNSS observations available at "+YYYY+MM+DD+HH+mm+ss)
   return(0)
elseif(all(ismissing(begselectioninds)).and..not.all(ismissing(endselectioninds)))then
   selectioninds = max(endselectioninds)
elseif(.not.all(ismissing(begselectioninds)).and.all(ismissing(endselectioninds)))then
   selectioninds = min(begselectioninds)
else
   selectioninds = ispan(begselectioninds,endselectioninds,1)
end if

;Get CYGNSS filenames
cygfiles = filenames(selectioninds)

;Loop through all files and read in data
ncygfiles = dimsizes(cygfiles)
do i=0,ncygfiles-1
   infile = cygfiles(i)
   ncinfile = addfile(infile,"r")
   ;Get time, lats, and lons of CYGNSS observations and wind speeds
   cygtimein := ncinfile->sample_time
   latsin    := ncinfile->lat
   lonsin    := ncinfile->lon
   vin       := ncinfile->yslf_nbrcs_wind_speed
   flags     := ncinfile->yslf_sample_flags
   uncertin  := ncinfile->yslf_nbrcs_wind_speed_uncertainty
;   rcg       := ncinfile->range_corr_gain
;   vin       := ncinfile->wind_speed
;   flags     := ncinfile->fds_sample_flags
;   uncertin  := ncinfile->wind_speed_uncertainty

   ;Convert flags array from short to binary and reverse the resulting
   ;bitmask array so we can compare it to YSLF status flags in metadata.
   bitmask := getbitsone(flags)
   bitmaskrev := bitmask(:,::-1)

   ;If the 0th bit (1) is flipped, then there is a fatal error condition.
   ;If the 8th bit (256) is flipped, then there is a fatal high wind speed error.
   ;If the 13th bit (8192) is flipped, then there is a low range-corrected gain.
   ;If the 15th bit (32768) is flipped, then there is non-fatal low-quality GPS
   ;antenna knowledge (usually Block IIf satellites.)
   ;We will only deal with values where these bits are not flipped.
   errorinds := ind(bitmaskrev(:,0).eq.1.or.bitmask(:,8).eq.1\
                    .or.bitmask(:,13).eq.1.or.bitmask(:,14).eq.1)
   latsin(errorinds) = latsin@_FillValue
   lonsin(errorinds) = lonsin@_FillValue
   vin(errorinds)    = vin@_FillValue

   ;If range-corrected gain is less than 20, set winds to missing
;   rcginds := ind(rcg.lt.20)
;   latsin(rcginds) = latsin@_FillValue
;   lonsin(rcginds) = lonsin@_FillValue
;   vin   (rcginds) = vin@_FillValue

   if(i.eq.0)then
      cygtime = round(cd_convert(cygtimein,timeunits),3)
      lats    = latsin
      lons    = lonsin
      v       = vin
      uncert  = uncertin
   else
      ;Append the arrays from the new file to arrays from the previous file
      cygtimea:= array_append_record(cygtime,round(cd_convert(cygtimein,timeunits),3),0)
      latsa   := array_append_record(lats,latsin,0)
      lonsa   := array_append_record(lons,lonsin,0)
      va      := array_append_record(v,vin,0)
      uncerta := array_append_record(uncert,uncertin,0)
      ;Reset arrays to the new, concatenated arrays.
      cygtime := cygtimea
      lats    := latsa
      lons    := lonsa
      v       := va
      uncert  := uncerta
   end if

   ;Find distance between storm center and each CYGNSS retrieval
   dist := gc_latlon(lat,lon,lats,lons,2,4)

   ;Get only CYGNSS wind speed retrievals within time interval and search radius
   selectioninds := ind(cygtime.ge.mintime.and.cygtime.le.maxtime.and.dist.le.radius)
   selectioninds_filtered := ind(cygtime.ge.mintime.and.cygtime.le.maxtime.and.dist.le.radius.and.uncert.lt.uncert_limit)

   ;Convert longitude from 0-360 to -180-180
   lons = mod((lons+180),360) - 180
   lons@valid_range := "(-180, 180)"

   ;If no obs available, return a scalar. Otherwise, return list of arrays.
   if(all(ismissing(selectioninds)))then
      print( "      No CYGNSS data found that fit all constraints :(")
      return(0)
   else
      v_out         = v(selectioninds)
      uncertainties = uncert(selectioninds)
      latsout       = lats(selectioninds)
      lonsout       = lons(selectioninds)
      print( "      Found "+dimsizes(v_out)+" CYGNSS wind observations that fit all constraints :)")
   end if
   if(.not.all(ismissing(selectioninds_filtered)))then
      v_filtered    = v(selectioninds_filtered)
      lats_filtered = lats(selectioninds_filtered)
      lons_filtered = lons(selectioninds_filtered)
      cygtime_filtered = cygtime(selectioninds_filtered)
      print( "      "+dimsizes(v_filtered)+" CYGNSS wind observations remain after filtering.")
      return [/v_out,cygtime,v_filtered,uncertainties,latsout,lonsout,lats_filtered,lons_filtered,cygtime_filtered/]
   else
      return(0)
   end if
end do
end
