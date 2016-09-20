package SOAP::Lite::Deserializer::XMLSchema1999;
use strict;

use SOAP::Lite::Deserializer::XMLSchemaSOAP1_1;

sub anyTypeValue { 'ur-type' }

# use as_string and as_boolean from SOAP1_1 Deserializer

sub as_string; *as_string = \&SOAP::Lite::Deserializer::XMLSchemaSOAP1_1::as_string;
sub as_boolean; *as_boolean = \&SOAP::Lite::Deserializer::XMLSchemaSOAP1_1::as_boolean;

sub as_hex { 
    shift; 
    my $value = shift; 
    $value =~ s/([a-zA-Z0-9]{2})/chr oct '0x'.$1/ge; 
    $value 
}

sub as_ur_type { $_[1] }

sub as_undef {
    shift;
    my $value = shift;
    $value eq '1' || $value eq 'true'
        ? 1 
        : $value eq '0' || $value eq 'false'
            ? 0 
            : die "Wrong null/nil value '$value'\n";
}

BEGIN {
    no strict 'refs';
    for my $method (qw(
        float double decimal timeDuration recurringDuration uriReference
        integer nonPositiveInteger negativeInteger long int short byte
        nonNegativeInteger unsignedLong unsignedInt unsignedShort unsignedByte
        positiveInteger timeInstant time timePeriod date month year century
        recurringDate recurringDay language
    )) {
        my $name = 'as_' . $method;
        *$name = sub { $_[1] };
    }
}

1;