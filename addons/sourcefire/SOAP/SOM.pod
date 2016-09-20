# ======================================================================
#
# Copyright (C) 2000-2003 Paul Kulchenko (paulclinger@yahoo.com)
# SOAP::Lite is free software; you can redistribute it
# and/or modify it under the same terms as Perl itself.
#
# $Id: SOM.pod 98 2007-10-09 09:41:55Z kutterma $
#
# ======================================================================

=pod

=head1 NAME

SOAP::SOM - provides access to the values contained in SOAP Response

=head1 DESCRIPTION

Objects from the SOAP::SOM class aren't generally instantiated directly by an application. Rather, they are handed back by the deserialization of a message. In other words, developers will almost never do this:

    $som = SOAP::SOM->new;

SOAP::SOM objects are returned by a SOAP::Lite call in a client context. For example:

    my $client = SOAP::Lite
        ->readable(1)
        ->uri($NS)
        ->proxy($HOST)
    $som = $client->someMethod();

=head1 METHODS

=over

=item new(message)

    $som = SOAP::SOM->new($message_as_xml);

As said, the need to actually create an object of this class should be very rare. However, if the need arises, the syntax must be followed. The single argument to new must be a valid XML document the parser will understand as a SOAP response.

=back

The following group of methods provide general data retrieval from the SOAP::SOM object. The model for this is an abbreviated form of XPath. Following this group are methods that are geared towards specific retrieval of commonly requested elements. 

=over

=item match(path)

    $som->match('/Envelope/Body/[1]');

This method sets the internal pointers within the data structure so that the retrieval methods that follow will have access to the desired data. In the example path, the match is being made against the method entity, which is the first child tag of the body in a SOAP response. The enumeration of container children starts at 1 in this syntax, not 0. The returned value is dependent on the context of the call. If the call is made in a boolean context (such as C<< if ($som->match($path)) >>), the return value is a boolean indicating whether the requested path matched at all. Otherwise, an object reference is returned. The returned object is also a SOAP::SOM instance but is smaller, containing the subset of the document tree matched by the expression.

=item valueof(node)

    $res = $som->valueof('[1]');

When the SOAP::SOM object has matched a path internally with the match method, this method allows retrieval of the data within any of the matched nodes. The data comes back as native Perl data, not a class instance (see dataof). In a scalar context, this method returns just the first element from a matched node set. In an array context, all elements are returned. Assuming that the earlier call happens after the earlier call to match, it retrieves the result entity from the method response that is contained in C<$som>, as this is the first child element in a method-response tag.

=item dataof(node)

    $resobj = $som->dataof('[1]');

Performs the same operation as the earlier valueof method, except that the data is left in its L<SOAP::Data> form, rather than being deserialized. This allows full access to all the attributes that were serialized along with the data, such as namespace and encoding.

=item headerof(node)

    $resobj = $som->headerof('[1]');

Acts much like dataof, except that it returns an object of the L<SOAP::Header> class (covered later in this chapter), rather than SOAP::Data. This is the preferred interface for manipulating the header entities in a message.

=item namespaceuriof(node)

    $ns = $som->namespaceof('[1]');

Retrieves the namespace URI that governs the requested node. Note that namespaces are inherited, so this method will return the relevant value, even if it derives from a parent or other ancestor node.

=back

The following methods provide more direct access to the message envelope. All these methods return some form of a Perl value, most often a hash reference, when called. Context is also relevant: in a scalar context only the first matching node is returned, while in an array context, all matching nodes are. When called as a static method or as a regular function (such as C<SOAP::SOM::envelope>), any of the following methods returns the XPath string that is used with the match method to retrieve the data.

=over

=item root

    $root = $som->root;

Returns the value of the root element as a hash reference. It behaves exactly as C<$som->valueof('/')> does.

=item envelope

    $envelope = $som->envelope;

Retrieves the "Envelope" element of the message, returning it and its data as a hash reference. Keys in the hash will be Header and Body (plus any optional elements that may be present in a SOAP 1.1 envelope), whose values will be the serialized header and body, respectively.

=item header

    $header = $som->header;

Retrieves the header portion of the envelope as a hash reference. All data within it will have been deserialized. If the attributes of the header are desired, the static form of the method can be combined with match to fetch the header as a SOAP::Data object:

    $header = $som->match(SOAP::SOM::header)->dataof;

=item headers

    @hdrs = $som->headers;

Retrieves the node set of values with deserialized headers from within the Header container. This is different from the earlier header method in that it returns the whole header as a single structure, and this returns the child elements as an array. In other words, the following expressions yield the same data structure:

    $header = ($som->headers)[0];
    $header = $som->valueof(SOAP::SOM::header.'/[1]');

=item body

    $body = $som->body;

Retrieves the message body as a hash reference. The entity tags act as keys, with their deserialized content providing the values.

=item fault

    if ($som->fault) { die $som->fault->faultstring }

Acts both as a boolean test whether a fault occurred, and as a way to retrieve the Fault entity itself from the message body as a hash reference. If the message contains a fault, the next four methods (faultcode, faultstring, faultactor, and faultdetail) may be used to retrieve the respective parts of the fault (which are also available on the hash reference as keys). If fault in a boolean context is true, the C<result>, C<paramsin>, C<paramsout>, and C<method> methods all return C<undef>.

=item faultcode

    $code = $som->faultcode;

