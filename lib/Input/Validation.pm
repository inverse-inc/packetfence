package Input::Validation;

use 5.016003;
use strict;
require Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

our @ISA = qw(Exporter);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = qw(sanitize validate form_field_validation);
our @EXPORT = qw(sanitize validate form_field_validation);
our $VERSION = '1.00';

our $VALID_PORT_REGEX = qr/^()([1-9]|[1-5]?[0-9]{2,4}|6[1-4][0-9]{3}|65[1-4][0-9]{2}|655[1-2][0-9]|6553[1-5])$/;
our $VALID_MAC_REGEX = qr/^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$/i;
our $VALID_DOMAIN_REGEX = qr/^(?!:\/\/)([a-zA-Z0-9-_]+\.)*[a-zA-Z0-9][a-zA-Z0-9-_]+\.[a-zA-Z]{2,11}?$/i;
our $VALID_DOMAIN_WILDCARD_REGEX = qr/^(?!:\/\/)([a-zA-Z0-9-_*]+\.)*[a-zA-Z0-9][a-zA-Z0-9-_]+\.[a-zA-Z]{2,11}?$/i;
our $VALID_HOSTNAME_REGEX = qr/^(([a-zA-Z]|[a-zA-Z][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z]|[A-Za-z][A-Za-z0-9\-]*[A-Za-z0-9])$/i;
our $VALID_IP_REGEX = qr/^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$/;
our $VALID_HOSTNAME_IP_REGEX = qr/^([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])(\.([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]{0,61}[a-zA-Z0-9]))*$/;

=head2 form_field_validation

Form Field Validation

=cut

sub form_field_validation {
    my ($action , $single_input , $field) = @_;
    my ($field_value , $field_name , @values_array) = ($field->value , $field->name);
    return (1) if (!defined($field_value));
    $field_value =~ s/\n/\,/g; # Replace newlines with commas
    @values_array = split(',',sanitize($field_value, nospace => 1), ( ($single_input) ? (1) : (-1) )); # Remove all spaces and split
    
    foreach my $value (@values_array)  
    { 
        if(!validate($value, $action => 1) || $value eq '') { return ($field->add_error("Invalid " . uc($field_name) . " Value!"),0); }
    } 
}

sub sanitize
{
	my ($s, @args) = @_;
	if(!$s) { return ""; }
	my ($state, $result) = _process(@_);
	return $result;
}

sub validate
{
	my ($s) = @_;
	if(!$s) { return 1; }
	my ($state, $result) = _process(@_);
	return $state;
}

sub _process
{
	my ($s, %opts) = @_;

	my $dispatch;
	$dispatch = {
 		'port' => sub { 
			return 2 if( !($s =~ $VALID_PORT_REGEX) );
		 },
  		'mac' => sub { 
			return 2 if( !($s =~ $VALID_MAC_REGEX) );
		},
  		'domain' => sub { 
			return 2 if( !($s =~ $VALID_DOMAIN_REGEX) );
		},
		'domain&&wildcard' => sub { 
			return 2 if( !($s =~ $VALID_DOMAIN_WILDCARD_REGEX) );
		},
  		'hostname' => sub { 	
			return 2 if( !($s =~ $VALID_HOSTNAME_REGEX) );
		},
		'ip' => sub { 
			return 2 if( !($s =~ $VALID_IP_REGEX) );
		},
  		'hostname||ip' => sub { 
			return 2 if( !($s =~ $VALID_HOSTNAME_IP_REGEX) );
		},
  		'alpha' => sub { 
			$s =~ s/[^A-Za-z0-9]//g;
		},
  		'hex' => sub { 
			$s =~ s/[^A-Fa-f0-9]//g;
		},
		'number' => sub { 
			$s =~ s/[^0-9]//g;
		},
  		'html' => sub { 
			$s =~ s/</&lt;/g;
			$s =~ s/>/&gt;/g;
		},
  		'nospace' => sub { 
			$s =~ s/\s+//g;
		},
		'noquotes' => sub { 
			$s =~ s/"//g;
			$s =~ s/'//g;
		},
  		'noencodings' => sub { 
			$s =~ s/%[0-9A-Fa-f]{2}//g;
		},
  		'email' => sub { 
			my ($name, $host) = split('@', $s);
			if(!$name || !$host) { return (0, ""); }
			$name = (split(' ', $name))[-1];
			$host = (split(' ', $host))[0];
			$name =~ s/[^A-Za-z0-9\.\!\#\$\%\&\'\*\+\-\/\=\?\^\_\`\{\|\}~]//g;
			$host =~ s/[^A-Za-z0-9\.\-]//g;
			$host =~ s/[\.\-]$//g;
			$s = $name . '@' . $host;
		}
	};

	foreach my $key (keys %opts)
	{
		last if( !(exists $dispatch->{lc($key)}) );
		my $state = $dispatch->{lc($key)}->();
		return (0,"") if (defined($state) && $state == 2);	
	}

	return ($s eq $_[0] ? 1 : 0, $s);
}

1;
__END__

=head1 NAME

Sanitize/Validate - Return true if validated or sanitize the input if using sanitize
