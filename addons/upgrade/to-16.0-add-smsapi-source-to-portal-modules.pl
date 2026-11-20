#!/usr/bin/perl

=head1 NAME

to-16.0-add-smsapi-source-to-portal-modules

=head1 DESCRIPTION

Add pf::Authentication::Source::SMSApiSource to every portal module whose
multi_source_object_classes is overridden in portal_modules.conf and already
lists an SMS source class, so SMSApi sources show up on the portal like the
other SMS sources do with the shipped defaults.

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
use lib qw(/usr/local/pf/lib_perl/lib/perl5);
use pf::IniFiles;
use pf::file_paths qw($portal_modules_config_file);

our $SMSAPI_CLASS = 'pf::Authentication::Source::SMSApiSource';
our $SMSSOURCE_CLASS = 'pf::Authentication::Source::SMSSource';
our %SMS_CLASSES = map { ("pf::Authentication::Source::${_}Source" => undef) } qw(SMS Twilio Clickatell);

main() if not caller();

sub main {
    my ($cs, $updated) = addSMSApiSource($portal_modules_config_file);
    if (!$cs) {
        print "Nothing to be done\n";
        exit 0;
    }

    $cs->RewriteConfig();
    print "Added $SMSAPI_CLASS to: " . join(", ", @$updated) . "\n";
    print "All done\n";
}

=head2 addSMSApiSource

Returns the updated config and the list of updated sections, or (undef, undef)
when nothing needs to change or the file doesn't exist

=cut

sub addSMSApiSource {
    my ($file) = @_;
    return (undef, undef) unless -e $file;
    my $cs = pf::IniFiles->new(-file => $file, -allowempty => 1);
    return (undef, undef) unless $cs;
    my @updated;
    for my $section ( grep {/^\S+$/} $cs->Sections() ) {
        next unless $cs->exists($section, 'multi_source_object_classes');
        my $list = $cs->val($section, 'multi_source_object_classes') // '';
        my @classes = grep { length } split(/\s*,\s*/, $list);
        next if grep { $_ eq $SMSAPI_CLASS } @classes;
        # Insert right after SMSSource like the shipped default,
        # or after the last SMS source class when SMSSource isn't listed
        my ($after) = grep { $classes[$_] eq $SMSSOURCE_CLASS } 0..$#classes;
        ($after) = grep { exists $SMS_CLASSES{$classes[$_]} } reverse 0..$#classes unless defined $after;
        next unless defined $after;
        splice(@classes, $after + 1, 0, $SMSAPI_CLASS);
        $cs->setval($section, 'multi_source_object_classes', join(",", @classes));
        push @updated, $section;
    }

    return @updated ? ($cs, \@updated) : (undef, undef);
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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

1;
