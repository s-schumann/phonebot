#!/usr/bin/perl

use strict;
use utf8;
use AnyEvent;
use AnyEvent::XMPP::Client;
use AnyEvent::XMPP::Ext::Disco;
use AnyEvent::XMPP::Ext::Version;
use AnyEvent::XMPP::Namespaces qw/xmpp_ns/;
use Net::LDAP;

my @msgs;
my $jid = 'USER@HOST';
my $pw = 'PASS';

my $ldapUsername = 'USER';
my $ldapPassword = 'PASS';
my $ldapHost = 'HOST';
my $ldapVersion = 3;

binmode STDOUT, ":utf8";

my $j       = AnyEvent->condvar;
my $cl      = AnyEvent::XMPP::Client->new (debug => 1);
my $disco   = AnyEvent::XMPP::Ext::Disco->new;
my $version = AnyEvent::XMPP::Ext::Version->new;

$cl->add_extension ($disco);
$cl->add_extension ($version);

$cl->set_presence (undef, 'Tell me a name and I\'ll give you details...', 1);

$cl->add_account ($jid, $pw);
warn "connecting to $jid...\n";

$cl->reg_cb (
	session_ready => sub {
		my ($cl, $acc) = @_;
		warn "connected!\n";
	},

	message => sub {
		my ($cl, $acc, $msg) = @_;
		my $colleague;
		my $repl = $msg->make_reply;
		my $answer;
		my %result;

		my $ldap = Net::LDAP->new ( $ldapHost ) or die "$@";
		my $mesg = $ldap->bind ( $ldapUsername,
			password => $ldapPassword,
			version => $ldapVersion
		);
		warn "binding to LDAP...\n";
		print "MESSAGE: $msg\n";
		$mesg = $ldap->search (
			base    => "DC=example,DC=com",
			scope   => "sub",
			filter  => "sn=$msg",
			attrs   =>  [ 'sn', 'givenName', 'mobile', 'telephoneNumber' ] );
		#$mesg->code && die $mesg->error;
		#if ( $result->code ) {
		#	# if we've got an error... record it
		#	my ($from, $mesg) = @_;
		#	print "Return code: ", $mesg->code;
		#	print "\tMessage: ", $mesg->error_name;
		#	print " :",          $mesg->error_text;
		#	print "MessageID: ", $mesg->mesg_id;
		#	print "\tDN: ", $mesg->dn;
		#};
		my @entries = $mesg->entries;
		my $entr;
		foreach $entr ( @entries ) {
			print "DN: ".$entr->dn."\n";
			my $attr;
			foreach $attr ( sort $entr->attributes ) {
				next if ( $attr =~ /;binary$/ ); # skip binary we can't handle
				print "  $attr : ", $entr->get_value ( $attr ) , "\n";
				$result{$attr} = $entr->get_value ( $attr );
			}
			$answer = $answer."Name: ".$result{givenName}." ".$result{sn}."\n";
			$answer = $answer."Phone: ".$result{telephoneNumber}." - Mobile: ".$result{mobile}."\n";
			print "#-------------------------------\n";
		};
		$mesg = $ldap->unbind;
		warn "LDAP unbind...\n";
		$repl->add_body ("Results for '".$msg->any_body."' should be here:\n$answer");
		warn "Got message: '".$msg->any_body."' from ".$msg->from."\n";
		#warn "Answered: $colleagues\n";
		$repl->send;
	},

	contact_request_subscribe => sub {
		my ($cl, $acc, $roster, $contact) = @_;
		$contact->send_subscribed;
		warn "Subscribed to ".$contact->jid."\n";
	},

	error => sub {
		my ($cl, $acc, $error) = @_;
		warn "Error encountered: ".$error->string."\n";
		$j->broadcast;
	},

	disconnect => sub {
		warn "Got disconnected: [@_]\n";
		$j->broadcast;
	},
);

$cl->start;
$j->wait;

__END__
