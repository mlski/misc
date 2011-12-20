#!/usr/bin/perl -w
# rev6.pl - shows PTR record for given IPv6 address
#	    using Net::DNS::Resolver perl module
# Author: Michal Lewandowski <mlski@wp.pl>
#
use strict;
use Net::DNS::Resolver;
use Cwd;

my $ipv6addr;	# global variable which contains ipv6 address from argument
		# passed to the script - from web interface or command line
my $showerror;	# wether show erros or not
my $rev6name;	# global variable which will contain reverse dns hostname

my @dns_servers = ('8.8.8.8', '8.8.4.4');  # specify DNS servers for queries (defaults are Google's public nameservers)
#my @dns_servers = ('127.0.0.1');

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
		print "Missing IPv6 address (usage: http://$ENV{HTTP_HOST}$ENV{SCRIPT_NAME}?address=2001:dead:beef::1)";
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

if ($ipv6addr !~ /[0-9a-f:]+/i) {
	showerror(1);
	exit 1;
}

my $_cwd = getcwd();
my $checkaddr = system("perl $_cwd/ipv6parser.pl $ipv6addr>/dev/null");

if ($checkaddr != 0) {
	showerror(2);
	exit 1;
}
else {
	my $res = Net::DNS::Resolver->new(nameservers => \@dns_servers);
	my $res_ans = $res->send("$ipv6addr");	# send request to dns servers
	my @answer = $res_ans->answer;		# store answer to @answer array
	for my $ans (@answer) {			# $ans is an array's element
						# (below) if $ans->type is PTR then save ptrdname
						# to $rev6name
		if ($ans->type eq 'PTR') { $rev6name = $ans->ptrdname; }
	}
}

if ($rev6name) {
	print "$ipv6addr => $rev6name\n";
} else {
	print "Can\'t resolve $ipv6addr\n";
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
		"IPv6 address contains illegal characters\n",
		"Bad IPv6 address\n"
	);
	if ($ENV{GATEWAY_INTERFACE}) { print '<br />'; }
	print "ERR: ",$errors[$_[0]];
}

