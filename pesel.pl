#!/usr/bin/perl -w
# pesel.pl - sprawdź numer pesel. bardzo prawdopodobne, że działa poprawie.
#            przynajmniej działał dla mojego i paru innych mi znajomych.. =)
#
print "error\n" and exit if (!$ARGV[0]||$ARGV[0]!~/^\d{11}$/);
for(split(//,$ARGV[0])){$x++;if($x==11){$k=$_;last;}$s+=$_*((split(//,'1379137913'))[$x-1]%10);}
if($k==((10-($s%10))%10)){print"DOBRY\n";}else{print"ZLY\n";}
