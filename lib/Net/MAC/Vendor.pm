#!/usr/bin/perl

package Net::MAC::Vendor;
use strict;

=head1 NAME

Net::MAC::Vendor - look up the vendor for a MAC

=head1 SYNOPSIS

	use Net::MAC::Vendor;

	my $mac = "00:0d:93:29:f6:c2";

	my $array = Net::MAC::Vendor::lookup( $mac );

You can also run this as a script with as many arguments as you
like.  The module realizes it is a script, looks up the information
for each MAC, and outputs it.

	perl Net/MAC/Vendor.pm 00:0d:93:29:f6:c2 00:0d:93:29:f6:c5

=head1 DESCRIPTION

The Institute of Electrical and Electronics Engineers (IEEE) assigns
an Organizational Unique Identifier (OUI) to manufacturers of network
interfaces.  Each interface has a Media Access Control (MAC) address
of six bytes.  The first three bytes are the OUI.

This module allows you to take a MAC address and turn it into the OUI
and vendor information.  You can, for instance, scan a network,
collect MAC addresses, and turn those addresses into vendors.  With
vendor information, you can often guess at what what you are looking
at (e.g. an Apple product).

You can use this as a module as its individual functions, or call it
as a script with a list of MAC addresses as arguments.  The module can
figure it out.

This module tries to persistently cache with DBM::Deep the OUI
information so it can avoid using the network.  If it cannot load
DBM::Deep, it uses a normal hash (which is lost when the process
finishes).  You can preload this cache with the load_cache() function.
 So far, the module looks in the current working directory for a file
named mac_oui.db to find the cache. I need to come up with a way to
let the user set that location.

=head2 Functions

=over 4

=cut

use base qw(Exporter);

__PACKAGE__->run( @ARGV ) unless caller;

use Carp;
use LWP::Simple qw(get);

# http://standards.ieee.org/regauth/oui/oui.txt

our $Cached = do {
	eval "require DBM::Deep" ?
		DBM::Deep->new( $ENV{NET_MAC_VENDOR_CACHE} || 'mac_oui.db' ) :
		{};
		};

our $VERSION = 1.18;

=item run( @macs )

If I call this module as a script, this class method automatically
runs.  It takes the MAC addresses and prints the registered vendor
information for each address. I can pass it a list of MAC addresses
and run() processes each one of them.  It prints out what it
discovers.

This method does try to use a cache of OUI to cut down on the
times it has to access the network.  If the cache is fully
loaded (perhaps using C<load_cache>), it may not even use the
network at all.

=cut

sub run
	{
	my $class = shift;

	load_cache();

	foreach my $arg ( @_ )
		{
		my $mac   = normalize_mac( $arg );
		my $lines = fetch_oui( $mac );

		unshift @$lines, $arg;

		print join "\n", @$lines, undef;
		}
	}

=item lookup( MAC )

Given the MAC address, return an anonymous array with the vendor
information. The first element is the OUI, the second element
is the vendor name, and the remaining elements are the address
lines. Different records may have different numbers of lines,
although the first two should be consistent.

The normalize_mac() function explains the possible formants
for MAC.

=cut

sub lookup
	{
	my $mac   = shift;

	   $mac   = normalize_mac( $mac );
	my $lines = fetch_oui( $mac );

	return $lines;
	}

=item normalize_mac( MAC )

Takes a MAC address and turns it into the form I need to
send to the IEEE lookup, which is the first six bytes in hex
separated by hyphens.  For instance, 00:0d:93:29:f6:c2 turns
into 00-0D-93.

The input string can be a separated by colons or hyphens. They
can omit leading 0's (which might make things look odd).  We
only need the first three bytes

	00:0d:93:29:f6:c2   # usual form

	00-0d-93-29-f6-c2   # with hyphens

	00:0d:93            # first three bytes

	0:d:93              # missing leading zero

	:d:93               # missing all leading zeros

=cut

sub normalize_mac
	{
	my $input = uc shift;

	my $mac   = join "-",
		grep { /^[0-9A-F]{2}$/ }
		map { sprintf "%02X", hex }
		( split /[:-]/, $input )[0..2];

	$mac = undef unless $mac =~ /^[0-9A-F]{2}-[0-9A-F]{2}-[0-9A-F]{2}$/;
	carp "Could not normalize MAC [$input]" unless $mac;

	return $mac;
	}

=item fetch_oui( MAC )

Looks up the OUI information on the IEEE website, or uses a cached
version of it.  Pass it the result of C<normalize_mac()> and you
should be fine.

