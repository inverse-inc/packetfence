package pf::web::provisioning::custom;

=head1 NAME

pf::web::provisioning::custom - Object oriented module for provisioning wifi profile.

=head1 SYNOPSIS

The pf::web::provisioning:custom module implement provisioning oriented finctions that are custom
to a particular setup.

=cut

use strict;
use warnings;
use Apache2::Request;
use Log::Log4perl;
use pf::config;
use pf::node;
use pf::web;
use pf::web::util;
use Apache2::Const;
use pf::Portal::Session;
use pf::util;


use base ('pf::web::provisioning');


1;

