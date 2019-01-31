load "/raid1/pduran/jm13/ncl/cygnss/read_sfmr.ncl"
load "/raid1/pduran/jm13/ncl/cygnss/map_sfmr.ncl"
load "/raid1/pduran/jm13/ncl/cygnss/azimuthal_avg.ncl"
load "/raid1/pduran/jm13/ncl/cygnss/plot_ike.ncl"
load "/raid1/pduran/jm13/ncl/cygnss/rad_azi.ncl"
load "/raid1/pduran/jm13/ncl/cygnss/montage_ike.ncl"
load "/raid1/pduran/jm13/ncl/cygnss/plot_ike_timeseries.ncl"
load "/raid1/pduran/jm13/ncl/cygnss/best_track_wind_profile.ncl"

bttype = 1  ;Best-track type (0=HURDAT2, 1=EBTRK)
basin = "NATL"
radius = 500
dthr = 3         ;Time period within which to seach (hours)
dt = dthr*60*60  ;Time period within which to search (seconds)
searchtype = "centered"   ;Valid options: "centered", "forward", or "backward"
                         ;Centered: Looks for obs within dt on each side of best-track time.
                         ;Forward: Looks for obs within dt after the best-track time.
                         ;Backward: Looks for obs within dt prior to the best-track time.
type = 0  ;0 = Azimuthal average using radial bins of width defined below
          ;2 = Morris and Ruf 2-parameter model
          ;3 = Morris and Ruf 3-parameter model (haven't been able to get this to converge!)
dr = 5   ;If type=0, width of radial bins
uncert_limit = 3.5   ;Filter out all obs with uncertainty greater than this (m/s)
wind_rad_compare_limit = 20  ;Filter out all obs that depart from the wind speed defined by
                             ;the best-track wind radii by more than +/- 20 m/s.
                             ;(See filter_cygnss.ncl for details.)
opt = "quadrant"  ;Valid options: "full" or "quadrant". "quadrant" will compute IKE in each
                  ;storm quadrant independently and sum the quadrant-IKE values. "full" will
                  ;azimuthally average across full circles and compute IKE using those avgs.
trakfile = "/raid1/pduran/jm13/best-tracks/ebtrk_atlc_2017.txt_interpolated"
trakfile1min = "/raid1/pduran/jm13/best-tracks/ebtrk_atlc_2017.txt_interpolated_1-minute"
timeunits = "seconds since 2016-1-1 00:00:00"


;------------------------------------;
;GET 1-MINUTE INTERPOLATED BEST-TRACK;
;DATA, WHICH WE WILL USE TO CALCULATE;
;RADIUS AND AZIMUTH FOR EACH SFMR OBS;
;------------------------------------;
print( "Reading 1-minute interpolated best-track file...")
stormname1min= systemfunc("awk '{print $2}' "+trakfile1min)
MMDDHHmm1min = systemfunc("awk '{print $3}' "+trakfile1min)
YYYY1min     = toint(systemfunc("awk '{print $4}' "+trakfile1min))
lat1min      = tofloat(systemfunc("awk '{print $5}' "+trakfile1min))
lon1min      = tofloat(systemfunc("awk '{print $6}' "+trakfile1min))*-1
MMDDHHmm1min_split = str_split_by_length(MMDDHHmm1min,2)
MM1min = toint(MMDDHHmm1min_split(:,0))
DD1min = toint(MMDDHHmm1min_split(:,1))
HH1min = toint(MMDDHHmm1min_split(:,2))
mm1min = toint(MMDDHHmm1min_split(:,3))
stormtime1min = round(cd_inv_calendar(YYYY1min,MM1min,DD1min,HH1min,mm1min,conform(mm1min,0,0),timeunits,0),3)
stormtime1min@units = timeunits

;-----------------------------------------;
;GET BEST TRACK INFORMATION FOR EACH STORM;
; TIME FOR WHICH WE WANT TO ESTIMATE IKE  ;
;-----------------------------------------;
btinput  = stringtochar(systemfunc("cat "+trakfile))
nlines = toint(systemfunc("wc "+trakfile)) 
r34int = new(4,"integer")
r50int = new(4,"integer")
r64int = new(4,"integer")
prevascfile = " "   ;Initialize variable used later to check if this is a new storm
do i=177,nlines-1
   print( "#####################################")
   print( "PROCESSING BEST-TRACK LINE "+i+" OF "+nlines)
   print( "#####################################")
   stormid   = tostring(btinput(i,0:5))
   stormname = str_squeeze(tostring(btinput(i,7:16)))
   MM        = tostring(btinput(i,17:18))
   DD        = tostring(btinput(i,19:20))
   HH        = tostring(btinput(i,21:22))
   YYYY      = tostring(btinput(i,24:27))
   mm        = "00"
   ss        = "00"
   lat       = tofloat(tostring(btinput(i,29:32)))
   lon       = tofloat(tostring(btinput(i,34:38)))*-1
   vmax      = tofloat(tostring(btinput(i,40:42)))*0.514444  ;Convert to m/s
   rmwint    = toint(tostring(btinput(i,49:51)))
   eyediamint= toint(tostring(btinput(i,53:55)))
   r34int    = toint(str_split_by_length(tostring(btinput(i,66:77)),3))
   r50int    = toint(str_split_by_length(tostring(btinput(i,79:90)),3))
   r64int    = toint(str_split_by_length(tostring(btinput(i,92:103)),3))
   rmwint@_FillValue = -99
   eyediamint@_FillValue = -99
   rmw     = round(rmwint*1.852,3)  ;Convert nm to km
   eyediam = round(eyediamint*1.852,1)
   r34     = round(r34int*1.852,1)
   r50     = round(r50int*1.852,1)
   r64     = round(r64int*1.852,1)
   r34@comment = "Indexes from 0 to 3 correspond to NE, SE, SW, NW quadrants, respectively."
   r50@comment = "Indexes from 0 to 3 correspond to NE, SE, SW, NW quadrants, respectively."
   r64@comment = "Indexes from 0 to 3 correspond to NE, SE, SW, NW quadrants, respectively."

   ;Set name of ASCII file to which we will print IKE values
   ascfilesfmr = "/raid1/pduran/jm13/web/sfmr/ascii/"+stormid+"-"+stormname+"-ike-"+searchtype+"-"+dthr+"h"+"-"+radius+"km-sfmr.txt"
   ascfileinit = "/raid1/pduran/jm13/web/sfmr/ascii/"+stormid+"-"+stormname+"-ike-"+searchtype+"-"+dthr+"h"+"-"+radius+"km-init.txt"

   ;Call function to read in SFMR data and filter it based on the user-defined criteria
   sfmrdata := read_sfmr(YYYY,MM,DD,HH,mm,ss,str_upper(stormname),lat,lon,radius,dt,searchtype)

   ;If there is a list of arrays, extract them and call SFMR mapping function.
   if(typeof(sfmrdata).eq."list")then
      sfmrv   := sfmrdata[0]
      sfmrlat := sfmrdata[1]
      sfmrlon := sfmrdata[2]
      sfmrtime:= sfmrdata[3]

      map_sfmr(stormname,stormid,YYYY,MM,DD,HH,mm,ss,vmax,rmw,r34,r50,r64,lat,lon,radius,\
               sfmrv,sfmrlat,sfmrlon,dt,searchtype)

      ;Compute distances and azimuths from storm center to each SFMR observation.
      ;This will use data from the 1-minute interpolated best-track file to compute
      ;(r,theta) using the storm center location interpolated to the time that each
      ;SFMR observation was retrieved.
      radazi := rad_azi(stormname1min,stormtime1min,lat1min,lon1min,stormname,sfmrlat,sfmrlon,sfmrtime)
;      radazi := rad_azi(lat,lon,sfmrlat,sfmrlon)
      Robs := radazi[0]
      azis := radazi[1]
      sfmrv@radii := Robs
      sfmrv@azimuths := azis

      ;Call function to create initial guess wind profile based on best-track wind radii.
      init = best_track_wind_profile(vmax,rmw,r34,r50,r64,radius,dr,0)

      ;Call function to compute azimuthal average of observations
      vavg := azimuthal_avg(lat,lon,sfmrlat,sfmrlon,sfmrv,radius,dr,opt)

      ;Fill missing values of vavg array using values from init array.
      vavg = where(ismissing(vavg),init,vavg)

      ;Only compute IKE for mean winds greater than 34 kt
      vavggt34kt := where(vavg.lt.17.4911,vavg@_FillValue,vavg)
      initgt34kt := where(init.lt.17.4911,init@_FillValue,init)
      if(all(ismissing(vavggt34kt)))then
         print( "No radial bin has an average wind greater than 34 kt. Can't compute IKE.")
         continue
      end if
      ;Compute IKE
      vdimsizes := dimsizes(vavg)
      if(dimsizes(vdimsizes).eq.1)then  ;Rank is 1 --> Average was computed around full circle
         ike = calc_ike(vavggt34kt,vavg&radius,opt)
         ike_init = calc_ike(initgt34kt,vavg&radius,opt)  ;IKE of initial wind profile
         ikeTJ = decimalPlaces(ike/1e12,3,True)
         ikeTJ_init = decimalPlaces(ike_init/1e12,3,True)
         ike_total = ikeTJ
         ike_total_init = ikeTJ_init
      else  ;Rank is 2 --> Average was computed quadrant-by-quadrant. Compute ike in each quadrant.
         ike = new(vdimsizes(0),"float")
         ike_init = new(vdimsizes(0),"float")
         do j=0,vdimsizes(0)-1
            ike(j) = calc_ike(vavggt34kt(j,:),vavg&radius,opt)
            ike_init(j) = calc_ike(initgt34kt(j,:),vavg&radius,opt)
         end do
         ikeTJ = decimalPlaces(ike/1e12,3,True)
         ikeTJ_init = decimalPlaces(ike_init/1e12,3,True)
         ;Check all quadrants for missing IKE. If missing, get last hour's estimate.
         ;This is no longer necessary, since using the initial wind profile to fill
         ;the gaps in observations eliminates any chance of missing IKE.
;         if(ismissing(ikeTJ(0)).and.ascfile.eq.prevascfile)then
;            newike = tofloat(systemfunc("tail -1 "+ascfile+" | awk '{print $7}'"))
;            ikeTJ(0) = newike
;         elseif(ismissing(ikeTJ(1)).and.ascfile.eq.prevascfile)then
;            newike = tofloat(systemfunc("tail -1 "+ascfile+" | awk '{print $8}'"))
;            ikeTJ(1) = newike
;         elseif(ismissing(ikeTJ(2)).and.ascfile.eq.prevascfile)then
;            newike = tofloat(systemfunc("tail -1 "+ascfile+" | awk '{print $9}'"))
;            ikeTJ(2) = newike
;         elseif(ismissing(ikeTJ(3)).and.ascfile.eq.prevascfile)then
;            newike = tofloat(systemfunc("tail -1 "+ascfile+" | awk '{print $10}'"))
;            ikeTJ(3) = newike
;         end if
         ikeTJ = where(ikeTJ.eq.-9999,ikeTJ@_FillValue,ikeTJ)
         ikeTJ_init = where(ikeTJ_init.eq.-9999,ikeTJ_init@_FillValue,ikeTJ_init)
         ike_total = sum(ikeTJ)/vdimsizes(0)
         ike_init_total = sum(ikeTJ_init)/vdimsizes(0)
      end if

      ;Print current estimates of IKE into ascii files
      ikeTJ@_FillValue = -9999.
      ikeTJ_init@_FillValue = -9999.
      ikestringsfmr = sprintf("%5.3f",ikeTJ(0))+" "+sprintf("%5.3f",ikeTJ(1))+" "+sprintf("%5.3f",ikeTJ(2))+" "+sprintf("%5.3f",ikeTJ(3))
      ikestringinit = sprintf("%5.3f",ikeTJ_init(0))+" "+sprintf("%5.3f",ikeTJ_init(1))+" "+sprintf("%5.3f",ikeTJ_init(2))+" "+sprintf("%5.3f",ikeTJ_init(3))
      outstringsfmr = YYYY+" "+MM+" "+DD+" "+HH+" "+mm+" "+ss+"   "+ikestringsfmr
      outstringinit = YYYY+" "+MM+" "+DD+" "+HH+" "+mm+" "+ss+"   "+ikestringinit
      if(ascfilesfmr.ne.prevascfile)then
         headerstring1 = "34-kt IKE [TJ] computed using SFMR supplemented by best-track wind radii"
         headerstring2 = "-------------------------------------------"
         headerstring3 = "YYYY MM DD HH mm ss ikeNE ikeSE ikeSW ikeNW"
         headerstring4 = "---- -- -- -- -- -- ----- ----- ----- -----"
         ;Print to SFMR output file
         system("echo "+headerstring1+" > "+ascfilesfmr)
         system("echo "+headerstring2+" >> "+ascfilesfmr)
         system("echo "+headerstring3+" >> "+ascfilesfmr)
         system("echo "+headerstring4+" >> "+ascfilesfmr)
         system("echo "+outstringsfmr+" >> "+ascfilesfmr)
         ;Print to init (first guess from best-track wind radii) output file
         headerstring1 = "34-kt IKE [TJ] computed using only best-track wind radii"
         system("echo "+headerstring1+" > "+ascfileinit)
         system("echo "+headerstring2+" >> "+ascfileinit)
         system("echo "+headerstring3+" >> "+ascfileinit)
         system("echo "+headerstring4+" >> "+ascfileinit)
         system("echo "+outstringinit+" >> "+ascfileinit)
         prevascfile = ascfilesfmr
      else
         system("echo "+outstringsfmr+" >> "+ascfilesfmr)
         system("echo "+outstringinit+" >> "+ascfileinit)
      end if

      ;Call procedure to plot wind profile and IKE
      plot_ike(stormname,stormid,YYYY,MM,DD,HH,mm,ss,vmax,rmw,radius,dt,type,dr,vavg,ikeTJ,sfmrv,opt,"sfmr",init)
      ;Call procedure to montage the plots
      montage_ike(stormname,stormid,YYYY,MM,DD,HH,mm,ss,searchtype,radius,dt,opt)
   end if
end do
;Plot time series of IKE for each storm
print( "Plotting time series of IKE for each storm...")
asciifiles_sfmr = systemfunc("ls /raid1/pduran/jm13/web/sfmr/ascii/*"+searchtype+"-"+dthr+"h-"+radius+"km-sfmr.txt")
asciifiles_init = systemfunc("ls /raid1/pduran/jm13/web/sfmr/ascii/*"+searchtype+"-"+dthr+"h-"+radius+"km-init.txt")
nfiles = dimsizes(asciifiles_sfmr)
do i=0,nfiles-1
   stormid = systemfunc("echo "+asciifiles_sfmr(i)+" | awk -F'/' '{print $NF}' | awk -F'-' '{print $1}'")
   stormname = systemfunc("echo "+asciifiles_sfmr(i)+" | awk -F'/' '{print $NF}' | awk -F'-' '{print $2}'")
   sfmrdata := readAsciiTable(asciifiles_sfmr(i),10,"float",4)
   initdata := readAsciiTable(asciifiles_init(i),10,"float",4)
   sfmrdata@_FillValue = -9999
   initdata@_FillValue = -9999
   YYYY  := sfmrdata(:,0)
   MM    := sfmrdata(:,1)
   DD    := sfmrdata(:,2)
   HH    := sfmrdata(:,3)
   mm    := sfmrdata(:,4)
   ss    := sfmrdata(:,5)
   ike_sfmr := sfmrdata(:,6:9)
   ike_init := initdata(:,6:9)
   plot_ike_timeseries(stormname,stormid,YYYY,MM,DD,HH,mm,ss,opt,searchtype,radius,dthr,ike_sfmr,ike_init,"sfmr")
end do
;Make ascii files prettier by replacing -9999.000 with -9999.
system("sed -i 's/-9999.000/-9999/g' /raid1/pduran/jm13/web/sfmr/ascii/*txt")
