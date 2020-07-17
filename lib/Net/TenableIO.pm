package Net::TenableIO;

use warnings;
use strict;

use Carp;
use List::Util qw(first);
use IO::Uncompress::Unzip qw(unzip $UnzipError);

use Net::TenableIO::REST_IO;

use Data::Dumper;

our $VERSION = '0.100';

sub new {

    my ($class, $host, $options) = @_;

    my $self = {
        host    => $host,
        options => $options,
        rest    => Net::TenableIO::REST_IO->new($host, $options),
    };

    bless $self, $class;

    return $self;

}

sub rest {

    my ($self) = @_;
    return $self->{rest};

}

### Modificada
sub auth {

    my ($self, $accesskey, $secretkey) = @_;

    (@_ == 3) or croak(q/Usage: $io->auth(ACCESSKEY, SECRETKEY)/);

    $self->rest->auth($accesskey, $secretkey);

    return 1;

}

### Modificada
sub get_policies_list {

    my ($self) = @_;

    return $self->rest->get('/policies');

}

### Modificada
sub get_policies {

    my ($self, $policy_id) = @_;

    (@_ == 2) or croak(q/Usage: $io->get_policies(POLICY_ID)/);

    croak('Invalid Policy ID') unless ($policy_id =~ /\d/);

    return $self->rest->get("/policies/$policy_id");

}

### Modificada
sub get_scanners_list {

    my ($self) = @_;

    return $self->rest->get('/scanners');

}

### Modificada
sub get_scanners {

    my ($self, $scanner_id) = @_;

    (@_ == 2) or croak(q/Usage: $io->get_scanners(SCANNER_ID)/);

    croak('Invalid Scanner ID') unless ($scanner_id =~ /\d/);

    return $self->rest->get("/scanners/$scanner_id");

}

### Modificada
sub get_agents_list {

    my ($self, %filters) = @_;

    my @query = ();
    $query[0] = '?';
    foreach my $filter (keys %filters) {
        if ($filter ne 'ft') {
            $query[0] .= 'f='.$filters{$filter}.'&';
        } else {
            $query[0] .= 'ft='.$filters{$filter}.'&';
        }
    }

    return $self->rest->get('/scanners/scanner_id/agents', \@query);

}

### Modificada
sub get_agents {

    my ($self, $agent_id) = @_;

    (@_ == 2) or croak(q/Usage: $io->get_agent(AGENT_ID)/);

    croak('Invalid Agent ID') unless ($agent_id =~ /\d/);

    return $self->rest->get("/scanners/scanner_id/agents/$agent_id");

}

### Modificada
sub add_agent_group {

    my ($self, %params) = @_;

    return $self->rest->post("/scanners/scanner_id/agent-groups", \%params);
}

########MOdificada Chesco################################
sub delete_agent_group {

    my ($self, $group_id) = @_;

    (@_ == 2) or croak(q/Usage: $io->delete_agent_group(agent_group_id)/);

    return $self->rest->delete("/scanners/scanner_id/agent-groups/$group_id");
}


### Modificada
sub add_agent_to_group {

    my ($self, %params) = @_;

    my $group_id = $params{'group_id'};
    my $agent_id = $params{'agent_id'};

    $self->rest->put("/scanners/scanner_id/agent-groups/$group_id/agents/$agent_id");

    return 1;

}

#####Funcion Añadida#################3
sub get_agent_group_list {

    my ($self, %filters) = @_;
    my @query = ();
    $query[0] = '?';
    foreach my $filter (keys %filters) {
        if ($filter ne 'ft') {
            $query[0] .= 'f='.$filters{$filter}.'&';
        } else {
            $query[0] .= 'ft='.$filters{$filter}.'&';
        }
    }

    return $self->rest->get('/scanners/scanner_id/agent-groups', \@query);

}

####Añadida CHesco########
sub get_scan_template_list{

    my ($self) = @_;
    return $self->rest->get('/editor/scan/templates')
}
########Añadida Chesco###########3
sub get_policy_template_list{

    my ($self) = @_;
    return $self->rest->get('/editor/policy/templates')
}

