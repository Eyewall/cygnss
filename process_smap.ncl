load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "/raid1/pduran/jm13/ncl/functions/tools.ncl"

;---------------------------------------------
; process_smap.ncl 
; Patrick Duran
; 30 November 2018
; 
; Reads all SMAP files in a directory and
; prints the filenames, along with the
; corresponding start and end times of each
; file, to a text file.
;---------------------------------------------

year = 2018
smapdir      = "/raid1/pduran/jm13/smap/"+year+"/"
smaptimefile = "/raid1/pduran/jm13/smap/"+year+"/smaptimes.txt"

timeunits= "seconds since 2016-1-1 00:00:00"
smapfilelist = systemfunc("ls "+smapdir+"*nc")
nsmapfiles = dimsizes(smapfilelist)
mintimes = new(nsmapfiles,"integer")
maxtimes = new(nsmapfiles,"integer")
do i=0,nsmapfiles-1
   unixi = i + 1
   print( "Processing SMAP file "+unixi+" of "+nsmapfiles)
   smapfile   = addfile(smapfilelist(i),"r")
   smapyear = smapfile@year_of_observation
   smapmon  = smapfile@month_of_observation
   smapday  = toint(systemfunc("echo "+smapfilelist(i)+" | awk -F'/' '{print $NF}' | awk -F'_' '{print $7}'"))
   minuteofday := smapfile->minute
   smapmidnight = cd_inv_calendar(smapyear,smapmon,smapday,0,0,0,timeunits,0)
   smaptimes := smapmidnight + minuteofday*60.
   smaptimes1d := ndtooned(smaptimes)
   copy_VarMeta(smapmidnight,smaptimes1d)
   ;Convert observation times of each file to a common unit
   smaptimes_convert := round(cd_convert(smaptimes1d,timeunits),3)
   mintimes(i) = min(smaptimes_convert)
   maxtimes(i) = max(smaptimes_convert)
   print( mintimes(i))
   print( maxtimes(i))
end do
;Write to output file
header = [/"Time units: '"+timeunits+"'"/]
header2  = [/"                                            FILENAME                                            MIN TIME  MAX TIME"/]
outlist = [/smapfilelist,mintimes,maxtimes/]
write_table(smaptimefile,"w",header,"%s")
write_table(smaptimefile,"a",header2,"%s")
write_table(smaptimefile,"a",outlist,"%s%09i%09i")
print( "Output written to "+smaptimefile)
