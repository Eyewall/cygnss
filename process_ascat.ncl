load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "/raid1/pduran/jm13/ncl/functions/tools.ncl"

;---------------------------------------------
; process_ascat.ncl 
; Patrick Duran
; 30 November 2018
; 
; Reads all ASCAT files in a directory and
; prints the filenames, along with the
; corresponding start and end times of each
; file, to a text file.
;---------------------------------------------

year = 2018
ascdir      = "/raid1/pduran/jm13/ascat/"+year+"/"
asctimefile = "/raid1/pduran/jm13/ascat/"+year+"/asctimes.txt"

timeunits= "seconds since 2016-1-1 00:00:00"
ascfilelist = systemfunc("ls "+ascdir+"*nc")
nascfiles = dimsizes(ascfilelist)
mintimes = new(nascfiles,"integer")
maxtimes = new(nascfiles,"integer")
do i=0,nascfiles-1
   unixi = i + 1
   print( "Processing ASCAT file "+unixi+" of "+nascfiles)
   ascfile   = addfile(ascfilelist(i),"r")
   asctimes := ascfile->time
   asctimes1d := ndtooned(asctimes)
   copy_VarMeta(asctimes,asctimes1d)
   ;Convert observation times of each file to a common unit
   asctimes_convert := round(cd_convert(asctimes1d,timeunits),3)
   mintimes(i) = min(asctimes_convert)
   maxtimes(i) = max(asctimes_convert)
end do
;Write to output file
header = [/"Time units: '"+timeunits+"'"/]
header2  = [/"                                            FILENAME                                            MIN TIME  MAX TIME"/]
outlist = [/ascfilelist,mintimes,maxtimes/]
write_table(asctimefile,"w",header,"%s")
write_table(asctimefile,"a",header2,"%s")
write_table(asctimefile,"a",outlist,"%s%09i%09i")
print( "Output written to "+asctimefile)