#######funcion añadida CHesco##############3
sub add_agent_scan {

    my ($self, %params) = @_;

    my $scan_data = {};

    my %settings_data = ();

    my @default_params = qw/scan_template name description policy_id agentGroup folderid/;

    foreach (@default_params) {

        next unless (defined($params{$_}));

           if ($_ eq 'scan_template')     { $scan_data = { 'uuid' => $params{$_} } }
        elsif ($_ eq 'name')       { $settings_data{'name'} = $params{$_} }
        elsif ($_ eq 'policy_id')    { $settings_data{'policy_id'} = $params{$_} }
        elsif ($_ eq 'agentGroup') { $settings_data{'agent_group_id'} = $params{$_} }
	elsif ($_ eq 'folderid') { $settings_data{'folder_id'} = $params{$_} }
        else                       { $settings_data{$_} = $params{$_} }

    }

    $scan_data->{'settings'} = \%settings_data;

    my $result = $self->rest->post('/scans', $scan_data);

    if ( $result->{'scan'}->{'id'} ) {
        return $result->{'scan'}->{'id'};
    }

}

#############################Funcion Añadida Chesco######################################3
sub export_agent_scan {

    my ($self, %params) = @_;

    my $scan_id = $params{'scanid'};
    my %params1 = ();
    $params1{'format'} = $params{'format_'};

    return $self->rest->post("/scans/$scan_id/export", \%params1);
}

#############################Funcion Añadida Chesco######################################3
sub check_scan_export_status{
	my ($self, %params) = @_;

    my $scan_id = $params{'scan'};
    my $file_id = $params{'file'};
    
    return $self->rest->get("/scans/$scan_id/export/$file_id/status");
}

#############################Funcion Añadida Chesco######################################3
sub download_agent_scan{
    my ($self, %params) = @_;

    my $scan_id = $params{'scan'};
    my $file_id = $params{'file'};
    
    return $self->rest->get("/scans/$scan_id/export/$file_id/download");
}


=pod
### Modificada
sub add_agent_scan {

    my ($self, %params) = @_;

    my $scan_data = {};

    my %settings_data = ();

    my @default_params = qw/policy name description scanner agentGroup/;

    foreach (@default_params) {

        next unless (defined($params{$_}));

           if ($_ eq 'policy')     { $scan_data = { 'uuid' => $params{$_} } }
        elsif ($_ eq 'name')       { $settings_data{'name'} = $params{$_} }
        elsif ($_ eq 'scanner')    { $settings_data{'scanner_id'} = $params{$_} }
        elsif ($_ eq 'agentGroup') { $settings_data{'agent_group_id'} = $params{$_} }
        else                       { $settings_data{$_} = $params{$_} }

    }

    $scan_data->{'settings'} = \%settings_data;

    my $result = $self->rest->post('/scans', $scan_data);

    if ( $result->{'scan'}->{'id'} ) {
        return $result->{'scan'}->{'id'};
    }

}
=cut

### Modificada
sub launch_scans {

    my ($self, $scan_id) = @_;

    (@_ == 2) or croak(q/Usage: $io->launch_scans(SCAN_ID)/);

    return $self->rest->post("/scans/$scan_id/launch");
}

### Modificada
sub get_scans_list {

    my ($self) = @_;

    return $self->rest->get('/scans');

}

### Modificada
sub get_scans {

    my ($self, $scan_id) = @_;

    (@_ == 2) or croak(q/Usage: $io->get_scans(SCAN_ID)/);

    croak('Invalid scan ID') unless ($scan_id =~ /\d/);

    return $self->rest->get("/scans/$scan_id");

}

### Modificada
sub get_scans_status {

    my ($self, $scan_id) = @_;

    (@_ == 2) or croak(q/Usage: $io->get_scans_status(SCAN_ID)/);

    my $result = $self->rest->get("/scans/$scan_id/latest-status");

    return $result->{'status'};

}

### Modificada
sub export_scans {

    my ($self, $scan_id) = @_;

    (@_ == 2) or croak(q/Usage: $io->export_scans(SCAN_ID)/);

    my $result = $self->rest->post("/scans/$scan_id/export");
}

sub get_scan_progress {

    my ($self, $scan_id) = @_;

    (@_ == 2) or croak(q/Usage: $sc->get_scan_progress(SCAN_ID)/);

    my $scan_data = $self->get_scan($scan_id, { 'fields' => 'id,totalChecks,completedChecks' });
    return sprintf('%d', ( $scan_data->{'completedChecks'} * 100 ) / $scan_data->{'totalChecks'});

}

sub pause_scan {

    my ($self, $scan_id) = @_;

    (@_ == 2) or croak(q/Usage: $sc->pause_scan(SCAN_ID)/);

    $self->rest->post("/scanResult/$scan_id/pause");
    return 1;

}

sub resume_scan {

    my ($self, $scan_id) = @_;

    (@_ == 2) or croak(q/Usage: $sc->resume_scan(SCAN_ID)/);

    $self->rest->post("/scanResult/$scan_id/resume");
    return 1;

}

