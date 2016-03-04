package pf::OMAPI;
=head1 NAME

pf::OMAPI

=cut

=head1 DESCRIPTION

pf::OMAPI

=head1 SYNOPSIS

    use pf::OMAPI;

    my $omapi = pf::OMAPI->new( key_name => 'pf_omapi_key',key_base64 => 'xJviCHiQKcDu6hk7+Ffa3A==', host => 'localhost', port => 7911);

    my $data = $omapi->lookup({'ip-address' => "10.229.25.247" });

=cut

use strict;
use warnings;
use Moo;
use MIME::Base64;
use Net::IP;
use Digest::HMAC_MD5 qw(hmac_md5);
use IO::Socket::INET;
use Socket qw(MSG_WAITALL);
use Time::HiRes qw(alarm);
use pf::log;

our $VERSION = '0.01';


=head1 ATTRIBUTES

=head2 host

host of dhcp server

=cut

has host => (is => 'rw', default => sub  { 'localhost' });

=head2 port

port of the dhcp server

=cut

has port => (is => 'rw', default => sub { 7911 } );

=head2 timeout

Timeout to read from the OMAPI

=cut

has timeout => (is => 'rw');

=head2 buffer

The reference to the buffer of message

=cut

has buffer => (is => 'rw', default => sub { my $s = "";\$s } );

=head2 sock

The socket used for communicating with the dhcpd server

=cut

has sock => (is => 'rw', builder => 1, lazy => 1, clearer => 1);

=head2 connected

A check if we are connected to the omapi service

=cut

has connected => (is => 'rw' , default => sub { 0 } );

=head2 key_name

The name of the key

=cut

has key_name => (is => 'rw');

=head2 op

The current operation

=cut

has op => (is => 'rw');

=head2 msg

The current message to be sent

=cut

has msg => (is => 'rw');

=head2 handle

The current handle to be sent

=cut

has handle => (is => 'rw');

=head2 obj

The current obj to be sent

=cut

has obj => (is => 'rw');

=head2 authid

The auth id to send

=cut

has authid => (is => 'rw', default => sub { 0 });


=head2 authlen

The length of signature

=cut

has authlen => (is => 'rw', default => sub { 0 });

=head2 id

The current id of the message

=cut

has id => (is => 'rw', default=> sub { int(rand(0x10000000)) } );

=head2 key

The key used to sign messages

=cut

has key => (is => 'rw', builder => 1, lazy => 1);

=head2 key

The key base64 representation of the key

=cut

has key_base64 => (is => 'rw');

#The different message types

our $OPEN    = 1;
our $REFRESH = 2;
our $UPDATE  = 3;
our $NOTIFY  = 4;
our $ERROR   = 5;
our $DELETE  = 6;


#The unpack format for the different return dhcp objects
#

our %FORMATLIST = (
    'flags'         => 'C',
    'ends'          => 'N',
    'tstp'          => 'N',
    'tsfp'          => 'N',
    'cltt'          => 'N',
    'pool'          => 'N',
    'state'         => 'N',
    'atsfp'         => 'N',
    'starts'        => 'N',
    'subnet'        => 'N',
    'hardware-type' => 'N',
    'result'        => 'N',
    'create'        => 'I',
    'exclusive'     => 'I',
    'handle'        => 'L',
);


#The methods used to unpack special values
#
our %UNPACK_DATA = (
    'ip-address' => , \&unpack_ip_address,
    'hardware-address' =>,\&unpack_hardware_address,
);

#The methods used to pack special values
#
our %PACK_DATA = (
    'ip-address' => , \&pack_ip_address,
    'hardware-address' =>,\&pack_hardware_address,
);


=head1 SUBROUTINES/METHODS

=head2 _trigger_key_base64

The will set the key to the binary from the base 64 version of the key

=cut

sub _trigger_key_base64 {
    my ($self) = @_;
    $self->key(decode_base64($self->key_base64));
}

=head2 _build_key

builds the key from base64 version of the key

=cut

sub _build_key {
    my ($self) = @_;
    return decode_base64($self->key_base64);
}


=head2 connect

Will connect and authenticate to the omapi server

=cut

