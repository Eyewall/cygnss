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
;------------------------------------------------

undef("azimuthal_avg")
function azimuthal_avg(centerlat:numeric,centerlon:numeric,lats:numeric,lons:numeric,\
                       vals:numeric,maxrad:numeric,dr:numeric)
begin

;Radial grid defining cutoffs for averages
nrads = maxrad/dr
radii = fspan(dr,maxrad,nrads)
;Radial grid where averages are valid
radout = radii-(dr/2)

;Compute distances from center position for each observation
Robs = gc_latlon(centerlat,centerlon,lats,lons,2,4)

;Loop through radial bins and compute averages and standard deviation
nobs        = new(dimsizes(radii),"float")
avgs        = new(dimsizes(radii),"float")
sigma       = new(dimsizes(radii),"float")
do i=0,dimsizes(radii)-1
   minrad = i*dr
   maxrad = (i+1)*dr
   indices := ind(Robs.ge.minrad.and.Robs.lt.maxrad)
   nobs(i)  = dimsizes(indices)
   avgs(i)  = avg(vals(indices))
   sigma(i) = stddev(vals(indices))
end do
avgs@num_obs = nobs
avgs@standard_deviation = sigma
return(avgs)
end
