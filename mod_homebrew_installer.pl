#!/usr/bin/perl

use strict;
use warnings;
use Fatal qw(open close);

my ($installer_org, $installer_modified);
my $a = @ARGV;
print "a: $a\n";

if (@ARGV == 2) {
	($installer_org, $installer_modified) = @ARGV;
}
else {
	die "usage: $0 INSTALLER_ORG INSTALLER_MODIFIED\n";
}

local undef $/;

open my $fh_org, '<', $installer_org;
my $installer_content = <$fh_org>;
close $fh_org;

$installer_content =~s/(\nhave_sudo_access\(\)\s+\{\s+)/$1return 1\n/s;
$installer_content =~s/(\nwait_for_user\(\)\s+\{\s+)/$1return\n/s;

open my $fh_mod, '>', $installer_modified;
print {$fh_mod} $installer_content;
close $fh_mod;

chmod 0775, $installer_modified;

print STDERR qq{Created modified homebrew installer "$installer_modified"\n};
exit 0;