The C<normalize_mac()> function explains the possible formants for
MAC.

To avoid multiple calls on the network, use C<load_cache> to preload
the entire OUI space into an in-memory cache. This can take a long
time over a slow network, thoug; the file is about 60,000 lines.

=cut

sub fetch_oui
	{
	fetch_oui_from_cache( $_[0] ) || fetch_oui_from_ieee( $_[0] );
	}

=item fetch_oui_from_ieee( MAC )

Looks up the OUI information on the IEEE website. Pass it the result
of C<normalize_mac()> and you should be fine.

The C<normalize_mac()> function explains the possible formants for
MAC.

=cut

sub fetch_oui_from_ieee
	{
	my $mac = normalize_mac( shift );

	parse_oui(
		extract_oui_from_html(
			get( "http://standards.ieee.org/cgi-bin/ouisearch?$mac" )
			)
		);
	}

=item fetch_oui_from_cache( MAC )

Looks up the OUI information in the cached OUI information (see
C<load_cache>).

The C<normalize_mac()> function explains the possible formats for
MAC.

To avoid multiple calls on the network, use C<load_cache> to preload
the entire OUI space into an in-memory cache.

If it doesn't find the MAC in the cache, it returns nothing.

=cut

sub fetch_oui_from_cache
	{
	my $mac = normalize_mac( shift );

	exists $Cached->{ $mac } ? $Cached->{ $mac } : ();
	}

=item extract_oui_from_html( HTML )

Gets rid of the HTML around the OUI information.  It may still be
ugly. The HTML is the search results page of the IEEE ouisearch
lookup.

Returns false if it could not extract the information. This could
mean unexpected input or a change in format.

=cut

sub extract_oui_from_html
	{
	my $html = shift;

	my( $oui ) = $html =~ m|<pre>(.*?)</pre>|gs;
	return unless defined $oui;

	$oui =~ s|</?b>||g;

	return $oui;
	}

=item parse_oui( STRING )

Takes a string that looks like

	00-03-93   (hex)            Apple Computer, Inc.
	000393     (base 16)        Apple Computer, Inc.
								20650 Valley Green Dr.
								Cupertino CA 95014
								UNITED STATES

and turns it into an array of lines.  It discards the first
line, strips the leading information from the second line,
and strips the leading whitespace from all of the lines.

With no arguments, it returns an empty anonymous array.

=cut

sub parse_oui
	{
	my $oui = shift;
	return [] unless $oui;

	my @lines = map { $_ =~ s/^\s+|\s+$//; $_ ? $_ : () } split /$/m, $oui;
	splice @lines, 1, 1, ();

	$lines[0] = ( split /\s+/, $lines[0], 3 )[-1];
	return \@lines;
	}

=item load_cache( [ SOURCE ] )

Downloads the current list of all OUIs, parses it with C<parse_oui()>,
and stores it in C<$Cached> anonymous hash keyed by the OUIs (i.e.
00-0D-93).  The C<fetch_oui()> will use this cache if it exists. The
cache is stored as a C<DBM::Deep> file named after the
C<NET_MAC_VENDOR_CACHE> environment variable, or C<mac_oui.db> by
default.

By default, this uses C<http://standards.ieee.org/regauth/oui/oui.txt>
, but given an argument, it tries to use that. To load from a local
file, use the C<file://> scheme.

If C<load_cache> cannot load the data, it issues a warning and returns
nothing.

=cut

sub load_cache
	{
	my $source = shift || "http://standards.ieee.org/regauth/oui/oui.txt";

	my $data;

	unless( $data = get( $source ) )
		{
		carp "Could not read from '$source'";
		return;
		}

	my @entries = split /\n\n/, $data;
	shift @entries;

	my $foo = '';
	foreach my $entry ( @entries )
		{
		$entry =~ s/^\s+|\s+$//;
		my $oui = substr $entry, 0, 8;
		$Cached->{ $oui } = parse_oui( $entry );
		}
	}

=back

=head1 SEE ALSO

L<Net::MacMap>

=head1 SOURCE AVAILABILITY

This source is part of a SourceForge project which always has the
latest sources in CVS, as well as all of the previous releases.

	http://sourceforge.net/projects/brian-d-foy/

If, for some reason, I disappear from the world, one of the other
members of the project can shepherd this module appropriately.

=head1 AUTHOR

brian d foy C<< <bdfoy@cpan.org> >>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2004-2007 brian d foy.  All rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
