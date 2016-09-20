package SOAP::Lite::Deserializer::XMLSchema2001;

use strict;
use SOAP::Lite::Deserializer::XMLSchema1999;
use SOAP::Lite::Deserializer::XMLSchemaSOAP1_1;
use SOAP::Lite::Deserializer::XMLSchemaSOAP1_2;

sub anyTypeValue { 'anyType' }
sub as_string; *as_string = \&SOAP::Lite::Deserializer::XMLSchema1999::as_string;
sub as_anyURI; *as_anyURI = \&SOAP::Lite::Deserializer::XMLSchemaSOAP1_1::as_anyURI;
sub as_boolean; *as_boolean = \&SOAP::Lite::Deserializer::XMLSchemaSOAP1_2::as_boolean;
sub as_base64Binary; *as_base64Binary = \&SOAP::Lite::Deserializer::XMLSchemaSOAP1_2::as_base64;
sub as_hexBinary; *as_hexBinary = \&SOAP::Lite::Deserializer::XMLSchema1999::as_hex;
sub as_undef; *as_undef = \&SOAP::Lite::Deserializer::XMLSchema1999::as_undef;

BEGIN {
    no strict 'refs';
    for my $method (qw(
        anyType anySimpleType
        float double decimal dateTime timePeriod gMonth gYearMonth gYear 
        century gMonthDay gDay duration recurringDuration
        language integer nonPositiveInteger negativeInteger long int short 
        byte nonNegativeInteger unsignedLong unsignedInt unsignedShort 
        unsignedByte positiveInteger date time dateTime
        QName
    )) {
        my $name = 'as_' . $method;
        *$name = sub { $_[1] }
    }
}

1;