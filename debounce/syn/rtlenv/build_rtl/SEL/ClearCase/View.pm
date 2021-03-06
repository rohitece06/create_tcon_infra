############################################################################
# COPYRIGHT (C) 2004 - 2010 Schweitzer Engineering Labs, Pullman, Washington
#  This class allows the client to map and unmap ClearCase views to drive
#  letters. It can also return data structures that are informative about
#  ClearCase views and/or mapped drives.
#####                                                                  #####  
##### NOTE: This module only works on Windows hosts                    #####
#####                                                                  #####  
############################################################################

use strict;

package SEL::ClearCase::View;

   use SEL::Report;
   use Cwd qw( chdir cwd );

   use vars qw( @ISA %ENV );
   @ISA = qw();

################################################################
# Private method(s):
   my $net_use = sub {
      my $this = shift;
      my @args = @_;
      # This internal method calls the 'net use' command with
      #  the desired arguments and returns 0 if no error.
      #  Optionally, it returns the text message generated by
      #  execution of the command.
      unshift @args, "net use";      # prepend command to arguments
      my $cmd_str = join ' ', @args; # make a single command string

      my $result = `$cmd_str`;       # run command

      # return result of command
      my $rtn = $result !~ m/successfully\./;

      return wantarray() ? ( $rtn, $result ) : $rtn;
   };