sub stop_scan {

    my ($self, $scan_id) = @_;

    (@_ == 2) or croak(q/Usage: $sc->stop_scan(SCAN_ID)/);

    $self->rest->post("/scanResult/$scan_id/stop");
    return 1;

}

sub delete_scan {

    my ($self, $scan_id) = @_;

    (@_ == 2) or croak(q/Usage: $sc->delete(SCAN_ID)/);

    return $self->rest->delete("/scans/$scan_id");
    

}

### Modificada
sub get_server_status {

    my ($self, $fields) = @_;

    (@_ == 1 || @_ == 2) or croak(q/Usage: $io->get_server_status([FIELDS])/);

    my %params = ();

    if ($fields) {
        if (ref $fields eq 'ARRAY') {
            $params{'fields'} = join(',', @{$fields});
        } else {
            $params{'fields'} = $fields;
        }
    }

    return $self->rest->get('/server/status', \%params);

}

sub get_device_info {

    my ($self, $repository_id, $ip_address, $params) = @_;

    (@_ == 3 || @_ == 4 || @_ == 5) or croak(q/Usage: $sc->get_device_info(REPOSITORY_ID, IP_ADDRESS [,PARAMS])/);

    croak('Invalid Repository ID') unless ($repository_id =~ /\d/);

    my %params = (
        'ip' => $ip_address,
    );

    if (defined($params->{'fields'})) {
        if (ref $params->{'fields'} eq 'ARRAY') {
            $params{'fields'} = join(',', @{$params->{'fields'}});
        } else {
            $params{'fields'} = $params->{'fields'};
        }
    }

    return $self->rest->get("/repository/$repository_id/deviceInfo", \%params);

}

sub get_repository_list {

    my ($self, $fields) = @_;

    my %params = ();

    if ($fields) {
        if (ref $fields eq 'ARRAY') {
            $params{'fields'} = join(',', @{$fields});
        } else {
            $params{'fields'} = $fields;
        }
    }

    return $self->rest->get('/repository', \%params);

}

sub get_repository {

    my ($self, $repository_id, $fields) = @_;

    (@_ == 2 || @_ == 3) or croak(q/Usage: $sc->get_repository(REPOSITORY_ID [,FIELDS])/);

    croak('Invalid Repository ID') unless ($repository_id =~ /\d/);

    my %params = ();

    if ($fields) {
        if (ref $fields eq 'ARRAY') {
            $params{'fields'} = join(',', @{$fields});
        } else {
            $params{'fields'} = $fields;
        }
    }

    return $self->rest->get("/repository/$repository_id", \%params);

}

sub get_report_list {

    my ($self, %params) = @_;
    return $self->rest->get('/report', \%params);

}

sub get_report {

    my ($self, $report_id, $fields) = @_;

    (@_ == 2 || @_ == 3) or croak(q/Usage: $sc->get_report(REPORT_ID [,FIELDS])/);

    croak('Invalid Report ID') unless ($report_id =~ /\d/);

    my %params = ();

    if ($fields) {
        if (ref $fields eq 'ARRAY') {
            $params{'fields'} = join(',', @{$fields});
        } else {
            $params{'fields'} = $fields;
        }
    }

    return $self->rest->get("/report/$report_id", \%params);

}

sub download_report {

    my ($self, $report_id) = @_;
    return $self->rest->post("/report/$report_id/download");

}

sub get_user_list {

    my ($self, %params) = @_;
    return $self->rest->get('/user', \%params);

}

sub get_user {

    my ($self, $user_id, $fields) = @_;

    (@_ == 2 || @_ == 3) or croak(q/Usage: $sc->get_user(CREDENTIAL_ID [,FIELDS])/);

    croak('Invalid User ID') unless ($user_id =~ /\d/);

    my %params = ();

    if ($fields) {
        if (ref $fields eq 'ARRAY') {
            $params{'fields'} = join(',', @{$fields});
        } else {
            $params{'fields'} = $fields;
        }
    }

    return $self->rest->get("/user/$user_id", \%params);

}

sub get_credential_list {

    my ($self, %params) = @_;
    return $self->rest->get('/credential', \%params);

}

sub get_credential {

    my ($self, $credential_id, $fields) = @_;

    (@_ == 2 || @_ == 3) or croak(q/Usage: $sc->get_credential(CREDENTIAL_ID [,FIELDS])/);

    croak('Invalid Credential ID') unless ($credential_id =~ /\d/);

    my %params = ();

    if ($fields) {
        if (ref $fields eq 'ARRAY') {
            $params{'fields'} = join(',', @{$fields});
        } else {
            $params{'fields'} = $fields;
        }
    }

    return $self->rest->get("/credential/$credential_id", \%params);

}

