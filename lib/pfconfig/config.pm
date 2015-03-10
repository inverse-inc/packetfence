package pfconfig::config;

use pfconfig::util;
use Config::IniFiles;

sub new {
    my ($class) = @_;
    my $self = bless {}, $class;
    $self->init();
    return $self;
}

sub init {
    my ($self) = @_;
    my $file = pfconfig::util::config_file_path();    
    
    my %cfg;
    tie %cfg, 'Config::IniFiles', (-file => $file);

    $self->{cfg} = \%cfg;
}

sub section {
    my ($self,$name) = @_;
    return $self->{cfg}{$name};
}

sub log_level {
    my ($self) = @_;
    return $self->{cfg}{general}{log_level};
}

1;