Returns the faultcode element of the fault if there is a fault; undef otherwise.

=item faultstring

    $string = $som->faultstring;

Returns the faultstring element of the fault if there is a fault; undef otherwise.

=item faultactor

    $actor = $som->faultactor;

Returns the faultactor element of the fault, if there is a fault and if the actor was specified within it. The faultactor element is optional in the serialization of a fault, so it may not always be present. This element is usually a string.

=item faultdetail

    $detail = $som->faultdetail;

Returns the content of the detail element of the fault, if there is a fault and if the detail element was provided. Note that the name of the element isn't the same as the method, due to the possibility for confusion had the method been called simply, detail. As with the faultactor element, this isn't always a required component of a fault, so it isn't guaranteed to be present. The specification for the detail portion of a fault calls for it to contain a series of element tags, so the application may expect a hash reference as a return value when detail information is available (and undef otherwise).

=item method

    $method = $som->method

Retrieves the "method" element of the message, as a hash reference. This includes all input parameters when called on a request message or all result/output parameters when called on a response message. If there is a fault present in the message, it returns undef.

=item result

    $value = $som->result;

Returns the value that is the result of a SOAP response. The value will be already deserialized into a native Perl datatype.

=item paramsin

    @list = $som->paramsin;

Retrieves the parameters being passed in on a SOAP request. If called in a scalar context, the first parameter is returned. When called in a list context, the full list of all parameters is returned. Each parameter is a hash reference, following the established structure for such return values.

=item paramsout

    @list = $som->paramsout;

Returns the output parameters from a SOAP response. These are the named parameters that are returned in addition to the explicit response entity itself. It shares the same scalar/list context behavior as the paramsin method.

=item paramsall

    @list = $som->paramsall;

Returns all parameters from a SOAP response, including the result entity itself, as one array.

=item parts()

Return an array of C<MIME::Entity>'s if the current payload contains attachments, or returns undefined if payload is not MIME multipart.

=item is_multipart()

Returns true if payload is MIME multipart, false otherwise.

=back

=head1 EXAMPLES

=head2 ACCESSING ELEMENT VALUES

Suppose for the following SOAP Envelope:

    <Envelope>
      <Body>
        <fooResponse>
          <bar>abcd</bar>
        </fooResponse>
      </Body>
    </Envelope>

And suppose you wanted to access the value of the bar element, then use the following code:

    my $soap = SOAP::Lite
        ->uri($SOME_NS)
        ->proxy($SOME_HOST);
    my $som = $soap->foo();
    print $som->valueof('//fooResponse/bar');

=head2 ACCESSING ATTRIBUTE VALUES

Suppose the following SOAP Envelope:

    <Envelope>
      <Body>
        <c2fResponse>
          <convertedTemp test="foo">98.6</convertedTemp>
        </c2fResponse>
      </Body>
    </Envelope>

Then to print the attribute 'test' use the following code:

    print "The attribute is: " . 
      $som->dataof('//c2fResponse/convertedTemp')->attr->{'test'};

=head2 ITERATING OVER AN ARRAY

Suppose for the following SOAP Envelope:

    <Envelope>
      <Body>
        <catalog>
          <product>
            <title>Programming Web Service with Perl</title>
            <price>$29.95</price> 
          </product>
          <product>
            <title>Perl Cookbook</title>
            <price>$49.95</price> 
          </product>
        </catalog>
      </Body>
    </Envelope>

If the SOAP Envelope returned contained an array, use the following code to iterate over the array:

    for my $t ($som->valueof('//catalog/product')) {
      print $t->{title} . " - " . $t->{price} . "\n";
    }

=head2 DETECTING A SOAP FAULT

A SOAP::SOM object is returned by a SOAP::Lite client regardless of whether the call succeeded or not. Therefore, a SOAP Client is responsible for determining if the returned value is a fault or not. To do so, use the fault() method which returns 1 if the SOAP::SOM object is a fault and 0 otherwise.

    my $som = $client->someMethod(@parameters);

    if ($som->fault) {
      print $som->faultdetail;
    } else {
      # do something
    }

=head2 PARSING ARRAYS OF ARRAYS

The most efficient way To parse and to extract data out of an array containing another array encoded in a SOAP::SOM object is the following:

    $xml = <<END_XML;
    <foo>
      <person>
        <foo>123</foo>
        <foo>456</foo>
      </person>
      <person>
        <foo>789</foo>
        <foo>012</foo>
      </person>
    </foo>
    END_XML

    my $som = SOAP::Deserializer->deserialize($xml);
    my $i = 0;
    foreach my $a ($som->dataof("//person/*")) {
        $i++;
        my $j = 0;
        foreach my $b ($som->dataof("//person/[$i]/*")) {
            $j++;
            # do something
        }
    }

=head1 SEE ALSO

L<SOAP::Data>, L<SOAP::Serializer>

=head1 ACKNOWLEDGEMENTS

Special thanks to O'Reilly publishing which has graciously allowed SOAP::Lite to republish and redistribute large excerpts from I<Programming Web Services with Perl>, mainly the SOAP::Lite reference found in Appendix B.

=head1 COPYRIGHT

Copyright (C) 2000-2004 Paul Kulchenko. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Paul Kulchenko (paulclinger@yahoo.com)

Randy J. Ray (rjray@blackperl.com)

Byrne Reese (byrne@majordojo.com)

=cut
