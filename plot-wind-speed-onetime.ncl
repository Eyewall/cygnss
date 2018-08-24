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
DD   = "10"
HH   = "06"
mm   = "00"
ss   = "00"
radius = 300      ;Search radius (km)
dt = 60*60*3      ;Time within which to search (s)
dthr = tostring(dt/3600)

cygdir = "/jm13/pduran/cygnss/"+YYYY+"/level2/"
outdir = "/jm13/pduran/web/cygnss/erc-cases/maps/"+NAME+"-"+ID+"/"

system("mkdir "+outdir)

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

latsplot = lats(selectioninds)
lonsplot = lons(selectioninds)
vplot    = v(selectioninds)

;Plot locations of CYGNSS observations along the storm's entire track
outfilename = outdir+"windspeed-"+YYYY+MM+DD+HH+mm+ss+"-"+radius+"km-"+dthr+"h.pdf"
print( "Writing to outout file "+outfilename)
mapwks = gsn_open_wks("pdf",outfilename)
;drawNDCGrid(mapwks)
mapres = True
mapres@gsnLeftStringFontHeightF = 0.015
mapres@gsnLeftString = "CYGNSS wind speeds within "+radius+"km and "+dthr+" h of "+NAME+\
                       " ("+YYYY+MM+DD+" "+HH+mm+" UTC)"
mapres@gsnLeftStringOrthogonalPosF = -0.0015
mapres@gsnPaperOrientation = "portrait"
mapres@mpDataBaseVersion = "HighRes"
mapres@mpMinLatF = min(latsplot)-0.5
mapres@mpMinLonF = min(lonsplot)-0.5
mapres@mpMaxLatF = max(latsplot)+0.5
mapres@mpMaxLonF = max(lonsplot)+0.5
mapres@mpGridAndLimbOn = True
mapres@mpGridLatSpacingF = 0.5
mapres@mpGridLonSpacingF = 0.5
mapres@pmTickMarkDisplayMode = "Always"
mapres@mpGridLineColor = "gray"
mapres@vpHeightF = 0.8
mapres@vpWidthF = 0.65
mapres@vpYF = 0.5
mapres@pmLabelBarHeightF = 0.2
mapres@gsnMaximize = True
mapres@gsnDraw = False
mapres@gsnFrame = False
map := gsn_csm_map(mapwks,mapres)
pmres = True
pmres@gsMarkerSizeF = 40
pmres@gsMarkerIndex = 1

;Loop through wind speed thresholds and plot dots for each threshold
;vthresh = (/0,10,20,30,40,50,60,70,80,90,100,110,120,130,140,150/)
;colors  = (/"aquamarine","cyan","cyan3","blue","chartreuse","green","green4","gold",\
;            "yellow3","orange","orangered","red","red4","magenta","magenta4","purple4"/)
colors = (/"lightcyan","lightcyan3","cyan","lightskyblue","deepskyblue3",\
           "blue","gold","gold2","orange","orange3",\
           "orangered","red","red4","orchid","orchid3",\
           "magenta","magenta4","purple4","black"/)
vthresh = (/0,5,10,15,20,25,30,35,40,45,50,55,60,65,70,75,80,85,90/)
;colors  = (/"cyan","cyan3","blue","green","green4","gold",\
;            "orange","red","red4","magenta"/)
nthresh = dimsizes(vthresh)
dum = new(nthresh,"graphic")
do i=0,nthresh-1
   if(i.ne.nthresh-1)then
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

;Attach label bar representing the colored dots
lbres = True
lbres@lbFillColors = colors
lbres@lbMonoFillPattern = True
lbres@lbFillPattern = 0
;lbres@lbBoxEndCapStyle = "TriangleBothEnds"
lbres@lbBoxMinorExtentF = 0.05
lbres@lbLabelAlignment = "ExternalEdges"
lbres@lbLabelStrings = array_append_record(vthresh,(vthresh(nthresh-1)+vthresh(1)-vthresh(0)),0)
lbres@lbLabelFontHeightF = 0.015
lbres@lbLabelOffsetF = 0.01
lbres@lbLabelAutoStride = False
lbres@lbLabelStride = 1
;lbres@lbOrientation = "horizontal"
;gsn_labelbar_ndc(mapwks,nthresh,tostring(vthresh),0.3,0.3,lbres)
lbres@lbOrientation = "vertical"
lbres@lbTitleString = "m s~S~-1"
lbres@lbTitleFontHeightF = 0.02
lbres@lbTitleJust = "BottomCenter"
gsn_labelbar_ndc(mapwks,nthresh,tostring(vthresh),0.665,0.85,lbres)

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
;maximize_output(mapwks,False)  ;Automatically draws map and advances wks
draw(map)
frame(mapwks)
