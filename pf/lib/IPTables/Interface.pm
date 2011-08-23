# IPTables::Interface - Perl style wrapper interface for IPTables::libiptc

package IPTables::Interface;

use strict;
use warnings;
use Carp;
use Time::HiRes; # Used for timing stuff
#use Errno qw(:POSIX);

#use Data::Dumper;

use IPTables::libiptc;

# Logging system
use Log::Log4perl qw(get_logger :levels);
my $logger = get_logger(__PACKAGE__);

# Locking system
use IPTables::Interface::Lock;
our $lock_base_name="iptables_cmd_lock";
our $lock = IPTables::Interface::Lock::new("$lock_base_name"); # Lock object instans

BEGIN {
     use Exporter ();
     our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

     # Package version
     $VERSION     = 0.3001;

     @ISA         = qw(Exporter);
     @EXPORT      =
      qw(
      );
}

# Package counter variables
our $command_timesum=0;
our $command_count=0;
our %stat_timesum;
our %stat_count;


# TODO: Remember to implement a Singelton class for each table.
#
# This is needed because libiptc returns a table handle that all
# changes MUST be apply to e.g. as changes will be lost if using
# several handles to the same table.
#
our %table_singleton_objects;

# Create a new iptables interface Object.
sub new
{
    my $tablename = shift;
    my $self      = {};
    my $log = "[Function] init() libiptc handle";

    # Extract object if it already exist.
    my $singleton = $table_singleton_objects{"$tablename"};
    if (defined $singleton) {
	$logger->debug("$log (returning singleton object)");
	return $singleton;
    }

    # Init / create a new object.
    # ---------------------------

    # TODO: Obtain lock here, before handle init...
    # TODO: Obtain a lock per "table"
    #$lock->lock("$tablename");
    $lock->lock();

    timer_start();
    my $handle = IPTables::libiptc::init("$tablename");
    timer_end("init");
    my $init_time = $stat_timesum{"init"};

    if (not defined $handle) {
	my $errmsg = "Cannot init libiptc handle: \"$!\"";
	$logger->logcroak($errmsg);
    } else {
	my $logtxt = sprintf("$log (InitTime:[%.3fs])", $init_time);
	#
	# Inform through error logging, if init time is high.
	if ($init_time > 0.5) {
	    $logger->error($logtxt);
	} else {
	    $logger->info($logtxt);
	}
    }

    bless $self;

    $self->{'tablename'}                   = $tablename;
    $self->{'handle'}                      = $handle;
    $table_singleton_objects{"$tablename"} = $self;

    return $self;
}

sub commit()
{
    my $func   = "commit";
    my $self   = shift;
    my $handle = $self->get_handle();
    my $log    = "[Function] $func()";
    $logger->debug($log);

    timer_start();
    my $success = $handle->commit();
    timer_end($func);

    my $tablename = $self->{'tablename'};

    # TODO: Unlock here...
    # $lock->unlock("$tablename");
    $lock->unlock();

    # Delete singleton hash/object instans here...
    delete $table_singleton_objects{"$tablename"};
    # TODO: What about destroying this object...?
    #       It would be wise to indicate, "do not use anymore after a commit"

    # TODO: What about destroying the iptables handle?
    #       (think that is done in the XS/C-code).

    if (!$success) {
	my $err="Cannot commit, you might be missing a kernel module";
	$err  .=" but have the userspace support.";
	$logger->log($FATAL, $err);
    }

    $self->record_info($success, $log, $FATAL);
    return $success;
}

sub get_handle()
{
    my $self   = shift;
    my $handle = $self->{'handle'};
    return $handle;
}

sub get_tablename()
{
    my $self = shift;
    my $name = $self->{'tablename'};
    return $name;
}

sub record_info($$$)
{
    my $self     = shift;
    my $success  = shift;
    my $logmsg   = shift;
    my $loglevel = shift || $WARN;

    $self->{'success'} = $success;

    if (!$success) {
	#my $errno  = $!;
	#my $errno  = $!{ENOENT};
	#$self->{'errno'}  = $errno;
	my $errstr = "$!";
	$self->{'logmsg'} = $logmsg;
	$self->{'errstr'} = "$errstr";
	#my $errmsg = "$logmsg: (errno:$errno) $errstr";
	my $errmsg = "$logmsg: $errstr";
	$self->{'errmsg'} = $errmsg;
	$logger->log($loglevel, $errmsg);
    }
}

