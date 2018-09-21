;---------------------------------------------
; process_sfmr.ncl 
; Patrick Duran
; 20 September 2018
; 
; Reads all files in a directory and creates
; a text file that contains 3 columns:
; FILENAME STORMNAME MINTIME  MAXTIME
; Mintime and maxtime correspond to the
; beginning and ending times of the
; corresponding SFMR observation file.
;---------------------------------------------

dir     = "/nfs/jm13/pduran/sfmr/2017/"
outfile = dir+"/sfmrtimes.txt"

;--------------------------------------;
;GET LIST OF AVAILABLE SFMR FILES AND  ;
;THE TIMES OF THE OBSERVATIONS, AND    ;
;PRINT TO OUTPUT FILE.                 ;
;--------------------------------------;
timeunits= "seconds since 2016-1-1 00:00:00"
filelist = systemfunc("ls "+dir+"*nc")
nfiles = dimsizes(filelist)
mintimes = new(nfiles,"integer")
maxtimes = new(nfiles,"integer")
stormname= new(nfiles,"string")
do i=0,nfiles-1
   unixi = i + 1
   print( "Processing SFMR file "+unixi+" of "+nfiles)

   ;Read dates, times and storm name from file
   f = addfile(filelist(i),"r")
   date := f->DATE
   time := f->TIME
   stormname(i) = str_upper(f@StormName)
   date@_FillValue = -9999
   time@_FillValue = -9999

   ;For some reason, the date is sometimes zero in
   ;the SFMR miles. Where this occurs, set date
   ;and time to missing.
   time = where(date.eq.0,time@_FillValue,time)
   date = where(date.eq.0,date@_FillValue,date)

   ;Time is stored as an integer, so need to prepend
   ;zeroes depending on how small the number is.
   timestr := tostring(time)
   timestr := where(time.eq.0,"0",timestr)
   timestr := where(time.lt.10,"0"+timestr,timestr)
   timestr := where(time.lt.100,"0"+timestr,timestr)
   timestr := where(time.lt.1000,"0"+timestr,timestr)
   timestr := where(time.lt.10000,"0"+timestr,timestr)
   timestr := where(time.lt.100000,"0"+timestr,timestr)

   ;Get hours, minutes, and seconds from time string
   timesplit := str_split_by_length(timestr,2)
   hour := toint(timesplit(:,0))
   minu := toint(timesplit(:,1))
   sec  := toint(timesplit(:,2))

   ;Get year, month, and day from date string
   datestr := tostring(date)
   datesplit := str_split_by_length(datestr,(/4,2,2/))
   year := toint(datesplit(:,0))
   mon  := toint(datesplit(:,1))
   day  := toint(datesplit(:,2))

   ;Convert observation times to a common unit and get min and max for each file
   sfmrtimes := round(cd_inv_calendar(year,mon,day,hour,minu,sec,timeunits,0),3)
   mintimes(i) = min(sfmrtimes)
   maxtimes(i) = max(sfmrtimes)
end do

;Write to output file
header = [/"Time units: '"+timeunits+"'"/]
header2  = [/"                     FILENAME                     MIN TIME  MAX TIME  STORM NAME"/]
print( stormname)
outlist = [/filelist,stormname,mintimes,maxtimes/]
write_table(outfile,"w",header,"%s")
write_table(outfile,"a",header2,"%s")
write_table(outfile,"a",outlist,"%s%s%09i%09i")
print( "Output written to "+outfile)
