;------------------------------------------------
; read_smap.ncl
; Patrick Duran
; 07 January 2019
;
; Reads and returns wind speed, lat/lon locations,
; and time from a SMAP NetCDF file.
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
; radius: Radius within which to search for SMAP observations (km).
; dt: Time interval within which to search (seconds; integer)
; searchtype: Search backward, forward, or centered on best-track time
;------------------------------------------------

undef("read_smap")
function read_smap(YYYY,MM,DD,HH,mm,ss,stormlat,stormlon,radius,dt,searchtype)
begin

dir = "/raid1/pduran/jm13/smap/"+YYYY+"/"

print( "Searching for SMAP data...")

;Get information from the smaptimes.txt file
timeunits = systemfunc("sed -n 1p "+dir+"smaptimes.txt | awk -F\' '{print $2}'")
smapinfo = readAsciiTable(dir+"smaptimes.txt",1,"string",2)
smapinfosplit = str_split_csv(smapinfo(:,0)," ",0)
smapfilenames = smapinfosplit(:,0)
mintimes      = toint(smapinfosplit(:,1))
maxtimes      = toint(smapinfosplit(:,2))

;Convert best-track date and time to timeunits
bttime = round(cd_inv_calendar(toint(YYYY),toint(MM),toint(DD),toint(HH),toint(mm),toint(ss),timeunits,0),3)
;Determine beginning and ending of seach period
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

;Find the SMAP file that contains data at the beginning of the search period
mintimediff = mintimes - mintime
maxtimediff = maxtimes - mintime
begselectioninds = min(ind(mintimediff.le.0.and.maxtimediff.ge.0))

;Find the SMAP file that contains data at the end of the search period
mintimediff = mintimes - maxtime
maxtimediff = maxtimes - maxtime
endselectioninds = max(ind(mintimediff.le.0.and.maxtimediff.ge.0))

if(all(ismissing(begselectioninds)).and.all(ismissing(endselectioninds)))then
   print( "   No SMAP data files available.")
   return(0)
elseif(all(ismissing(begselectioninds)).and..not.all(ismissing(endselectioninds)))then
   selectioninds = max(endselectioninds)
elseif(.not.all(ismissing(begselectioninds)).and.all(ismissing(endselectioninds)))then
   selectioninds = min(begselectioninds)
else
   selectioninds = ispan(begselectioninds,endselectioninds,1)
end if

;Concatenate SMAP files
smapfiles = smapfilenames(selectioninds)

;Loop through all files and read in data
nsmapfiles = dimsizes(smapfiles)
print( "   Found "+nsmapfiles+" SMAP files containing data within time interval. Reading & processing...")
times = new((/720,1440,2,nsmapfiles/),"integer")
lats  = new((/720,1440,2,nsmapfiles/),"float")
lons  = new((/720,1440,2,nsmapfiles/),"float")
v     = new((/720,1440,2,nsmapfiles/),"float")
do i=0,nsmapfiles-1
   f = addfile(smapfiles(i),"r")
   smapyear = f@year_of_observation
   smapmon  = f@month_of_observation
   smapday  = toint(systemfunc("echo "+smapfiles(i)+" | awk -F'/' '{print $NF}' | awk -F'_' '{print $7}'"))
   minuteofday := f->minute
   latsin := tofloat(f->lat)   ;Units deg N
   lonsin := tofloat(f->lon)   ;Units deg E 0-360
   vin    := tofloat(f->wind)  ;Units m/s

   ;Scale the wind speed, as specified by the wind variable metadata
   vin := vin*.01

   ;Convert longitude from 0-360 to -180-180
   lonsin = mod((lonsin+180),360) - 180
   lonsin@valid_range := "(-180, 180)"

   ;Get times in timeunits
   smapmidnight = cd_inv_calendar(smapyear,smapmon,smapday,0,0,0,timeunits,0)
   smaptimes = smapmidnight + minuteofday*60
   times(:,:,:,i) = toint(smaptimes)
   lats (:,:,:,i) = conform(smaptimes,latsin,0)
   lons (:,:,:,i) = conform(smaptimes,lonsin,1)
   v    (:,:,:,i) = vin
end do

;Convert arrays to 1-D so we can get indices
times1d = ndtooned(times)
lats1d  = ndtooned(lats)
lons1d  = ndtooned(lons)
v1d     = ndtooned(v)

;Find distance between storm center and each SMAP retrieval
dist1d = gc_latlon(stormlat,stormlon,lats1d,lons1d,2,4)

;Get indices of observations that fit space and time constraints
indices = ind(times1d.ge.mintime.and.times1d.lt.maxtime.and.dist1d.le.radius)

if(all(ismissing(indices)))then
   print( "      No SMAP data found that fit all constraints :(")
   return(0)
else
   print( "      Found "+dimsizes(indices)+" SMAP wind observations that fit all constraints :)")
   smapv    := v1d(indices)
   smaplats := lats1d(indices)
   smaplons := lons1d(indices)
   smaptimes:= times1d(indices)
   return([/smapv,smaplats,smaplons,smaptimes/])
end if

end