sub download_nessus_scan {

    my ($self, $scan_id, $filename) = @_;

    (@_ == 2 || @_ == 3) or croak(q/Usage: $sc->download_nessus_scan(SCAN_ID [,FILE])/);

    croak('Invalid Scan ID') unless ($scan_id =~ /\d/);

    my $sc_scan_data     = $self->rest->post("/scanResult/$scan_id/download",  { 'downloadType' => 'v2' });
    my $nessus_scan_data = '';

    if ($sc_scan_data) {
        unzip \$sc_scan_data => \$nessus_scan_data or croak "Failed to uncompress Nessus scan: $UnzipError\n";
    }

    return $nessus_scan_data unless($filename);

    open(my $fh, '>', $filename)
        or croak("Could not open file '$filename': $!");

    print $fh $nessus_scan_data;
    close $fh;

    return 1;

}

sub get_plugin_list {

    my ($self, %params) = @_;
    return $self->rest->get('/plugin', \%params);

}

sub get_plugin {

    my ($self, $plugin_id, $fields) = @_;

    (@_ == 2 || @_ == 3) or croak(q/Usage: $sc->get_plugin(PLUGIN_ID [,FIELDS])/);

    croak('Invalid Plugin ID') unless ($plugin_id =~ /\d/);

    my %params = ();

    if ($fields) {
        if (ref $fields eq 'ARRAY') {
            $params{'fields'} = join(',', @{$fields});
        } else {
            $params{'fields'} = $fields;
        }
    }

    return $self->rest->get("/plugin/$plugin_id", \%params);

}

sub get_plugin_family_list {

    my ($self, %params) = @_;
    return $self->rest->get('/pluginFamily', \%params);

}

sub get_plugin_family {

    my ($self, $plugin_family_id, $fields) = @_;

    (@_ == 2 || @_ == 3) or croak(q/Usage: $sc->get_plugin_family(PLUGIN_FAMILY_ID [,FIELDS])/);

    croak('Invalid Plugin Family ID') unless ($plugin_family_id =~ /\d/);

    my %params = ();

    if ($fields) {
        if (ref $fields eq 'ARRAY') {
            $params{'fields'} = join(',', @{$fields});
        } else {
            $params{'fields'} = $fields;
        }
    }

    return $self->rest->get("/pluginFamily/$plugin_family_id", \%params);

}

sub logout {

    my ($self) = @_;
    $self->rest->logout();
    return 1;

}

1;

__END__
=pod

=encoding UTF-8

=head1 NAME

Net::TenableIO - Perl interface to Tenable Tenable IO REST API

=head1 SYNOPSIS

    use Net::TenableIO;
    my $io = Net::TenableIO('io.example.org');

    $io->auth('accesskey', 'secretkey');

=head1 DESCRIPTION

This module provides Perl scripts easy way to interface the REST API of Tenable IO.

For more information about the Tenable IO REST API follow the online documentation:

L<https://developer.tenable.com/docs>

=head1 CONSTRUCTOR

=head2 Net::TenableIO->new ( host [, { timeout => $timeout , ssl_options => $ssl_options } ] )

Create a new instance of B<Net::TenableIO> using B<Net::TenableIO::REST> package.

=over 4

=item * C<timeout> : Request timeout in seconds (default is 180) If a socket open,
read or write takes longer than the timeout, an exception is thrown.

=item * C<ssl_options> : A hashref of C<SSL_*> options to pass through to L<IO::Socket::SSL>.

=back

=head1 CORE METHODS

=head2 $io->rest ()

Return the instance of L<Net::TenableIO::REST_IO> class

=head2 $io->auth ( accesskey, secrectkey )

Authentication keys for Tenable IO.


=head1 SCAN METHODS

=head2 $io->add_scan ( name => $name, ipList => $ip_list, description => $description, policy => $policy_id, repository => $repository_id, zone => $zone_id )

Create a new scan on SecurityCenter.

    $sc->add_scan(
        name        => 'Test API scan',
        ipList      => [ '192.168.1.2', '192.168.1.3' ],
        description => 'Test from Net::SecurityCenter Perl module',
        policy      => 1,
        repository  => 2,
        zone        => 1
    );

Params:

=over 4

=item * C<name> : Name of scan (required)

=item * C<description> : Description of scan

=item * C<ipList> : One or more IP address

=item * C<zone> : Scan Zone ID

