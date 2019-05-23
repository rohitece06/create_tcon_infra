use strict;

package SEL::Report;

################################################################
# This package contains a reporting function that allows
# the caller to print to STDOUT and be identified explicitly
# by this function
################################################################

use vars qw( @ISA @EXPORT $VERSION );

use Exporter;
$VERSION = 1.00;
@ISA = qw( Exporter );

@EXPORT      = qw( $report report );

use vars qw( $report );
use constant PROC_NAME_FIELD => 3;

$report = sub {
   ##############################################################################
   # The guts of the report subroutine is put into a variable here in order
   # to allow the variable to be rewritten as a no-op when reporting is turned
   # off.
   ##############################################################################
   my( $message, $callstack_position ) = @_;
   my $pkg = caller;
   $callstack_position = 0 if!defined ($callstack_position);
   my $function = (caller(2+$callstack_position))[PROC_NAME_FIELD];
   print "$pkg\::$function: $message\n";
};

sub report {
   my( $message, $callstack_position ) = @_;
   ##############################################################################
   # FUNCTION NAME: report()
   #
   # DESCRIPTION:   Prints the requested message to STDOUT. The caller of this
   #                function is identified at the beginning of the message.
   #                If the caller wants to attribute the message to its caller,
   #                it can utilize the optional callstack_position parameter.
   #                Since this function is a wrapper that calls the $report
   #                code reference, the client can redefine the code reference
   #                and change the behavior of this function during runtime.
   #
   # USAGE:         report( 'Compiling...' );
   #
   # INPUTS:        message
   #                   The message targeted to standard output
   #
   #                callstack_position (optional)
   #                   How many callers back to attribute the message to. The
   #                   default is 0.
   #
   # OUTPUTS:       A message such as:
   #                   SEL::Device::new: Creating Serial Connection
   #                   is printed to STDOUT when the caller, SEL::Device::new,
   #                   has a command:
   #                   report( 'Creating Serial Connection' );
   #
   # RETURN VALUE:  none
   #
   # --DATE-- --ECO-- NAME    REVISION HISTORY
   # 20040728         dandw   Created
   ##############################################################################
   &$report( @_ );
}
1;
