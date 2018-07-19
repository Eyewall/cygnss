cygdir  = "/jm13/pduran/cygnss/testdir/"
haildir = "/jm13/pduran/hail-reports/"
outdir  = "/jm13/pduran/web/cygnss/ddm/"
timeunits = "seconds since 2016-1-1 00:00:00"
ignoreblockIIF = True

;-------------------------------;
;READ IN ALL OF THE CYGNSS FILES;   
;-------------------------------;
;Get number of CYGNSS files in directory and initialize arrays
;cygfiles  = systemfunc("ls "+cygdir+"*/level1/*nc")
cygfiles  = systemfunc("ls "+cygdir+"*nc")
ncygfiles = dimsizes(cygfiles)
;Maximum of 86400 obs times each day; up to 4 specular points per obs time
cygvers    = new(ncygfiles,"string")
cygtime    = new((/ncygfiles,86400/),"double")
filenames  = new((/ncygfiles,86400/),"string")
prn        = new((/ncygfiles,86400,4/),"byte")
cyglat     = new((/ncygfiles,86400,4/),"float")
cyglon     = new((/ncygfiles,86400,4/),"float")
do i=0,ncygfiles-1
   unixi = i + 1
   print( "Reading CYGNSS file "+unixi+" of "+ncygfiles)
   cygfilename = cygfiles(i)
   satnum  = systemfunc("echo "+cygfilename+" | awk -F'/' '{print $NF}' | awk -F'.' '{print $1}'")
   cygfile = addfile(cygfilename,"r")
   cygvers(i) = cygfile@title
   nsamples= dimsizes(cygfile->sample)
   cygtime  (i,:nsamples-1)   = cygfile->ddm_timestamp_utc
   prn      (i,:nsamples-1,:) = cygfile->prn_code    ;PRN code
   cyglat   (i,:nsamples-1,:) = cygfile->sp_lat
   cyglon   (i,:nsamples-1,:) = cygfile->sp_lon
   filenames(i,:nsamples-1)   = conform(nsamples,cygfilename,-1)
end do

;Ignore retrievals that use BlockIIF satellites
if(ignoreblockIIF)then
   print( "Ignoring retrievals computed using Block IIF satellites.")
   toignore = (/1,3,6,8,9,10,24,25,26,27,30,32/) ;PRN codes for BlockIIF sats
   do k=0,dimsizes(toignore)-1
      cyglat = where(prn.eq.toignore(k),cyglat@_FillValue,cyglat)
      cyglon = where(prn.eq.toignore(k),cyglon@_FillValue,cyglon)
   end do
   delete(prn) ;Don't need this anymore!
end if

;Since Level 1 files have 4 specular points per satellite per timestamp time,
;we need to conform cygtime to have the same rank & dimension sizes as cyglat.
ctime_conform = round(conform(cyglat,cygtime,(/0,1/)),3)
ctime_conform@units = timeunits

;Make CYNGSS time, lat, and lon arrays 1-D to make
;them easier to compare to hail files
ctime1d    = ndtooned(ctime_conform)
cyglat1d   = ndtooned(cyglat)
cyglon1d   = ndtooned(cyglon)
cygfiles1d = ndtooned(filenames)
ctime1d@units = cygtime@units
delete([/ctime_conform,cyglat,cyglon,filenames/])

;Convert CYGNSS time to common units
ctime = round(cd_convert(ctime1d,timeunits),3)

;Convert CYGNSS longitude to -180 to 180 coodinates
cyglon1d = 180 - cyglon1d

;--------------------------------------------------;
;LOOP THROUGH HAIL FILES AND GET CYGNSS LOCATIONS. ;
;PLOT DDM FOR EACH SPECULAR POINT IN THE HAIL FILES;
;--------------------------------------------------;
hailfiles = systemfunc("ls "+haildir+"*txt")
nhailfiles= dimsizes(hailfiles)
do i=0,nhailfiles-1
   unixi = i + 1
   print( "Reading hail report file "+unixi+" of "+nhailfiles)
   hailfile = hailfiles(i)
   hailreport = systemfunc("sed -n 1p "+hailfile)
   haildata := readAsciiTable(hailfile,10,"float",4)
   year  := toint(haildata(:,0))
   month := toint(haildata(:,1))
   day   := toint(haildata(:,2))
   hour  := toint(haildata(:,3))
   minu  := toint(haildata(:,4))
   sec   := toint(haildata(:,5))
   lat   := haildata(:,6)
   lon   := haildata(:,7)

   ;Loop through each specular point in the hail file
   nhailobs = dimsizes(year)
   hailtime := round(cd_inv_calendar(year,month,day,hour,minu,sec,timeunits,0),3)
   do j=0,nhailobs-1
      unixj = j + 1
      print( "Reading hail report "+unixj+" of "+nhailobs+" in file "+unixi+" of "+nhailfiles)
      ;Find CYGNSS observation time that matches
      indices:= ind((hailtime(j)-ctime).eq.0)
      if(all(ismissing(indices)))then
         continue
      end if
      print( indices)
   end do   ;Loop through each specular point in the hail file
end do   ;Loop through each hail file