sub connect {
    my ($self) = @_;
    return 1 if $self->connected;
    my ($received_startup_message,$len);
    my $sock = $self->sock;
    eval {
        local $SIG{ALRM} = sub { die ("Timeout sending on OMAPI socket"); };
        alarm $self->timeout;
        $len = $sock->read($received_startup_message,8);
        my ($version,$headerLength) = unpack('N2',$received_startup_message);
        my $startup_message = pack("N2",$version,$headerLength);
        $len = $sock->send($startup_message) || die "error sending startup message";
        alarm 0;
    };
    alarm 0;
    if($@) {
        die $@;
    }

    unless ($self->send_auth()) {
        $self->connected(0);
        $sock->close();
        $self->clear_sock();
        die "Error send auth";
    }
    $self->connected(1);
    return 1;
}


=head2 send_auth

send the auto info

=cut

sub send_auth {
    my ($self) = @_;
    #no key if the we are good to go
    return 1 unless $self->key && $self->key_name;
    my $reply = $self->send_msg($OPEN,{type => 'authenticator'},{ name => $self->key_name, algorithm => 'hmac-md5.SIG-ALG.REG.INT.'});
    return 0 unless $reply->{op} == $UPDATE;

    $self->authid ($reply->{handle});
    $self->authlen(16);
    return 1;
}

=head2 lookup

Look up a message

=cut

sub lookup {
    my ($self, $msg, $obj) = @_;
    $self->connect();
    return $self->send_msg($OPEN,$msg, $obj);
}

=head2 create_host

=cut

sub create_host {
    my ($self, $mac, $assignments) = @_;
    $assignments //= {};
    use Data::Dumper;
    $self->connect();
    my $previous_entry = $self->lookup({"type" => "host"}, {"hardware-address" => $mac, "hardware-type" => 1});
    if($previous_entry->{op} == 3){
        get_logger->warn("Entry for $mac already exists. Cannot create it...");
    }
    else {
        my $result = $self->send_msg($OPEN, { "type" => "host", "create" => 1, exclusive => 1 }, { "name" => "dynhost-$mac", "hardware-address" => $mac, "hardware-type" => 1, %{$assignments}});
        if($result->{op} == 3){
            get_logger->info("Created host entry for $mac using OMAPI");
        }
        else {
            get_logger->error("Couldn't create host entry for $mac : ".$result->{msg}->{message});
        }
    }
}

sub delete_host {
    my ($self, $mac) = @_;
    $self->connect();
    my $previous_entry = $self->lookup({"type" => "host"}, {"hardware-address" => $mac, "hardware-type" => 1});
    # we check that the host entry exists
    if($previous_entry->{op} == 3){
        my $result = $self->send_msg($DELETE, { "type" => "host" }, { }, $previous_entry->{handle});
        if($result->{msg}->{result} == 0){
            get_logger->info("Successfully deleted host entry for $mac");
        }
        else {
            get_logger->error("Couldn't delete host entry for $mac : ".$result->{msg}->{message});
        }
    }
}

=head2 send_msg

Sends the message to the dhcpd server

=cut