##########################################
# Statistics functions
##########################################

our $collect_stats = 1;
our $timer_start;

sub timer_start()
{
    $timer_start = Time::HiRes::time() if $collect_stats;
    #return $timer_start;
}

sub timer_end($)
{
    if ($collect_stats) {
	my $function = shift;
	my $time_end = Time::HiRes::time();
	my $timediff = $time_end - $timer_start;

	# Record statistics
	$command_count++;
	$command_timesum += $timediff;
	$stat_count{"$function"}++;
	$stat_timesum{"$function"} += $timediff;
	#return $timediff;
    }
}

sub report_statistics()
{
    my $self = shift;

    my $time_total   = $self->get_commands_time_total();
    my $count        = $self->get_commands_count();
    my $time_average = $self->get_commands_time_average();

    print "\n";
    print " Statistics for iptables command calls:\n";
    print " --------------------------------------\n";
    print " Number of calls : $count\n";
    printf(" Total time used : %.8fs\n", $time_total);
    printf(" Average per call: %.8fs\n", $time_average);

    print " Statistics per command action:\n";
    foreach my $action (keys %stat_count ) {
	my $count   = $stat_count{$action};
	my $time    = $stat_timesum{$action};
	my $average = $time / $count;
	print " calls:$count \t";
	printf("time:%.8fs\t", $time);
	printf(" average:%.8fs\t", $average);
	print " Action:\"$action\"\n";

    }
}

sub get_commands_count()
{
    my $self = shift;
    # return $self->{'run_cnt'};
    return $command_count;
}

sub get_commands_time_total()
{
    my $self = shift;
    return $command_timesum;
}

sub get_commands_time_average()
{
    my $self = shift;
    return ($command_timesum / $command_count) if $collect_stats
}

# Debugging stuff
sub report_if_failed()
{
    my $self  = shift;
    if ($self->{success} == 0) {
	print "ERRMSG:" . $self->{'errmsg'} . "\n";
    }
}


##########################################
# IPTables: Policy operations
##########################################

#void get_policy(self, chain)
sub get_policy($)
{
    my $func   = "get_policy";
    my $self   = shift;
    my $chain  = shift;
    my $handle = $self->get_handle();
    my $log    = "[Function] $func($chain)";
    $logger->debug($log);
    my ($policy, $pkt_cnt, $byte_cnt);

    timer_start();
    my $success =
	(($policy, $pkt_cnt, $byte_cnt) = $handle->get_policy("$chain"));
    timer_end($func);

    $self->record_info($success, $log, $ERROR);
    return ($policy, $pkt_cnt, $byte_cnt);
}

#void set_policy(self, chain, policy, pkt_cnt=0, byte_cnt=0)
sub set_policy()
{
    my $func     = "set_policy";
    my $self     = shift;
    my $chain    = shift;
    my $policy   = shift;
    my $pkt_cnt  = shift;
    my $byte_cnt = shift;
    my $handle   = $self->get_handle();
    my $log      = "[Function] $func($chain)";
    $logger->debug($log);
    my ($success, $old_policy, $old_pkt_cnt, $old_byte_cnt);

    timer_start();
    if (not defined $byte_cnt) {
	($success, $old_policy) =
	    $handle->set_policy("$chain", $policy);
    } else {
	($success, $old_policy, $old_pkt_cnt, $old_byte_cnt) =
	    $handle->set_policy("$chain", $policy, $pkt_cnt, $byte_cnt);
    }
    timer_end($func);

    $self->record_info($success, $log, $ERROR);
    return ($success, $old_policy, $old_pkt_cnt, $old_byte_cnt);

}

##########################################
# IPTables: Chain operations
##########################################

# $success = is_chain($chain);
sub is_chain($)
{
    my $func   = "is_chain";
    my $self   = shift;
    my $chain  = shift;
    my $handle = $self->get_handle();
    my $log    = "[Function] $func($chain)";
    $logger->debug($log);

    timer_start();
    my $success = $handle->is_chain("$chain");
    timer_end($func);

    # Change loglevel as failure is to be expected.
    $self->record_info($success, $log, $INFO);
    return $success;
}


# This attempts to create the chain $chain.
#
# $success = create_chain($chain);
sub create_chain($)
{
    my $func   = "create_chain";
    my $self   = shift;
    my $chain  = shift;
    my $handle = $self->get_handle();
    my $log    = "[Function] $func($chain)";
    $logger->debug($log);

    timer_start();
    my $success = $handle->create_chain("$chain");
    timer_end($func);

    $self->record_info($success, $log);
    return $success;
}

