echo #################### MAKE SURE YOU'RE RUNNING FROM VSVARS32.BAT

ruby extconf.rb
nmake clean
nmake
mt -manifest frasm.so.manifest -outputresource:frasm.so;2
nmake install

