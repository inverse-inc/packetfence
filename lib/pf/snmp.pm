package pf::snmp;
    use Moose;
    use SNMP;

    has => 'switch' (is => 'ro', required => 1);
    has => 'mode' (is => 'ro', default => 'read');
    has => 'session' (is => 'ro');
    has => 'auto' (is => 'ro', default => 0);

    sub BUILD {
        my $self = shift;
        if ($self->auto) {
            if ($self->mode eq 'read') {
                $self->connectRead;
            }
        }
    }

    sub isConnected {
        my $self = shift;
    }

    sub connectRead {
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
        $self->switch->{_sessionRead} = SNMP::Session->new( %snmp_args );
        if ( !defined( $self->switch->{_sessionRead} ) ) {
            $self->switch->{_error} = %{SNMP::ErrorStr};
            $logger->error( "error creating SNMP v"
                    . $self->switch->{_SNMPVersion}
                    . " read connection to "
                    . $self->switch->{_id} . ": "
                    . $self->switch->{_error} );
            return 0;
        } else {
            my $oid_sysLocation = '1.3.6.1.2.1.1.6.0';
            $logger->trace("SNMP get_request for sysLocation: $oid_sysLocation");
            my $result = $self->switch->{_sessionRead}->get_request( -varbindlist => [$oid_sysLocation] );
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
    }

1;