# This attempts to delete the chain $chain.
#
#$success = delete_chain($chain);
sub delete_chain($)
{
    my $func   = "delete_chain";
    my $self   = shift;
    my $chain  = shift;
    my $handle = $self->get_handle();
    my $log    = "[Function] $func($chain)";
    $logger->debug($log);

    timer_start();
    my $success = $handle->delete_chain("$chain");
    timer_end($func);

    # TEST/DEBUG code
    if (!$success) {
	my $refs = $handle->get_references("$chain");
	$logger->error("DEBUG: Failed delete chain: $chain, chain refs: $refs");
    }

    $self->record_info($success, $log, $ERROR);
    return $success;
}

# $success = rename_chain($oldchain, $newchain);
sub rename_chain($$)
{
    my $func   = "rename_chain";
    my $self     = shift;
    my $oldchain = shift;
    my $newchain = shift;
    my $handle = $self->get_handle();
    my $log = "[Function] $func($oldchain, $newchain)";

    $logger->debug($log);

    timer_start();
    my $success = $handle->rename_chain($oldchain, $newchain);
    timer_end($func);

    $self->record_info($success, $log, $ERROR);
    return $success;
}

# $success = builtin($chain)
sub builtin($)
{
    my $func   = "buildin";
    my $self   = shift;
    my $chain  = shift;
    my $handle = $self->get_handle();
    my $log = "[Function] $func($chain)";

    $logger->debug($log);

    timer_start();
    my $success = $handle->builtin($chain);
    timer_end($func);

    $self->record_info($success, $log, $DEBUG);
    return $success;
}


# $num_of_refs = get_references($chain)
# Returns -1 on failure.
sub get_references($)
{
    my $func   = "get_references";
    my $self   = shift;
    my $chain  = shift;
    my $handle = $self->get_handle();
    my $log = "[Function] $func($chain)";
    my $success=1;

    #$logger->debug($log);

    timer_start();
    my $num_of_refs = $handle->get_references($chain);
    timer_end($func);

    $log .= ": refs=$num_of_refs";
    $logger->debug($log);

    if ($num_of_refs < 0) {
	$success=0;
    }

    $self->record_info($success, $log, $WARN);
    return $num_of_refs;
}



##########################################
# Functions affecting all chains
##########################################

sub flush_all_chains()
{
    my $func   = "flush_all_chains";
    my $self   = shift;
    my $chain  = shift;
    my $handle = $self->get_handle();
    my $log = "[Function] $func()";

    $logger->debug($log);

    my $verbose = 1;

    timer_start();
    # Function "for_each_chain" not implemented yet in "libiptc.pm"
    # my $success =
    #	$handle->for_each_chain('flush_entries', $verbose, 1, &handle);
    my $success = $self->iptables_do_command("-F");
    timer_end($func);

    $self->record_info($success, $log);
    return $success;
}

sub delete_all_chains()
{
    my $func   = "delete_all_chains";
    my $self   = shift;
    my $chain  = shift;
    my $handle = $self->get_handle();
    my $log = "[Function] $func()";

    $logger->debug($log);

    my $verbose = 1;

    timer_start();
    # Function "for_each_chain" not implemented yet in "libiptc.pm"
    # my $success =
    #	$handle->for_each_chain('delete_chain', $verbose, 1, &handle);
    my $success = $self->iptables_do_command("-X");
    timer_end($func);

    $self->record_info($success, $log);
    return $success;
}


##########################################
# Rules/Entries affecting a full chain
##########################################

# Delete all rules in a chain
sub flush_chain($)
{
    my $self    = shift;
    my $chain   = shift;
    my $success = $self->flush_entries($chain);
    return $success;
}
sub flush_entries($)
{
    my $func   = "flush_entries";
    my $self   = shift;
    my $chain  = shift;
    my $handle = $self->get_handle();
    my $log = "[Function] $func($chain)";

    $logger->debug($log);

    timer_start();
    my $success = $handle->flush_entries($chain);
    timer_end($func);

    $self->record_info($success, $log);
    return $success;
}

