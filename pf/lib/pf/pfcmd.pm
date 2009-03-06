#
# Copyright 2009 Inverse groupe conseil
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html
#
#

package pf::pfcmd;

use strict;
use warnings;
use diagnostics;

use Log::Log4perl;

sub parseCommandLine {
    my ($commandLine) = @_;
    my $logger = Log::Log4perl::get_logger("pf::pfcmd");
    $logger->debug("starting to parse '$commandLine'");

    my @arguments = split( / +/, $commandLine );

    my %cmd;

    if ( ( scalar(@arguments) == 1 ) && ( $arguments[0] eq 'version' ) ) {
        $cmd{'command'}[0] = 'version';
        return %cmd;
    }
    
    if ( ( scalar(@arguments) == 2 )
        && ( $arguments[0] eq 'configfiles' )
        && ( $arguments[1] =~ /^(push|pull)$/ ) ) {
        $cmd{command}[0] = 'configfiles';
        $cmd{command}[1] = $arguments[1];
        return %cmd;
    } 
    
    if ( ( scalar(@arguments) == 2 ) && ( $arguments[0] eq 'help' ) ) {
        $cmd{command}[0] = $arguments[0];
        $cmd{command}[1] = $arguments[1];
        return %cmd;
    } 
    
    if ( ( scalar(@arguments) == 2 )
        && ( $arguments[0] eq 'reload' )
        && ( $arguments[1] =~ /^(fingerprints|violations)$/ ) ) {
        $cmd{command}[0] = 'reload';
        $cmd{command}[1] = $arguments[1];
        return %cmd;
    } 
    
    if ( ( scalar(@arguments) == 2 )
        && ( $arguments[0] eq 'report' )
        && ( $arguments[1]
            =~ /^(inactive|active|unregistered|registered|osclass|os|unknownprints|openviolations|statics)$/
           )
        ) {
        $cmd{command}[0] = $arguments[0];
        $cmd{command}[1] = $arguments[1];
        return %cmd;
    } 
    
    if ( ( scalar(@arguments) == 2 )
        && ( $arguments[0] eq 'update' )
        && ( $arguments[1] =~ /^(fingerprints|oui)$/ ) ) {
        $cmd{command}[0] = 'update';
        $cmd{command}[1] = $arguments[1];
        return %cmd;
    } 
    
    if ( ( scalar(@arguments) == 3 )
        && ( $arguments[0] eq 'class' )
        && ( $arguments[1] eq 'view' )
        && ( $arguments[2] =~ /^(all|\d+)$/ ) ) {
        $cmd{'command'}[0] = $arguments[0];
        $cmd{'command'}[1] = $arguments[1];
        $cmd{'command'}[2] = $arguments[2];
        return %cmd;
    } 
    
    if ( ( scalar(@arguments) == 3 )
        && ( $arguments[0] eq 'lookup' )
        && ( $arguments[1] =~ /^(person|node)$/ )
        && ( $arguments[2] =~ /^[\/,0-9a-zA-Z_\*\.\-\:_\;\@\ ]*$/ ) ) {
        $cmd{'command'}[0] = $arguments[0];
        $cmd{'command'}[1] = $arguments[1];
        $cmd{'command'}[2] = $arguments[2];
        return %cmd;
    } 
    
    if ( ( scalar(@arguments) == 3 )
        && ( $arguments[0] eq 'nodecategory' )
        && ( $arguments[1] eq 'view' )
        && ( $arguments[2] =~ /^\w+$/ ) ) {
        $cmd{'command'}[0] = $arguments[0];
        $cmd{'command'}[1] = $arguments[1];
        $cmd{'command'}[2] = $arguments[2];
        return %cmd;
    } 
    
    if ( ( scalar(@arguments) == 3 )
        && ( $arguments[0] eq 'report' )
        && ( $arguments[1]
            =~ /^(unregistered|registered|osclass|os|unknownprints|openviolations|statics)$/
           )
        && ( $arguments[2] =~ /^(all|active)$/ ) ) {
        $cmd{'command'}[0] = $arguments[0];
        $cmd{'command'}[1] = $arguments[1];
        $cmd{'command'}[2] = $arguments[2];
        return %cmd;
    } 
    
    if ( ( scalar(@arguments) == 3 )
        && ( $arguments[0] eq 'service' )
        && ( $arguments[1]
            =~ /^(named|dhcpd|pfmon|pfdhcplistener|pfdetect|pfredirect|snort|httpd|pfsetvlan|snmptrapd|pf)$/
           )
        && ( $arguments[2] =~ /^(stop|start|restart|status|watch)$/ ) ) {
        $cmd{'command'}[0] = $arguments[0];
        $cmd{'command'}[1] = $arguments[1];
        $cmd{'command'}[2] = $arguments[2];
        return %cmd;
    } 
    
    if ( ( scalar(@arguments) == 3 )
        && ( $arguments[0] eq 'interfaceconfig' )
        && ( $arguments[1] =~ /^(get|delete)$/ )
        && ( $arguments[2] =~ /^(all|[^ ]+)$/ ) ) {
        $cmd{'command'}[0] = $arguments[0];
        $cmd{'command'}[1] = $arguments[1];
        $cmd{'command'}[2] = $arguments[2];
        return %cmd;
    } 
    
    if ( ( scalar(@arguments) == 3 )
        && ( $arguments[0] eq 'networkconfig' )
        && ( $arguments[1] =~ /^(get|delete)$/ )
        && ( $arguments[2] =~ /^(all|(\d{1,3}\.){3}\d{1,3})$/ ) ) {
        $cmd{'command'}[0] = $arguments[0];
        $cmd{'command'}[1] = $arguments[1];
        $cmd{'command'}[2] = $arguments[2];
        return %cmd;
    } 
    
    if ( ( scalar(@arguments) == 3 )
        && ( $arguments[0] eq 'switchconfig' )
        && ( $arguments[1] =~ /^(get|delete)$/ )
        && ( $arguments[2] =~ /^(all|default|(\d{1,3}\.){3}\d{1,3})$/ ) ) {
        $cmd{'command'}[0] = $arguments[0];
        $cmd{'command'}[1] = $arguments[1];
        $cmd{'command'}[2] = $arguments[2];
        return %cmd;
    } 
    
    if ( ( scalar(@arguments) == 3 )
        && ( $arguments[0] eq 'violationconfig' )
        && ( $arguments[1] =~ /^(get|delete)$/ )
        && ( $arguments[2] =~ /^(all|defaults|(\d+))$/ ) ) {
        $cmd{'command'}[0] = $arguments[0];
        $cmd{'command'}[1] = $arguments[1];
        $cmd{'command'}[2] = $arguments[2];
        return %cmd;
    } 
    
    if ( ( scalar(@arguments) == 4 )
        && ( $arguments[0] eq 'switchlocation' )
        && ( $arguments[1] eq 'view' )
        && ( $arguments[2] =~ /^(\d{1,3}\.){3}\d{1,3}$/ )
        && ( $arguments[3] =~ /^\d+$/ ) ) {
        $cmd{'command'}[0] = $arguments[0];
        $cmd{'command'}[1] = $arguments[1];
        $cmd{'command'}[2] = $arguments[2];
        $cmd{'command'}[3] = $arguments[3];
        return %cmd;
    } 

    # precompiled grammar (2.6x increase in speed)
    require pf::pfcmd::pfcmd_pregrammar;
    import pf::pfcmd::pfcmd_pregrammar;
    my $parser = pfcmd_pregrammar->new();

    my $result = $parser->start($commandLine);
    $cmd{'grammar'} = ( defined($result) ? 1 : 0 );
    return %cmd;
}

1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
