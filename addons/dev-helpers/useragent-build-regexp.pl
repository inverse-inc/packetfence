#!/usr/bin/perl -w

=head1 NAME

useragent-build-regexp - Build a useragent regular expression for a database import.

=head1 SYNOPSIS

useragent-build-regexp.pl

=head1 DESCRIPTION

This script outputs the useragent regular expressions with proper escaping to 
allow both the regular expression to survive the database transformation and to
have useragent metacharacters quoted.

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301,
USA.

=cut

# TODO: This should be callable from shell instead of hardcoded but I have more
# work to do to avoid shell escaping

# the gist is: remember to double quote stuff before inserting them in a db (one for the db, one for a regexp)
print quotemeta(quotemeta('Mozilla/5.0 (Linux; U; Android 1.5; en-us; Android Dev Phone 1 Build/CRB43) AppleWebKit/528.5+ (KHTML, like Gecko) Version/3.1.2 Mobile Safari/525.20.1'));
print "\n";
print quotemeta('Mozilla/5.0 (iPhone; U; CPU iPhone OS 2_0 like Mac OS X; de-de) AppleWebKit/525.18.1 (KHTML, like Gecko) Version/3.1.1 Mobile/5A347 Safari/525.20');
print "\n";

