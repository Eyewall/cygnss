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
filenames_conform = conform(cyglat,filenames,(/0,1/))

;Make CYNGSS time, lat, and lon arrays 1-D to make
;them easier to compare to hail files
ctime1d    = ndtooned(ctime_conform)
cyglat1d   = ndtooned(cyglat)
cyglon1d   = ndtooned(cyglon)
cygfiles1d = ndtooned(filenames_conform)
ctime1d@units = cygtime@units
delete([/ctime_conform,cyglat,cyglon,filenames/])

;Convert CYGNSS time to common units
ctime = round(cd_convert(ctime1d,timeunits),3)

;Convert CYGNSS longitude to -180 to 180 coodinates
;Source: https://gis.stackexchange.com/questions/201789/verifying-formula-that-will-convert-longitude-0-360-to-180-to-180
cyglon1d = mod((cyglon1d(indices)+180),360) - 180 

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
   dx    := haildata(:,8)
   dt    := haildata(:,9)

   ;Loop through each specular point in the hail file
   nhailobs = dimsizes(year)
   hailtime := round(cd_inv_calendar(year,month,day,hour,minu,sec,timeunits,0),3)
   do j=0,nhailobs-1
      unixj = j + 1
      print( "Reading hail report "+unixj+" of "+nhailobs+" in file "+unixi+" of "+nhailfiles)
      ;Find CYGNSS observation that matches time
      indices:= ind((hailtime(j)-ctime).eq.0)
      if(all(ismissing(indices)))then
         print( "CYGNSS time don't match! Moving on...")
         continue
      end if
      ;Find observation that matches location
      dist = gc_latlon(lat(j),lon(j),cyglat1d(indices),cyglon1d(indices),2,4)
      mindistind = indices(minind(dist))
      cygfilename = cygfiles1d(mindistind)      
      ;Read CYGNSS file and plot DDM
      cygfile = addfile(cygfilename,"r")
;      brcs    = cygfile->brcs
      brcs    = cygfile->power_analog
;      brcs    = cygfile->eff_scatter
      spdelay = cygfile->sp_precise_delay ;Specular point delay in chips (1/1,023,000 s).
      spdopp  = cygfile->sp_precise_dopp  ;Specular point Doppler in Hz.
      delayres= cygfile->delay_resolution ;DDM delay bin resolution in chips.
      doppres = cygfile->dopp_resolution  ;DDM Doppler bin resolution in Hz.
      spdelayrow = round(cygfile->brcs_ddm_sp_bin_delay_row,3)
      spdoppcol  = round(cygfile->brcs_ddm_sp_bin_dopp_col,3)
      ;Make arrays 1-D to make them easier to deal with
;      printVarSummary( brcs)
      ;FOR NOW, JUST PICK AN INDEX...
      printMinMax(spdelay,0)
      pdfopt = True
      pdfopt@bin_min = -10
      pdfopt@bin_max = 10
      delaypdf = pdfx(spdelay,10,pdfopt)
      sampleind = 36000
      ddmind    = 2
      ;Get appropriate BRCS for this sample time and DDM index
      brcsvals := brcs(sampleind,ddmind,:,:)
      ;Get delay and doppler values for this DDM
      delays  = new(17,"float")
      doppler = new(11,"float")
      delays = 0
      doppler = 0
      ;Set the delay and Doppler at the specular point
      thisspdelayrow = spdelayrow(sampleind,ddmind)
      thisspdoppcol  = spdoppcol (sampleind,ddmind)
      delays (thisspdelayrow) = spdelay(sampleind,ddmind)
      doppler(thisspdoppcol ) = spdopp (sampleind,ddmind)
      ;Set the delay and Doppler at the rest of the points
      delayinds = ispan(0,16,1)
      doppinds  = ispan(0,10,1)
      delayindsrel = delayinds - thisspdelayrow
      doppindsrel  = doppinds - thisspdoppcol
      delays = (delayindsrel*delayres)+delays(thisspdelayrow)
      doppler= (doppindsrel*doppres)+delays(thisspdoppcol)
      brcsvals!0 = "delay"
      brcsvals!1 = "doppler"
      brcsvals&delay = delays
      brcsvals&doppler = doppler/1000. ;Convert to kHz
      printMinMax(delays,0)
      ;Plot the DDM!
      filename = "/jm13/pduran/web/ddm.png"
      wks = gsn_open_wks("png",filename)
      gsn_define_colormap(wks,"BlGrYeOrReVi200")
      res = True
      res@cnFillMode = "RasterFill"
      res@cnFillOn   = True
      res@cnLinesOn  = False
      res@cnLevelSelectionMode = "ManualLevels"
      res@cnMinLevelValF = 1e-20
      res@cnMaxLevelValF = 1e-18
      res@cnLevelSpacingF = 5e-20
      res@tiYAxisString = "Delay (chips) (1 chip = 1/1,023,000 s)"
      res@tiXAxisString = "Doppler (kHz)"
      res@lbOrientation = "vertical"
      res@tmYROn = False
      res@tmXTOn = False
      res@cnInfoLabelOn = False
      res@cnLineLabelsOn = False
      plot = gsn_csm_contour(wks,brcsvals,res)
   end do   ;Loop through each specular point in the hail file
end do   ;Loop through each hail file
