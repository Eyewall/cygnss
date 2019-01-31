;------------------------------------------------
; level2-plot-spec-points.ncl
; Patrick Duran
; 06 August 2018
;
; Plots CYGNSS wind speed retrievals
; collected within a user-defined radius of
; a tropical cyclone and within a user-defined
; time interval.
; Plots show dots color-coded by wind speed and
; the location of the storm center.
;------------------------------------------------


cygdir = "/raid1/pduran/jm13/cygnss/"

NAME  = "IRMA" 
ID    = "201711L"

YYYY1 = "2017"    ;Beginning date and time (strings)
MM1   = "09"
DD1   = "06"
HH1   = "00"
mm1   = "00"
ss1   = "00"

YYYY2 = "2017"    ;Ending date and time (strings)
MM2   = "09"
DD2   = "06"
HH2   = "00"
mm2   = "00"
ss2   = "00"

radius = 300      ;Search radius (km)

outdir = "/raid1/pduran/jm13/web/cygnss/erc-cases/"+NAME+"-"+ID+"/"

infile = systemfunc("ls "+cygdir+YYYY1+"/stormfiles/"+NAME+"-searchrad"+radius+"km.nc")
ncinfile = addfile(infile,"r")

;Get time, lats, and lons of CYGNSS observations and wind speeds
cygtime := ncinfile->cygtime
lats    := ncinfile->lat
lons    := ncinfile->lon
v       := ncinfile->v

;Get storm track data
stormlat := ncinfile->stormlat
stormlon := ncinfile->stormlon
vmax     := ncinfile->vmax
pmin     := ncinfile->pmin

;Convert selected times to units of cygtime
cygtime@units = "seconds since 2016-1-1 00:00:00"
time1 = cd_inv_calendar(toint(YYYY1),toint(MM1),toint(DD1),toint(HH1),toint(mm1),toint(ss1),cygtime@units,0)
time2 = cd_inv_calendar(toint(YYYY2),toint(MM2),toint(DD2),toint(HH2),toint(mm2),toint(ss2),cygtime@units,0)

;Get the observations between the selected times
stormlats = stormlat({time1:time2})
stormlons = stormlon({time1:time2})
vmaxplot  = vmax({time1:time2})
latsplot = lats({time1:time2},:)
lonsplot = lons({time1:time2},:)
vplot    =    v({time1:time2},:)

;Source: https://gis.stackexchange.com/questions/201789/verifying-formula-that-will-convert-longitude-0-360-to-180-to-180
lons = mod((lons+180),360) - 180

;Plot locations of CYGNSS observations along the storm's entire track
outfilename = outdir+"windspeed-"+YYYY1+MM1+DD1+HH1+mm1+ss1+"-"+YYYY2+MM2+DD2+HH2+mm2+ss2+"-"+radius+"km.png"
mapwks = gsn_open_wks("png",outfilename)
mapres = True
mapres@gsnLeftStringFontHeightF = 0.015
mapres@gsnLeftString = "CYGNSS wind speeds within "+radius+"km of "+NAME+" ("+year+")"
mapres@mpMinLatF = min(latsplot)-0.5
mapres@mpMinLonF = min(lonsplot)-0.5
mapres@mpMaxLatF = max(latsplot)+0.5
mapres@mpMaxLonF = max(lonsplot)+0.5
mapres@gsnMaximize = True
mapres@gsnDraw = False
mapres@gsnFrame = False
map := gsn_csm_map(mapwks,mapres)
pmres = True
pmres@gsMarkerSizeF = 20
pmres@gsMarkerIndex = 1
pmres@gsMarkerColor = "green"
print( "Plotting CYGNSS points...")
dum := gsn_add_polymarker(mapwks,map,lonsplot,latsplot,pmres)

;Add storm symbols
txres = True
txres@txFontHeightF = 30.
txres@txFontThicknessF = 5.
txres@txFontColor = "red"
tdind := ind(vmaxplot.lt.34)
tsind := ind(vmaxplot.ge.34.and.vmaxplot.lt.64)
hurind:= ind(vmaxplot.ge.64)
if(.not.all(ismissing(tdind)))then
   print( "Adding TD symbols...")
   tdlats  := stormlats(tdind)
   tdlons  := stormlons(tdind)
   tdsymb  := conform(tdlats,"~F22~L",-1)
   dum1 := gsn_add_text(mapwks,map,tdsymb,tdlons,tdlats,txres)
end if
if(.not.all(ismissing(tsind)))then
   print( "Adding TS symbols...")
   tslats  := stormlats(tsind)
   tslons  := stormlons(tsind)
   tssymb  := conform(tslats,"~F35~m",-1)
   dum2 := gsn_add_text(mapwks,map,tssymb,tslons,tslats,txres)
end if
if(.not.all(ismissing(hurind)))then
   print( "Adding HURRICANE symbols...")
   hurlats := stormlats(hurind)
   hurlons := stormlons(hurind)
   hursymb  := conform(hurlats,"~F37~p",-1)
   dum2 := gsn_add_text(mapwks,map,hursymb,hurlons,hurlats,txres)
end if
draw(map)
frame(mapwks)
