;------------------------------------------------
; read_ascat.ncl
; Patrick Duran
; 03 December 2018
;
; Reads and returns wind speed, lat/lon locations,
; and time from an ASCAT NetCDF file.
; Filters out all observations where FLAG!=0 (i.e.
; only returns valid obs that aren't questionable.
;
; CURRENTLY THIS SCRIPT DOES NOT APPLY ANY QC FILTERING
; 
; ---------
; ARGUMENTS
; ---------
; YYYY: Year (string)
; MM: Month (string)
; DD: Day (string)
; HH: Hour (string)
; mm: Minutes (string)
; ss: Seconds (string)
; stormlat: Latitude of storm center
; stormlon: Longitude of storm center
; radius: Radius within which to search for ASCAT observations (km).
; dt: Time interval within which to search (seconds; integer)
; searchtype: Search backward, forward, or centered on best-track time
;------------------------------------------------

undef("read_ascat")
function read_ascat(YYYY,MM,DD,HH,mm,ss,stormlat,stormlon,radius,dt,searchtype)
begin

dir = "/raid1/pduran/jm13/ascat/"+YYYY+"/"

print( "Searching for ASCAT data...")

;Get information from the asctimes.txt file
timeunits = systemfunc("sed -n 1p "+dir+"asctimes.txt | awk -F\' '{print $2}'")
ascinfo = readAsciiTable(dir+"asctimes.txt",1,"string",2)
ascinfosplit = str_split_csv(ascinfo(:,0)," ",0)
ascfilenames = ascinfosplit(:,0)
mintimes     = toint(ascinfosplit(:,1))
maxtimes     = toint(ascinfosplit(:,2))

;Convert best-track date and time to timeunits
bttime = round(cd_inv_calendar(toint(YYYY),toint(MM),toint(DD),toint(HH),toint(mm),toint(ss),timeunits,0),3)

;Find the ASCAT files that contain data for the selected time period
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
   print( "   No ASCAT data files available.")
   return(0)
elseif(all(ismissing(begselectioninds)).and..not.all(ismissing(endselectioninds)))then
   selectioninds = max(endselectioninds)
elseif(.not.all(ismissing(begselectioninds)).and.all(ismissing(endselectioninds)))then
   selectioninds = min(begselectioninds)
else
   selectioninds = ispan(begselectioninds,endselectioninds,1)
end if

;Get ASCAT filenames
ascfiles = ascfilenames(selectioninds)

;Loop through all files and read in data
nascfiles = dimsizes(ascfiles)
print( "   Found "+nascfiles+" ASCAT files containing data within time interval. Reading & processing...")
do i=0,nascfiles-1
   f = addfile(ascfiles(i),"r")
   timesin := f->time  ;(seconds since 1990-01-01 00:00:00)
   latsin  := f->lat   ;Integer with 1e-05 scale factor (deg N)
   lonsin  := f->lon   ;Integer with 1e-05 scale factor (deg E 0-360)
   vin     := f->wind_speed   ;Short with 0.01 scale factor (m/s)
   flagsin := f->wvc_quality_flag  ;Bitmask array
   if(i.eq.0)then
      times   = ndtooned(timesin)
      latsint = ndtooned(latsin)
      lonsint = ndtooned(lonsin)
      vint    = ndtooned(vin)
      flags   = ndtooned(flagsin)
   else
      ;Append the arrays from the new file to arrays from the previous file
      timesa := array_append_record(times,  ndtooned(timesin),0)  
      latsa  := array_append_record(latsint,ndtooned(latsin),0)  
      lonsa  := array_append_record(lonsint,ndtooned(lonsin),0)  
      va     := array_append_record(vint,   ndtooned(vin),0)
      flagsa := array_append_record(flags,  ndtooned(flagsin),0)
      ;Reset arrays to the new, concatenated arrays.
      times   := timesa
      latsint := latsa  ;Integer to be converted later
      lonsint := lonsa  ;Integer to be converted later
      vint    := va     ;Integer to be converted later
      flags   := flagsa
   end if
end do

;Copy metadata
copy_VarMeta(timesin,times)
copy_VarMeta(latsin,latsint)
copy_VarMeta(lonsin,lonsint)
copy_VarMeta(vin,vint)
copy_VarMeta(flagsin,flags)

;Convert ASCAT times to timeunits
asctime = round(onedtond(cd_convert(times,timeunits),dimsizes(times)),3)
asctime@units = timeunits

;Adjust values by their scale factors
lats = tofloat(latsint * latsint@scale_factor)
lons = tofloat(lonsint * lonsint@scale_factor)
v    = tofloat(vint * vint@scale_factor)

;Convert longitude from 0-360 to -180-180
lons = mod((lons+180),360) - 180
lons@valid_range := "(-180, 180)"

;Convert flags array from short to binary and reverse the resulting
;bitmask array so we can compare it to flag_meanings in metadata.
bitmask := getbitsone(flags)
bitmaskrev := bitmask(:,::-1)
;LIST OF BITS AND THEIR flag_meanings
;See ASCAT manual, page 28 for table of QC flags.
;0       Unused
;1       Unused
;2       Unused
;3       Unused
;4       Unused
;5       Unused
;6       distance_to_gmf_too_large 
;7       data_are_redundant 
;8       no_meteorological_background_used 
;9       rain_detected 
;10      rain_flag_not_usable 
;11      small_wind_less_than_or_equal_to_3_m_s 
;12      large_wind_greater_than_30_m_s 
;13      wind_inversion_not_successful 
;14      some_portion_of_wvc_is_over_ice 
;15      some_portion_of_wvc_is_over_land 
;16      variational_quality_control_fails 
;17      knmi_quality_control_fails 
;18      product_monitoring_event_flag 
;19      product_monitoring_not_used 
;20      any_beam_noise_content_above_threshold 
;21      poor_azimuth_diversity 
;22      not_enough_good_sigma0_for_wind_retrieval

;Per the ASCAT wind product user manual, page 16,
;we will filter out observations with the product
;monitoring flag, KNMI QC flag, or variational QC flag flipped.
errorinds = ind(bitmaskrev(:,16).eq.1.or.bitmaskrev(:,17).eq.1.or.bitmaskrev(:,18).eq.1)
lats(errorinds) = lats@_FillValue
lons(errorinds) = lons@_FillValue
v(errorinds)    = v@_FillValue

;Find distance between storm center and each ASCAT retrieval
dist = gc_latlon(stormlat,stormlon,lats,lons,2,4)

;Set missing values to be consistent with other variables in IKE computation
v@_FillValue       = -9999.
lats@_FillValue    = -9999.
lons@_FillValue    = -9999.
asctime@_FillValue = -9999

;Find all of the data that fit the time and space constraints and return
indices = ind(asctime.ge.mintime.and.asctime.lt.maxtime.and.dist.le.radius)
if(all(ismissing(indices)))then
   print( "      No ASCAT data found that fit all constraints :(")
   return(0)
elseif(all(ismissing(v(indices))))then
   print( "      No ASCAT data found that fit all constraints :(")
   return(0)
else
   print( "      Found "+dimsizes(indices)+" ASCAT wind observations that fit all constraints :)")
   ascv    = v(indices)
   asclats = lats(indices)
   asclons = lons(indices)
   asctimes= asctime(indices)
   return([/ascv,asclats,asclons,asctimes/])
end if
end
