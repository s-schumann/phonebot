#!/usr/bin/perl

use strict;
use Net::LDAP;

my $ldapUsername = 'USER';
my $ldapPassword = 'PASS';
my $ldapHost = 'HOST';
my $ldapVersion = 3;
my $ldapSearch = 'SEARCHSTRING';

my $ldap = Net::LDAP->new ( $ldapHost ) or die "$@";
my $mesg = $ldap->bind ( $ldapUsername,
	password => $ldapPassword,
	version => $ldapVersion
	);
my $searchString='sn='.$ldapSearch;

#sub LDAPsearch {
#	my ($ldap,$searchString,$attrs,$base) = @_;

	# if they don't pass a base... set it for them
	#if (!$base ) { $base = "DC=example,DC=com"; }
	my $base = "DC=example,DC=com";

	# if they don't pass an array of attributes...
	# set up something for them

	#if (!$attrs ) { $attrs = [ 'sn', 'givenName', 'mobile', 'telephoneNumber' ]; }
	my $attrs = [ 'sn', 'givenName', 'mobile', 'telephoneNumber' ];

	my $result = $ldap->search ( base    => $base,
		scope   => "sub",
		filter  => $searchString,
		attrs   =>  $attrs );
#}

#my $result = LDAPsearch ( $ldap, "sn=$name" );

if ( $result->code ) {
	# if we've got an error... record it
	LDAPerror ( "Searching", $result );
}

sub LDAPerror {
	my ($from, $mesg) = @_;
	print "Return code: ", $mesg->code."\n";
	print "\tMessage: ", $mesg->error_name."\n";
	print " :",          $mesg->error_text."\n";
	print "MessageID: ", $mesg->mesg_id."\n";
	print "\tDN: ", $mesg->dn."\n";

	#---
	# Programmer note:
	#
	#  "$mesg->error" DOESN'T work!!!
	#
	#print "\tMessage: ", $mesg->error;
	#-----
}

my @entries = $result->entries;

my $entr;
foreach $entr ( @entries ) {
	print "DN: ", $entr->dn, "\n";

	my $attr;
	foreach $attr ( sort $entr->attributes ) {
		next if ( $attr =~ /;binary$/ ); # skip binary we can't handle
		print "  $attr : ", $entr->get_value ( $attr ) ,"\n";
	}
	print "#-------------------------------\n";
}

$ldap->unbind;
