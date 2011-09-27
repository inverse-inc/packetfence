#!/usr/bin/perl

=head1 NAME

soh.cgi - A web interface to manage SoH rules

=cut

use lib "/usr/local/pf/lib";

use CGI;
use POSIX;
use Try::Tiny;
use CGI::Session;
use HTML::Entities;
use CGI::Carp qw( fatalsToBrowser );
use Locale::gettext;
use Log::Log4perl;
use PHP::Session;
use DBD::mysql;
use Template;
use JSON;

use pf::config;
use pf::web;
use pf::web::custom;

# If we can find an existing PHP session, we allow the user to proceed.
# Otherwise we redirect to / and let login.php handle authentication. We
# also need a CGI::Session object to (try to) play nice with pf::web.

my $q = CGI->new;
my $sid = $q->cookie('PHPSESSID');
my $sdir = "$install_dir/var/session";

my $session;
if ($sid && -f "$sdir/sess_$sid") {
    $session = PHP::Session->new($sid, {save_path => $sdir});
}
unless ($session && $session->get('user')) {
    print $q->redirect("/");
    exit;
}

my $csession = CGI::Session->new(undef, $q, {Directory => '/tmp'});

# Next, set up our logger, database handle, translation context, etc.

Log::Log4perl->init("$conf_dir/log.conf");
my $logger = Log::Log4perl->get_logger('soh.cgi');

my ($db, $host, $port, $user, $pass) =
    @{$Config{database}}{qw/db host port user pass/};

my $dbh = DBI->connect(
    "dbi:mysql:dbname=$db;host=$host;port=$port", $user, $pass,
    { RaiseError => 0, PrintError => 0 }
);

setlocale(LC_MESSAGES, pf::web::web_get_locale($q, $csession));
bindtextdomain("packetfence", "$conf_dir/locale");
textdomain("packetfence");

# Now, what does this request ask of us?
#
# We know how to (a) generate the index page, (b) add a filter,
# (c) delete a filter, (d) add/edit/delete the rules in a filter.

my $method = $q->request_method;
(my $action = $q->path_info) =~ s/^\///;

# GET / renders templates/soh/index.html

if ($method eq 'GET' && $action eq '') {
    print $q->header;

    my $filters = $dbh->selectall_arrayref(
        "select filter_id, name, action, vid ".
        "from soh_filters order by filter_id asc",
        {Slice => {}}
    );

    my $rules = $dbh->selectall_arrayref(
        "select filter_id, class, op, status ".
        "from soh_filter_rules order by filter_id asc, ".
        "rule_id asc", {Slice => {}}
    );

    $filters ||= [{filter_id => 1, name => "Default"}];
    $rules ||= [];

    my $vars = {
        self => $q->url(-absolute => 1, -rewrite => 1),
        logo => $Config{general}{logo},
        i18n => \&pf::web::i18n,
        list_filters => $filters,
        list_rules => $rules
    };

    my $tmpl = Template->new({INCLUDE_PATH => [$CAPTIVE_PORTAL{TEMPLATE_DIR}]});
    $tmpl->process("soh/index.html", $vars);
}

# POST /filters/* does something and returns a JSON response

elsif ($method eq 'POST' && $action =~ s/^filters\///) {
    my $r = { status => 'error', message => "Invalid request" };

    my $name = $q->param('name');
    my $dname = encode_entities($name);

    if (($action eq 'add' || $action eq 'delete') && !$name) {
        $r->{message} = i18n("You must specify a filter name");
    }

    elsif (($action eq 'add' || $action eq 'delete') && $name =~ /[^a-zA-Z0-9_-]/) {
        $r->{message} = i18n("Invalid filter name (must be alphanumeric)");
    }

    # Add a named filter and return the new filter_id.

    elsif ($action eq 'add') {
        my $insert = "insert into soh_filters (name) values (?)";
        unless ($dbh->do($insert, {}, $name)) {
            $r->{message} = $dbh->errstr ||
                i18n("Couldn't create filter $dname");
        }
        else {
            $r->{filter_id} = $dbh->last_insert_id((undef)x4);
            $r->{message} = i18n("Filter $dname created");
            $r->{status} = 'ok';
        }
    }

    # Delete a named filter (and let MySQL delete all the associated
    # rules), but protect the filter named default.

    elsif ($action eq 'delete') {
        my $delete = "delete from soh_filters where name=?";
        if (lc $name eq 'default') {
            $r->{message} = i18n("You may not delete the default filter");
        }
        elsif (not $dbh->do($delete, {}, $name)) {
            $r->{message} = $dbh->errstr || i18n("No filter named $dname");
        }
        else {
            $r->{message} = i18n("Filter $dname deleted");
            $r->{status} = 'ok';
        }
    }

    # Delete and recreate all filter rules based on the submitted data.
    # This is based on the assumption that there will be only a few SoH
    # filters at any time, with only a handful of rules in each one.

    elsif ($action eq 'save') {
        $dbh->begin_work;
        try {
            local $dbh->{RaiseError} = 1;

            my @ids = $q->param('filter_id');
            my @names = $q->param('filter_name');
            my @actions = $q->param('action');
            my @vids = $q->param('vid');

            foreach my $fid (@ids) {
                my $name = shift @names || undef;
                my $dname = encode_entities($name);
                my $action = shift @actions || undef;
                my $vid = shift @vids || undef;

                $name = "Default" if $fid == 1;

                die "Invalid name specified: $dname"
                    if $name && $name =~ /[^a-zA-Z0-9_-]/;
                die "Invalid action specified for filter $dname"
                    if $action && $action =~ /[^a-zA-Z0-9-]/;
                die "Invalid violation id specified for filter $dname"
                    if $vid && $vid =~ /[^0-9]/;
                die "No violation id specified for filter $dname"
                    if ($action && $action eq 'violation' && !$vid);

                $dbh->do(
                    "update soh_filters set name=?, action=?, vid=? ".
                    "where filter_id=?", {}, $name, $action, $vid, $fid
                );

                $dbh->do(
                    "delete from soh_filter_rules where filter_id=?",
                    {}, $fid
                );

                my @classes = $q->param("r${fid}class");
                my @ops = $q->param("r${fid}op");
                my @statuses = $q->param("r${fid}status");

                foreach my $class (@classes) {
                    $class ||= undef;
                    my $op = shift @ops || undef;
                    my $status = shift @statuses || undef;

                    die "Invalid class specified"
                        if $class && $class =~ /[^a-zA-Z0-9]/;
                    die "Invalid op specified"
                        if $op && $op =~ /[^a-zA-Z0-9]/;
                    die "Invalid status specified"
                        if $status && $status =~ /[^a-zA-Z0-9_-]/;

                    $dbh->do(
                        "insert into soh_filter_rules ".
                        "(filter_id, class, op, status) values (?, ?, ?, ?)",
                        {}, $fid, $class, $op, $status
                    );
                }
            }

            $dbh->commit;
        }
        catch {
            # TODO: Translate the SQL error into something nicer
            $r->{message} = $_;
            try { $dbh->rollback };
        }
        finally {
            unless (@_) {
                $r->{message} = i18n("Filter rules saved");
                $r->{status} = 'ok';
            }
        }
    }

    print $q->header('application/json');
    print to_json($r);
}

# Anything else is an error

else {
    pf::web::generate_error_page($q, $csession, i18n("Unrecognised request"));
}

=head1 AUTHOR

Abhijit Menon-Sen <amenonsen@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2011 Inverse inc.

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
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
MA 02110-1301, USA.

=cut
