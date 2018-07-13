#!/bin/csh/

#mvfiles.sc
#Patrick Duran
#11 July 2018
#
#Will move files from the CYGNSS wget directory
#tree into a specified output directory.
#
set indir  = "/jm13/pduran/cygnss/2018/podaac-ftp.jpl.nasa.gov/allData/cygnss/L2/v2.0/2018/"
set outdir = "/jm13/pduran/cygnss/2018/"

cd $indir

ls -d */ > dirlist

set ndirs = `wc dirlist | awk '{print $1'}`

set i=1
while($i <= $ndirs)
   set dir = `sed -n $i'p' dirlist`
   echo $indir$dir
   cd $indir$dir
   mv *nc $outdir
   set i = `expr $i + 1`
   cd $indir
end
