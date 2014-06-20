package pf::snmp;
    use Moose;
    use SNMP;
    use Log::Log4perl;
    use Data::Dumper;

    has 'switch' => (is => 'ro', required => 1);
    has 'sessionRead' => (is => 'rw');
    has 'sessionWrite' => (is => 'rw');

    $SNMP::auto_init_mib = 0;
    $SNMP::use_numeric = 1;

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
    sub get_tables { #{{{
        my ($self,$base_oids,$max_it) = @_;
        $self->connectRead unless $self->sessionRead;
        $self->{_base_oids} = $base_oids;
        $self->{_base_oid} = shift @{$self->{_base_oids}};
        $self->{_max_it} = $max_it || 10;
        if (not $self->{_base_oid}) {
            warn "No base oid\n";
            exit;
        }
        return $self->_get_tables_cb( $self->sessionRead->bulkwalk(0,$self->{_max_it},[$self->{_base_oid}]) );
    } #}}}
    sub _get_tables_cb { #{{{
        my ($self,$results) = @_;
        my $oid;
        my $max = int(1000 / 26 / 1);
        #foreach my $vl (@$results) {
            foreach my $r (@$results) {
                $oid = $r->[0].'.'.$r->[1];
                if ($oid =~ /^$self->{_base_oid}/) {
                    next if ($r->val eq 'NOSUCHINSTANCE');
                    next if ($r->val eq 'NOSUCHOBJECT');
                    $self->{_results}->{$oid} = $r->[2];
                }
            }
        #}
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
1;

