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
; opt: "full"=Average around full 360 deg; "quadrant"=Average around 4 quadrants (90 deg each)
; interpgap: Maximum gap (km) across which to interpolate the radial wind profile.
;------------------------------------------------

undef("azimuthal_avg")
function azimuthal_avg(centerlat:numeric,centerlon:numeric,lats:numeric,lons:numeric,\
                       vals:numeric,maxrad:numeric,dr:numeric,opt:string,interpgap:numeric)
begin

if(interpgap.ne.0.and.opt.eq."full")then
   print( "azimuthal_avg: INTERPOLATION NOT SUPPORTED FOR FULL AZIMUTHAL AVERAGES")
   exit
end if

pi = atan(1)*4

;Get radii and azimuths of each observation from attribute attached to velocity array
obsradii = vals@radii
obsazis  = vals@azimuths

;Radial grid defining cutoffs for averages
nrads = maxrad/dr
radii = fspan(dr,maxrad,nrads)

;Radial grid where averages are valid (halfway between radii)
radout = radii-(dr/2)

if(opt.eq."full")then
   ;Loop through radial bins and compute averages and standard deviation
   nobs       := new(nrads,"integer")
   avgs        = new(nrads,"float")
   sigma       = new(nrads,"float")
   obs_density = new(nrads,"float")
   do i=0,nrads-1
      innerrad = i*dr
      outerrad = (i+1)*dr
      indices := ind(obsradii.ge.innerrad.and.obsradii.lt.outerrad)
      if(all(ismissing(indices)))then
         continue
      end if
      if(all(ismissing(vals(indices))))then
         continue
      end if
      nobs(i)  = dimsizes(indices)
      avgs(i)  = avg(vals(indices))
      sigma(i) = stddev(vals(indices))
      ;Compute observation density
      A_bin = pi*(outerrad^2-innerrad^2)
      obs_density(i) = nobs(i)/A_bin
   end do
   A_total = pi*outerrad^2
   obs_total = sum(nobs)
   obs_density_domain = obs_total/A_total
   avgs!0 = "radius"
   avgs&radius = radout
   avgs@standard_deviation = sigma
   avgs@num_obs = nobs
   avgs@obs_density = obs_density
   avgs@obs_density_domain = obs_density_domain
   avgs@comment  = "obs_density = number of obs per square km in each radial bin"
   avgs@comment2 = "obs_density_domain = # of obs per square km in whole domain"
   avgs@comment3 = "averages are valid at the midpoint of each radial bin"
   return(avgs)
elseif(opt.eq."quadrant")then
   ;Loop through azimuthal and radial bins and compute averages and standard deviation
   nobs       := new((/4,nrads/),"integer")
   avgs        = new((/4,nrads/),"float")
   sigma       = new((/4,nrads/),"float")
   obs_density = new((/4,nrads/),"float")
   do i=0,3
      minazi = i*90
      maxazi = minazi + 90
      do j=0,nrads-1
         innerrad = j*dr
         outerrad = (j+1)*dr
         indices := ind(obsradii.ge.innerrad.and.obsradii.lt.outerrad.and.obsazis.ge.minazi.and.obsazis.lt.maxazi)
         if(all(ismissing(indices)))then
            continue
         end if
         if(all(ismissing(vals(indices))))then
            continue
         end if
         nobs(i,j)  = dimsizes(indices)
         avgs(i,j)  = avg(vals(indices))
         sigma(i,j) = stddev(vals(indices))
         A_bin = 0.25*pi*(outerrad^2-innerrad^2) ;Mult. by 0.25 since this is a quadrant
         obs_density(i,j) = tofloat(nobs(i,j))/A_bin
      end do
   end do

   ;Interpolate across gaps, if desired.
   if(interpgap.ne.0)then
      maxpts = (interpgap/dr)-1
      avgs = linmsg(avgs,(/0,maxpts/))
   end if

   A_total = pi*outerrad^2
   obs_total = sum(nobs)
   obs_density_domain = tofloat(obs_total)/A_total
   avgs!0 = "azimuth"
   avgs!1 = "radius"
   avgs&azimuth = (/45,135,225,315/)
   avgs&radius  = radout 
   avgs@standard_deviation = sigma
   avgs@obs_density = obs_density
   avgs@obs_density_domain = obs_density_domain
   avgs@long_name = "Azimuthal average of all wind observations in each quadrant"
   avgs@comment = "obs_density = number of obs per square km in each radial bin"
   avgs@comment2 = "obs_density_domain = # of obs per square km in whole domain"
   avgs@comment3 = "Averages are valid at the midpoint of each radial and azimuthal bin"
   avgs@comment4 = "For azimuths, 0 deg is North, 90 deg is East, etc."
   avgs@comment5 = "interpolation performed across gaps in wind profiles smaller than "+interpgap
   copy_VarCoords(avgs,nobs)
   nobs@long_name = "Number of observations from all platforms"
   return([/avgs,nobs/])
end if   ;opt

end
