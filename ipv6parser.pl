#!/usr/bin/perl -w
# ipv6parser.pl - check wether IPv6 address is correct
# author: Michal Lewandowski <mlski@wp.pl>
#
use strict;
my $ipv6addr;	# global variable which contains ipv6 address from argument
		# passed to the script - from web interface or command line
my $showerror;	# wether show erros or not

if ($ENV{GATEWAY_INTERFACE}) {
	# if there is $ENV{GATEWAY_INTERFACE} set it means that script is being
	# executed from web interface, so to avoid 'Internal Server Error' just
	# print 'Content-Type'
	print "Content-Type: text\/html\n\n";
	
	# and add CGI module to process arguments from URI
	use CGI qw(:standard);
	$ipv6addr	= param('address');
	$showerror	= param('err') || 0;
	if (!$ipv6addr) {
		print "Missing IPv6 address (usage: http://host/ipv6parser.pl?address=2001:dead:beef::1)";
		exit 1;
	}
}
else {
	$ipv6addr = $ARGV[0];
	if (!$ARGV[0]) {
		print "\nUsage: ./$0 ipv6_address [0|1]\n\n";
		exit 1;
	}
	$showerror = $ARGV[1] || 0;
}

my @split_addr = split(/::/,$ipv6addr);	# Split address using '::' as delimiter and store address's parts in array

my @parts;	# Array which stores all parts of IPv6 address

for (@split_addr) {
	if ($#split_addr > 1) { showerror(1); }	# Raise error if there is more than one ::, code 1
						# because it means that address is incorrectly compressed
	for (split(/:/,$_)) {			# Now split address with ':' as delimiter.
		push @parts, $_;		# Insert into @parts array all address's parts
	}
}

if ($#split_addr == 1 && $#parts+1 > 7) { showerror(2); }	# code 2 - too much parts	
if ($#split_addr < 1 && $#parts+1 != 8) { showerror(3); }	# code 3 - uncompressed address without
								#          8 parts needed

# Loop below checks each part of IPv6 address. Characters allowed: 0-9 and a-f, length: min 1, max 4
for (@parts) {
	showerror(4) if ($_ !~ /^[a-f0-9]{1,4}$/i);	# code 4 - address's part has incorrect characters (allowed: 0-9,a-f)
}

# Print final result of parsing

print "OK: Address \'$ipv6addr\' is correct\n";
exit 0;			# Return code 0 means that address is correct.

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
		"IPv6 address is incorrectly compressed\n",
		"IPv6 address contains too much parts (only 8x16bits allowed)\n",
		"IPv6 address is has incorrect amount of parts (should contain 8x16 bits delimited with \':\')\n",
		"IPv6 address containts illegal characters (0-9, a-f allowed)\n"
	);
	if ($ENV{GATEWAY_INTERFACE}) { print '<br />'; }
	print "ERR: ",$errors[$_[0]];
}