sub send_msg {
    my ($self, $op, $msg, $obj, $handle) = @_;
    $self->op($op);
    $self->handle($handle // 0);
    $self->msg($msg);
    $self->obj($obj);
    $self->send();
    return $self->get_reply();
}

=head2 send

send the message

=cut

sub send {
    my ($self) = @_;
    $self->_build_message;
    my $result;
    eval {
        local $SIG{ALRM} = sub { die ("Timeout sending on OMAPI socket"); };
        alarm $self->timeout;
        $result = $self->sock->send(${$self->buffer});
        alarm 0;
    };
    alarm 0;
    if($@) {
        pf::log::get_logger->error($@);
    }
    return $result;
}

=head2 get_reply

get the reply of the message

=cut

sub get_reply {
    my ($self) = @_;
    my $data;
    eval {
        local $SIG{ALRM} = sub { die ("Timeout reading on OMAPI socket"); };
        alarm $self->timeout;
        $self->sock->recv($data,64*1024);
        alarm 0;
    };
    alarm 0;
    if($@) {
        pf::log::get_logger->error($@);
    }
    return $self->parse_stream($data) ;
}

=head2 _build_message

Builds the message from current data

=cut

sub _build_message {
    my ($self) = @_;
    $self->_clear_buffer;
    my $handle = 0;
    $self->_append_ints_buffer($self->authid,$self->authlen,$self->op,$self->handle,$self->id,0);
    $self->_append_name_values($self->msg);
    $self->_append_name_values($self->obj);
    $self->_sign();
}

=head2 _append_name_values

Appends a hash to the buffer to send

=cut

sub _append_name_values {
    my ($self,$data) = @_;
     while( my ($name,$value) = each %$data) {
        if(exists $FORMATLIST{$name} ) {
            $value = pack($FORMATLIST{$name},$value);
        }
        if(exists $PACK_DATA{$name}) {
            $value = $PACK_DATA{$name}->($self,$value);
        }
        $self->_pack_and_append('n/a* N/a*',$name,$value);
    }
    $self->_pack_and_append('n',0);
    return ;
}

=head2 _build_sock

Creates a socket

=cut

sub _build_sock {
    my ($self) = @_;
    my $sock = IO::Socket::INET->new(PeerAddr => $self->host, PeerPort => $self->port, Timeout => $self->timeout, Proto => 'tcp') || die "Can't bind : $@\n";
    return $sock;
}

=head2 _clear_buffer

Clear the buffer

=cut

sub _clear_buffer {
    my ($self) = @_;
    my $buf = $self->buffer;
    $$buf = '';
}

=head2 _append_ints_buffer

Append a list of integers to the buffer

=cut

sub _append_ints_buffer {
    my ($self,@ints) = @_;
    $self->_pack_and_append('N*',@ints);
}

=head2 _pack_and_append

pack data and apeends it the buffer

=cut

sub _pack_and_append {
    my ($self,$format,@data) = @_;
    my $data = pack($format,@data);
    my $buf = $self->buffer;
    $$buf .= $data;
}


=head2 parse_stream

Parse the omapi message from the given stream

=cut

sub parse_stream {
    my ($self, $buffer) = @_;
    my ($msg,$obj,$sig);
    my ($authid, $authlen, $op, $handle, $id, $rid, $rest) = unpack('N6 a*',$buffer);
    if($rest && length($rest)) {
        ($msg, $rest) = $self->parse_name_value_pairs($rest);
        ($obj, $rest) = $self->parse_name_value_pairs($rest);
        $sig = unpack("B$authlen",$rest);
    }
    return {
        op      => $op,
        id      => $id,
        rid     => $rid,
        handle  => $handle,
        authlen => $authlen,
        authid  => $authid,
        msg     => $msg,
        obj     => $obj,
        sig     => $sig,
    };
}


=head2 parse_name_value

Parses the name value pair from the buffer

=cut

sub parse_name_value_pairs {
    my ($self,$rest) = @_;
    my %data;
    my ($value,$name);
    ($name,$rest) = unpack('n/a a*',$rest);
    while($name) {
        ($value,$rest) = unpack('N/a a*',$rest);
        if(exists $FORMATLIST{$name}) {
            $value = unpack($FORMATLIST{$name},$value);
        }
        if(exists $UNPACK_DATA{$name} ) {
            $value = $UNPACK_DATA{$name}->($self,$value);
        }
        $data{$name} = $value;

        ($name,$rest) = unpack('n/a a*',$rest);
    }
    return (\%data,$rest);
}


=head2 pack_ip_address

Packs the ipaddress from a string

=cut

sub pack_ip_address {
    my ($self,$value) = @_;
    $value = pack("C4",split('\.',$value));
    return $value;
}

=head2 pack_hardware_address

Packs the pack_hardware_address from a string

=cut

sub pack_hardware_address {
    my ($self,$value) = @_;
    return pack("C6", map { hex } split(':',$value));
}

=head2 unpack_ip_address

unpacks the ip address from the buffer

=cut

sub unpack_ip_address {
    my ($self,$value) = @_;
    return join('.',unpack("C4",$value));
}

=head2 unpack_hardware_address

unpacks the hardware from the buffer

=cut

sub unpack_hardware_address {
    my ($self,$value) = @_;
    return join(':',map { sprintf "%02x", $_ } unpack("C6",$value));
}

=head2 _sign

Sign the message

=cut

sub _sign {
    my ($self) = @_;
    return unless $self->authid;
    my $buffer = $self->buffer;
    my $digest = hmac_md5(substr($$buffer,4), $self->key);
    $$buffer .= $digest;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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
