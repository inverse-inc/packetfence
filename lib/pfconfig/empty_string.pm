package pfconfig::empty_string;

=head1 NAME

pfconfig::empty_string

=cut

=head1 DESCRIPTION

Used to represent an empty string in the BDB backend since Cache::BDB doesn't store empty strings

=cut

sub new {
    my ($class) = @_;
    my $self = bless {}, $class;
    return $self;
}

1;
