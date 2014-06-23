package pf::snmp;

=head1 NAME

pf::snmp - Class for accessing snmp via net-snmp's SNMP.pm module

=head1 SYNOPSIS

    use pf::snmp;

    # $switch is a pf::Switch object.
    my $snmp = pf::snmp->new( switch => $switch );

=head1 DESCRIPTION

This class simplifies and duplicates the same functions as Net::SNMP only with much higher performance and overhead.
It duplicates some of the methods in pf::Switch to allow for graduale migration.

=cut
    use Moose;
    use SNMP;
    use Log::Log4perl;
    use Data::Dumper;

    our $VERSION = 1.00;

    has 'switch' => (is => 'ro', required => 1);
    has 'sessionRead' => (is => 'rw');
    has 'sessionWrite' => (is => 'rw');
    has 'error' => (is => 'rw');

    $SNMP::auto_init_mib = 0;
    $SNMP::use_numeric = 1;

=head1 METHODS

=head2 connectRead

Duplicates the connectRead in pf::switch only using net-snmp instead of Net::SNMP
Options are pulled from the pf::Switch object to connect.

=cut

    sub connectRead { # {{{
        my $self = shift;
        my $logger = Log::Log4perl::get_logger( ref($self->switch) );
        if ( defined( $self->switch->{_sessionRead} ) ) {
            return 1;
        }

        my %snmp_args;
        $snmp_args{DestHost} = $self->switch->{_ip};
        $snmp_args{Version} = $self->switch->{_SNMPVersion};
        $snmp_args{Timeout} = 2000000; # 2 seconds
        $snmp_args{Retries} = 1;
        if ( $self->switch->{_SNMPVersion} eq '3' ) {
            $snmp_args{SecName} = $self->switch->{_SNMPUserNameRead};
            $snmp_args{AuthProto} = $self->switch->{_SNMPAuthProtocolRead};
            $snmp_args{AuthPass} = $self->switch->{_SNMPAuthPasswordRead};
            $snmp_args{PrivProto} = $self->switch->{_SNMPPrivProtocolRead};
            $snmp_args{PrivPass} = $self->switch->{_SNMPPrivPassRead};
            $snmp_args{SecLevel} = 'authPriv';
        }
        else {
            $snmp_args{Community} = $self->switch->{_SNMPCommunityRead};
        }

        $self->sessionRead( SNMP::Session->new( %snmp_args ) );

        # for backwards compatability
        $self->switch->{_sessionRead} = $self->sessionRead;

        if ( !defined( $self->sessionRead ) ) {
            $self->switch->{_error} = %{SNMP::ErrorStr};
            $self->error(%{SNMP::ErrorStr});
            $logger->error( "error creating SNMP v"
                    . $self->switch->{_SNMPVersion}
                    . " read connection to "
                   . $self->switch->{_id} . ": "
                    . $self->switch->{_error} );
            return 0;
        }
        else {
            my $oid_sysLocation = '.1.3.6.1.2.1.1.6.0';

            $logger->trace("SNMP get_request for sysLocation: $oid_sysLocation");
            my $result = $self->get([
                $oid_sysLocation,
            ]);
            if ( !defined($result) ) {
                $logger->error( "error creating SNMP v"
                        . $self->switch->{_SNMPVersion}
                        . " read connection to "
                        . $self->switch->{_id} . ": "
                        . $self->switch->{_sessionRead}->error() );
                $self->switch->{_sessionRead} = undef;
                return 0;
            }
        }
        return 1;
    } # }}}

=head2 get

simplified snmpget. Returns a hash in the same manner as Net::SNMP.

    my $results = $self->get([
        $oid_sysLocation,
    ]);

=cut

    sub get { #{{{
        my ($self,$oids) = @_;
        my $vars;
        $self->connectRead unless $self->sessionRead;
        foreach (@$oids) {
            push(@$vars,[ $_ ]);
        }

        my $return;
        my $results;
         @{ $results } = $self->sessionRead->get($vars);
        foreach my $r (@{$vars}) {
            next if ($r->[2] eq 'NOSUCHINSTANCE');
            next if ($r->[2] eq 'NOSUCHOBJECT');
            $return->{$r->[0].'.'.$r->[1]} = $r->[2];
        }
        return $return;
    } # }}}

=head2 get_tables

Easy way to get a table or tables or portions within a table. Returns a single hash in the typical oid => val style.

    my $results = $snmp->get_tables([
        '.1.3.6.1.2.1.2.2.1.2', #interface desc
        '.1.3.6.1.2.1.2.2.1.3', #interface type
    ]);

=cut

    sub get_tables { #{{{
        my ($self,$base_oids,$max_it) = @_;
        $self->connectRead unless $self->sessionRead;
        $self->{_base_oids} = $base_oids;
        $self->{_base_oid} = shift @{$self->{_base_oids}};
        $self->{_max_it} = $max_it || 10;
        if (not $self->{_base_oid}) {
            # TODO: better handling of this.
            warn "No base oid\n";
            exit;
        }
        return $self->_get_tables_cb( $self->sessionRead->bulkwalk(0,$self->{_max_it},[$self->{_base_oid}]) );
    } #}}}
    sub _get_tables_cb { #{{{
        my ($self,$results) = @_;
        my $oid;
        my $max = int(1000 / 26 / 1);
        foreach my $r (@$results) {
            $oid = $r->[0].'.'.$r->[1];
            if ($oid =~ /^$self->{_base_oid}/) {
                next if ($r->val eq 'NOSUCHINSTANCE');
                next if ($r->val eq 'NOSUCHOBJECT');
                $self->{_results}->{$oid} = $r->[2];
            }
        }
        if ( $oid && ($oid =~ /^$self->{_base_oid}/) ) {
            $self->_get_tables_cb($self->sessionRead->bulkwalk(0,$self->{_max_it},[$oid]));
        }
        else {
            if (@{$self->{_base_oids}}) {
                $self->{_base_oid} = shift @{$self->{_base_oids}};
                $self->_get_tables_cb($self->sessionRead->bulkwalk(0,$self->{_max_it},[$self->{_base_oid}]));
            }
            else {
                my $return = delete $self->{_results};
                delete $self->{_base_oid};
                delete $self->{_base_oids};
                delete $self->{_max_it};
                return $return;
            }
        }
    } #}}}

=head2 set

SNMP set request interface

Accepts an array of arrays each with the following format

[ <oid>, <instance>, <value>, <datatype> ]

    $snmp->set([
        ['.1.3.6.1.2.1.2.2.1.7','1',1,"INTEGER"],
        ['.1.3.6.1.2.1.2.2.1.7','2',1,"INTEGER"]
    ]

=cut

    sub set {
        my ($self,$oids) = @_;
        $self->connectWrite unless $self->sessionWrite;
        my $errorno = $self->sessionWrite->set($oids);
        if ($errorno) {
            $self->switch->{_error} = $self->sessionWrite->{ErrorStr};
            $self->error($self->sessionWrite->{ErrorStr});
            return;
        }
        return 1;
    }

    __PACKAGE__->meta->make_immutable;
1;

=head1 FUTURE

    - add connectWrite method
    - add trap methods

=head1 AUTHOR

mullagain <m5mulli@gmail.com>

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


