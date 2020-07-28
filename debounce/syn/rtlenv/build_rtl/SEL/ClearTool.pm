##########################################################################################
# COPYRIGHT (c) 2007-2011 Schweitzer Engineering Labs, Pullman, Washington
#
# This package contains a simple interface for using the ClearTool command in
# a platform independent way.  Additionally, it uses OLE to access ClearCase
# via COM in windows.  There we can access the ClearTool COM object, which has
# a one-to-one correspondance to the cleartool executable used from the command
# line. Using it via COM however has the advantage that execution happens via
# memory resident code, and we don't suffer the performance penalty associated
# with starting up and unloading the cleartool executable image each time we
# want to issue a command.
# 
# NOTE:  This module must run on SUNs such as einstein, Linux and Windows so it
#        must be tested in these environments.
#
##########################################################################################
use strict;

package SEL::ClearTool;

use vars qw( @ISA @EXPORT @EXPORT_OK $VERSION );
require Exporter;

$VERSION = '1.01';

@ISA = qw(Exporter);

@EXPORT = qw( ct_line_handler
              ct_array_handler
              get_cca_ole_handler
            );

@EXPORT_OK = qw( get_ct_ole_handler );  # symbols to export on request

use constant IN_WINDOWS => $^O =~ /MSWin32|Windows_NT/i;

BEGIN {
    if (IN_WINDOWS) {
        require Win32::OLE;
    }
}

sub ct_array_handler {
##########################################################################################
# SUBROUTINE: ct_array_handler -  Handles multi-line output from cleartool
#
# INPUTS: $ct_input - An arbitrary cleartool command line string.
#
# OUTPUTS: An array corresponding to eeach line of output returned from cleartool
#
# NOTES: This is the routine to be used when you expect your cleartool command to return
#        multiple lines of output.
##########################################################################################
    my ($ct_input) = @_;
    my @ret_list = ();

    if ($ct_input) {
        my $ct_output = ct_line_handler($ct_input);
        if ($ct_output && $? == 0) {
            @ret_list = split('\n', $ct_output);
        }
    }
    else {
        Carp::confess('Caller passed ct_array_handler() empty input');
    }
    return @ret_list;
}

{
    my $ct = 0;     # Not global, but has a permanant scope with the extra block { } above

    sub get_ct_ole_handler() {
##########################################################################################
# SUBROUTINE: get_ct_ole_handler -  Get the ClearTool OLE handler
#
# INPUTS: None.
#
# OUTPUTS: ClearTool OLE object
#
##########################################################################################
	return if(!IN_WINDOWS);
        if (!$ct) {                     # Only create a new ClearTool object once
            $ct = Win32::OLE->new('ClearCase.ClearTool');

            if (my $err = Win32::OLE->LastError) {
                die("Error creating new ClearTool OLE object: $err");
            }
        }
        return $ct;
    }
}

{
    my $cca = 0;

    sub get_cca_ole_handler() {
##########################################################################################
# SUBROUTINE: get_ct_ole_handler -  Get the ClearCase OLE handler
#
# INPUTS: None.
#
# OUTPUTS: ClearCase OLE object or undef if not in windows
#
##########################################################################################
	return if(!IN_WINDOWS);
        if (!$cca) {
            $cca = Win32::OLE->new('ClearCase.Application');

            if (my $err = Win32::OLE->LastError) {
                die("Couldn't create a new ClearCase.Application: $err");
            }
        }
        return $cca;
    }
}

sub ct_line_handler {
#########################################################################################
# SUBROUTINE: ct_line_handler -  Handles single-line output from cleartool
#
# INPUTS: $ct_input - An arbitrary cleartool command line string.
#
# OUTPUTS: $ct_output - A line of output returned by calling cleartool (possibly empty)
#
# NOTES: This is the routine to use when you expect only one line of output.  If a
#        command issues multiple lines of output, then ct_array_handler should be used
#        instead.
#########################################################################################
    my ($ct_input) = @_;
    my $ct_output = q{};    # Empty string
    if (IN_WINDOWS) {
        $Win32::OLE::Warn = 0;
        my $ct = get_ct_ole_handler();
        $? = 0;
        $ct_output = $ct->CmdExec($ct_input);
        if (my $err = Win32::OLE->LastError) {
            $ct_output = $err;
            $? = 1;
        }
	$Win32::OLE::Warn = 1;

    }
    else { # UNIX-based system
        $ct_output = `cleartool $ct_input`; # Future note: look into single process
    }                                       # space solution for speed improvements.

    $ct_output =~ tr/\r//d;
    return $ct_output;
}

1;