# Zero counter (on all rules) in a chain
sub zero_entries($)
{
    my $func   = "zero_entries";
    my $self   = shift;
    my $chain  = shift;
    my $handle = $self->get_handle();
    my $log = "[Function] $func($chain)";

    $logger->debug($log);

    timer_start();
    my $success = $handle->zero_entries($chain);
    timer_end($func);

    $self->record_info($success, $log);
    return $success;
}


##########################################
# Listing related
##########################################

sub list_chains()
{
    my $func   = "list_chains";
    my $self   = shift;
    my $chain  = shift;
    my $handle = $self->get_handle();
    my $log = "[Function] $func()";
    my $success = 1;

    $logger->debug($log);

    timer_start();
    my @list_of_chainnames = $handle->list_chains();
    timer_end($func);

    $self->record_info($success, $log);
    return @list_of_chainnames;

}

# Given a $chain, list the rules src or dst IPs.
#  $type = {dst,src}
sub list_rules_IPs($$)
{
    my $func   = "list_rules_IPs";
    my $self   = shift;
    my $type  = shift;
    my $chain  = shift;
    my $handle = $self->get_handle();
    my $log = "[Function] $func($type, $chain)";
    my $success = 1;

    $logger->debug($log);

    timer_start();
    my @list_of_IPs = $handle->list_rules_IPs($type, $chain);
    timer_end($func);

    $self->record_info($success, $log);
    return @list_of_IPs;
}


##########################################
# Calling iptables "do_command" function
##########################################

# TODO: Catch output from the command (STDOUT and STDERR). This
#       requires some filehandle Perl tricks...
#
sub iptables_do_command()
{
    my $func      = "iptables_do_command";
    my $self      = shift;
    my @input     = @_;
    my $handle    = $self->get_handle();
    my $log = "[Function] $func(@input)";

    $logger->debug($log);

    #print "INPUT:\n", Dumper(@input);

    # We need to transform input into an array, where the individual
    # command arguments are seperated. This is easy in Perl...
    my @cmd_array;
    foreach my $string (@input) {
	if (defined $string) {
	    my @tmp = split(/\s+/, $string);
	    push @cmd_array, @tmp
	}
    }
    #print "CMD_ARRAY:\n", Dumper(\@cmd_array);

    timer_start();
    my $success = $handle->iptables_do_command(\@cmd_array);
    timer_end($func);

    $self->record_info($success, $log);
    return $success;
}


##########################################
# Rule operations through "do_command"
##########################################

# arguments($func, $action, $chain, $rule, $target)
sub __command_rule($$$$$)
{
    my $self   = shift;
    my $func   = shift;
    my $action = shift;
    my $chain  = shift;
    my $rule   = shift || "";
    my $target = shift;
    my $loglevel = shift || $ERROR;

    # Handle if the "target" is not specified
    my $target_cmd="";
    if (defined $target && $target ne "") {
	$target_cmd="-j $target";
    }
    else {
	$target = "";
    }

    my $log = "[Function] $func($chain, $rule, $target)";

    $logger->debug($log);

    timer_start();
    my $success =
	$self->iptables_do_command("$action","$chain", $rule, $target_cmd);
    timer_end($func);

    $self->record_info($success, $log, $loglevel);
    return $success;
}

sub append_rule($$$)
{
    my $self   = shift;
    my $func   = "append_rule";
    my $action = "--append";
    my ($chain, $rule, $target) = @_;
    my $success =
	$self->__command_rule($func, $action, "$chain", $rule, $target);
    return $success;
}

sub insert_rule($$$)
{
    my $self   = shift;
    my $func   = "insert_rule";
    my $action = "--insert";
    my ($chain, $rule, $target) = @_;
    my $success =
	$self->__command_rule($func, $action, "$chain", $rule, $target);
    return $success;
}

sub delete_rule($$$)
{
    my $self   = shift;
    my $func   = "delete_rule";
    my $action = "--delete";
    my ($chain, $rule, $target) = @_;
    my $success =
	$self->__command_rule($func, $action, "$chain", $rule, $target, $INFO);
    return $success;
}


##########################################
# High level Rule operations
##########################################

# Move a rule to the end of the chain.
# ------------------------------------
# - Purpose: assure that a rule is the last in a chain.
#
# - This is a legacy function from IPTables::command.pm
#   where this action was difficult, with libiptc integration
#   this is quite easy (because we first commit changes later).
#
sub move_to_end_rule($$$)
{
    my $self   = shift;
    my $func   = "move_to_end_rule";
    my ($chain, $rule, $target) = @_;

    my $log = "[Function] $func($chain, $rule, $target)";
    $logger->debug($log);

    my $success = $self->delete_rule("$chain", $rule, $target);

    if (!$success) {
	$logger->info("$log: Could not delete rule, trying to creating it.");
    }
    $success = $self->append_rule("$chain", $rule, $target);

    $self->record_info($success, $log, $ERROR);
    return $success;

}


