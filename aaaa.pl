#!/usr/bin/perl -w
# aaaa.pl - check if given domain has correct AAAA record
# Author: Michal Lewandowski <mlski@wp.pl>
#
use strict;

my $domain;	# global variable which contains ipv6 address from argument
		# passed to the script - from web interface or command line
my $showerror;	# wether show erros or not

if ($ENV{GATEWAY_INTERFACE}) {
	# if there is $ENV{GATEWAY_INTERFACE} set it means that script is being
	# executed from web interface, so to avoid 'Internal Server Error' just
	# print 'Content-Type'
	print "Content-Type: text\/html\n\n";
	
	# and add CGI module to process arguments from URI
	use CGI qw(:standard);
	$domain	= param('domain');
	$showerror	= param('err') || 0;
	
	if (!$domain) {
		print "Missing domain (usage: http://$ENV{HTTP_HOST}$ENV{SCRIPT_NAME}?domain=host.example.pl)";
		exit 1;
	}
}
else {
	$domain = $ARGV[0];
	if (!$ARGV[0]) {
		print "\nUsage: ./$0 domain [0|1]\n\n";
		exit 1;
	}
	$showerror = $ARGV[1] || 0;
}

# check if dig exists
my $cmd = system("dig>/dev/null");
if ($cmd != 0) {
	showerror(2);
}

if ($domain !~ /^[0-9a-z\.\-]+\.[a-z]{2,5}$/i) {
	showerror(1);
	exit 1;
}


my $dig = `dig -t aaaa $domain |grep AAAA|grep -v \';\'|awk \'{print \$1,\$5}\'`;
if ($dig eq '') {
	print "There is now AAAA record for given domain - $domain.\n";
	exit 1;
}
else {
	if ($ENV{GATEWAY_INTERFACE}) { $_ =~ s/\n/\n<br \/>/g; }
	my ($d,$a) = split(/\s/,$dig);
	print "$d ==> $a\n";
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
		"Domain contains illegal characters or is incorrect\n",
		"Missing \'dig\' binary. Please install this tool before you start checking...\n"
	);
	if ($ENV{GATEWAY_INTERFACE}) { print '<br />'; }
	print "ERR: ",$errors[$_[0]];
}


