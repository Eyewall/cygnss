;------------------------------------------------
; parametric-model-morris+ruf.ncl
; Patrick Duran
; 08 August 2018
;
; Adapted from code received from Dan Cecil on hiraddata:
; /usr/people/pduran/progs/idl/cygnss_proposal/parametric_model.pro
;
; Fits CYGNSS observations to a parametric wind model using
; the methodology of Morris and Ruf (2017):
;
; FOR THE 2-PARAMETER MODEL, THE EQUATION IS:
; v(r) = 2*r*(Rm*Vm + 0.5*f*Rm^2)/(Rm^2 + r^2) -f*r/2.
; WHERE Rm = Radius of Maximum Wind (TO BE SOLVED BY LEAST SQUARE FIT)
;       Vm = Maximum Wind (TO BE SOLVED BY LEAST SQUARE FIT)
;        f = Coriolis parameter

; FOR THE 3-PARAMETER MODEL, THE EQUATION IS:
; v(r) = 2*r*(Rm*Vm + 0.5*f*Rm^2)/(Rm^2 + a*r^b) -f*r/2.
; WHERE Rm = Radius of Maximum Wind (TO BE SOLVED BY LEAST SQUARE FIT)
;       Vm = Maximum Wind (TO BE SOLVED BY LEAST SQUARE FIT)
;        f = Coriolis parameter
;        b = radial decay coefficient (TO BE SOLVED BY LEAST SQUARE FIT)
;        a = ( (c4+c5+c6+c7)/(Vm*Rm^2+cQ*Vm) )^b
;       c1 = -0.5*f
;       c2 = -f*Rm^2 - 2*Rm*Vm*(b-1) - f*Rm*(b-1)
;       c3 = -0.5*f*Rm^4 + 2*Rm^3*Vm +f*Rm^4
;       c4 = 2*Rm*Vm*cQ^(1./b)
;       c5 = f*Rm^2*cQ^(1./b)
;       c6 = -0.5*f*cQ(1./b)
;       c7 = -0.5*F*cQ*cQ(1./b)
;       cQ = -sqrt(c2^2-4*c1*c3)
;
; ARGUMENTS
; ---------
; stormlat : Latitude of the storm center in decimal degrees North
; basin    : Storm basin (e.g. "NATL","EPAC","WPAC"
; v        : Observed wind speeds (m/s)
; r        : Distance of the observed wind speeds from storm center (km)
; nparams  : Number of free parameters in Morris+Ruf model (2 or 3)
;------------------------------------------------

undef("MorrisRufModel")
function MorrisRufModel(stormlat:numeric,basin:string,v:numeric,r:numeric,nparams:integer)

begin

pi = atan(1) * 4
km_to_m = 1000.
kt_to_mps = 0.514444

;Get r in meters
r_m = r*km_to_m

;Coriolis parameter
f = 2*7.292e-5*sin(stormlat*pi/180.)
 
;Per Morris & Ruf (July 2017, page 1851,1864), set initial R_limits
;(which are basin-specific).
if(basin.eq."NATL".or.basin.eq."EPAC")then
   Rlimit = 200*km_to_m
else
   Rlimit = 300*km_to_m
end if

if(nparams.eq.2)then
   ;-----------------------------------------------------------;
   ;EXECUTE PARAMETRIC WIND MODEL (MORRIS AND RUF, JANUARY 2017;
   ;-----------------------------------------------------------;
   ;We will loop over the two free parameters (Vmax and Rmax)
   ;from between the values set below with the steps set below.
   vmin = 0.       ;Minimum Vmax to test
   vmax = 100.     ;Maximum Vmax to test
   rmin = 0.       ;Minimum Rmax to test (km)
   rlimit = 100.   ;Maximum Rmax to test (km)
   dr   = 1.       ;Rmax step
   dv   = 1.       ;Vmax step
   ;The i loop is here so that we can make rlimit and r34 computed by the
   ;parametric model converge. It will never loop through all 100
   ;iterations because we will break it before then.
   do i=0,99
      ;Set the radii of the parametric model
      Rparam := fspan(1,toint(Rlimit),toint(Rlimit))
      nrads = toint((rlimit-rmin)/dr)
      nvmax = toint((vmax-vmin)/dv)
      costfunction = new((/nvmax,nrads/),"float")
      do Rmax=0,nrads-1
         unixRmax = Rmax + 1
;         print( "Computing cost function for Rmax "+unixRmax+" of "+nrads)
         Rmax_m = Rmax*km_to_m
         do Vmax=0,nvmax-1
            Robs := round(r_m(ind(r_m.le.Rlimit)),1)
            Vobs := v(ind(r_m.le.Rlimit))
            Vest := 2*Rparam*(Rmax_m*Vmax+0.5*f*Rmax_m^2)/(Rmax_m^2+Rparam^2)-0.5*f*Rparam
            ;Get all of the indices where Robs=Rparam so that we can get arrays of
            ;the same size. We only need to do this for the very first iteration of
            ;Rmax, since the only time Robs can change is after the Rmax loop finishes.
            if(Rmax.eq.0)then
               diffinds := new(dimsizes(Vobs),integer)
               do diffind=0,dimsizes(Vobs)-1
                  diffinds(diffind) = ind(Rparam.eq.Robs(diffind))
               end do
            end if
            costfunction(Vmax,Rmax) = sqrt(avg((Vest(diffinds)-Vobs)^2))
         end do
      end do
      ;Find Vmax and Rmax for which cost function is minimized
      costfunction1d = ndtooned(costfunction)
      indices = ind_resolve(minind(costfunction1d),dimsizes(costfunction))
      bestVmax = indices(0,0)
      bestRmax = indices(0,1)
      ;Compute radial wind profile using these values
      Vest = 2*Rparam*((bestRmax*km_to_m)*bestVmax+0.5*f*(bestRmax*km_to_m)^2)/((bestRmax*km_to_m)^2+Rparam^2)-0.5*f*Rparam
      ;Determine r34. If it's close enough to Rlimit, break out of the i loop and plot.
      ;If it's not close enough to Rlimit, set Rlimit to r34 and recalculate.
      ;Get all indices outside of rmax
      rmaxind = maxind(Vest)
      Vest_outside_rmax := Vest(rmaxind:)
      Rparam_outside_rmax := Rparam(rmaxind:)
      r34 := Rparam_outside_rmax(minind(abs(Vest_outside_rmax-34*kt_to_mps)))
      diff := abs(Rlimit-r34)
      if(diff.ge.10000)then
         Rlimit = r34
      else
         break
      end if
   end do
   ;Plot the cost function with a dot at the minimum
   wks = gsn_open_wks("png","/jm13/pduran/web/cygnss/parametric/costfunction.png")
   gsn_define_colormap(wks,"WhiteBlueGreenYellowRed")
   res = True
   res@cnFillOn = True
   res@tmYROn = False
   res@tmXTOn = False
   res@gsnMaximize = True
   res@gsnLeftStringFontHeightF = .014
   res@gsnLeftString = "Cost function (Minimized at V~B~max~N~ = "+bestVmax+\
                       " m s~S~-1~N~, R~B~max~N~ = "+bestRmax+" km)"
   res@tiXAxisString = "Radius of maximum wind (km)"
   res@tiYAxisString = "Maximum wind speed (m s~S~-1~N~)"
   res@lbOrientation = "Vertical"
   res@pmLabelBarWidthF = 0.05
   res@lbLabelFontHeightF = 0.008
   res@tiYAxisFontHeightF = 0.015
   res@tiXAxisFontHeightF = 0.015
   res@tmXBLabelFontHeightF = 0.015
   res@tmYLLabelFontHeightF = 0.015
   res@gsnDraw = False
   res@gsnFrame = False
   plot = gsn_csm_contour(wks,costfunction,res)
   polyres = True
   polyres@gsMarkerIndex = 1
   polyres@gsMarkerSizeF = .05
   dum = gsn_add_polymarker(wks,plot,bestRmax,bestVmax,polyres)
   draw(plot)
   frame(wks)
   ;Plot the observed winds and the parametric wind profile
   wks2 = gsn_open_wks("png","/jm13/pduran/web/cygnss/parametric/2parametermodel.png")
   res2 = True
   res2@gsnMaximize = True
   res2@gsnLeftString = "CYGNSS observations (dots) and 2-parameter modeled wind profile (line)"
   res2@gsnLeftStringFontHeightF = 0.014
   res2@xyMarkLineMode = "Markers"
   res2@xyMarkers = 1
   res2@xyMarkerColor = "black"
   res2@xyMarkerSizeF = 0.015
   res2@tiYAxisString = "Wind speed (m s~S~-1~N~)"
   res2@tiXAxisString = "Radius (km)"
   res2@tiYAxisFontHeightF = 0.015
   res2@tiXAxisFontHeightF = 0.015
   res2@tmXBLabelFontHeightF = 0.015
   res2@tmYLLabelFontHeightF = 0.015
   res2@tmYLMode = "Manual"
   res2@tmYLTickStartF = 0.
   res2@tmYLTickEndF = 100.
   res2@tmYLTickSpacingF = 5.
   res2@tmYLMinorOn = False
   res2@trXMinF = 0.
   if(basin.eq."NATL".or.basin.eq."EPAC")then
      res2@trXMaxF = 200. 
   else
      res2@trXMaxF = 300.
   end if
   res2@trYMinF = 0.
   res2@trYMaxF = max((/max(Vobs),max(Vest)/))
   res2@tmYROn = False
;   res2@tmXTOn = False
   res2@gsnDraw = False
   res2@gsnFrame = False
   plot2 = gsn_csm_xy(wks2,Robs/km_to_m,Vobs,res2)
   lineres2 = True
   lineres2@gsLineColor = "blue"
   lineres2@gsLineThicknessF = 5
   gsn_polyline(wks2,plot2,Rparam/km_to_m,Vest,lineres2)
   draw(plot2)
   frame(wks2)
else
   ;--------------------------------------------------------------------;
   ;EXECUTE PARAMETRIC WIND MODEL (MORRIS AND RUF, JULY 2017, APPENDIX C;
   ;EACH "STEP" OUTLINED HERE CORRESPONDS TO THE STEPS IN THEIR PAPER   ;
   ;--------------------------------------------------------------------;
   ;Small perturbations to the free parameters to use in
   ;populating the Jacobian matrix (see STEP 3 below).
   dvmax = 1.
   db    = 0.1
   drmax = 10.
   ;Gamma for regularization matrix (see STEP 4 below).
   Gamma = 1.0
   ;Use a=1 and b=2 for first guess.
   a = 1.
   b = 2.
   do i=0,50
      unixi = i + 1
      ;------;
      ;Step 1;
      ;------;
      ;Use only observations within Rlimit
      Robs := radii(ind(radii.le.Rlimit))
      Vobs := winds(ind(radii.le.Rlimit))
      Vest := 2*Robs*(rmax*vmax+0.5*f*rmax^2)/(rmax^2+a*Robs^b)-0.5*f*Robs
      ;------;
      ;Step 2;
      ;------;
      dV := Vest-Vobs
      ;------;
      ;Step 3;
      ;------;
      J := new((/dimsizes(Vobs),3/),"float")  ;Jacobian matrix for all free parameters
      do j=0,2
         if(j.eq.0)then
            pert2 := 2*Robs*(rmax*(vmax+dvmax)+0.5*f*rmax^2)/(rmax^2+a*Robs^b)-0.5*f*Robs
            pert1 := 2*Robs*(rmax*(vmax-dvmax)+0.5*f*rmax^2)/(rmax^2+a*Robs^b)-0.5*f*Robs
            dVobs_dVmax := (pert2-pert1)/(dvmax*2)
            J(:,j) = dVobs_dVmax
         else if(j.eq.1)then
            pert2 := 2*Robs*(rmax*vmax+0.5*f*rmax^2)/(rmax^2+a*Robs^(b+db))-0.5*f*Robs
            pert1 := 2*Robs*(rmax*vmax+0.5*f*rmax^2)/(rmax^2+a*Robs^(b-db))-0.5*f*Robs
            dVobs_db := (pert2-pert1)/(db*2)
            J(:,j) = dVobs_db
         else if(j.eq.2)then
            pert2 := 2*Robs*((rmax+drmax)*vmax+0.5*f*(rmax+drmax)^2)/((rmax+drmax)^2+a*Robs^b)-0.5*f*Robs
            pert1 := 2*Robs*((rmax-drmax)*vmax+0.5*f*(rmax-drmax)^2)/((rmax-drmax)^2+a*Robs^b)-0.5*f*Robs
            dVobs_dRmax := (pert2-pert1)/(drmax*2)
            J(:,j) = dVobs_dRmax
         end if
         end if
         end if
      end do
      ;------;
      ;Step 4;
      ;------;
      ;Define regularization matrix
      Rarray := new((/3,3/),"integer")
      Rarray = 0
      do k=0,2
         Rarray(k,k) = 1
      end do
      R := Gamma*Rarray
      dx := inverse_matrix(transpose(J)#J+R)#transpose(J)#dV
      print( dx)
      ;------;
      ;Step 5;
      ;------;
      ;Update estimate of the free parameters
      rmax = rmax + dx(0)
      b    = b + dx(1)
      vmax = vmax + dx(2)
      ;------;
      ;Step 6;
      ;------;
      ;Calculate a. See Morris and Ruf (July 2017, Appendix B)
      c1 = -0.5*f
      c2 = -f*rmax^2-2*rmax*vmax*(b-1)-f*rmax*(b-1)
      c3 = -0.5*f*rmax^4+2*rmax^3*vmax+f*rmax^4
      cQ = (-c2-sqrt(c2^2-4*c1*c3))/(2*c1)
      c4 = 2*rmax*vmax*cQ^(1./b)
      c5 = f*rmax^2*cQ^(1./b)
      c6 = -0.5*f*cQ^(1./b)
      c7 = -0.5*f*cQ*cQ^(1./b)
      a = ((c4+c5+c6+c7)/(vmax*rmax^2+cQ*vmax))^b
      ;------;
      ;Step 7;
      ;------;
      Vest := 2*Robs*(rmax*vmax+0.5*f*rmax^2)/(rmax^2+a*Robs^b)-0.5*f*Robs
      dV := Vest-Vobs
      ;------;
      ;Step 8;
      ;------;
      ;Make sure parameters are positive. If not, force them positive.
      ;------;
      ;Step 9;
      ;------;
      ;(Paragraph below Step 9 in Morris & Ruf)
      if(i.eq.0)then
         ;Get all indices outside of rmax
         ind_outside_rmax := ind(Robs.ge.rmax)
         V_outside_rmax := Vest(ind_outside_rmax)
         r_outside_rmax := Robs(ind_outside_rmax)
         r34 := r_outside_rmax(min(ind(V_outside_rmax.le.34)))
         diff := abs(Rlimit-r34)
         if(diff.ge.10000)then
            Rlimit = r34
         end if
      end if
      ;----------------------------------------------------;
      ;PLOT THE PARAMETRIC WIND PROFILE AND THE INPUT WINDS
      ;----------------------------------------------------;
      wks = gsn_open_wks("png","/jm13/pduran/web/cygnss/parametric/"+unixi+".png")
      res = True
      res@gsnMaximize = True
      res@gsnLeftString = "CYGNSS observations (dots) and parameteric wind profile (line) for iteration "+unixi
      res@gsnLeftStringFontHeightF = 0.014
      res@xyMarkLineMode = "Markers"
      res@xyMarkers = 1
      res@xyMarkerColor = "black"
      res@xyMarkerSizeF = 0.015
      res@tiYAxisString = "Wind speed (m s~S~-1~N~)"
;Get r in meters
      res@tiXAxisString = "Radius (km)"
      res@tiYAxisFontHeightF = 0.015
      res@tiXAxisFontHeightF = 0.015
      res@tmXBLabelFontHeightF = 0.015
      res@tmYLLabelFontHeightF = 0.015
      res@tmYROn = False
   ;   res@tmXTOn = False
      res@gsnDraw = False
      res@gsnFrame = False
      plot = gsn_csm_xy(wks,Robs/km_to_m,Vobs,res)
      lineres = True
      lineres@gsLineColor = "blue"
      lineres@gsLineThicknessF = 5
      print( vmax)
      print( rmax)
      print( b)
      gsn_polyline(wks,plot,Rparam/km_to_m,Vest,lineres)
      draw(plot)
      frame(wks)
      ;Return the parametric wind profile
      print( Vest)
   end do
end if

;Return wind profile
Vest!0 = "radius"
Vest&radius = Rparam/km_to_m
return(Vest)
end
