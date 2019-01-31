undef("montage_ike")
procedure montage_ike(NAME,ID,YYYY,MM,DD,HH,mm,ss,searchtype,radius,dt,option,outhomedir)
begin

winddir = outhomedir+"/ike-windprofiles/"+option+"/"+NAME+"-"+ID+"/"
mapdir  = outhomedir+"/maps/"+searchtype+"/"+NAME+"-"+ID+"/" 
montagehmdir = outhomedir+"/ike-windprofiles+maps_montage/"
montagedir1  = outhomedir+"/ike-windprofiles+maps_montage/"+searchtype+"/"
montagedir2  = outhomedir+"/ike-windprofiles+maps_montage/"+searchtype+"/"+radius+"km/"
montagedir   = montagedir2+NAME+"-"+ID+"/"

dthr = tostring(dt/3600)

;If output directory doesn't exist, create it.
dirstotest = (/montagehmdir,montagedir1,montagedir2,montagedir/)
do testdir=0,dimsizes(dirstotest)-1
   dirtest = systemfunc("test -d "+dirstotest(testdir)+"; echo $?")
   if(dirtest.eq.1)then
      system("mkdir "+dirstotest(testdir))
   end if
end do

windoutfilename = winddir+YYYY+MM+DD+HH+mm+ss+"-"+radius+"km-"+dthr+"h.png"
mapoutfilename  = mapdir+"windspeed-"+YYYY+MM+DD+HH+mm+ss+"-"+radius+"km-"+dthr+"h.png"
montagefilename = montagedir+YYYY+MM+DD+HH+mm+ss+"-"+radius+"km-"+dthr+"h.png"

print( "Writing montage to "+montagefilename)
system("montage "+mapoutfilename+" "+windoutfilename+" -trim -tile 2x2 -bordercolor white -border 5 -geometry +0+0 "+montagefilename)

end
