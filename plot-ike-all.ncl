load "/raid1/pduran/jm13/ncl/cygnss/read_ascat.ncl"
load "/raid1/pduran/jm13/ncl/cygnss/read_sfmr.ncl"
load "/raid1/pduran/jm13/ncl/cygnss/read_smap.ncl"
load "/raid1/pduran/jm13/ncl/cygnss/filter_cygnss.ncl"
load "/raid1/pduran/jm13/ncl/cygnss/map_all.ncl"
load "/raid1/pduran/jm13/ncl/cygnss/map_cygnss.ncl"
load "/raid1/pduran/jm13/ncl/cygnss/best_track_wind_profile.ncl"
load "/raid1/pduran/jm13/ncl/cygnss/azimuthal_avg.ncl"
load "/raid1/pduran/jm13/ncl/cygnss/rad_azi.ncl"
load "/raid1/pduran/jm13/ncl/cygnss/ike.ncl"
load "/raid1/pduran/jm13/ncl/cygnss/plot_ike.ncl"
load "/raid1/pduran/jm13/ncl/cygnss/montage_ike.ncl"
load "/raid1/pduran/jm13/ncl/cygnss/plot_ike_timeseries.ncl"

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
;minobsdensity = 0 ;Minimum density of observations (#/km^2) required for IKE to be computed.
interpgap = 25 ;Interpolate across gaps in the radial wind profile less than or equal to (km)
timeunits = "seconds since 2016-1-1 00:00:00"
trakfile = "/raid1/pduran/jm13/best-tracks/ebtrk_atlc_2017.txt_interpolated"
trakfile1min = "/raid1/pduran/jm13/best-tracks/ebtrk_atlc_2017.txt_interpolated_1-minute"
outdir = "/raid1/pduran/jm13/web/cygnss/ike/all-interp-across-"+interpgap+"km/"

;-------------------------------------------------------------;
;Create output home directory and subdirectories, if necessary;
;-------------------------------------------------------------;
dirtest = systemfunc("test -d "+outdir+"; echo $?")
if(dirtest.eq.1)then
   system("mkdir "+outdir)
   system("mkdir "+outdir+"/ascii/")
   system("mkdir "+outdir+"/maps/")
   system("mkdir "+outdir+"/maps/"+searchtype)
   system("mkdir "+outdir+"/ike-windprofiles+maps_montage/")
   system("mkdir "+outdir+"/ike-windprofiles+maps_montage/"+searchtype)
end if

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
btinput_string = systemfunc("cat "+trakfile)
btinput = stringtochar(btinput_string)
nlines = toint(systemfunc("wc "+trakfile)) 
r34int = new(4,"integer")
r50int = new(4,"integer")
r64int = new(4,"integer")
prevascfile = " "   ;Initialize variable used later to check if this is a new storm
prevstormid = " "   ;Initialize variable used later to check if this is a new storm
do i=0,nlines-1
   print( "###################################################################")
   print( "PROCESSING BEST-TRACK LINE "+i+" OF "+nlines+" "+systemfunc("date"))
   print( "###################################################################")
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
   print( stormname+" "+MM+"/"+DD+"/"+YYYY+" "+HH+":"+mm)

   ;Check if we have a new storm. If we do, perform a few operations.
   if(stormid.ne.stormidprev)then
      ;Set up ASCII files for new storm
      ascfileinit = outdir+"/ascii/"+stormid+"-"+stormname+"-ike-"+searchtype+"-"+dthr+"h"+"-"+radius+"km-init.txt"
      ascfileall  = outdir+"/ascii/"+stormid+"-"+stormname+"-ike-"+searchtype+"-"+dthr+"h"+"-"+radius+"km-all.txt"
      headerstring1 = "34-kt IKE [TJ] computed using SFMR and CYGNSS data supplemented by best-track wind radii"
      headerstring2 = "------------------------------------------- ----- ------- ------ ----- -----------"
      headerstring3 = "YYYY MM DD HH mm ss ikeNE ikeSE ikeSW ikeNW nSFMR nCYGNSS nASCAT nSMAP obs density"
      headerstring4 = "---- -- -- -- -- -- ----- ----- ----- ----- ----- ------- ------ ----- -----------"
      system("echo "+headerstring1+" > "+ascfileall)
      system("echo "+headerstring2+" >> "+ascfileall)
      system("echo "+headerstring3+" >> "+ascfileall)
      system("echo "+headerstring4+" >> "+ascfileall)
      headerstring1 = "34-kt IKE [TJ] computed using only best-track wind radii"
      system("echo "+headerstring1+" > "+ascfileinit)
      system("echo "+headerstring2+" >> "+ascfileinit)
      system("echo "+headerstring3+" >> "+ascfileinit)
      system("echo "+headerstring4+" >> "+ascfileinit)
 
      ;Print wind profile arrays to NetCDF files.     

   end if

   ;Call function to create initial guess wind profile based on best-track wind radii.
   ;Proceed only if we have a best-track wind profile (sometimes we don't have all of
   ;the info we need to compute the init wind profile. For example, the initial entries
   ;for Arlene (2017) don't have an RMW, so we can't get a wind profile.)
   init = best_track_wind_profile(vmax,rmw,r34,r50,r64,radius,dr,0)
   if(all(ismissing(init)))then
      print( "Insufficient best track wind radii to compute initial guess wind profile...Skipping...")
      continue   ;Go to next best track entry.
   end if

   ;Call function to read in ASCAT data and filter it based on the user-defined criteria
;   ascdata := read_ascat(YYYY,MM,DD,HH,mm,ss,lat,lon,radius,dt,searchtype)
ascdata = 0
   ;Call function to read in SFMR data and filter it based on the user-defined criteria
;   sfmrdata := read_sfmr(YYYY,MM,DD,HH,mm,ss,str_upper(stormname),lat,lon,radius,dt,searchtype)
sfmrdata = 0
   ;Call function to read in SMAP data and filter it based on the user-defined criteria
;   smapdata := read_smap(YYYY,MM,DD,HH,mm,ss,lat,lon,radius,dt,searchtype)
smapdata = 0
   ;Call function to read in the CYGNSS data and filter it based on the user-defined criteria
   cygdata := filter_cygnss(YYYY,MM,DD,HH,mm,ss,eyediam,rmw,r34,r50,r64,radius,lat,lon,dt,searchtype,\
              uncert_limit,wind_rad_compare_limit)

   ;If there is a list of arrays for any variable, extract them and call mapping functions.
   ;Otherise, set the variable to a missing value.
   obsarraytypes = new(4,"string")
   obsarraytypes(0) = typeof(sfmrdata)
   obsarraytypes(1) = typeof(cygdata)
   obsarraytypes(2) = typeof(ascdata)
   obsarraytypes(3) = typeof(smapdata)
   if(any(obsarraytypes.eq."list"))then
      if(typeof(sfmrdata).eq."list")then
         sfmrv   := tofloat(sfmrdata[0])
         sfmrlat := sfmrdata[1]
         sfmrlon := sfmrdata[2]
         sfmrtime:= sfmrdata[3]
         nSFMR = dimsizes(.not.ismissing(sfmrv))
      else
         sfmrv   := -9999. 
         sfmrlat := -9999. 
         sfmrlon := -9999.
         sfmrtime:= -9999
         sfmrv@_FillValue    = -9999
         sfmrlat@_FillValue  = -9999
         sfmrlon@_FillValue  = -9999
         sfmrtime@_FillValue = -9999
         nSFMR    = 0
      end if 
      if(typeof(cygdata).eq."list")then
         cygv   := cygdata[2]
         cyglat := cygdata[6]
         cyglon := cygdata[7]
         cygtime:= cygdata[8]
         nCYGNSS = dimsizes(.not.ismissing(cygv))
      else
         cygv   := -9999. 
         cyglat := -9999. 
         cyglon := -9999.
         cygtime:= -9999
         cygv@_FillValue    = -9999
         cyglat@_FillValue  = -9999
         cyglon@_FillValue  = -9999
         cygtime@_FillValue = -9999
         nCYGNSS = 0
      end if
      if(typeof(ascdata).eq."list")then
         ascv   := ascdata[0]
         asclat := ascdata[1]
         asclon := ascdata[2]
         asctime:= ascdata[3]
         nASCAT  = dimsizes(.not.ismissing(ascv))
      else
         ascv   := -9999. 
         asclat := -9999. 
         asclon := -9999.
         asctime:= -9999
         ascv@_FillValue    = -9999
         asclat@_FillValue  = -9999
         asclon@_FillValue  = -9999
         asctime@_FillValue = -9999
         nASCAT  = 0
      end if
      if(typeof(smapdata).eq."list")then
         smapv   := smapdata[0]
         smaplat := smapdata[1]
         smaplon := smapdata[2]
         smaptime:= smapdata[3]
         nSMAP  = dimsizes(.not.ismissing(smapv))
      else
         smapv   := -9999. 
         smaplat := -9999. 
         smaplon := -9999.
         smaptime:= -9999
         smapv@_FillValue    = -9999
         smaplat@_FillValue  = -9999
         smaplon@_FillValue  = -9999
         smaptime@_FillValue = -9999
         nSMAP  = 0
      end if

      ;Concatenate all data into single arrays.
      vcat1    := array_append_record(sfmrv,cygv,0)
      vcat2    := array_append_record(vcat1,smapv,0)
      vcat     := array_append_record(vcat2,ascv,0)
      latcat1  := array_append_record(sfmrlat,cyglat,0)
      latcat2  := array_append_record(latcat1,smaplat,0)
      latcat   := array_append_record(latcat2,asclat,0)
      loncat1  := array_append_record(sfmrlon,cyglon,0)
      loncat2  := array_append_record(loncat1,smaplon,0)
      loncat   := array_append_record(loncat2,asclon,0)
      timecat1 := array_append_record(sfmrtime,cygtime,0)
      timecat2 := array_append_record(timecat1,smaptime,0)
      timecat  := array_append_record(timecat2,asctime,0)

      ;Compute distances and azimuths from storm center to each observation.
      ;This will use data from the 1-minute interpolated best-track file to compute
      ;(r,theta) using the storm center location interpolated to the time that each
      ;observation was retrieved.
      print( "Computing radius and azimuth of each wind observation...")
      radazi := rad_azi(stormname1min,stormtime1min,lat1min,lon1min,stormname,latcat,loncat,timecat)
      Robs := radazi[0]
      azis := radazi[1]
      vcat@radii := Robs
      vcat@azimuths := azis

      ;Call function to compute azimuthal average of observations, yielding radial
      ;wind profiles, interpolating across gaps smaller than interpgap.
      print( "Computing azimuthal average of observations...")
      vavg := azimuthal_avg(lat,lon,latcat,loncat,vcat,radius,dr,opt,interpgap)
      obs_density = vavg@obs_density_domain

      ;Check if the observation density meets the set cutoff value.
      ;If not, skip the rest of the loop and go to next time.
;      if(ismissing(obs_density))then
;         continue
;      elseif(obs_density.lt.minobsdensity)then
;         print( "OBSERVATION DENSITY SMALLER THAN CUTOFF VALUE. NO IKE ESTIMATE CREATED.")
;         continue
;      end if

      ;Call mapping function that creates a 4-panel plot of observations from each platform
      map_all(stormname,stormid,YYYY,MM,DD,HH,mm,ss,vmax,rmw,r34,r50,r64,lat,lon,radius,\
               sfmrv,sfmrlat,sfmrlon,cygv,cyglat,cyglon,ascv,asclat,asclon,smapv,smaplat,\
               smaplon,dt,searchtype,outdir)

      ;Fill missing values of vavg array using values from init array.
      vavg_nonfilled = vavg
      vavg = where(ismissing(vavg),init,vavg)

      ;Only compute IKE for mean winds greater than 34 kt
      print( "Computing IKE...")
      vavggt34kt := where(vavg.lt.17.4911,vavg@_FillValue,vavg)
      initgt34kt := where(init.lt.17.4911,init@_FillValue,init)
      if(all(ismissing(vavggt34kt)))then
         print( "No radial bin has an average wind greater than 34 kt. Can't compute IKE.")
         continue
      end if
      ;Compute IKE for both azimuthally averaged observations and for init wind profile
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
         ikeTJ = where(ikeTJ.eq.-9999,ikeTJ@_FillValue,ikeTJ)
         ikeTJ_init = where(ikeTJ_init.eq.-9999,ikeTJ_init@_FillValue,ikeTJ_init)
         ike_total = sum(ikeTJ)
         ike_init_total = sum(ikeTJ_init)
      end if

      ;Print current estimates of IKE into ascii files
      ikeTJ@_FillValue = -9999.
      ikeTJ_init@_FillValue = -9999.
      obs_density@_FillValue = 0.
      ikestringall = sprintf("%5.2f",ikeTJ(0))+" "+sprintf("%5.2f",ikeTJ(1))+" "+sprintf("%5.2f",ikeTJ(2))+" "+sprintf("%5.2f",ikeTJ(3))
      ikestringinit = sprintf("%5.2f",ikeTJ_init(0))+" "+sprintf("%5.2f",ikeTJ_init(1))+" "+sprintf("%5.2f",ikeTJ_init(2))+" "+sprintf("%5.2f",ikeTJ_init(3))
      outstringall = YYYY+" "+MM+" "+DD+" "+HH+" "+mm+" "+ss+"   "+ikestringall+" "+sprinti("%0.5i",nSFMR)+" "+sprinti("%0.7i",nCYGNSS)+" "+sprinti("%0.6i",nASCAT)+" "+sprinti("%0.6i",nSMAP)+" "+sprintf("%11.10f",obs_density)
      outstringinit = YYYY+" "+MM+" "+DD+" "+HH+" "+mm+" "+ss+"   "+ikestringinit
      system("echo "+outstringall+" >> "+ascfileall)
      system("echo "+outstringinit+" >> "+ascfileinit)

      ;Call procedure to plot wind profile and IKE
      print( "Plotting wind profiles...")
      plot_ike(stormname,stormid,YYYY,MM,DD,HH,mm,ss,vmax,rmw,radius,dt,type,dr,vavg,vavg_nonfilled,ikeTJ,vcat,opt,init,outdir)

      ;Call procedure to montage the plots
      print( "Montaging images...")
      montage_ike(stormname,stormid,YYYY,MM,DD,HH,mm,ss,searchtype,radius,dt,opt,outdir)

      ;Reset stormidprev
      stormidprev = stormid
   end if
end do
;Plot time series of IKE for each storm
print( "Plotting time series of IKE for each storm...")
asciifiles_all = systemfunc("ls "+outdir+"/ascii/*"+searchtype+"-"+dthr+"h-"+radius+"km-all.txt")
asciifiles_init = systemfunc("ls "+outdir+"/ascii/*"+searchtype+"-"+dthr+"h-"+radius+"km-init.txt")
nfiles = dimsizes(asciifiles_all)
do i=0,nfiles-1
   stormid = systemfunc("echo "+asciifiles_all(i)+" | awk -F'/' '{print $NF}' | awk -F'-' '{print $1}'")
   stormname = systemfunc("echo "+asciifiles_all(i)+" | awk -F'/' '{print $NF}' | awk -F'-' '{print $2}'")
   alldata := readAsciiTable(asciifiles_all(i),15,"float",4)
   initdata := readAsciiTable(asciifiles_init(i),10,"float",4)
   alldata@_FillValue = -9999
   initdata@_FillValue = -9999
   YYYY  := alldata(:,0)
   MM    := alldata(:,1)
   DD    := alldata(:,2)
   HH    := alldata(:,3)
   mm    := alldata(:,4)
   ss    := alldata(:,5)
   ike_all := alldata(:,6:9)
   ike_init := initdata(:,6:9)
   nsfmr   := alldata(:,10)
   ncygnss := alldata(:,11)
   nascat := alldata(:,12)
   nsmap := alldata(:,13)
   obs_density := alldata(:,14)
   plot_ike_timeseries(stormname,stormid,YYYY,MM,DD,HH,mm,ss,opt,searchtype,radius,dthr,ike_all,ike_init,nsfmr,ncygnss,nsmap,obs_density,outdir)
end do
system("sed -i 's/-9999\.00/-9999/g' "+outdir+"/ascii/*txt")