1;
__END__
# Below is documentation for the module.

=head1 NAME

IPTables::Interface - Perl style wrapper interface for IPTables::libiptc

=head1 SYNOPSIS

  use Log::Log4perl qw(:easy);
  Log::Log4perl->easy_init($DEBUG);
  
  use IPTables::Interface;
  $table = IPTables::Interface::new('filter');
  
  my $chain = "chainname";
  $table->create_chain($chain);
  $table->iptables_do_command("-A $chain", "-s 10.0.0.42", "-j ACCEPT");
  
  # Its important to commit/push-back the changes to the kernel
  $table->commit();


=head1 DESCRIPTION

This module is basically a wrapper/shadow interface around
IPTables::libiptc.

The purpose of the module, is to provide:

=over

=item 1. Safe access to the table handles, by locking and singleton
      classes.

=item 2. Provide logging functionality (with Log::Log4perl).

=item 3. Collect call statistics.

=back

=head1 METHODS


Basically we shadows the functions in IPTables::libiptc, see this
module for method documentation.

=head2 Chain Operations

=over

=item B<get_policy>

    my ($policy)                      = $table->get_policy("chainname");
    my ($policy, $pkt_cnt, $byte_cnt) = $table->get_policy("chainname");

This returns an array containing the default policy, and the number of
packets and bytes which have reached the default policy, in the chain
C<chainname>.  If C<chainname> does not exist, or if it is not a
built-in chain, an empty array will be returned, $! will be set to a
string containing the reason, and $table->{'success'} == 0.

=item B<set_policy>

    my ($success)              = $table->set_policy("chainname", "POLICY");
    my ($success, $old_policy) = $table->set_policy("chainname", "POLICY");
    my ($success, $old_policy, $old_pkt_cnt, $old_byte_cnt) =
        $table->set_policy("chainname", "POLICY", $pkt_cnt, $byte_cnt);

This returns an array containing if the command was successful and the
previous default policy.  It is also possible to set the counter
values (on the buildin chain), this will cause the command to return
the previous counter values.  The C<chainname> must be a built-in
chain name.

=back

=head2 Listing Operations

=over

=item B<list_chains>

    @array = $table->list_chains();

Lists all chains.

=item B<list_rules_IPs>

    @list_of_IPs = $table->list_rules_IPs('type', 'chainname');

This function lists the (rules) source or destination IPs from a given
chain.  The C<type> is either C<src> or C<dst> for source and
destination IPs.  The netmask is also listed together with the IPs,
but seperated by a C</> character.  If chainname does not exist
C<undef> is returned.

=back

=head2 Iptables commands (from iptables.h)

=over

=item B<iptables_do_command>

    $success = $table->iptables_do_command("-A chain", "-s 10.0.0.42");
    $success = $table->iptables_do_command("-I", "chain", "-s 10.0.0.42");

The iptables_do_command calls the C<do_command> function from
C<iptables.c>.  This means that the input is the same as the iptables
command line arguments.  The perl function automatically transforms
the input into the seperate command line arguments need by the
C<do_command> function.

=back

=head2 Rules Operations

Rule operations are done through the C<iptables_do_command>.  The
following helper function are implemented.

    $success = append_rule($chain, $rule, $target);
    $success = insert_rule($chain, $rule, $target);
    $success = delete_rule($chain, $rule, $target);

=head1 DEPENDENCIES

L<IPTables::libiptc>,
L<Log::Log4perl>,
L<Time::HiRes>.
L<IPTables::Interface::Lock>.


=head1 SEE ALSO

Documentation of the module IPTables::libiptc.


=head1 AUTHOR

Jesper Dangaard Brouer, E<lt>hawk@comx.dkE<gt> or E<lt>hawk@diku.dkE<gt>.

=head2 Authors SVN version information

 $LastChangedDate: 2009-11-12 16:06:07 +0100 (Thu, 12 Nov 2009) $
 $Revision: 1001 $
 $LastChangedBy: jdb $


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Jesper Dangaard Brouer

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.


=cut
