;------------------------------------------------
; azimuthal_avg.ncl
; Patrick Duran
; 24 August 2018
;
; Computes azimuthal averages of observations
; within radial bins of user-defined width
; and extent. Averages are valid at the
; midpoint between grid intervals
; (i.e. if dr=100 and maxrad=500, then the averages
;  will be valid at r=50,150,250,350,450)
;
; ARGUMENTS
; ---------
; centerlat: Latitude of the center of the grid (degrees North)
; centerlon: Longitude of the center of the grid (degrees East)
; lats: Latitudes of observations
; lons: Longitudes of observations
; vals: Array of values to average
; maxrad: Outer radius
; dr: Width of radial bins
; opt: 0=Average around full 360 deg; 1=Average around 4 quadrants (90 deg each)
;------------------------------------------------

undef("azimuthal_avg")
function azimuthal_avg(centerlat:numeric,centerlon:numeric,lats:numeric,lons:numeric,\
                       vals:numeric,maxrad:numeric,dr:numeric,opt:integer)
begin

pi = atan(1)*4

;Radial grid defining cutoffs for averages
nrads = maxrad/dr
radii = fspan(dr,maxrad,nrads)

;Radial grid where averages are valid (halfway between radii)
radout = radii-(dr/2)

;Compute distances from center position for each observation
Robs = gc_latlon(centerlat,centerlon,lats,lons,2,4)

;Get indices for each quadrant
NEquad = ind(lats.gt.centerlat.and.lons.ge.centerlon)
SEquad = ind(lats.le.centerlat.and.lons.ge.centerlon)
SWquad = ind(lats.lt.centerlat.and.lons.lt.centerlon)
NWquad = ind(lats.ge.centerlat.and.lons.lt.centerlon)

;Compute azimuths from storm center for each observation
;(0 deg=North; 90 deg=East; 180 deg=South; 270 deg=West)
;First compute x component of radius for each observation
;and then use the radii and x components to get azimuths.
nobs = dimsizes(Robs)
xcomps = new(nobs,"float")
do i=0,nobs-1
   xcomps(i) = gc_latlon(centerlat,centerlon,centerlat,lons(i),2,4)
end do

;Compute azimuths quadrant-by-quadrant
azis = new(dimsizes(lats),"float")
arcsin = asin(xcomps/Robs)*(180/pi)
arccos = acos(xcomps/Robs)*(180/pi)
azis(NEquad) = arcsin(NEquad)
azis(SEquad) = 90 + arccos(SEquad)
azis(SWquad) = 270 - arccos(SWquad)
azis(NWquad) = 270 + arccos(NWquad)

if(opt.eq.0)then
   ;Loop through radial bins and compute averages and standard deviation
   nobs       := new(nrads,"float")
   avgs        = new(nrads,"float")
   sigma       = new(nrads,"float")
   obs_density = new(nrads,"float")
   do i=0,nrads-1
      minrad = i*dr
      maxrad = (i+1)*dr
      indices := ind(Robs.ge.minrad.and.Robs.lt.maxrad)
      if(all(ismissing(indices)))then
         continue
      end if
      nobs(i)  = dimsizes(indices)
      avgs(i)  = avg(vals(indices))
      sigma(i) = stddev(vals(indices))
      ;Compute observation density
      A_outer = pi*maxrad^2
      A_inner = pi*minrad^2
      A_bin = A_outer - A_inner
      obs_density(i) = nobs(i)/A_bin
   end do
   avgs!0 = "radius"
   avgs&radius = radout
   avgs@standard_deviation = sigma
   avgs@num_obs = nobs
   avgs@obs_density = obs_density
   avgs@comment  = "obs_density = number of obs per square km in each radial bin"
   avgs@comment2 = "averages are valid at the midpoint of each radial bin"
   return(avgs)
else
   ;Loop through azimuthal and radial bins and compute averages and standard deviation
   nobs       := new((/4,nrads/),"float")
   avgs        = new((/4,nrads/),"float")
   sigma       = new((/4,nrads/),"float")
   obs_density = new((/4,nrads/),"float")
   do i=0,3
      minazi = i*90
      maxazi = minazi + 90
      do j=0,nrads
         minrad = j*dr
         maxrad = (j+1)*dr
         indices := ind(Robs.ge.minrad.and.Robs.lt.maxrad.and.azis.ge.minazi.and.azis.lt.maxazi)
         if(all(ismissing(indices)))then
            continue
         end if
         nobs(i,j)  = dimsizes(indices)
         avgs(i,j)  = avg(vals(indices))
         sigma(i,j) = stddev(vals(indices))
         A_outer = pi*maxrad^2
         A_inner = pi*minrad^2
         A_bin = A_outer - A_inner
         obs_density(i,j) = nobs(i,j)/A_bin
      end do
   end do
   avgs!0 = "azimuth"
   avgs!1 = "radius"
   avgs&azimuth = (/45,135,225,315/)
   avgs&radius  = radout 
   avgs@standard_deviation = sigma
   avgs@num_obs = nobs
   avgs@obs_density = obs_density
   avgs@comment = "obs_density = number of obs per square km in each radial bin"
   avgs@comment2 = "Averages are valid at the midpoint of each radial and azimuthal bin"
   avgs@comment3 = "For azimuths, 0 deg is North, 90 deg is East, etc."
   return(avgs)
end if   ;opt
end
