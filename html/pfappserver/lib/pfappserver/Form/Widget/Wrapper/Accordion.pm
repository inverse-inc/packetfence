package pfappserver::Form::Widget::Wrapper::Accordion;

=head1 NAME

pfappserver::Form::Widget::Wrapper::Accordion

=cut

=head1 DESCRIPTION

pfappserver::Form::Widget::Wrapper::Accordion

=cut

use Moose::Role;
with 'HTML::FormHandler::Widget::Wrapper::Bootstrap';
use HTML::FormHandler::Render::Util ('process_attrs');
use pf::log;

around wrap_field => sub {
    my ($orig, $self, $result, $rendered_widget ) = @_;
    my $output = '';
#    use Data::Dumper;get_logger->info(Dumper($self));
    my $parent_name = $self->parent->name;
    my $name = $self->name;
    my $id = "accordion_" . $self->parent->name . "_" . $name;
    my $heading = $self->get_tag("accordion_heading");
    $heading = $self->do_accordion_heading unless $heading;

    $output = <<EOS;
<div class="accordion-group">
    $heading
    <div id="$id" class="accordion-body collapse">
        <div class="accordion-inner">$rendered_widget</div>
    </div>
</div>
EOS
    return $output;
};

sub do_accordion_heading {
    my ($self) = @_;
    my $content = $self->get_tag("accordion_heading_content");
    $content  = $self->do_accordion_heading_content unless $content;
    return <<EOS;
    <div class="accordion-heading">
        $content
    </div>
EOS
}

sub do_accordion_heading_content {
    my ($self) = @_;
    my $parent_name = $self->parent->name;
    my $name = $self->name;
    my $id = "accordion_" . $self->parent->name . "_" . $name;
    return <<EOS;
        <a class="accordion-toggle" data-toggle="collapse" href="#$id">
            $parent_name $name
        </a>
EOS
}

use namespace::autoclean;
1;

=head1 AUTHOR

Inverse inc. <info@inverse.ca>


=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and/or
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

