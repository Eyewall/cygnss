load "/raid1/pduran/jm13/ncl/cygnss/read_sfmr.ncl"
load "/raid1/pduran/jm13/ncl/cygnss/read_smap.ncl"
load "/raid1/pduran/jm13/ncl/cygnss/azimuthal_avg.ncl"

;test = read_sfmr("2017","09","08","12","00","00","Irma",21.8,-74.7,500,3*60*60,"centered")
test = read_smap("2017","09","09","00","00","00",21.8,-74.7,500,3*60*60,"centered")
print( test)
;
;
;
;
;lats = (/31,30.5,30,29.5,29,29.5,30,30.5/) - 30.
;lons = (/-80,-79.5,-79,-79.5,-80,-80.5,-81,-80.5/) + 80.
;vals = (/20,20,20,20,20,20,20,20/)
;;lats = new(360,"float")
;;lons = new(360,"float")
;;vals = new(360,"float")
;;nggcog(0,0,1,lats,lons)
;;lons = mod((lons+180),360) - 180
;;vals = 20
;test = azimuthal_avg(0,0,lats,lons,vals,500,50,1)
;numobs = test@num_obs
;print( test)
;print( numobs)
