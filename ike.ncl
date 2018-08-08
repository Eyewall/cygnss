;------------------------------------------------
; ike.ncl
; Patrick Duran
; 08 August 2018
;
; Adapted from code received from Dan Cecil on hiraddata:
; /usr/people/pduran/progs/idl/cygnss_proposal/ike_fcn.pro
; Computes integrated kinetic energy (IKE) from
; a specified wind profile.
;
; IKE = integral ( 0.5 * rho * U^2 dV) (Powell and Reinhold 2007 BAMS)
; rho = 1 kg m-3
; V includes 1 meter vertical depth
;
; Integrate piecewise between each radius, assuming axisymmetry.
;------------------------------------------------

rho = 1.0
km_to_m = 1000.
pi = atan(1) * 4

;For now, assume Rankine vortex
radii = fspan(1,1000,1000)*km_to_m
winds = new(dimsizes(radii),"float")
vmax = 50
rmax = 25*km_to_m
ind1 = ind(radii.lt.rmax)
ind2 = ind(radii.ge.rmax)
winds(ind1) = vmax*radii(ind1)/rmax
winds(ind2) = vmax*(rmax/radii(ind2))^0.5

;Ensure that input wind and radius arrays have the same size
if(dimsizes(winds).ne.dimsizes(radii))then
   print( "Input wind and radii arrays must have same size. Exiting.")
   exit
end if

;Sort the radii into ascending order, and adjust wind array
radii!0 = "indices"
radii&indices = ispan(0,dimsizes(radii)-1,1)
qsort( radii)
windprofile = winds(radii&indices)

;Treat each wind as representing a constant value for the area
;halfway from the previous grid point to halfway to the next grid point.
nbins = dimsizes(winds)
areas = new(nbins,"float")
do i=0,nbins-1
   router = 0.5*(radii(i)+radii(i+1))
   if(i.eq.0)then
      rinner = 0.5*(radii(i)+0)
   else
      rinner = 0.5*(radii(i)+radii(i-1))
   end if
   areas(i) = pi*(router^2-rinner^2) 
end do

energies = 1.*rho*areas*windprofile
ike = sum(energies)
print( ike)
