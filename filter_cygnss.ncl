undef("filter_cygnss")
function filter_cygnss(YYYY,MM,DD,HH,mm,ss,eyediam,rmw,r34,r50,r64,radius,lat,lon,\
                       dt,searchtype,uncert_limit,wind_rad_compare_limit)
begin

print( "Reading and filtering CYGNSS observations for "+YYYY+MM+DD+" "+HH+":"+mm+":"+ss+"...")

;Get list of CYGNSS files and the times contained within each of them
cygdir = "/jm13/pduran/cygnss/"+YYYY+"/level2/"
cygfilelist = systemfunc("cat "+cygdir+"cygtimes.txt | sed '1,3d' | awk '{print $1}'")
cygmintimes = toint(systemfunc("cat "+cygdir+"cygtimes.txt | sed '1,3d' | awk '{print $2}'"))
cygmaxtimes = toint(systemfunc("cat "+cygdir+"cygtimes.txt | sed '1,3d' | awk '{print $3}'"))

;Convert selected time to units of cygtime
timeunits = systemfunc("sed -n 1p "+cygdir+"cygtimes.txt | awk -F\' '{print $2}'")
time = toint(cd_inv_calendar(toint(YYYY),toint(MM),toint(DD),toint(HH),toint(mm),toint(ss),timeunits,0))

;Get CYGNSS file name that corresponds to the best-track time.
;We will need to get another file in addition to this one if the
;best-track time is within dt of the beginning or ending time
;of the file. We will check this later.
timediffsmin := cygmintimes - time
timediffsmax := cygmaxtimes - time
cygfileind = ind(timediffsmax.ge.0.and.timediffsmin.le.0)
;If there is a CYGNSS outage, there might not be data
;at the best-track time. Check for this:
if(ismissing(cygfileind))then
   print( "filter_cygnss: No CYGNSS observations available at "+YYYY+MM+DD+HH+mm+ss)
   return(0)
else
   infile = cygfilelist(cygfileind)
   ;This loop exists so we can search multiple files for CYGNSS observations
   ;within dt of the best-track time.
   ;Only allows two iterations, which means that a maximum of two CYGNSS
   ;files can be read. This precludes using dt > 24 hours.
   do i=0,1
      ncinfile = addfile(infile,"r")
      ;Get time, lats, and lons of CYGNSS observations and wind speeds
      cygtimein := ncinfile->sample_time
      latsin    := ncinfile->lat
      lonsin    := ncinfile->lon
      vin       := ncinfile->yslf_nbrcs_wind_speed
      flags     := ncinfile->yslf_sample_flags
      uncertin  := ncinfile->yslf_nbrcs_wind_speed_uncertainty
;      vin       := ncinfile->fds_nbrcs_wind_speed
;      flags     := ncinfile->fds_sample_flags
;      uncertin  := ncinfile->wind_speed_uncertainty

      ;Convert flags array from short to binary and reverse the resulting
      ;bitmask array so we can compare it to YSLF status flags in metadata.
      bitmask := getbitsone(flags)
      bitmaskrev := bitmask(:,::-1)

      ;If the 1st bit is flipped, then there is a fatal error condition.
      ;If the 8th bit is flipped, then there is a fatal high wind speed error.
      ;If the 13th bit is flipped, then there is a low range-corrected gain.
      ;If the 14th bit is flipped, then there is non-fatal low-quality GPS
      ;antenna knowledge (usually Block IIf satellites.)
      ;We will only deal with values where these bits are not flipped.
      errorinds := ind(bitmaskrev(:,0).eq.1.or.bitmask(:,8).eq.1\
                       .or.bitmask(:,13).eq.1.or.bitmask(:,14).eq.1)
      latsin(errorinds) = latsin@_FillValue
      lonsin(errorinds) = lonsin@_FillValue
      vin(errorinds)    = vin@_FillValue

      if(i.eq.0)then
         cygtime = round(cd_convert(cygtimein,timeunits),3)
         lats    = latsin
         lons    = lonsin
         v       = vin
         uncert  = uncertin
      else
         ;Append the arrays from the new file to arrays from the previous file
         cygtimea:= array_append_record(cygtime,round(cd_convert(cygtimein,timeunits),3),0)
         latsa   := array_append_record(lats,latsin,0)
         lonsa   := array_append_record(lons,lonsin,0)
         va      := array_append_record(v,vin,0)
         uncerta := array_append_record(uncert,uncertin,0)
         ;Reset arrays to the new, concatenated arrays.
         cygtime := cygtimea
         lats    := latsa
         lons    := lonsa
         v       := va
         uncert  := uncerta
      end if

      ;Find distance between storm center and each CYGNSS retrieval
      dist := gc_latlon(lat,lon,lats,lons,2,4)

      ;Get only CYGNSS wind speed retrievals within time interval and search radius
      if(searchtype.eq."centered")then
         mintime = time - dt
         maxtime = time + dt
      else if(searchtype.eq."forward")then
         mintime = time
         maxtime = time + dt
      else if(searchtype.eq."backward")then
         mintime = time - dt
         maxtime = time
      end if
      end if
      end if
      selectioninds := ind(cygtime.ge.mintime.and.cygtime.le.maxtime.and.dist.le.radius)
      selectioninds_filtered := ind(cygtime.ge.mintime.and.cygtime.le.maxtime.and.dist.le.radius.and.uncert.lt.uncert_limit)

      ;Check if the beginning and ending times of the CYGNSS file are within dt of the
      ;best-track time. If so, we will need to read another file and concatenate the
      ;observations to the return array. If not, we can break out of the loop.
      if(mintime.lt.min(cygtime))then
         infile = cygfilelist(cygfileind-1)
         continue
      else if(maxtime.gt.max(cygtime))then
         infile = cygfilelist(cygfileind+1)
         continue
      else
         break
      end if
      end if
   end do

   ;Convert longitude from 0-360 to -180-180
   lons = mod((lons+180),360) - 180
   lons@valid_range := "(-180, 180)"

   ;If no obs available, return a scalar. Otherwise, return list of arrays.
   if(all(ismissing(selectioninds)))then
      print( "No CYGNSS observations within the selected time interval and search radius.")
      return(0)
   else
      ;Create output variables
      v_out         = v(selectioninds)
      v_filtered    = v(selectioninds_filtered)
      uncertainties = uncert(selectioninds)
      latsout       = lats(selectioninds)
      lonsout       = lons(selectioninds)
      lats_filtered = lats(selectioninds_filtered)
      lons_filtered = lons(selectioninds_filtered)
      return [/v_out,v_filtered,uncertainties,latsout,lonsout,lats_filtered,lons_filtered/]
   end if
end if
end
