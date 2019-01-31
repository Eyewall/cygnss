undef("montage_cygnss")
procedure montage_cygnss(NAME,ID,YYYY,MM,DD,HH,mm,ss,searchtype,radius,dt,sfmroutvartype)
begin

cygdir  = "/raid1/pduran/jm13/web/cygnss/maps/"+searchtype+"/"+NAME+"-"+ID+"/"
sfmrdir = "/raid1/pduran/jm13/web/sfmr/maps/"+searchtype+"/"+NAME+"-"+ID+"/" 
montagedir = "/raid1/pduran/jm13/web/cygnss/ike-windprofiles+maps_montage/"+searchtype+"/"+radius+"km/"
montagefilterdir = "/raid1/pduran/jm13/web/cygnss/filtered-windspeed-maps/"+searchtype+"/"+radius+"km/"
montageuncertdir = "/raid1/pduran/jm13/web/cygnss/windspeed+uncertainty-maps/"+searchtype+"/"+radius+"km/"

dthr = tostring(dt/3600)

;If output directory doesn't exist, create it.
dirstotest = (/montagedir,montagefilterdir,montageuncertdir/)
do testdir=0,dimsizes(dirstotest)-1
   dirtest = systemfunc("test -d "+dirstotest(testdir)+"; echo $?")
   if(dirtest.eq.1)then
      system("mkdir "+dirstotest(testdir))
   end if
end do

windoutfilename   = cygdir+"windspeed-"+YYYY+MM+DD+HH+mm+ss+"-"+radius+"km-"+dthr+"h.png"
filtoutfilename   = cygdir+"filtered-"+YYYY+MM+DD+HH+mm+ss+"-"+radius+"km-"+dthr+"h.png"
sfmroutfilename   = sfmrdir+"windspeed-"+YYYY+MM+DD+HH+mm+ss+"-"+radius+"km-"+dthr+"h.png"
uncertoutfilename = cygdir+"uncertainty-"+YYYY+MM+DD+HH+mm+ss+"-"+radius+"km-"+dthr+"h.png"
montageoutdir = montagefilterdir+NAME+"-"+ID+"/"
montagefilename = montageoutdir+YYYY+MM+DD+HH+mm+ss+"-"+radius+"km-"+dthr+"h.png"
montagefilename = montageoutdir+YYYY+MM+DD+HH+mm+ss+"-"+radius+"km-"+dthr+"h.png"

;If output directory doesn't exist, create it.
dirtest = systemfunc("test -d "+montageoutdir+"; echo $?")
if(dirtest.eq.1)then
   system("mkdir "+montageoutdir)
end if

print( "Writing montage to "+montagefilename)
;Montage wind speed and filtered wind speed maps
if(sfmroutvartype.ne."list")then   ;No SFMR; montage CYGNSS only
   system("montage "+windoutfilename+" "+filtoutfilename+" -trim -tile 1x2 -bordercolor white -border 5 -geometry +0+0 "+montagefilename)
else  ;There are SFMR data, so plot them along with CYGNSS
   system("montage "+windoutfilename+" "+sfmroutfilename+" "+filtoutfilename+" -trim -tile 2x2 -bordercolor white -border 5 -geometry +0+0 "+montagefilename)
end if

;Montage wind speed and uncertainty maps
montageoutdir = montageuncertdir+NAME+"-"+ID+"/"
montagefilename = montageoutdir+YYYY+MM+DD+HH+mm+ss+"-"+radius+"km-"+dthr+"h.png"
;If output directory doesn't exist, create it.
dirtest = systemfunc("test -d "+montageoutdir+"; echo $?")
if(dirtest.eq.1)then
   system("mkdir "+montageoutdir)
end if
system("montage "+windoutfilename+" "+uncertoutfilename+" -trim -tile 1x2 -bordercolor white -border 5 -geometry +0+0 "+montagefilename)

end
