#!/usr/bin/perl -w
# 6to4.pl - converts IPv4 address to IPv6 address using 6to4 rules
#	    and it's prefix 2002::/16; also prints config file for given
#	    OS (linux,mswin32,freebsd)
# Author: Michal Lewandowski <mlski@wp.pl>
use strict;

my $ipv4addr;		#global variable which contains ipv4 address from argument
			# passed to the script - from web interface or command line

my $showerror;		# wether show erros or not
my $printconfig;	# Available configurations: windows,linux,freebsd

if ($ENV{GATEWAY_INTERFACE}) {
	# if there is $ENV{GATEWAY_INTERFACE} set it means that script is being
	# executed from web interface, so to avoid 'Internal Server Error' just
	# print 'Content-Type'
	print "Content-Type: text\/html\n\n";
	
	# and add CGI module to process arguments from URI
	use CGI qw(:standard);
	$ipv4addr	= param('address');
	$showerror	= param('err') || 0;
	$printconfig	= param('config') || detectOS('www',$ENV{HTTP_USER_AGENT});
	if (!$ipv4addr) {
		print "Missing IPv4 address (usage: http://$ENV{HTTP_HOST}$ENV{SCRIPT_NAME}?address=192.168.0.1)";
		exit 1;
	}
}
else {
	$ipv4addr = $ARGV[0];
	if (!$ARGV[0]) {
		print "\nUsage: ./$0 ipv4_address [0|1] [linux|mswin32|freebsd|d]\n\n(\'d\' instead of OS name detects operating system)\n(0|1 - as a second parameter specifies if you want to print only error code or error message as well)\n\n";
		exit 1;
	}
	$showerror = $ARGV[1]?$ARGV[1]:0;
	$printconfig = ($ARGV[2] && $ARGV[2] =~ /^d$/)?detectOS('cmdl',$^O):$ARGV[2];
}

# check syntax of provided IPv4 address

if ($ipv4addr !~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/) {
	showerror(1);
}
else {
	# split address with '.' as delimiter; anonymous array (@_) will be returned by 'for' loop
	# and then each element of this array will be examined by 'if' statement
	for (split(/\./,$ipv4addr)) {
		if (scalar($_) > 255) {	# check if single octet of ipv4 address is bigger than 255
			showerror(1);
		}
	}
}

print "Twój adres IPv6: ",convert6to4($ipv4addr),"\n\n",$ENV{GATEWAY_INTERFACE}?'<br /><br />':"";

# If printconfig is set then print config for 6to4 for particular OS
if ($printconfig && $printconfig =~ /^(linux|freebsd|mswin32)$/i) {
	print config6to4($printconfig,$ipv4addr,convert6to4($ipv4addr));
}
else {
	showerror(2);	# code 2 - unknown OS type
}

# detectOS(detection_type,detection_string) - subroutine checks which operating system is being used
# Args:
#	1. detection_type - www basing on user agent; cmdl - basing on $^O perl variable
#	2. deteciont_string - for www should be $ENV{HTTP_USER_AGENT}; for cmdl - $^O
#
sub detectOS {
	my $d_type	= shift;
	my $d_string	= shift;

	if ($d_type eq 'cmdl') {
		if ($d_string !~ /^(linux|freebsd|mswin32)$/i) { return 'unknown'; }
		else { return $d_string; }
	}
	elsif ($d_type eq 'www') {
		if ($d_string =~ /(windows|win32)/i) { return 'mswin32'; }
		elsif ($d_string =~ /linux/i) { return 'linux'; }
		elsif ($d_string =~ /freebsd/i) { return 'freebsd'; }
		else { return 'unknown'; }
	}
	else {
		return 'internal error: incorrect detection type';
	}
}

sub convert6to4 {
	my @splitted_addr = split(/\./,$_[0]);	# split address with '.' and insert all octets into array
	my @hex_addr;	# stores hex values of ipv4 address
	my $prefix6to4 = '2002';
	for (@splitted_addr) {
		push @hex_addr,  sprintf "%02x", scalar($_);
	}
	return "$prefix6to4:$hex_addr[0]$hex_addr[1]:$hex_addr[2]$hex_addr[3]:0:0:0:0:1";
}

sub config6to4 {
	my $os		= shift;
	my $ipv4	= shift;
	my $ipv6	= shift;
	my %configs;

$configs{'linux'} = <<LINUXCONFIG;
ip tunnel add 6to4tunnel mode sit remote any local $ipv4 ttl 64
ip link set dev 6to4tunnel up
ip -6 addr add $ipv6/128 dev 6to4tunnel
ip -6 route add 2000::/3 via ::192.88.99.1 dev 6to4tunnel metric 1

or

ifconfig sit0 up
ifconfig sit0 add $ipv6/48
route -A inet6 add 2000::/3 gw ::192.88.99.1 dev sit0
LINUXCONFIG

$configs{'mswin32'} = <<WINDOWSCONFIG;
ipv6 rtu 2002::/16 2
ipv6 adu 2/$ipv6
ipv6 rtu ::/0 2/::192.88.99.1

or

netsh interface ipv6 6to4 set relay 192.88.99.1
WINDOWSCONFIG

$configs{'freebsd'} = <<FREEBSDCONFIG;
ifconfig gif0 create
ifconfig gif0 tunnel $ipv4 192.88.99.1
ifconfig gif0 inet6 alias $ipv6
route add -inet6 default -interface gif0
\n\n
FREEBSDCONFIG

if ($ENV{GATEWAY_INTERFACE}) { $configs{$os} =~ s/\n/\n<br \/>/g; }
return $configs{$os};

}

#
# showerror() - simple subroutine which prints error and exits with proper error code
#
sub showerror {
	print "ERR: code ($_[0])\n";
	if ($showerror && $showerror == 1) {
		printerror($_[0]);
	}
	exit $_[0];
}

sub printerror {
	my @errors = (
		"",
		"IPv4 address is incorrect\n",
		"Unknown OS - can\'t show config file for provided OS name. Available configurations: linux, mswin32, freebsd or \'d\' for OS detection\n"
	);
	if ($ENV{GATEWAY_INTERFACE}) { print '<br />'; }
	print "ERR: ",$errors[$_[0]];
}
