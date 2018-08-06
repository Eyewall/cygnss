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

NAME  = "IRMA" 
ID    = "201711L"

YYYY = "2017"
MM   = "09"
DD   = "06"
HH   = "00"
mm   = "00"
ss   = "00"
radius = 300      ;Search radius (km)
dt = 60*60*3      ;Time within which to search (s)
dthr = tostring(dt/3600)

cygdir = "/jm13/pduran/cygnss/"+YYYY+"/level2/"
outdir = "/jm13/pduran/web/cygnss/erc-cases/"+NAME+"-"+ID+"/"

cygfilelist = systemfunc("cat "+cygdir+"cygtimes.txt | sed '1,3d' | awk '{print $1}'")
cygmintimes = toint(systemfunc("cat "+cygdir+"cygtimes.txt | sed '1,3d' | awk '{print $2}'"))
cygmaxtimes = toint(systemfunc("cat "+cygdir+"cygtimes.txt | sed '1,3d' | awk '{print $3}'"))

;Convert selected time to units of cygtime
timeunits = systemfunc("sed -n 1p "+cygdir+"cygtimes.txt | awk -F\' '{print $2}'")
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

;Get the observations between the selected times
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

latsplot = lats(selectioninds)
lonsplot = lons(selectioninds)
vplot    = v(selectioninds)

;Plot locations of CYGNSS observations along the storm's entire track
outfilename = outdir+"windspeed-"+YYYY+MM+DD+HH+mm+ss+"-"+radius+"km-"+dthr+"h.png"
mapwks = gsn_open_wks("png",outfilename)
drawNDCGrid(mapwks)
mapres = True
mapres@gsnLeftStringFontHeightF = 0.01
mapres@gsnLeftString = "CYGNSS wind speeds within "+radius+"km and "+dthr+" h of "+NAME+\
                       " ("+YYYY+MM+DD+" "+HH+mm+" UTC)"
mapres@mpMinLatF = min(latsplot)-0.5
mapres@mpMinLonF = min(lonsplot)-0.5
mapres@mpMaxLatF = max(latsplot)+0.5
mapres@mpMaxLonF = max(lonsplot)+0.5
mapres@gsnMaximize = False
mapres@gsnDraw = False
mapres@gsnFrame = False
map := gsn_csm_map(mapwks,mapres)
pmres = True
pmres@gsMarkerSizeF = 40
pmres@gsMarkerIndex = 1

;Loop through wind speed thresholds and plot dots for each threshold
vthresh = (/0,10,20,30,40,50,60,70,80,90,100,110,120,130,140,150/)
colors  = (/"aquamarine","cyan","cyan3","blue","chartreuse","green","green4","yellow",\
            "yellow3","orange","orangered","red","red4","magenta","magenta4","purple4"/)
dum = new(dimsizes(vthresh),"graphic")
do i=0,dimsizes(vthresh)-1
   if(i.ne.dimsizes(vthresh)-1)then
      indices := ind(vplot.ge.vthresh(i).and.vplot.lt.vthresh(i+1))
   else
      indices := ind(vplot.ge.vthresh(i))
   end if
   if(all(ismissing(indices)))then
      continue
   end if
   pmres@gsMarkerColor = colors(i)
   dum(i) = gsn_add_polymarker(mapwks,map,lonsplot(indices),latsplot(indices),pmres)
end do

;Add storm symbol
txres = True
txres@txFontHeightF = 30.
txres@txFontThicknessF = 5.
txres@txFontColor = "red"
if(vmax.lt.34)then
   symb  = "~F22~L"
else if(vmax.ge.34.and.vmax.lt.64)then
   symb  = "~F35~m"
else if(vmax.ge.64)then
   symb  = "~F37~p"
end if
end if
end if
dum1 := gsn_add_text(mapwks,map,symb,stormlon,stormlat,txres)
draw(map)
frame(mapwks)
