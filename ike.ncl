;------------------------------------------------
; ike.ncl
; Patrick Duran
; 08 August 2018
;
; Computes integrated kinetic energy (IKE) from
; a specified wind profile.
;
; IKE = integral ( 0.5 * rho * U^2 dV) (Powell and Reinhold 2007 BAMS)
; rho = 1 kg m-3
; V includes 1 meter vertical depth
;
; Integrate piecewise between each radius, assuming axisymmetry.
;
;ARGUMENTS
;---------
;winds: Wind speeds (m/s)
;radii: Radii that correspond to wind observations (km)
;opt: Valid options: "full" or "quadrant"
;------------------------------------------------

undef("calc_ike")
function calc_ike(winds:numeric,radii:numeric,opt:string)
begin

rho = 1.15  ;Constant density suggested by Holland (1980); Morris and Ruf (2017)
pi = atan(1) * 4

radii_m = radii*1000.

;Ensure that input wind and radius arrays have the same size
if(dimsizes(winds).ne.dimsizes(radii))then
   print( "calc_ike: Input wind and radii arrays must have same size. Exiting.")
   exit
end if

;Sort the radii into ascending order, and adjust wind array accordingly
radii_m!0 = "indices"
radii_m&indices = ispan(0,dimsizes(radii_m)-1,1)
qsort( radii_m)
windprofile = winds(radii_m&indices)

;Treat each wind as representing a constant value for the area
;halfway from the previous grid point to halfway to the next grid point
nbins = dimsizes(winds)
areas = new(nbins,"float")
do i=0,nbins-2
   router = 0.5*(radii_m(i)+radii_m(i+1))
   if(i.eq.0)then
      rinner = 0.5*(radii_m(i)+0)
   else
      rinner = 0.5*(radii_m(i)+radii_m(i-1))
   end if
   ;Compute IKE using full annuli
   if(opt.eq."full")then
      areas(i) = pi*(router^2-rinner^2)
   ;Compute IKE using quarter annuli
   else if(opt.eq."quadrant")then
      areas(i) = 0.25*pi*(router^2-rinner^2)
   end if
   end if
end do
energies = rho*areas*windprofile^2
ike = sum(energies)
ike@units = "Joules"
return(ike)
end
