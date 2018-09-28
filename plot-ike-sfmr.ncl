load "/jm13/pduran/ncl/cygnss/read_sfmr.ncl"
load "/jm13/pduran/ncl/cygnss/map_sfmr.ncl"
load "/jm13/pduran/ncl/cygnss/azimuthal_avg.ncl"
load "/jm13/pduran/ncl/cygnss/plot_ike.ncl"

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
trakfile = "/jm13/pduran/best-tracks/ebtrk_atlc_2017.txt"
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

   ;Call function to read in SFMR data and filter it based on the user-defined criteria
   sfmrdata := read_sfmr(YYYY,MM,DD,HH,mm,ss,str_upper(stormname),lat,lon,radius,dt,searchtype)
   ;If there is a list of arrays, extract them and call SFMR mapping function.
   if(typeof(sfmrdata).eq."list")then
      sfmrv   := sfmrdata[0]
      sfmrlat := sfmrdata[1]
      sfmrlon := sfmrdata[2]
      map_sfmr(stormname,stormid,YYYY,MM,DD,HH,mm,ss,vmax,rmw,r34,r50,r64,lat,lon,radius,\
               sfmrv,sfmrlat,sfmrlon,dt,searchtype)

      ;Call function to compute azimuthal average
      vavg = azimuthal_avg(lat,lon,sfmrlat,sfmrlon,sfmrv,radius,dr,1)
      print( vavg)
      exit
   end if
   ;Call procedure to compute and plot wind profile and IKE
;   plot_ike(stormname,stormid,basin,YYYY,MM,DD,HH,mm,ss,vmax,rmw,radius,lat,lon,dt,type,dr,uncert_limit)
end do
