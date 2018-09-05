load "/jm13/pduran/ncl/cygnss/plot_ike.ncl"
load "/jm13/pduran/ncl/cygnss/map_cygnss.ncl"

bttype = 1  ;Best-track type (0=HURDAT2, 1=EBTRK)
basin = "NATL"
radius = 1000
dt = 3*60*60
type = 0  ;0 = Azimuthal average using radial bins of width defined below
          ;2 = Morris and Ruf 2-parameter model
          ;3 = Morris and Ruf 3-parameter model (haven't been able to get this to converge!)
dr = 50   ;If type=0, width of radial bins
uncert_limit = 4   ;Filter out all obs with uncertainty greater than this (m/s)

;--------------------------;
;GET BEST TRACK INFORMATION;
;--------------------------;
if(bttype.eq.0)then
   trakfile = "/jm13/pduran/best-tracks/hurdat2-2017.txt"
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
      do j=4,ntimes-1
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
         ;Call procedure to compute and plot wind profile and IKE
;         plot_ike(stormname,stormid,basin,YYYY,MM,DD,HH,mm,ss,vmax,rmw,radius,lat,lon,dt,type,dr,uncert_limit)
         ;Call procedure to plot map of CYGNSS observations
         map_cygnss(stormname,stormid,YYYY,MM,DD,HH,mm,ss,vmax,rmw,radius,lat,lon,dt,uncert_limit)
         ;Delete lat and lon variables to avoid warning:VarVarWrite during next iteration
         delete([/lat,lon/])
      end do   ;Times loop
   end do   ;Storms loop
else  ;bttype
   trakfile = "/jm13/pduran/best-tracks/ebtrk_atlc_2017.txt"
   btinput  = stringtochar(systemfunc("cat "+trakfile))
   nlines = toint(systemfunc("wc "+trakfile)) 
   do i=0,nlines-1
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
      rmwint@_FillValue = -99
      rmwkm     = rmwint*1.852  ;Convert nm to km
      rmw       = tostring(round(rmwkm,3))
      ;Call procedure to compute and plot wind profile and IKE
;      plot_ike(stormname,stormid,basin,YYYY,MM,DD,HH,mm,ss,vmax,rmw,radius,lat,lon,dt,type,dr,uncert_limit)
      ;Call procedure to plot map of CYGNSS observations
      map_cygnss(stormname,stormid,YYYY,MM,DD,HH,mm,ss,vmax,rmw,radius,lat,lon,dt,uncert_limit)
   end do
end if   ;bttype
