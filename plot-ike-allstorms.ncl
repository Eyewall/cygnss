load "/raid1/pduran/jm13/ncl/cygnss/filter_cygnss.ncl"
load "/raid1/pduran/jm13/ncl/cygnss/map_cygnss.ncl"
load "/raid1/pduran/jm13/ncl/cygnss/read_sfmr.ncl"
load "/raid1/pduran/jm13/ncl/cygnss/map_sfmr.ncl"
load "/raid1/pduran/jm13/ncl/cygnss/plot_ike.ncl"
load "/raid1/pduran/jm13/ncl/cygnss/montage_cygnss.ncl"

bttype = 1  ;Best-track type (0=HURDAT2, 1=EBTRK)
basin = "NATL"
radius = 500
dt = 3*60*60  ;Time period within which to search
searchtype = "centered"   ;Valid options: "centered", "forward", or "backward"
                         ;Centered: Looks for obs within dt on each side of best-track time.
                         ;Forward: Looks for obs within dt after the best-track time.
                         ;Backward: Looks for obs within dt prior to the best-track time.
type = 0  ;0 = Azimuthal average using radial bins of width defined below
          ;2 = Morris and Ruf 2-parameter model
          ;3 = Morris and Ruf 3-parameter model (haven't been able to get this to converge!)
dr = 50   ;If type=0, width of radial bins
uncert_limit = 3.5   ;Filter out all obs with uncertainty greater than this (m/s)
wind_rad_compare_limit = 20  ;Filter out all obs that depart from the wind speed defined by
                             ;the best-track wind radii by more than +/- 20 m/s.
                             ;(See filter_cygnss.ncl for details.)

;--------------------------;
;GET BEST TRACK INFORMATION;
;--------------------------;
if(bttype.eq.0)then
   trakfile = "/raid1/pduran/jm13/best-tracks/hurdat2-2017.txt"
   ;Get list of all storms in the file by finding all
   ;lines with only three columns. Then get number of
   ;storms in the file, storm IDs, and storm names.
   system("awk 'NF==3{print}{}' "+trakfile+" > stormlist.tmp")
   nstorms    = toint(systemfunc("wc stormlist.tmp | awk '{print $1}'"))
   stormids   = systemfunc("awk '{print $1}' stormlist.tmp | sed 's/,//g'")
   stormnames = systemfunc("awk '{print $2}' stormlist.tmp | sed 's/,//g'")
   
   ;Loop through all storms
   do i=0,nstorms-1
      unixi = i +1
      stormid   = stormids(i)
      stormname = stormnames(i)
      ;Get lines for the current storm by printing all lines between
      ;the current storm ID line and the next storm ID line.
      if(i.ne.(nstorms-1))then
         system("awk '/"+stormid+"/{flag=1;next}/"+stormids(i+1)+"/{flag=0}flag' "+trakfile+" > currentstorm.tmp")
      else
         system("sed -n '/"+stormid+"/,$p' "+trakfile+" | sed '/"+stormid+"/d' > currentstorm.tmp")
      end if
      ;Read best-track data for the current storm using comma delimeters
      year    := systemfunc("awk -F',' '{print $1}' currentstorm.tmp | cut -c 1-4")
      mon     := systemfunc("awk -F',' '{print $1}' currentstorm.tmp | cut -c 5-6")
      day     := systemfunc("awk -F',' '{print $1}' currentstorm.tmp | cut -c 7-8")
      hour    := systemfunc("awk -F',' '{print $2}' currentstorm.tmp | sed 's/ //g' | cut -c 1-2")
      minu    := systemfunc("awk -F',' '{print $2}' currentstorm.tmp | sed 's/ //g' | cut -c 3-4")
      landfall:= systemfunc("awk -F',' '{print $3}' currentstorm.tmp")
      stmtyp  := systemfunc("awk -F',' '{print $4}' currentstorm.tmp")
      lats    := tofloat(systemfunc("awk -F ',' '{print $5}' currentstorm.tmp"))
      lons    := tofloat(systemfunc("awk -F ',' '{print $6}' currentstorm.tmp"))
      ;Determine whether north or south latitude; east or west longitude
      norslat := systemfunc("awk '{print substr($5,5,5)}' currentstorm.tmp | sed 's/,//g'")
      eorwlon := systemfunc("awk '{print substr($6,5,5)}' currentstorm.tmp | sed 's/,//g'")
      ;Multiply any south latitudes or west longitudes by -1
      lats := where(norslat.eq."S",lats*-1,lats)
      lons := where(eorwlon.eq."W",lons*-1,lons)
      ;Loop through all times
      ntimes = dimsizes(lats)
      do j=0,ntimes-1
         unixj = j + 1
         print( "#######################################################################")
         print( "Processing time "+unixj+" of "+ntimes+" for storm "+unixi+" of "+nstorms)
         print( "#######################################################################")
         YYYY = year(j)
         MM   = mon(j)
         DD   = day(j)
         HH   = hour(j)
         mm   = minu(j)
         ss   = "00"
         lat  = lats(j)
         lon  = lons(j)
         rmw  = "N/A"
         ;Call procedure to plot map of CYGNSS observations
;         map_cygnss(stormname,stormid,YYYY,MM,DD,HH,mm,ss,vmax,rmw,radius,lat,lon,dt,uncert_limit)
;      map_cygnss(stormname,stormid,YYYY,MM,DD,HH,mm,ss,vmax,rmw,lat,lon,radius,v,cyglat,cyglon,v_filtered,lats_filtered,lons_filtered,dt,uncert_limit)
      exit
         ;Call procedure to compute and plot wind profile and IKE
;         plot_ike(stormname,stormid,basin,YYYY,MM,DD,HH,mm,ss,vmax,rmw,radius,lat,lon,dt,type,dr,uncert_limit)
         ;Delete lat and lon variables to avoid warning:VarVarWrite during next iteration
         delete([/lat,lon/])
      end do   ;Times loop
   end do   ;Storms loop
else  ;bttype
   trakfile = "/raid1/pduran/jm13/best-tracks/ebtrk_atlc_2017.txt"
   btinput  = stringtochar(systemfunc("cat "+trakfile))
   nlines = toint(systemfunc("wc "+trakfile)) 
   r34int = new(4,"integer")
   r50int = new(4,"integer")
   r64int = new(4,"integer")
   do i=0,nlines-1
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
      vmax      = toint(tostring(btinput(i,40:42)))
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
      ;Call function to read in the CYGNSS data and filter it based on the user-defined criteria
      cygdata := filter_cygnss(YYYY,MM,DD,HH,mm,ss,eyediam,rmw,r34,r50,r64,radius,lat,lon,dt,searchtype,\
                 uncert_limit,wind_rad_compare_limit)
      ;If there is a list of arrays, extract them and call CYGNSS mapping function.
      if(typeof(cygdata).eq."list")then
         v := cygdata[0]
         v_filtered := cygdata[1]
         uncert := cygdata[2]
         cyglat := cygdata[3]
         cyglon := cygdata[4]
         lats_filtered := cygdata[5]
         lons_filtered := cygdata[6]
         map_cygnss(stormname,stormid,YYYY,MM,DD,HH,mm,ss,vmax,rmw,r34,r50,r64,lat,lon,radius,v,uncert,\
                    cyglat,cyglon,v_filtered,lats_filtered,lons_filtered,dt,searchtype,uncert_limit)
      end if
      ;Call function to read in SFMR data and filter it based on the user-defined criteria
      sfmrdata := read_sfmr(YYYY,MM,DD,HH,mm,ss,str_upper(stormname),lat,lon,radius,dt,searchtype)
      ;If there is a list of arrays, extract them and call SFMR mapping function.
      if(typeof(sfmrdata).eq."list")then
         sfmrv   := sfmrdata[0]
         sfmrlat := sfmrdata[1]
         sfmrlon := sfmrdata[2]
         map_sfmr(stormname,stormid,YYYY,MM,DD,HH,mm,ss,vmax,rmw,r34,r50,r64,lat,lon,radius,\
                  sfmrv,sfmrlat,sfmrlon,dt,searchtype)
      end if
      ;If CYGNSS maps were created, montage them. Also include type of sfmrdata to determine
      ;whether or not to include SFMR map in montage.
      if(typeof(cygdata).eq."list")then
        montage_cygnss(stormname,stormid,YYYY,MM,DD,HH,mm,ss,searchtype,radius,dt,typeof(sfmrdata))
      end if
     ;Call procedure to compute and plot wind profile and IKE
;      plot_ike(stormname,stormid,basin,YYYY,MM,DD,HH,mm,ss,vmax,rmw,radius,lat,lon,dt,type,dr,uncert_limit)
   end do
end if   ;bttype
