;------------------------------------------------
; best_track_wind_profile.ncl
; Patrick Duran
; 29 October 2018
;
; Constructs a radial wind profile based on
; input from the TC best-track for four
; quadrants (NE,SE,SW,NW).
;
; Assumes v=0 at r=0 and v=0 at 1000 km.
;
; Note that tension splines generally don't work well for
; the best-track wind profiles. Must use large tension to
; avoid spurious inflection points and to avoid over-
; representing vmax when RMW is small. But these large
; tensions make the function approach piecewise linear
; interpolation, and also sometimes can break (producing
; nans) under some conditions.
;
; Sometimes the radius of maximum wind is not consistent
; with the wind radii in all quadrants (e.g., a 55-kt vmax
; at a radius of 40 km cannot be applied if there is no
; 50-kt wind radius in a given quadrant. Another example
; would be a 250-km RMW with a vmax of 45 kt applied to a
; quadrant where r34 is 100 km.)
; In both cases above, we determine RMW quadrant-by-quadrant,
; scaling it by the r34 value: RMW = rmw(r34/max(r34)).
; RMW and r34 are the radii in each quadrant (4-element arrays)
; and RMW is the (scalar) radius of max wind from the best track.
; In other words, we assume that the best-track RMW really only
; applies in the quadrant(s) with the largest wind field, and
; the RMW decreases linearly with the size of r34.
; In the first case above, for all quadrants where there is
; no r50, we set v=45 at the RMW.
;
; ARGUMENTS
; ---------
; vmax: Maximum wind speed (m/s)
; rmw: Radius of maximum wind (km)
; r34: 34-kt wind radius (km)
; r50: 50-kt wind radius (km)
; r64: 64-kt wind radius (km)
; maxrad: Maximum radius of wind profile (km)
; dr: Radial grid spacing for profile (km)
; type: 0=Piecewise linear interpolation; 1=Cubic spline under tension
;------------------------------------------------

undef("best_track_wind_profile")
function best_track_wind_profile(vmax,rmw,r34,r50,r64,maxrad,dr,type)
begin

RMW = new(4,"integer")
RMW@_FillValue = -9999
r34@_FillValue = -9999
r50@_FillValue = -9999
r64@_FillValue = -9999
r34 = where(r34.eq.0,r34@_FillValue,r34)
r50 = where(r50.eq.0,r50@_FillValue,r50)
r64 = where(r64.eq.0,r64@_FillValue,r64)

;Get indices of non-missing values in each wind radius array
r34ind = ind(.not.ismissing(r34))
r50ind = ind(.not.ismissing(r50))
r64ind = ind(.not.ismissing(r64))

;Use wind radius indices to determine where to put RMW.
;If there are any 64-kt wind radii, use RMW in these radii.
;If there are any 50-kt wind radii, and no 64-kt radii, use RMW in quadrants with 50-kt radii.
;If there are any 34-kt wind radii, and no 64-kt or 50-lt radii, use RMW in quadrants with 64-kt radii.
if(.not.all(ismissing(r64ind)))then
   rmwi := r64ind
elseif(.not.all(ismissing(r50ind)))then
   rmwi := r50ind
elseif(.not.all(ismissing(r34ind)))then
   rmwi := r34ind
end if

;Set output abscissa and initialize output array
npts = maxrad/dr
xo = fspan(dr,maxrad,npts)-(dr/2)
func = new((/4,dimsizes(xo)/),"float")
if(type.eq.0)then    ;Piecewise linear interpolation
   ;Initialize arrays
   inputx = new((/4,6/),"float")
   inputy = new((/4,6/),"float")
   inputx@_FillValue = -9999
   inputy@_FillValue = -9999
   ;Set input ordinate
   inputy(:,0) = 0
   inputy(:,1) = vmax
   inputy(:,2) = 32.9244
   inputy(:,3) = 25.7222
   inputy(:,4) = 17.9110
   inputy(:,5) = 0
   ;Set input abscissa
   inputx(:,0) = 0
   inputx(:,1) = rmw*(r34/max(r34))
   inputx(:,2) = r64
   inputx(:,3) = r50
   inputx(:,4) = r34
   inputx(:,5) = 1000
   ;Loop through all quadrants and interpolate
   do i=0,3
      ;Only compute a radial wind profile if both rmw and r34 are defined
      if(.not.ismissing(r34(i)).and..not.ismissing(rmw))
         ;Sometimes the RMW can lie at a particular wind radius but vmax
         ;is higher than the wind at that radius (e.g., a 55-kt vmax with
         ;the RMW at the same radius as the 50-kt wind radius.) In this
         ;case, we set original rmw to missing.
         if(.not.ismissing(r64(i)))then
            if(rmw.eq.r64(i))then
               inputx(i,1) = inputy@_FillValue
            end if
         end if
         if(.not.ismissing(r50(i)))then
            if(rmw.eq.r50(i))then
               inputx(i,1) = inputy@_FillValue
            end if
         end if
         if(.not.ismissing(r34(i)))then
            if(rmw.eq.r34(i))then
               inputx(i,1) = inputy@_FillValue
            end if
         end if
         ;Since rmw and vmax are defined for the whole storm, we don't
         ;know in which quadrant vmax actually lies. A result of this
         ;is that sometimes there can be a vmax of, e.g., 60 kt, but no
         ;50-kt wind radius in one or more quadrants. In such a case,
         ;it makes no sense to have a 60-kt wind in that quadrant with
         ;no 50-kt wind radius defined. When this happens, we will set
         ;the wind speed at the RMW (vmax) for this quadrant to the wind
         ;speed of the lowest missing wind radius minus 5 kt.
         if(ismissing(r64(i)).and.vmax.gt.32.9244)then
            inputy(i,1) = 30.3522   ;Set vmax in this quadrant to 59 kt
         end if
         if(ismissing(r50(i)).and.vmax.gt.25.7222)then
            inputy(i,1) = 23.1500   ;Set vmax in this quadrant to 45 kt
         end if
         ;Get indices of nonmissing values and perform interpolation
         indxy := ind(.not.ismissing(inputx(i,:)).and..not.ismissing(inputy(i,:)))
         func(i,:) = linint1(inputx(i,indxy),inputy(i,indxy),False,xo,0)
      end if
   end do
elseif(type.eq.1)then   ;Tension spline interpolation
   ;Set tension of spline
   tension = 20.
   ftsetp("sig",tension)
   ;Initialize arrays
   inputx = new(6,"float")
   inputy = new(6,"float")
   inputx@_FillValue = -9999
   inputy@_FillValue = -9999
   ;Set input ordinate
   inputy(0) = 0
   inputy(1) = vmax
   inputy(2) = 32.9244
   inputy(3) = 25.7222
   inputy(4) = 17.9110
   inputy(5) = 0
   ;Loop through all quadrants and interpolate
   do i=0,3
      ;Set input abscissa
      inputx(0) = 0
      inputx(1) = rmw
      inputx(2) = r64(i)
      inputx(3) = r50(i)
      inputx(4) = r34(i)
      inputx(5) = 1000
      ;Get indices of nonmissing values
      indxy := ind(.not.ismissing(inputx).and..not.ismissing(inputy))
      ;Perform interpolation
      func(i,:) = ftcurv(inputx(indxy),inputy(indxy),xo)
   end do
end if

return(func)

end
