#!/usr/bin/perl
use strict;
use Template::Parser;
use File::Slurp qw(read_file);

our $GIT_COMMAND = q[/usr/bin/git];
our @ERRORS;
our $STASHED;

END {
    if($STASHED) {
        local $?;
        git_cmd (qw(reset --hard));
        git_cmd (qw(stash apply --index));
        git_cmd (qw(stash drop --index));
    }
}

my ($code,$output);
our $OLD_STASH;

($code,$OLD_STASH) = git_cmd(qw(rev-parse -q --verify refs/stash));

($code,$output) = git_cmd(qw(stash --keep-index));

unless( $code == 0 ) {
    print STDERR "Error stashing working space\n";
    print STDERR $output;
    exit 1;
}

our ($code,$NEW_STASH) = git_cmd(qw(rev-parse -q --verify refs/stash));

#return if there are no changes
exit 0 if $OLD_STASH eq $NEW_STASH;

$STASHED = 1;

sub pod_checker {
    my ($file_name) = @_;
    if(does_file_match({file_match => qr/\.pm$/},$file_name)) {
        $file_name = quotemeta($file_name);
        my $results = qx{/usr/bin/podchecker $file_name 2>&1};
        push @ERRORS,$results if $? != 0;
    }
}

sub perl_compile {
    my ($file_name) = @_;
    if(does_file_match({file_match => qr/\.(pm|cgi|pl)$/},$file_name)) {
        $file_name = quotemeta($file_name);
        my $results = qx{/usr/bin/perl -c -Ilib $file_name 2>&1};
        push @ERRORS,$results if $? != 0;
    }
}

sub template_compile {
    my ($file_name) = @_;
    if(does_file_match({file_match => qr/\.(tt)$/},$file_name)) {
        my $parser = Template::Parser->new({});
        my $file = read_file($file_name);
        my $data = $parser->parse($file);
        push @ERRORS,$parser->error() unless $data;
    }
}

sub git_cmd {
    my @args = @_;
    my $cmd = join (' ',map {quotemeta $_} @args);
    my $result = qx{$GIT_COMMAND $cmd};
    return ($?,$result);
}

#my ($ret,$result) = git_cmd(qw{stash --include-untracked});
#$STASHED = ($ret == 0);

my @NO_ADD_TESTS = (
    {
        test_name  => "No Data::Dumper",
        file_match => qr/\.pm$/,
        line_match => qr/^\s*use\s*Data::Dumper/
    },
    {
        test_name  => "No lowercase in =head1",
        file_match => qr/\.pm$/,
        line_match => qr/=head1 .[a-z]+./
    },
    {
        test_name  => "No console.log",
        file_match => qr/\.js$/,
        line_match => qr/(^|\s)console\s*\.log/
    }
);

my @RUNNER_TESTS = (
    {
        test_name  => "Pod checker",
        file_match => qr/\.pm$/,
        runner => "/usr/bin/podchecker %s 2>&1",
    },
);


our %changed_files;

if(has_changed_files()) {
    my ($ret,$result) = git_cmd(qw{diff -z --cached --name-status});
    my %temp =  reverse split /\0/,$result;
    while(my ($file_name,$status) = each %temp) {
        $changed_files{$file_name} = {
          status => $status,
        };
    }
    my @changed_files = grep { $changed_files{$_}{status} ne 'D' } keys %changed_files;
    for my $file_name (@changed_files) {
        match_no_add ($file_name);
        runner ($file_name);
        perl_compile ($file_name);
        template_compile($file_name);
    }
}

if (@ERRORS) {
    push @ERRORS, "To bypass pre-commit hook use 'git commit --no-verify'";
    print STDERR join("\n",@ERRORS,"");
    exit 1;
}

sub match_no_add {
    my ($file) = @_;
    my $results;
    my @tests = grep { can_do_match_no_add($_,$file) } @NO_ADD_TESTS;
    foreach my $test (@tests) {
        my $line_match = $test->{line_match};
        my @matched = grep {$_ =~ $line_match } added_lines($file);
        if(@matched) {
            my $test_name = $test->{name} || "No add";
            push @ERRORS,  "Test '$test_name' failed","The following lines should not be added in $file",@matched;
        }
    }
}

sub runner {
    my ($file_name) = @_;
    my @tests = grep { exists $_->{runner} && can_do_match_no_add($_,$file_name) } @RUNNER_TESTS;
    $file_name = quotemeta($file_name);
    foreach my $test (@tests) {
        my $runner = sprintf($test->{runner},$file_name);
        my $results = qx{$runner};
        if($? != 0) {
            my $test_name = $test->{test_name};
            push @ERRORS,"Test '$test_name' failed for $file_name", $results;
        }
    }
}


sub can_do_match_no_add {
    my ($test,$file) = @_;
    return does_file_match($test,$file) && file_not_excluded($test,$file);
}

sub does_file_match {
    my ($test,$file) = @_;
    return !exists $test->{file_match} ||  $file =~ $test->{file_match};
}

sub file_not_excluded {
    my ($test,$file) = @_;
    my $result = 1;
    if (exists $test->{excluded}) {

    }
    return $result;
}

sub added_lines {
    my ($file) = @_;
    if(exists $changed_files{$file}) {
        my $changed_file = $changed_files{$file};
        add_diff_data($file) unless (exists $changed_file->{added_lines});
        return @{$changed_file->{added_lines}};
    }
    return ();
}

sub add_diff_data {
    my ($file) = @_;
    my ($ret,$result) = git_cmd(qw{diff --cached},$file);
    my @lines = split $/,$result;
    my $changed_file = $changed_files{$file};
    $changed_file->{diff} = $result;
    $changed_file->{diff_lines} = \@lines;
    $changed_file->{added_lines} = [ map {local $_= $_;s/^\+ {4}//;$_} grep { /^\+ {4}/ } @lines  ];
    $changed_file->{deleted_lines} = [ map {local $_= $_;s/^- {4}//;$_} grep { /^- {4}/ } @lines  ];
}


sub get_file_content {
    my ($file) = @_;
    my ($ret,$result) = git_cmd(qw{cat-file blob},"HEAD:$file");
    return $result;
}

sub has_changed_files {
    my ($ret,$result) = git_cmd(qw(diff-index --quiet HEAD -- ));
    return $ret != 0;
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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


