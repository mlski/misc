#!/usr/bin/perl -w
#  myquota.pl - mysql and disk space quota daemon (0.1 beta)
#
# Copyright (c) 2009 Michał Lewandowski, foristh@IRCNet,irc.perl.org,irc.freenode.net
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

use strict;
use DBI;
use POSIX qw(strftime);
use Fcntl qw(:flock);

# CONFIGURABLE SECTION
my $cmdDU	= '/usr/bin/du';
my $cmdAWK	= '/usr/bin/awk';
my $cmdQUOTA	= '/usr/sbin/repquota';
my $cmdGREP	= '/bin/grep';
my $dbdir	= '/var/lib/mysql/data/';	# Path to directory with mysql databases files.
my $devFS	= '/dev/hda3';			# Filesystem where user files are and where quota is set.
my $logFile	= '/var/log/myquota.log';	# Path to log file. If you don't want logging just comment this line using #
my $pidFile	= '/var/run/myquota.pid';	# Path to pidfile. If you don't want this functionality comment with #
my $sleepIval	= 30;				# Time in seconds between each checking of used disk space 
my $quotaIval	= 3;				# This value multiplied by $sleepIval gives us a time between
						# each checking of quota table (for 30sec $sleepIval we've got
						# 90sec etc.)

my $dbUser	= 'root';
my $dbPassword	= 'xxxxxxxx';
my $dbName	= 'mysql';
my $dbHost	= 'localhost';
# END OF: CONFIGURABLE SECTION

# SQL SECTION
my $sql_dsn	= 'DBI:mysql:database='.$dbName.':'.$dbHost;
my $sql_dbh	= DBI->connect($sql_dsn, $dbUser, $dbPassword, {RaiseError => 1, AutoCommit => 1}
		) or die "\n".'[ERROR] Couldn\'t connect to database.'."\n";
# END OF: SQL SECTION

# CODE SECTION
my (%userQs);
my $_qival = 0;

if($pidFile) {
	open(LOCK, '>', $pidFile) or die $!;
	flock(LOCK, LOCK_EX | LOCK_NB) or die "\n".'[ERROR] Can\'t lock the pidfile. Probably another instance already running...'."\n";
	print LOCK $$;
}

readQuota();

while (1) {
	if ($_qival == $quotaIval) {
		readQuota();
		$_qival = 0;
	}
	checkDBsize();
	foreach (keys %userQs) {
		next if (!$userQs{$_}[2]);	# if user don't have a database jump to next loop..
		my $_dudbSum = $userQs{$_}[0]+$userQs{$_}[2];
		# if disk usage and database size is bigger than quota size, then...
		if ($_dudbSum > $userQs{$_}[1]) {
			my $_overQuota = $_dudbSum-$userQs{$_}[1];
			for (my $i = 3; $i <= $#{$userQs{$_}}; $i++) {
			# value $#{userQs{$_}} is last index number from table @{$userQs{username}}
			# we start loop from 3 because databases names are placed in this table
			# starting from index number 3...
				my $sql_select = $sql_dbh->prepare("revoke INSERT,CREATE,UPDATE on\
							 $userQs{$_}[$i].* FROM $_\@localhost");
				$sql_select->execute();
				$sql_dbh->do('FLUSH PRIVILEGES');
			}
			reportOverQuota($_,$_overQuota);
		}
	}
	sleep $sleepIval;
	$_qival++;
}

sub checkDBsize {
	my ($_prevUser,$_prevDBsize,$dbSize);
	my $sql_select = $sql_dbh->prepare('SELECT user,db FROM db');
	   $sql_select->execute();
	while (my $sql_ref = $sql_select->fetchrow_hashref()) {
		#after fetchrow.. we've got $sql_ref{'user'} for username and {'db'} for database name
		next if (!$userQs{$sql_ref->{'user'}});	# skip to another loop if user doesn't exist in %userQs
							# it means user's quota equals 0
		if ($_prevUser && ($_prevUser eq $sql_ref->{'user'})) {
		# $_prevUser stores last username checked by fetchrow..if in next loop we've the same username
		# we increase $dbSize with $_prevDBsize (which is $dbSize from last loop)
			$dbSize = `$cmdDU -s $dbdir\/$sql_ref->{'db'}|$cmdAWK {'print \$1'}`; chomp($dbSize);
			$dbSize += $_prevDBsize;
		}
		else { $dbSize = `$cmdDU -s $dbdir\/$sql_ref->{'db'}|$cmdAWK {'print \$1'}`; chomp($dbSize); }
		$userQs{$sql_ref->{'user'}}[2] = $dbSize;	# after readQuota() we've got %userQs filled with
								# usernames as keys and their values: user disk space
								# and quota size. now we push another value to anonymous
								# table (as [2]) - user databases size
		push (@{$userQs{$sql_ref->{'user'}}}, $sql_ref->{'db'});
		$_prevUser = $sql_ref->{'user'}; $_prevDBsize = $dbSize;
	}
}

sub readQuota {
	# readQuota() saves output from repquota command to %usersQs hash
	# where usernames are keys and values are tables with two values:
	# [0] is for used disk space, [1] is for quota size.
	for (`$cmdQUOTA $devFS`) {
		if ($_ =~ /^([\d\w]+)\s+[\-]+\s+(\d+)\s+(\d+)/) {
			next if ($3 == 0);	# skip to another loop if user quota equals 0
			$userQs{$1} = [$2,$3];
		}
	}
}

sub reportOverQuota {
	my $_time = strftime "%D %H:%M:%S", localtime;
	if ($logFile) {
		open (LOGFILE, '>>',$logFile) or die $!;
		print LOGFILE "[$_time] USER: $_[0], OVER QUOTA: ${_[1]}kbytes\n";
		close LOGFILE;
	}
}
