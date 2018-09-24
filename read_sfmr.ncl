;------------------------------------------------
; read_sfmr.ncl
; Patrick Duran
; 17 September 2018
;
; Reads and returns wind speed, lat/lon locations,
; and time from an SFMR NetCDF file.
; Filters out all observations where FLAG!=0 (i.e.
; only returns valid obs that aren't questionable.
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
; name: Storm name (string; first letter upper-case)
; stormlat: Latitude of storm center
; stormlon: Longitude of storm center
; radius: Radius within which to search for SFMR observations (km).
; dt: Time interval within which to search (seconds; integer)
; searchtype: Search backward, forward, or centered on best-track time
;------------------------------------------------

undef("read_sfmr")
function read_sfmr(YYYY,MM,DD,HH,mm,ss,name,stormlat,stormlon,radius,dt,searchtype)
begin

dir = "/jm13/pduran/sfmr/"+YYYY+"/"

print( "Searching for SFMR data...")

;Get information from the sfmrtimes.txt file
timeunits = systemfunc("sed -n 1p "+dir+"sfmrtimes.txt | awk -F\' '{print $2}'")
sfmrinfo = readAsciiTable(dir+"sfmrtimes.txt",1,"string",2)
sfmrinfosplit = str_split_csv(sfmrinfo(:,0)," ",0)
sfmrfilenames = sfmrinfosplit(:,0)
stormnames    = sfmrinfosplit(:,1)
mintimes      = toint(sfmrinfosplit(:,2))
maxtimes      = toint(sfmrinfosplit(:,3))

;Convert best-track date and time to timeunits
bttime = round(cd_inv_calendar(toint(YYYY),toint(MM),toint(DD),toint(HH),toint(mm),toint(ss),timeunits,0),3)

;Find the SFMR files that contain data for the selected time period and storm
thisstorminds = ind(name.eq.stormnames)
if(searchtype.eq."centered")then
   mintime = bttime - dt
   maxtime = bttime + dt
else if(searchtype.eq."forward")then
   mintime = bttime
   maxtime = bttime + dt
else if(searchtype.eq."backward")then
   mintime = bttime - dt
   maxtime = bttime
end if
end if
end if
mintimediff = abs(mintimes - mintime)
maxtimediff = abs(maxtimes - maxtime)
selectioninds = ind((mintimediff.le.dt.or.maxtimediff.le.dt).and.stormnames.eq.name)
if(all(ismissing(selectioninds)))then
   print( "No SFMR data files available.")
   return(0)
end if
sfmrfiles = sfmrfilenames(selectioninds)

;Loop through all files and read in data
do i=0,dimsizes(sfmrfiles)-1
   f = addfile(sfmrfiles(i),"r")
   datesin := f->DATE
   timesin := f->TIME
   latsin  := f->LAT
   lonsin  := f->LON
   vin     := f->SWS
   if(i.eq.0)then
      dates = datesin
      times = timesin
      lats  = latsin
      lons  = lonsin
      v     = vin
   else
      ;Append the arrays from the new file to arrays from the previous file
      datesa := array_append_record(dates,datesin,0)  
      timesa := array_append_record(times,timesin,0)  
      latsa  := array_append_record(lats,latsin,0)  
      lonsa  := array_append_record(lons,lonsin,0)  
      va     := array_append_record(v,vin,0)  
      ;Reset arrays to the new, concatenated arrays.
      dates := datesa
      times := timesa
      lats  := latsa
      lons  := lonsa
      v     := va
   end if
end do

;Get only those observations that fall within the time constraints
;Time is stored as an integer, so need to prepend
;zeroes depending on how small the number is.
timestr := tostring(times)
timestr := where(times.eq.0,"0",timestr)
timestr := where(times.lt.10,"0"+timestr,timestr)
timestr := where(times.lt.100,"0"+timestr,timestr)
timestr := where(times.lt.1000,"0"+timestr,timestr)
timestr := where(times.lt.10000,"0"+timestr,timestr)
timestr := where(times.lt.100000,"0"+timestr,timestr)

;Split time and date strings and convert to integer
timesplit = str_split_by_length(timestr,2)
sfmrhour = toint(timesplit(:,0))
sfmrminu = toint(timesplit(:,1))
sfmrsec  = toint(timesplit(:,2))
datesplit = str_split_by_length(tostring(dates),(/4,2,2/))
sfmryear = toint(datesplit(:,0))
sfmrmon  = toint(datesplit(:,1))
sfmrday  = toint(datesplit(:,2))

;Convert SFMR dates and times to timeunits
sfmrtime = round(cd_inv_calendar(sfmryear,sfmrmon,sfmrday,sfmrhour,sfmrminu,sfmrsec,timeunits,0),3)

;Find distance between storm center and each SFMR retrieval
dist = gc_latlon(stormlat,stormlon,lats,lons,2,4)

;Find all of the data that fit the time constraints and return
indices = ind(sfmrtime.ge.mintime.and.sfmrtime.lt.maxtime.and.dist.le.radius)
if(all(ismissing(indices)))then
   return(0)
else
   sfmrv = v(indices)
   sfmrlats = lats(indices)
   sfmrlons = lons(indices)
   return([/sfmrv,sfmrlats,sfmrlons/])
end if

end
