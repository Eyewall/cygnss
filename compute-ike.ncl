load "/jm13/pduran/ncl/cygnss/parametric-model-morris+ruf.ncl"
load "/jm13/pduran/ncl/cygnss/ike.ncl"

;------------------------------------------------
; compute-ike.ncl
; Patrick Duran
; 16 August 2018
;
; Takes as input a storm name, ID, basin, and
; date/time, and computes integrated kinetic
; energy using the parametric wind model of
; Morris & Ruf.
; Plots CYGNSS obs and parametric wind profile
; with IKE value printed on the plot.
;------------------------------------------------

NAME  = "KATIA" 
ID    = "201713L"
basin = "NATL"

YYYY = "2017"
MM   = "09"
DD   = "08"
HH   = "06"
mm   = "00"
ss   = "00"
radius = 200      ;Search radius (km)
cygdir = "/jm13/pduran/cygnss/"+YYYY+"/level2/"
outdir = "/jm13/pduran/web/cygnss/erc-cases/ike-windprofiles/"+NAME+"-"+ID+"/"
dt = 60*60*3      ;Time within which to search (s)
dthr = tostring(dt/3600)

system("mkdir "+outdir)

print( "Getting CYGNSS data... "+systemfunc("date"))

;Get the list of availble CYGNSS level-2 files and the beginning
;and ending times for each file, in units defined by timeunits.
cygfilelist = systemfunc("cat "+cygdir+"cygtimes.txt | sed '1,3d' | awk '{print $1}'")
cygmintimes = toint(systemfunc("cat "+cygdir+"cygtimes.txt | sed '1,3d' | awk '{print $2}'"))
cygmaxtimes = toint(systemfunc("cat "+cygdir+"cygtimes.txt | sed '1,3d' | awk '{print $3}'"))
timeunits = systemfunc("sed -n 1p "+cygdir+"cygtimes.txt | awk -F\' '{print $2}'")

;Convert selected time to units of cygtime
time = cd_inv_calendar(toint(YYYY),toint(MM),toint(DD),toint(HH),toint(mm),toint(ss),timeunits,0)

;Get CYGNSS file name
timediffsmin := cygmintimes - time
timediffsmax := cygmaxtimes - time
cygfileind = ind(timediffsmax.ge.0.and.timediffsmin.le.0)
;If there is a CYGNSS outage, there might not be data
;at the best-track time. Check for this:
if(ismissing(cygfileind))then
   yyyymmddhh = tostring(yyyy)+tostring(mm)+tostring(dd)+tostring(hour)
   print( "No CYGNSS observations available at "+YYYY+MM+DD+HH+mm+ss)
   exit
end if
infile = cygfilelist(cygfileind)
ncinfile = addfile(infile,"r")

;Get time, lats, and lons of CYGNSS observations and wind speeds
cygtimein := ncinfile->sample_time
lats      := ncinfile->lat
lons      := ncinfile->lon
v         := ncinfile->yslf_nbrcs_wind_speed

;Convert cygtime to common units
cygtime = cd_convert(cygtimein,timeunits)

;Convert longitude from 0-360 to -180-180
;Source: https://gis.stackexchange.com/questions/201789/verifying-formula-that-will-convert-longitude-0-360-to-180-to-180
lons = mod((lons+180),360) - 180
lons@valid_range := "(-180, 180)"

;Get storm track data
trackfilename = systemfunc("ls /jm13/pduran/cygnss/"+YYYY+"/stormfiles/"+NAME+"-searchrad300km.nc") 
trackfile = addfile(trackfilename,"r")
tracktimes:= trackfile->tracktime
stormlats := trackfile->stormlat
stormlons := trackfile->stormlon
vmaxs     := trackfile->vmax
pmins     := trackfile->pmin

;Get the observation at the selected time
stormlat = stormlats({time})
stormlon = stormlons({time})
vmax     = vmaxs({time})
pmin     = pmins({time})

;Find distance between storm center and each CYGNSS retrieval
dist = gc_latlon(stormlat,stormlon,lats,lons,2,4)

;Get only CYGNSS wind speed retrievals within time interval and search radius
mintime = time - dt
maxtime = time + dt
selectioninds = ind(cygtime.ge.mintime.and.cygtime.le.maxtime.and.dist.le.radius)

if(all(ismissing(selectioninds)))then
   print( "No CYGNSS observations within the selected time interval and search radius.")
   exit
end if

;These are the lats, lons, and wind speed observations of level-2 CYGNSS
;retrievals that meet the user-selected criteria.
cyglats = lats(selectioninds)
cyglons = lons(selectioninds)
Vobs    = v(selectioninds)
Robs    = gc_latlon(stormlat,stormlon,cyglats,cyglons,2,4)

;Call function to compute parameteric wind profile
print( "Running parametric wind model. This could take a few minutes... "+systemfunc("date"))
Vparam = MorrisRufModel(stormlat,basin,Vobs,Robs,2)
radii = Vparam&radius

;Call function to compute integrated kinetic energy
print( "Computing IKE... "+systemfunc("date"))
ike = calc_ike(Vparam,radii)
ikeTJ = decimalPlaces(ike/1e12,3,True)

print( ike)

;Plot wind profile with IKE value printed on the plot
outfilename = outdir+YYYY+MM+DD+HH+mm+ss+"-"+radius+"km-"+dthr+"h.png"
wks = gsn_open_wks("png",outfilename)
res = True
res@gsnMaximize = True
res@gsnLeftString = "CYGNSS observations (dots) and 2-parameter modeled wind profile (line)"
res@gsnLeftStringFontHeightF = 0.014
res@xyMarkLineMode = "Markers"
res@xyMarkers = 1
res@xyMarkerColor = "black"
res@xyMarkerSizeF = 0.015
res@tiYAxisString = "Wind speed (m s~S~-1~N~)"
res@tiXAxisString = "Radius (km)"
res@tiYAxisFontHeightF = 0.015
res@tiXAxisFontHeightF = 0.015
res@tmXBLabelFontHeightF = 0.015
res@tmYLLabelFontHeightF = 0.015
res@tmYLMode = "Manual"
res@tmYLTickStartF = 0.
res@tmYLTickEndF = 100.
res@tmYLTickSpacingF = 5.
res@tmYLMinorOn = False
res@trXMinF = 0.
if(basin.eq."NATL".or.basin.eq."EPAC")then
   res@trXMaxF = 200.
else
   res@trXMaxF = 300.
end if
res@trYMinF = 0.
res@trYMaxF = max((/max(Vobs),max(Vparam)/))
res@tmYROn = False
res@tmXTOn = False
res@gsnDraw = False
res@gsnFrame = False
plot = gsn_csm_xy(wks,Robs,Vobs,res)
lineres = True
lineres@gsLineColor = "blue"
lineres@gsLineThicknessF = 5
gsn_polyline(wks,plot,radii/1000.,Vparam,lineres)
txres = True
txres@txFontHeightF = 30.
txres@txFontThicknessF = 3.
txres@txFontColor = "red"
txres@txJust = "TopRight"
text = "IKE = "+ikeTJ+" TJ"
txdum = gsn_add_text(wks,plot,text,res@trXMaxF-1,res@trYMaxF-.1,txres)
draw(plot)
frame(wks)