#
################################################################

   # Constructor
   sub new {
      my $class = shift;
      my( $verbose ) = @_;
      ##############################################################################
      # FUNCTION NAME:  new()
      #
      # DESCRIPTION:    Instantiates a class instance
      #
      #  USAGE:         $view_manager = new SEL::ClearCase::View( 1 );         # or
      #                 $view_manager = new SEL::ClearCase::View( "verbose" ); # or
      #                 $view_manager = new SEL::ClearCase::View;
      #
      #  INPUTS:        verbose (optional boolean)
      #                    If true, this value indicates that the user desires
      #                    verbose output
      #
      #  OUTPUTS:       none
      #
      #  RETURN VALUE:  A class instance is returned
      #
      #  --DATE- -ECO-    NAME    REVISION HISTORY
      # 20040727          dandw   Created
      ##############################################################################

      my $this = bless({}, $class) or return undef;    # Create class instance

      # maintain some class instance data
      $this->{CT} = 'cleartool.exe ';
      $this->{NET} = 'net use ';
      $this->{MOUNTS} = {}; # hash reference of class instance mounted drives
      $this->{VERBOSE} = $verbose;

      # overwrite the report subroutine with a null subroutine
      $report = sub{ 1 } if not $this->{VERBOSE};

      $this->$net_use( '/PERSISTENT:YES' ) == 0 or return undef;

      report( "A class instance has been instantiated" );
      return $this;
   }

   sub DESTROY {
      ##############################################################################
      # FUNCTION NAME:  DESTROY()
      #
      # DESCRIPTION:    Destructor for the Clearcase class view instance.
      #
      #  USAGE:         $view_manager->DESTROY;
      #                 also called implicitely by Perl
      #
      #  INPUTS:        none
      #
      #  OUTPUTS:       none
      #
      #  RETURN VALUE:  none
      #
      #  --DATE- -ECO-    NAME    REVISION HISTORY
      # 20040727          dandw   Created
      ##############################################################################
      my $this = shift;

      report( 'Destroying Class instance' );
      # clean up after ourselves
      foreach( keys( %{$this->{MOUNTS}} ) )
      {
         $this->unmount( $_ ) == 0 or report( "Could not unmount drive: $_" ) if $this->{MOUNTS}->{$_};
      }
   }

   sub mount {
      my $this = shift;
      my( $view, $drive ) = @_;
      ##############################################################################
      # FUNCTION NAME:  mount()
      #
      # DESCRIPTION:    Mounts a ClearCase view to a drive letter. If the view is
      #                  already mounted, the existing drive letter is returned
      #
      #  USAGE:         $drive = $view_manager->mount( 'dandw_ux_view' );  # or
      #                 $drive = $view_manager->mount( 'dandw_ux_view', 'z' );
      #
      #  INPUTS:        view (string)
      #                    A valid ClearCase view that is desired to be mapped to
      #                     a drive letter.
      #
      #                 drive (optional char)
      #                    A valid, unused drive letter to map the view to. The
      #                     inclusion of this parameter does not guarantee that
      #                     the view gets mapped to this letter. Check the return
      #                     value.
      #
      #  OUTPUTS:       View mapped to a drive letter
      #
      #  RETURN VALUE:  The drive letter is returned or 0 if there was an error
      #
      #  --DATE- -ECO-    NAME    REVISION HISTORY
      # 20040727          dandw   Created
      ##############################################################################
      report( "Mounting \"$view\" " . ($drive ? "on drive $drive:" : "") );

      # make sure view exists
      grep m/^$view$/, $this->views or report( "View: \"$view\", does not exist" ) and return 0;

      # make sure drive is not already mounted
      report( "Drive $drive: is already mounted" ) and return 0 if $drive and grep m/^$drive$/, keys( %{$this->parse_drives} );

      # make sure drive is a valid letter if it is specified
      $drive =~ m/^[a-zA-Z]$/ or report( "\"$drive\" is not a valid drive letter" ) and return 0 if $drive;

      # Check to see if view is already mounted
      report( "$view already mounted on $_:" ) and return $_ if( $_ = $this->parse_mounted_views->{$view} );

      # start the view
      return 0 if system( $this->{CT} . "startview $view" );

      $drive = $drive ? uc( $drive ).":" : "*";
      my $network_view_location = "\\\\view\\$view";

      my( $fail, $report ) = $this->$net_use( $drive, $network_view_location );
      if( $fail )
      {
         report( "Invalid drive or network location" );
         system( $this->{CT} . "endview $view" );
         return 0;
      }

      if( $drive eq "*" )
      {
         $report =~ m/^Drive ([A-Z]{1}): is now connected to/;
         $drive = $1;
      }
      else
      {
         chop( $drive );
      }

      # store this mount in the class instance for later cleanup
      $this->{MOUNTS}->{$drive} = 1;

      report( "\"$view\" mapped to drive $drive:" );

      return $drive;
   }

   sub unmount {
      my $this = shift;
      my( $drive ) = @_;
      ##############################################################################
      # FUNCTION NAME:  unmount()
      #
      # DESCRIPTION:    unmounts a ClearCase view from a drive letter. The working
      #                  directory of the client should not be on the drive to
      #                  unmap.
      #
      #  USAGE:         $view_manager->unmount( 'W' ) == 0 or die;
      #
      #  INPUTS:        drive (char)
      #                    A valid, view mapped drive letter must be given by this
      #                     parameter.
      #
      #  OUTPUTS:       View unmapped from a drive letter
      #
      #  RETURN VALUE:  0 if success, -1 otherwise
      #
      #  --DATE- -ECO-    NAME    REVISION HISTORY
      # 20040727          dandw   Created
      ##############################################################################

      $drive = uc( $drive );
      report( "Unmounting $drive: and associated view" );

      my $drives = $this->parse_drives;

      report( "Drive: $drive: does not map to a view" ) and return -1 unless $drives->{$drive}->{IS_VIEW};

      # If the working directory is on the mounted drive, lets move to a new location
      #  so that the script will operate correctly
      my( $working_drive ) = cwd() =~ m/^([A-Z]):/;
      if( $working_drive eq $drive )
      {
         report( 'Changing working directory to an unmounted drive' );
         # grab first directory out of the path environment variable
         my( $safe_dir ) = $ENV{'PATH'} =~ m/(.+?);.*/;
         chdir( $safe_dir );
      }

      report( "Could not delete drive $drive:" ) and return -1 if $this->$net_use( "$drive:", '/DELETE' );

      # find the view name
      $drives->{$drive}->{REMOTE} =~ m/\\\\view\\([\w-]+)/ or report( "Could not extract view" ) and return -1;

      undef $this->{MOUNTS}->{$drive};  # let destructor know not to worry about unmounting this drive

      my $cmd = $this->{CT} . "endview $1";
      return system( $cmd );
   }

   sub views {
      my $this = shift;
      ##############################################################################
      # FUNCTION NAME:  views()
      #
      # DESCRIPTION:    Gives an array of valid views
      #
      #  USAGE:         my @views = $view_manager->views;
      #
      #  INPUTS:        none
      #
      #  OUTPUTS:       none
      #
      #  RETURN VALUE:  An array of valid views, or scalar zero if error
      #
      #  --DATE- -ECO-    NAME    REVISION HISTORY
      # 20040727          dandw   Created
      ##############################################################################
      my $cmd = $this->{CT} . " lsview";

      # Find all possible views
      open VIEWS, "$cmd|" or report( "Could not run command: \"$cmd\"" ) and return 0;
      my @views;
      while( <VIEWS> )
      {
         # looking for '*   w_matches-this    anything'
         #             ' w_matches-this anything'
         m/\*?\s+([\w\-\.]+)\s+.+/ or report( "Could not parse following line:\n\"$_\"" );
         push( @views, $1 );
      }
      close VIEWS;
      return @views;
   }

   sub parse_drives {
      my $this = shift;
      ##############################################################################
      # FUNCTION NAME:  parse_drives()
      #
      # DESCRIPTION:    This returns a reference to a hash of network mapped drive
      #                  letters. Each drive entry has a REMOTE field containing
      #                  the network location. A true value in the IS_VIEW field
      #                  indicates that the drive letter is mapped to a ClearCase
      #                  view.
      #
      #  USAGE:         my $drive_ref = $view_manager->parse_drives;
      #
      #  INPUTS:        none
      #
      #  OUTPUTS:       none
      #
      #  RETURN VALUE:  A reference to a hash of network mapped drive letters
      #
      #  --DATE- -ECO-    NAME    REVISION HISTORY
      # 20040727          dandw   Created
      ##############################################################################
      my $drives;

      # Create a hash of mounted view tag keys and associated drive letters
      open DRIVES, "net use|" or die;
      while( <DRIVES> )
      {
         # looking for A:    someword       anything<eol>'
         my( $drive, $remote ) = m/([A-Z]):\s+(\S+)/ or next;
         $drives->{$drive}->{REMOTE} = $remote;
         $drives->{$drive}->{IS_VIEW} = 1 if $remote =~ m/^\\\\view/;
      }
      close DRIVES;
      return $drives;
   }

   sub parse_mounted_views {
      my $this = shift;
      ##############################################################################
      # FUNCTION NAME:  parse_mounted_views()
      #
      # DESCRIPTION:    This returns a reference to a hash of mounted ClearCase
      #                  views. A drive letter value is associated with each
      #                  view key.
      #
      #  USAGE:         my $view_ref = $view_manager->parse_mounted_views;
      #
      #  INPUTS:        none
      #
      #  OUTPUTS:       none
      #
      #  RETURN VALUE:  A reference to a hash of mounted views
      #
      #  --DATE- -ECO-    NAME    REVISION HISTORY
      # 20040727          dandw   Created
      ##############################################################################
      my $drives = $this->parse_drives;

      my $views;

      foreach( keys( %$drives ) )
      {
         next unless $drives->{$_}->{IS_VIEW};
         my $remote = $drives->{$_}->{REMOTE};
         my( $view ) = $remote =~ m/\\\\view\\?([\w-]+)?/ or die( __PACKAGE__ . "::parse_mounted_views: Could not parse \"$remote\"" );
         if ($view)
         {
            $views->{$view} = $_ ;
         }
         else
         {
            $views->{SERVER} = $_;   # usually the M: drive
         }
      }
      return $views;
   }

   sub views_drive {
      my $this = shift;
      my( $view ) = @_;
      ##############################################################################
      # FUNCTION NAME:  views_drive()
      #
      # DESCRIPTION:    This returns the drive letter of a mounted ClearCase view.
      #
      #  USAGE:         my $drive = $view_manager->views_drive( 'dandw_ux_view' );
      #
      #  INPUTS:        view (string)
      #                  A ClearCase view tag
      #
      #  OUTPUTS:       none
      #
      #  RETURN VALUE:  The drive letter of the mounted view or zero if none exists
      #
      #  --DATE- -ECO-    NAME    REVISION HISTORY
      # 20040727          dandw   Created
      ##############################################################################
      my $views = $this->parse_mounted_views;

      return $views->{$view};
   }
1;

