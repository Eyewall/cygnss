;------------------------------------------------
; post_process.ncl
; Patrick Duran
; 06 February 2019
;
; Reads in all netCDF files in a directory and
; find the number of radial bins with missing
; values in each quadrant. If this number
; exceeds the maximum number set by the user,
; the script will search for a time within dt
; hours of the current time and use the IKE
; estimate from that time in that quadrant
; for the current time, after scaling by the
; change in IKE from that time to the current
; time computed using the best track wind radii.
;
; ARGUMENTS
; ---------
; ncdir: Directory from which to get netCDF files
; maxmiss: Maximum number of missing radial bins
;          to allow in a given quadrant.
;------------------------------------------------

undef("post_process")
procedure post_process(ncdir:string,maxmiss:numeric)
begin

;Read in netCDF files.
filenames = systemfunc("ls "+ncdir+"*nc")
ncfiles = addfiles(filenames,"r")

;Loop through netCDF files and perform tasks.
nfiles = dimsizes(filenames)
do i=0,nfiles-1
   ;Read data
   ncfile = ncfiles[i]
   stormname= ncfile@stormname
   stormid  = ncfile@stormid
   ike      := ncfile->ike
   ike_init := ncfile->ike_init
   nobs     := ncfile->nobs
   vavg     := ncfile->vavg
   ntimes = dimsizes(ike(0,:))
   ;Loop through quadrants and times to get the
   ;number of radial bins with missing data at
   ;each time in each quadrant.
   bins_missing = new(dimsizes(nobs),"logical")
   bins_missing_interp = new(dimsizes(nobs),"logical")
   flags = new((/4,ntimes/),"logical")
   flags_interp = new((/4,ntimes/),"logical")
   do j=0,3
      do k=0,ntimes-1
         nobs_quad := nobs(j,:,k)
         ;Number of bins missing values before interpolation
         bins_missing(j,:,k) = ismissing(nobs_quad)
         nbins_missing = dimsizes(ind(bins_missing(j,:,k)))
         if(nbins_missing.gt.maxmiss)then
            flags(j,k) = True
         end if
         ;Number of bins missing values after interpolation
         bins_missing_interp(j,:,k) = ismissing(vavg(j,:,k))
         nbins_missing_interp = dimsizes(ind(bins_missing_interp(j,:,k)))
         if(nbins_missing_interp.gt.maxmiss)then
            flags_interp(j,k) = True
         end if
      end do
   end do
   print( ike(0,:))
   print( bins_missing_interp(0,:,96))
   exit
end do

end
