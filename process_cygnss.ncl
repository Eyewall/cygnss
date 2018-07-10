load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "/jm13/pduran/ncl/functions/tools.ncl"

;---------------------------------------------
; process_cygnss.ncl 
; Patrick Duran
; 10 July 2018
; 
; Reads a file containing best-track information
; and interpolates each storm in the file to
; 1-second time intervals.
; Then finds the CYGNSS file that corresponds to
; each time in the best-track file and finds
; all CYGNSS Level 2 wind speed observations 
; within a user-defined radius of the storm center.
;---------------------------------------------

trakfile = "/jm13/pduran/best-tracks/hurdat2-1851-2016-041117.txt"

;--------------------------;
;GET BEST TRACK INFORMATION;
;--------------------------;
;Get list of all storms in the file by finding all
;lines with only three columns. Then get number of
;storms in the file.
system("awk 'NF==3{print}{}' "+trakfile+" > stormlist.tmp")
nstorms    = toint(systemfunc("wc stormlist.tmp | awk '{print $1}'"))
stormids   = systemfunc("awk '{print $1}' stormlist.tmp | sed 's/,//g'")
stormnames = systemfunc("awk '{print $2}' stormlist.tmp | sed 's/,//g'")
print( stormnames)

;Loop through all storms
do i=0,nstorms-1
   stormid   = stormids(i)
   stormname = stormnames(i)
   ;Get lines for the current storm by printing all lines between
   ;the current storm ID line and the next storm ID line.
   if(i.ne.(nstorms-1))then
      system("awk '/"+stormid+"/{flag=1;next}/"+stormids(i+1)+"/{flag=0}flag' "+trakfile+" > currentstorm.tmp")
   else
      system("sed -n '/"+stormid+"/,$p' "+trakfile+" | sed '/"+stormid+"/d' > currentstorm.tmp")
   end if
   ;Read best-track data for the current storm (after deleting comma delimeters)
;   system("sed -i 's/,//g' currentstorm.tmp")
   yyyy    := toint(systemfunc("awk -F',' '{print $1}' currentstorm.tmp | cut -c 1-4"))
   mm      := toint(systemfunc("awk -F',' '{print $1}' currentstorm.tmp | cut -c 5-6"))
   dd      := toint(systemfunc("awk -F',' '{print $1}' currentstorm.tmp | cut -c 7-8"))
   hour    := toint(systemfunc("awk -F',' '{print $2}' currentstorm.tmp | sed 's/ //g' | cut -c 1-2"))
   minu    := toint(systemfunc("awk -F',' '{print $2}' currentstorm.tmp | sed 's/ //g' | cut -c 3-4"))
   landfall:= systemfunc("awk -F',' '{print $3}' currentstorm.tmp")
   stmtyp  := systemfunc("awk -F',' '{print $4}' currentstorm.tmp")
   lat     := tofloat(systemfunc("awk -F ',' '{print $5}' currentstorm.tmp"))
   lon     := tofloat(systemfunc("awk -F ',' '{print $6}' currentstorm.tmp"))
   ;Determine whether north or south latitude; east or west longitude
   norslat := systemfunc("awk '{print substr($5,5,5)}' currentstorm.tmp | sed 's/,//g'")
   eorwlon := systemfunc("awk '{print substr($6,5,5)}' currentstorm.tmp | sed 's/,//g'")
   ;Multiply any south latitudes or east longitudes by -1
   lat := where(norslat.eq."S",lat*-1,lat)
   lon := where(eorwlon.eq."E",lon*-1,lon)
   print( yyyy)
end do
