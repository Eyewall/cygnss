;------------------------------------------------
; rad_azi.ncl
; Patrick Duran
; 03 October 2018
;
; Computes radius and azimuth of a lat,lon
; point from a reference lat,lon point.
; Uses storm center information from an
; interpolated best-track file to find the
; storm center at the time of the observation.
;
; ARGUMENTS
; ---------
; stormname1min: Storm name from interpolated best-track file
; stormtime1min: Storm time from interpolated best-track file
; reflat: Latitude of the storm center (degrees North)
; reflon: Longitude of the storm center (degrees East)
; lats: Latitudes of observations
; lons: Longitudes of observations
; time: Times of the observations
;------------------------------------------------

undef("rad_azi")
function rad_azi(stormname1min:string,stormtime1min:numeric,reflat:numeric,reflon:numeric,stormname,lats:numeric,lons:numeric,times:numeric)
;function rad_azi(reflat:numeric,reflon:numeric,lats:numeric,lons:numeric)

begin

pi = atan(1)*4

;Loop through all observations and get radius and azimuth from the
;storm center position at the closest time.
storminds = ind(stormname1min.eq.stormname)
stormtimes = stormtime1min(storminds)
stormlats = reflat(storminds)
stormlons = reflon(storminds)
nobs   = dimsizes(times)       ;Number of observations
Robs   = new(nobs,"float")     ;Radii of obs
quad   = new(nobs,"integer")   ;Quadrants of obs
xcomps = new(nobs,"float")     ;x component of radius of obs
Robs@_FillValue = -9999.

do i=0,nobs-1
   ;If this time isn't missing, find nearest best-track time
   if(ismissing(times(i)))then
      continue
   end if
   timeind = minind(abs(stormtimes-times(i)))
   ;Compute distance of this observation from storm center
   Robs(i) = gc_latlon(stormlats(timeind),stormlons(timeind),lats(i),lons(i),2,4)
   ;Determine the storm quadrant in which this observation lies
   if(lats(i).gt.stormlats(timeind).and.lons(i).ge.stormlons(timeind))then
      quad(i) = 0   ;NE quadrant
   elseif(lats(i).le.stormlats(timeind).and.lons(i).ge.stormlons(timeind))then
      quad(i) = 1   ;SE quadrant
   elseif(lats(i).lt.stormlats(timeind).and.lons(i).lt.stormlons(timeind))then
      quad(i) = 2   ;SW quadrant
   elseif(lats(i).ge.stormlats(timeind).and.lons(i).lt.stormlons(timeind))then
      quad(i) = 3   ;NW quadrant
   end if
   ;Compute x component of radius of obs, which we will use later to compute azimuths
   xcomps(i) = gc_latlon(stormlats(timeind),stormlons(timeind),stormlats(timeind),lons(i),2,4)
end do
;Exclude any obs right on storm center (no way to define azimuth).
Robs = where(Robs.eq.0,Robs@_FillValue,Robs)

;Get indices of each quadrant
NEquad = ind(quad.eq.0)
SEquad = ind(quad.eq.1)
SWquad = ind(quad.eq.2)
NWquad = ind(quad.eq.3)

;Compute azimuths from storm center for each observation
;(0 deg=North; 90 deg=East; 180 deg=South; 270 deg=West)
;Compute azimuths quadrant-by-quadrant
azis = new(nobs,"float")
arcsin = asin(xcomps/Robs)*(180/pi)
arccos = acos(xcomps/Robs)*(180/pi)
if(.not.all(ismissing(NEquad)))
   azis(NEquad) = arcsin(NEquad)
end if
if(.not.all(ismissing(SEquad)))
   azis(SEquad) = 90 + arccos(SEquad)
end if
if(.not.all(ismissing(SWquad)))
   azis(SWquad) = 270 - arccos(SWquad)
end if
if(.not.all(ismissing(NWquad)))
   azis(NWquad) = 270 + arccos(NWquad)
end if

return([/Robs,azis/])

end