=item * C<policy> : Policy ID

=item * C<repository> : Repository ID

=item * C<maxScanTime> : Max Scan Time

=back

=head2 $sc->download_nessus_scan ( scan_id [, filename ] )

Download the Nessus (XML) scan result.

    my $nessus_scan = $sc->download_nessus_scan(1337);

    $sc->download_nessus_scan(1337, '/var/nessus/scans/1337.nessus');

=head2 $io->get_scan_list ()

Get the list of all scans.

=head2 $sc->get_scan ( scan_id [, fields ] )

Get scan information.

=head2 $sc->get_scan_progress ( scan_id )

Get scan progress.

    print 'Scan progress: ' . $sc->get_scan_progress(1337) . '%';

=head2 $sc->get_scan_status ( scan_id )

Get scan status.

    print 'Scan status: ' . $sc->get_scan_status(1337);

=head2 $sc->pause_scan ( scan_id )

Pause a scan.

    if ($sc->get_scan_status(1337) eq 'running') {
        $sc->pause_scan(1337);
    }

=head2 $sc->resume_scan ( scan_id )

Resume a paused scan.

    if ($sc->get_scan_status(1337) eq 'paused') {
        $sc->resume_scan(1337);
    }

=head2 $sc->stop_scan ( scan_id )

Stop a scan.

    if ($sc->get_scan_status(1337) eq 'running') {
        $sc->stop_scan(1337);
   }

=head1 PLUGIN METHODS

=head2 $sc->get_plugin_list ( [ fields ] )

Gets the list of all Nessus Plugins.

=head2 $sc->get_plugin ( plugin_id [, fields ] )

Get information about Nessus Plugin.

    $sc->get_plugin(19506, [ 'description', 'name' ]);

=head2 $sc->get_plugin_family_list ( [ fields ] )

Get list of Nessus Plugin Family.

=head2 $sc->get_plugin_family ( plugin_family_id [, fields ])

Get ifnrmation about Nessus Plugin Family.

=head1 SYSTEM INFORMATION AND MAINTENANCE METHODS

=head2 $sc->get_status ( [ fields ] )

Gets a collection of status information, including license.

=head2 $sc->get_system_info ()

Gets the system initialization information.

=head2 $sc->get_system_diagnostics_info ()

Gets the system diagnostics information.

=head2 $sc->generate_app_status_diagnostics ()

Starts an on-demand, diagnostics analysis for the System that can be downloaded after its job completes.

=head2 $sc->generate_diagnostics_file ( [ options ] )

Starts an on-demand, diagnostics analysis for the System that can be downloaded after its job completes.

=head2 $sc->download_system_diagnostics ()

Downloads the system diagnostics, debug file that was last generated.

=head2 $sc->get_feed ( [ type ] )

=head1 REPOSITORY METHODS

=head2 $sc->get_repository_list ( [ fields ] )

=head2 $sc->get_repository ( repository_id [, fields ])

=head2 $sc->get_device_info ( repository_id, ip_address [, params ] )

=head2 $sc->get_ip_info ( ip_address [, params ])

=head1 SCAN ZONE METHODS

=head2 $sc->get_scan_zone_list ( [ fields ] )

=head2 $sc->get_scan_zone ( zone_id [, fields ] )

=head1 SCAN POLICY METHODS

=head2 $io->get_policies_list ()

=head2 $io->get_policies ( policy_id )

=head1 REPORT METHODS

=head2 $sc->get_report_list ( [ fields ] )

=head2 $sc->get_report ( report_id [, fields ])

=head2 $sc->download_report ( report_id )

=head1 USER METHODS

=head2 $sc->get_user_list ( [ fields ] )

=head2 $sc->get_user ( user_id [, fields ] )

=head1 CREDENTIAL METHODS

=head2 $sc->get_credential_list ( [ fields ] )

=head2 $sc->get_credential ( credential_id [, fields ] )

=head1 SUPPORT

=head2 Bugs / Feature Requests

Please report any bugs or feature requests through the issue tracker
at L<https://github.com/LotarProject/perl-Net-SecurityCenter/issues>.
You will be notified automatically of any progress on your issue.

=head2 Source Code

This is open source software.  The code repository is available for
public review and contribution under the terms of the license.

L<https://github.com/LotarProject/perl-Net-SecurityCenter>

    git clone https://github.com/LotarProject/perl-Net-SecurityCenter.git

=head1 AUTHORS

=over 4

=item * Giuseppe Di Terlizzi <gdt@cpan.org>

=back

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2018 by Giuseppe Di Terlizzi.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
