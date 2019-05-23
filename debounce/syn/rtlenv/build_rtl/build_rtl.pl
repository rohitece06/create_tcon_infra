package main;
#*******************************************************************************
# COPYRIGHT (c) 2004-2019 Schweitzer Engineering Laboratories, Inc.
# SEL Confidential
#
#        FILE NAME: build_rtl.pl  (Windows Perl script)
#
# FILE DESCRIPTION: This script conducts configurable logic builds utilizing
#                   the build.pl files found in <component>/syn
#                   directories.  Refer to the readme file for more information.
#
# NOTES:            When using Clearcase this script must be executed from a
#                   drive-mapped ClearCase view.
#
# REVISION HISTORY: The following is a brief description of the major.minor
#                   releases.  Refer to the version control system for a complete
#                   history.
#
#  1.0  - First version released with semantic version labels
#
#******************************************************************************/

   use strict;
   # use warnings;  # disabled due to frequent "Argument "#  #  #  " treated as 0 in increment (++)" for use of: $indent++
   use constant IN_WINDOWS => $^O =~ /MSWin32|Windows_NT/i;

   use POSIX;

   my $Registry;
   my %RegHash;

   if ( IN_WINDOWS )
   {
      require Win32::OLE;
      require Win32::TieRegistry;
      Win32::TieRegistry->import(
         ArrayValues=>1,
         SplitMultis=>1,
         AllowLoad=>1
      );
      Win32::TieRegistry->import(qw(
              REG_SZ REG_EXPAND_SZ REG_DWORD REG_BINARY REG_MULTI_SZ
              KEY_READ KEY_WRITE KEY_ALL_ACCESS
          ));
      Win32::TieRegistry->import(TiedHash => \%RegHash);
      $Registry = \%RegHash;
   }

   use Data::Dumper;
   use File::Basename;
   use IO::Tee;
   use Cwd;
   use Config;

   # Get relative path to Utilities and Indent modules
   use File::Spec::Functions qw(rel2abs);
   use File::Basename qw(dirname);
   use lib dirname(Cwd::realpath(rel2abs($0)));

   use SEL::ClearCase qw( r_clean );
   use SEL::ClearCase::View;
   use SEL::Utilities qw( get_abs_path
                          add_indents_to_lines
                          set_env_var
                          indent_system
                          extract_file
                          touch_file
                          forward_slashify
                        );
   use SEL::Indent;


   # Defines:
   my $build_file_name = "syn/build.pl";

   my $cc_root = "";  # else gets used while un-initialized

   # used to make log files pretty
   tie my $indent, "SEL::Indent";

   # need to be global so that sigint handler has access
   my $old_registry;
   my $tied_registry;
   my $reg_found = 0;
   my $err_found = 0;

# Functions:

sub usage
{
   my( $error) = @_;
   ##############################################################################
   # FUNCTION NAME:  usage()
   #
   # DESCRIPTION:    This function prints usage information to standard output
   #                  and then exits.
   #
   #  USAGE:         usage( 'must define parameters' );
   #
   #  INPUTS:        error ( optional )
   #                    A string defining the error, if any
   #
   #  OUTPUTS:       none
   #
   #  RETURN VALUE:  0 error is not defined, -1 otherwise
   #
   ##############################################################################
   if (defined( $error ))
   {
      print "\n$error\n";
   }

   my @usage =
   (
      "",
      "Usage: perl build_rtl.pl <target directory> [-h] [-64] [-nocc] [-noclean]",
      "                         [-CONTONERR] [-buildid <0-4|D|N|X|R>]",
      "                         [-v KEY1 VAL1 [KEY2 VAL2 [...]]]",
      "\nWhere:",
      "  <target directory> : This parameter is the component's",
      "                       top level directory, usually contains",
      "                       at least the syn, src and doc",
      "                       directories.\n",
      "  -h         : This usage information will be displayed.\n",
      "  -64        : Use this flag to motivate use of 64-bit tools, where applicable\n",
      "  -LIBERO_SOC : Use this flag to select Microsemi's Libero SOC (instead of Libero IDE) tool flow\n",
      "  -nocc      : Allows build_rtl.pl to run on systems that do not have dynamic",
      "               ClearCase.",
      "               Notes:",
      "                * Since cleaning is dependent on ClearCase, the -nocc flag",
      "                  also has the effect of implementing the -noclean flag.",
      "                  If -nocc is used for release builds, ensure that a \"clean\"",
      "                  transpires before build_rtl.pl is invoked.",
      "                * Since -buildid with any parameter besides '0' is dependent",
      "                  on ClearCase, its use is mutually exclusive with the -nocc",
      "                  flag.\n",
      "  -noclean   : ClearCase view-private objects and directories will not",
      "               be deleted out of the 'syn' directory\n",
      "  -flat      : Specify component directory structure as a flat structure",
      "  -CONTONERR : build_rtl halts when a command returns a positive error code.",
      "               Use -CONTONERR to continue processing despite command errors.\n",
      "  -buildid <0-4|D|N|X|R> : This parameter will take the build id for the ",
      "               current build from a file located in the syn directory called",
      "               build_id.txt. The build id is as follows:",
      "                  major.minor.release.build",
      "               The single character parameters that follow the -buildid flag",
      "               have the following functionality:",
      "               0 - do not increment the build number (Preferred)",
      "               1 - increments the build number",
      "               2 - increments release and zeroes build",
      "               3 - increments minor and zeroes release and build",
      "               4 - increments major and zeroes the rest",
      "               D - increments the build number, sets upper two bits of release",
      "                   to 00 for developer build",
      "               N - increments the build number, sets upper two bits of release",
      "                   to 01 for night build",
      "               X - increments the build number, sets upper two bits of release",
      "                   to 10 for X release",
      "               R - increments the build number, sets upper two bits of release",
      "                   to 11 for R release",
      "  -v         : This allows variables from the target component to be",
      "               overridden at the command line. This is useful for",
      "               performing many build permutations without modifying",
      "               the build.pl file every time. Note that this must be",
      "               the last command line argument.",
      " ",
      "Notes:",
      " * See \\tools\\doc\\build_rtl_users_guide.doc for detailed documentation.",
      " * All command-line input parameters are case-sensitive.",
      " * By default, this script cleans all non-version controlled objects",
      "   out of the syn directories of the target component and all",
      "   child components. Do not use the syn directory as a repository",
      "   for non-version controlled objects.",
      " * Given that everything that follows the -v flag is interpreted as a key/value",
      "   pair, the -v flag must be the last command line argument.",
      " ",
      "Internal Flags:",
      "   As an alternative to command line paramemters you may override the ",
      "   following internal flags in your top level build.pl file with this syntax",
      "     our \$flag_name = value;",
      " ",
      "   \$clearcase_flag      -- default=1, set to 0 with -nocc",
      "   \$clean_flag          -- default=1, set to 0 with -nocc or -noclean",
      "   \$halt_on_error_flag  -- default=1, set to 0 with -CONTONERR",
      "   \$directory_structure -- default=clearcase, set to flat with -nocc or -flat",
      "   \$sixty_four_bit_flag -- default=0, set to 1 with -64",
      "   \$libero_soc_flag     -- default=0, set to 1 with -LIBERO_SOC",
      " ",
      "  NOTE: This override method has priority over command line flags",
   );
   print join "\n", @usage;
   print "\n\n";
   exit defined( $error ) ? -1 : 0;
}

sub extract_project
{
   my( $target, $parameters ) = @_;
   #############################################################################
   # FUNCTION NAME:  extract_project()
   #
   # DESCRIPTION:    This function parses a target file to extract expected
   #                  data structures.
   #
   #  USAGE:         extract_project( 'build.pl', \%params );
   #
   #  INPUTS:        target
   #                    Path to target file
   #
   #                 parameters ( optional )
   #                    A hash reference containing keys and values that get
   #                     added to the $VARS data structure extracted from
   #                     the target file. Used to overwrite default build
   #                     parameters.
   #
   #  OUTPUTS:       none
   #
   #  RETURN VALUE:  Returns a hash reference containing extracted data
   #                     structures
   #
   ##############################################################################
   $target = forward_slashify(get_abs_path( $target ));

   $target .= $build_file_name if -d $target;

   -f $target or die "EXTRACT_PROJECT: Cannot find target: $target\n";

   print "${indent}Parsing:  $target\n";

   my $MYDIR = get_abs_path ($target, "only_dir");

   my $file = extract_file( $target );

   my $TEMPDIRS = {};
   my $VARS = {};
   my $DOCS = [];
   my $COMMANDS = [];
   my $PRECOMMANDS = [];
   my $SOURCES = [];
   my $COMPONENTS = [];
   my $TEMPFILES = [];

   # $first gets from $VARS in the file to one of the other keywords ($TEMPDIRS or $DOCS or...)
   # $second gets the file from that keyword on.
   my( $before_vars, $vars_section, $after_vars ) = $file =~ m/^(.*?)(^\s*\$VARS\s*\=\s*{.*?}\s*;\s*)(.*)$/sm;
   my $vars_section = $vars_section ? $vars_section : "";   # initialize to "" if empty, per Perl warning
   my $after_vars   = $after_vars   ? $after_vars   : "";   # initialize to "" if empty, per Perl warning

   $before_vars = $vars_section ? $before_vars : $file;  # if no variables defined make before_vars equal to the file contents

   # Evaluate the VARS section of the file prior to evaluating parameters so that
   # parameters can overwrite VARS
   eval $vars_section;
   die $@ if length($@) > 0;

   # Add parameters to the defined variables
   if ($parameters)
   {
      print "${indent}\n${indent}Adding parent parameters to project parameters\n${indent}\n";
      foreach( keys( %$parameters ) )
      {
         if ($_ eq "") { next; } # Skip empty lines
         if (exists( $VARS->{$_} ))
         {
            print "${indent} For, \"$_\", replacing value of \"$VARS->{$_}\" with \"$parameters->{$_}\"\n";
         }
         else
         {
            print "${indent} Adding variable, \"$_\", with value of \"$parameters->{$_}\"\n";
         }
         $VARS->{$_} = $parameters->{$_};
      }
   }

   # Evaluate rest of the file.  Note that these have to be evaluated
   # separately and cannot be grouped with the earlier eval.  This is because
   # the VARS portion must be evaluated first to update VARS, then execute
   # these portions.
   eval $before_vars;
   die $@ if length($@) > 0;
   eval $after_vars;
   die $@ if length($@) > 0;

   die "EXTRACT_PROJECT: can't recreate hash reference variable from $target: $@" if$@;

   my %rtn =
   (
      TEMPDIRS     => $TEMPDIRS,
      VARS         => $VARS,
      DOCS         => $DOCS,
      COMMANDS     => $COMMANDS,
      PRECOMMANDS  => $PRECOMMANDS,
      SOURCES      => $SOURCES,
      COMPONENTS   => $COMPONENTS,
      TEMPFILES    => $TEMPFILES,
      WRK_DIR      => $MYDIR,
   );
   return (\%rtn);
}

sub get_build_id
{
   my ($code) = @_;
   #############################################################################
   # FUNCTION NAME:  get_build_id()
   #
   # DESCRIPTION:    This function reads the current build id from build_id.txt
   #                  in the syn directory of the project that is being built.
   #                  The build id in the file is incremented based on a code
   #                  that is passed to the build_rtl.pl file
   #
   #  USAGE:         get_build_id( code );
   #
   #  INPUTS:        code: 0 "get_build_id()" without any incrementing
   #                       1 increments build
   #                       2 increments release and zeroes build
   #                       3 increments minor and zeroes release and build
   #                       4 increments major and zeroes the rest
   #                       D increments build and forces upper 2 bits of release to 00
   #                       N increments build and forces upper 2 bits of release to 01
   #                       X increments build and forces upper 2 bits of release to 10
   #                       R increments build and forces upper 2 bits of release to 11
   #
   #  OUTPUTS:       none
   #
   #  RETURN VALUE:  BUILDID string with format d.d.d.d where d is a decimal
   #                 between 0 and 255
   #
   ##############################################################################
   my $maj = 0;
   my $min = 0;
   my $rel = 0;
   my $bui = 0;
   my $id_file = get_abs_path("..","only dir")."syn/build_id.txt";
   unless(open(ID,"<$id_file"))
   {
      die("Error opening file $id_file!!");
   }
   my $line;
   while (<ID>) #grab last line in file
   {
      $line = $_;
   }
   close ID;
   if($line =~ /(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})/)
   {
      $maj = $1;
      $min = $2;
      $rel = $3;
      $bui = $4;

      # If the code is not zero, figure out which code it is and apply
      #  the appropriate flavor of incrementing and manipulation of the
      #  build_id.txt file.
      if ($code ne "0")
      {
         if( $code eq "1")
         {
            if( $bui == 255)
            {
               die "ERROR: build id rollover : Build number cannot go above 255";
            }
            else
            {
               $bui = $bui+1;
            }
         }
         elsif( $code eq "2")
         {
            if( $rel == 255)
            {
               die "ERROR: build id rollover : Release number cannot go above 255";
            }
            else
            {
               $rel = $rel+1;
               $bui = 0;
            }
         }
         elsif ($code eq "3")
         {
            if ($min == 255)
            {
               die "ERROR: build id rollover : Minor number cannot go above 255";
            }
            else
            {
               $min = $min+1;
               $bui = 0;
               $rel = 0;
            }
         }
         elsif ($code eq "4")
         {
            if ($maj == 255)
            {
               die "ERROR: build id rollover : Major number cannot go above 255";
            }
            else
            {
               $maj = $maj+1;
               $bui = 0;
               $rel = 0;
               $min = 0;
            }
         }
         elsif ($code eq "D") #Developer release - upper bits of $rel are 00
         {
            if ($bui == 255) #if $bui rolls over we use the lower bits of $rel
            {                #if $rel rolls over it goes to zero due to the mod operation
               $rel = $rel+1;
               $bui = 0;
            }
            else
            {
               $bui = $bui+1;
            }
            $rel = $rel % 64;
         }
         elsif ($code eq "N") #Night build - upper bits of $rel are 01
         {
            if ($bui == 255) #if $bui rolls over we use the lower bits of $rel
            {                #if $rel rolls over it goes to zero due to the mod operation
               $rel = $rel+1;
               $bui = 0;
            }
            else
            {
               $bui = $bui+1;
            }
            $rel = $rel%64;
            $rel = $rel+64;
         }
         elsif ($code eq "X") #X Release for test - upper bits of $rel are 10
         {
            if ($bui == 255) #if $bui rolls over we use the lower bits of $rel
            {                #if $rel rolls over it goes to zero due to the mod operation
               $rel = $rel+1;
               $bui = 0;
            }
            else
            {
               $bui = $bui+1;
            }
            $rel = $rel%64;
            $rel = $rel+128;
         }
         elsif ($code eq "R") #R Release for customer - upper bits of $rel are 11
         {
            if ($bui == 255) #if $bui rolls over we use the lower bits of $rel
            {                #if $rel rolls over it goes to zero due to the mod operation
               $rel = $rel+1;
               $bui = 0;
            }
            else
            {
               $bui = $bui+1;
            }
            $rel = $rel%64;
            $rel = $rel+192;
         }
         else
         {
            #Should not be able to get here because $code is checked for number
            die "Code not 0-4, D, N, X, or R Something is really wrong!";
         }
         indent_system("cleartool.exe co -nc $id_file");
         open(ID,">>$id_file");
         my($sec,$mn,$hr,$day,$month,$yrOffset,$dayOfWeek,$julian,$daylightSav)=localtime(); #include build time in build_id.txt file
         my $str = sprintf("\nCurrent build ID is %01u.%01u.%01u.%01u  Time of build: %02u:%02u on %u/%u/%02u",$maj,$min,$rel,$bui,$hr,$mn,$month+1,$day,$yrOffset-100);
         print ID $str;
         close ID;
         indent_system("cleartool.exe ci -c \"$maj.$min.$rel.$bui\" $id_file");
      }
   }
   else
   {
      die "ERROR: build ID file not in correct format.   Build ID must be \"d.d.d.d\"\nwhere d is a decimal number between 0 and 255.\n";
   }
   return ("$maj.$min.$rel.$bui");
}

sub build
{
   my( $target, $build_dir, $parameters )= @_;
   #############################################################################
   # FUNCTION NAME:  build()
   #
   # DESCRIPTION:    This function recursively builds all components required by
   #                  the target and then builds the target.
   #
   #  USAGE:         build( '/meter/fpga/top_meter', 1, 'syn' );
   #
   #  INPUTS:        target
   #                    Directory of fpga component to build
   #
   #                 build_dir
   #                    The directory that output files should be placed in.
   #
   #                 parameters
   #                    A hash of key/value pairs that will end up overwriting
   #                     hash entries defined in the target $VARS data structure.
   #                     Used to effectively pass parameters to component projects.
   #
   #  OUTPUTS:       none
   #
   #  RETURN VALUE:  Returns an array reference containing sources to be used
   #                  by the caller of this routine.
   #
   ##############################################################################
   my $start_time = time ();

   # expose global variables
   our $clean_flag;
   our $clearcase_flag;
   our $directory_structure;
   our $halt_on_error_flag;
   our $use_rtlenv;
   our $rtlenv_dir;
   our $rtlenv_top;

   # make build directory be 'syn' if none defined
   $build_dir = $build_dir ? $build_dir : get_abs_path( $target, "only_dir" ) . 'syn';
   $build_dir =~ /syn/ or die "BUILD: Builds must be in a sub directory of syn, not $build_dir";

   mkdir( $build_dir ) or die "BUILD: Could not make $build_dir" unless -d $build_dir;

   # Give a good error message if the path is bad
   my $my_target = forward_slashify(get_abs_path( $target ));
   if ($my_target eq 0)
   {
      die "BUILD: no such file or directory \"$target\" missing VOB?";
   }
   else
   {
      $target = $my_target;
   }

   print "${indent}\n${indent}\n${indent}#######################################################\n";
   print "${indent}# Extracting project data structure from build file(s):\n${indent}# $target\n";
   print "${indent}#######################################################\n";
   $indent++;

   print "${indent}\n";

   my $project = extract_project( $target, $parameters ) or die "BUILD:  extract_project call failed";

   chdir( $build_dir );

   if (($clean_flag == 1) && ($clearcase_flag == 1))
   {
      print "${indent}\n${indent}\n${indent}Cleaning all derived and " .
         "view-private files from:\n${indent} " .
         "$project->{WRK_DIR}\n${indent}\n";
      r_clean( $project->{WRK_DIR}, '', 1 );
   }

   my @sources = @{$project->{SOURCES}};

   if (@{$project->{COMPONENTS}} > 0 && !($err_found && $halt_on_error_flag))
   {
      print "${indent}\n${indent}\n${indent}Building component projects:\n";
      foreach my $component_line ( @{$project->{COMPONENTS}} )
      {
         if ($component_line eq "") { next; } # Skip empty lines
         # The $component variable is the complete relative path to the
         # component assuming the ClearCase folder structure.  The component
         # name is extracted from this variable so the search for build.pl can
         # be done assuming a flat component structure. If it is not found, then
         # the original ClearCase location is used instead.
         # Testbench components are located two levels deeper in the folder
         # structure (i.e. <component>/syn/ vs <component>/tb/<tb_comp>/syn/)
         # so both locations are needed.
         my( $component, $param_list ) = split m/\s*;\s*/, $component_line;
         my $param_list = $param_list ? $param_list : "";   # initialize to "" if empty, per Perl warning
         $component = forward_slashify($component);
         $component =~ s!^\s+|(\s|/)+$!!g; #Remove extra whitespace and trailing slashes
         my $component_orig = $component;
         if ($use_rtlenv == 1) {
            $component =~ m!([^/]+)$!;  # Component name only gets stored in $1

            # Check for the component name in the RTLenv folder
            if (-e "$rtlenv_dir/$1/$build_file_name")
            {
               $component = "$rtlenv_dir/$1";
            }
            # Check for the component name when we are looking for the parent of
            # the testbench.  Two conditions exist.  The first is when the component
            # name matches the $rtlenv_top and the second is when the component name
            # matches ".."  Either way we are looking in the same folder for the
            # parent build file.
            elsif(-e "$rtlenv_dir/../../$build_file_name" && ($1 eq $rtlenv_top || $1 eq ".."))
            {
               $component = "$rtlenv_dir/../../";
            }
            else
            {  # If folder with build.pl doesn't exist: Indicate error, but allow subsequent "Done Building ___" to give context.
              $err_found = 1;
              print "-"x80 . "\n" . "-"x22 . " HALTED ON COMPONENT FILE PATH ERROR " . "-"x21 . "\n";
              print "BUILD:  Could not find \"$build_file_name\" for \"$1\" using rtlenv folder structure.  Tried the following paths:\n".
                 "    " . (get_abs_path("$rtlenv_dir/$1"    ) ? get_abs_path("$rtlenv_dir/$1"    ) : "$rtlenv_dir/$1"    ) .          "\n" .
                 "    " . (get_abs_path("$rtlenv_dir/../../") ? get_abs_path("$rtlenv_dir/../../") : "$rtlenv_dir/../../") . "\n" . "-"x80 . "\n";
              last;
            }
         }
         elsif ($directory_structure eq "flat")
         {
            $component =~ m!([^/]+)$!;  # Component name only gets stored in $1

            # Assuming the current directory is the syn folder.  Up two folders
            # should get us to the common directory with all of the components.
            if (-e "../../$1/$build_file_name")
            {
               $component = "../../" . $1;
            }
            # If this is a testbench component the current directory is tb/<tb_name>/syn
            # so we need to go up 4 directory levels to get to the common folder.
            # To attempt to avoid false positives this path includes stepping back
            # into the tb folder and then going back up.
            elsif (-e "../../../tb/../../$1/$build_file_name")
            {
               $component = "../../../../" . $1;
            }
            else
            {  # If folder with build.pl doesn't exist: Indicate error, but allow subsequent "Done Building ___" to give context.
               $err_found = 1;
               print "-"x80 . "\n" . "-"x22 . " HALTED ON COMPONENT FILE PATH ERROR " . "-"x21 . "\n";
               print "BUILD: Could not find $build_file_name for \'$1\' using flat folder structure.  Tried the following paths:\n" .
               # Print nicer path if path okay but file !exist. If bad path, prints the user's concatenation:
               "    First Check : " . (get_abs_path("$build_dir/../../$1")            ? get_abs_path("$build_dir/../../$1")             : "$build_dir/../../$1"            ) . "\n" .
               "    Second Check: " . (get_abs_path("$build_dir/../../../tb/../../$1")? get_abs_path("$build_dir/../../../tb/../../$1") : "$build_dir/../../../tb/../../$1") . "\n" .
               "If you wanted a \"clearcase\" folder structure in GIT add the following to your top level $build_file_name file:\n" .
               "    our \$directory_structure = \"clearcase\"\;\n" . "-"x80 . "\n";
               last;
            }
         }
         elsif (!-e "$component/$build_file_name")
         {  # If folder with build.pl doesn't exist: Indicate error, but allow subsequent "Done Building ___" to give context.
            $err_found = 1;
            print "-"x80 . "\n" . "-"x22 . " HALTED ON COMPONENT FILE PATH ERROR " . "-"x21 . "\n";
            print "BUILD: Could not find $build_file_name for:\n "
              . (get_abs_path($component)? get_abs_path($component) : $component) . "\n" . "-"x80 . "\n";
            last; # above prints nicer path if path okay but file !exist. If bad path, prints the user's concatenation.
         }

         my @params = split ",", $param_list;
         my %param_hash;
         foreach( @params )
         {
            my( $key, $val ) = m/^\s*(.*?)\s*=>\s*(.*?)\s*$/ or next;
            $param_hash{$key} = $val;
         }
         my $component_sources =
           build( $component, $build_dir, \%param_hash );

         # Abort if error and halt flag (byte 1 has return error, so >>8 ):
         if (((($? >> 8) != 0) || $err_found) && $halt_on_error_flag)
         {
            if (!$err_found)  # indicates it was a DOC error, already reported to screen
            {
              print "-"x80 . "\n" . "-"x30 . " HALTED ON BUILD ERROR " . "-"x27 . "\n";
              print "-"x23 . "To override, see the -usage notes." . "-"x23 . "\n" . "-"x80 . "\n";
            }
            $err_found = 1;
            last;
         }

         unshift( @sources, @$component_sources );   # put component sources up front
      }
   }

   if (@{$project->{PRECOMMANDS}} > 0 && !($err_found && $halt_on_error_flag))
   {
      printf "${indent}\n${indent}\n${indent}Processing build file Precommands\n";
      foreach( @{$project->{PRECOMMANDS}} )
      {
         if ($_ eq "") { next; } # Skip empty lines
         indent_system( $_, $indent );
         # Abort if error and halt flag (byte 1 has return error, so >>8 ):
         if ((($? >> 8) != 0) && $halt_on_error_flag)
         {
            $err_found = 1;
            print "-"x80 . "\n" . "-"x30 . " HALTED ON PRECMD ERROR " . "-"x29 . "\n";
            print "-"x23 . "To override, see the -usage notes." . "-"x23 . "\n" . "-"x80 . "\n";
            last;
         }
      }
   }

   # create @srcs from @sources with redundancy removed
   my @srcs = ();
   if (@sources && !($err_found && $halt_on_error_flag))
   {
      @srcs = @sources;
      $indent++;
      my %seen = ();
      my @new_srces = ();
      foreach my $item ( @srcs )
      {
         if ($item eq "") { next; } # Skip empty lines
         my $item_original = $item;   # Save name to report error later, if needed
         $item = get_abs_path($item); # Remove redundant sources called from separate components
         if (!$item) {       # If source file PATH didn't come back as real:
            # BTW: we don't check for -exists here bcs some don't get created
            $err_found = 1;  # until later (eg <tag> files). VCOM will catch them if wrong.
            print "-"x80 . "\n" . "-"x23 . " HALTED ON SOURCE FILE PATH ERROR " . "-"x23 . "\n";
            print "Could not find the following file path from SOURCES variable in the build.pl file:\n  $item_original\n" . "-"x80 . "\n";
            print "-"x80 . "\n";
            last;
         }
         $item =~ s!\\!/!g; # Convert all slashes to forward-slashes
         print "${indent}Removing redundant source: $item\n", if (exists $seen{$item});
         push(@new_srces, $item) unless $seen{$item}++;
      }
      $indent--;
      @srcs = @new_srces;
   }

   if (!($err_found && $halt_on_error_flag))
   {
      printf "${indent}\n${indent}\n${indent}The %s recovered source files are listed below:\n${indent}\n", scalar @sources;
      print add_indents_to_lines( ( join "\n", @srcs ), $indent . '   ' );
   }

   if (keys( %{$project->{TEMPDIRS}} ) && !($err_found && $halt_on_error_flag))
   {
      printf "${indent}\n${indent}\n${indent}Creating temporary directories\n${indent}\n";
      my $dirs = $project->{TEMPDIRS};
      foreach( keys( %$dirs ) )
      {
         if ($_ eq "") { next; } # Skip empty lines
         $_ = forward_slashify($_);
         print "${indent}   $dirs->{$_} already exists\n" and next if-d $dirs->
         {
            $_
         };
         mkdir( $dirs->{$_} ) or die "BUILD:  Could not make directory: $dirs->{$_}\n";
         print "${indent}   $dirs->{$_} created\n";
      }
   }

   if (@{$project->{TEMPFILES}} > 0 && !($err_found && $halt_on_error_flag))
   {
      printf "${indent}\n${indent}\n${indent}Processing temporary files\n";
      foreach my $filename (@{$project->{TEMPFILES}})
      {
         if ($filename eq "") { next; } # Skip empty lines
         foreach my $keyname (keys (%$filename) )
         {
            if ($keyname eq "") { next; } # Skip empty lines
            if ($keyname ne 'NAME' and $keyname ne 'TEXT')
            {
               print "${indent}\n${indent} WARNING: Invalid hash key, $keyname, in build file\n"
            }
         }

         my $contents;
         my $real_filename = forward_slashify($filename->{NAME});
         open FH, "> $real_filename" or die "BUILD:  Could not open $real_filename for writing";

         $contents = $filename->{TEXT};

         # remove white space from beginning of all text lines
         my @lines = split "\n", $contents;
         grep s/^\s*(.*)$/$1/, @lines;
         $contents = join "\n", @lines;

         if ($contents =~ m/(<<<(.*?)SOURCES(.*?)>>>)/)
         {
            my $whole_line = $1;
            my $prefix  = $2;
            my $postfix = $3;

            my $srcstr = '';
            foreach ( @srcs )
            {
               if ($_ eq "") { next; } # Skip empty lines
               $srcstr .= $prefix . $_ . $postfix . "\n";
            }
            $contents =~ s/$whole_line/$srcstr/;
         }

         print "${indent}\n${indent} Creating file, \"$real_filename\", with the following contents:\n${indent}\n";
         print add_indents_to_lines( $contents, $indent . '   ' );
         print FH $contents;

         close FH or die "BUILD:  Could not close $real_filename";
      }
   }

   if (@{$project->{DOCS}} > 0 && !($err_found && $halt_on_error_flag))
   {
      printf "${indent}\n${indent}\n${indent}Touching Project Design Documents\n";
      foreach( @{$project->{DOCS}} )
      {
         if ($_ eq "") { next; } # Skip empty lines
         $_ = forward_slashify($_);
         $err_found = (touch_file( $_, $indent . '  ' ) != 0); # -1 err code
         # Abort if error and halt flag:
         if ($err_found && $halt_on_error_flag)
         {
            print "-"x80 . "\n" . "-"x30 . " HALTED ON DOC ERROR " . "-"x29 . "\n";
            print "-"x23 . "To override, see the -usage notes." . "-"x23 . "\n" . "-"x80 . "\n";
            last;
         }
      }
   }

   if (@{$project->{COMMANDS}} > 0 && !($err_found && $halt_on_error_flag))
   {
      printf "${indent}\n${indent}\n${indent}Processing build file commands\n";
      foreach( @{$project->{COMMANDS}} )
      {
         if ($_ eq "") { next; } # Skip empty lines
         indent_system( $_, $indent );
         # Abort if error and halt flag (byte 1 has return error, so >>8 ):
         if ((($? >> 8) != 0) && $halt_on_error_flag)
         {
            $err_found = 1;
            print "-"x80 . "\n" . "-"x30 . " HALTED ON CMD ERROR " . "-"x29 . "\n";
            print "-"x23 . "To override, see the -usage notes." . "-"x23 . "\n" . "-"x80 . "\n";
            last;
         }
      }
   }

   # Log the build duration:
   my $sec = time - $start_time;
   my $min = int( $sec / 60 );
   $sec = $sec % 60;
   print "${indent}\n${indent}Build took $min minute(s), $sec second(s)\n${indent}\n";

   $indent--;
   print "${indent}#######################################################\n";
   print "${indent}# Done Building:\n${indent}#   $target\n";
   print "${indent}#######################################################\n${indent}\n";

   return (\@sources);
}

sub get_reg_file_list
{
   #############################################################################
   # FUNCTION NAME: get_reg_file_list ()
   #
   # DESCRIPTION:   This function gets the list of files used to alter the
   #                registry for xilinx compiles.
   #
   # USAGE:         get_reg_file_list ();
   #
   # INPUTS:        cc_root
   #                   Base path of build
   #
   # OUTPUTS:       none
   #
   # RETURN VALUE:  Returns a list of registry.pl files
   #
   ##############################################################################
   my @reg_file_list = ();
   while (glob( $cc_root . "/compilers/xilinx/*" ))
   {
      -d or next;
      my $reg_file = "$_/registry.pl";
      -f $reg_file or next;
      push (@reg_file_list, $reg_file);
      $reg_found = 1;
   }
   return(@reg_file_list);
}


sub sigint_restore_registry
{
   #############################################################################
   # FUNCTION NAME: sigint_restore_registry ()
   #
   # DESCRIPTION:   This function restores the registry to its previous
   #                contents, then exits.
   #
   #*** NOTE:       Sleep statements are there to prevent faults - do not remove
   #
   # USAGE:         sigint_restore_registry ();
   #
   # INPUTS:        old_registry
   #                   registry values to restore
   #
   # OUTPUTS:       none
   #
   # RETURN VALUE:  none
   #
   ##############################################################################
   my( $err_code) = @_;
   if (IN_WINDOWS && $reg_found)
   {
      sleep 2;  # Required to prevent fault
      $tied_registry->{"Xilinx/"} = $old_registry;
      sleep 2;  # Required to prevent fault
      print "\n\nRegistry Restored\n";
      sleep 2;  # Required to prevent fault
   }
   exit ($err_code);
}


#############################################################################
# FUNCTION NAME: main()
#
# DESCRIPTION:   This function overwrites the clients path, registry and several
#                environment variables to ensure that an RTL build is
#                conducted using version controlled tools.
#
# USAGE:         clearaudit /c perl /tools/bin/build_rtl.pl /meter/fpga/top_meter
#
# INPUTS:        run this script without parameters to see inputs
#
# OUTPUTS:       creates output files as defined by the component build
#                file (build.pl)
#
# RETURN VALUE:  exits with zero unconditionally to ensure that clearaudit
#                attaches configuration record to all output files
#
##############################################################################
our $clean_flag     = 1;
our $halt_on_error_flag = 1;
our $directory_structure = "clearcase";

# RTLenv Variables and flags
our $use_rtlenv = 0;
our $rtlenv_dir;
our $rtlenv_top;

# This flag is set to one for legacy behavior. It is set to
#  zero to allow for building without Dynamic ClearCase.
our $clearcase_flag = 1;

# This flag is set to one to motivate use of 64-bit tools, where applicable
our $sixty_four_bit_flag = 0;

# This flag is set to one when use of Libero SOC (over Libero IDE) is intended
our $libero_soc_flag = 0;

# This flag is left undefined for default behavior. Otherwise, it is set to
#  the build_id code that was passed as a parameter.
my $build_id_flag  = undef;

my $target = "";
my $verbose;
my %params;

@ARGV >= 1 or usage( 'Target parameter required' );

if (system('cleartool catcs >NUL 2>&1'))
{
   # If cleartool is not available or a config spec cannot be found, let's go
   #  out on a limb and assume that this is not a clearcase view and the user
   #  would probably thank us for saving them the trouble of checking out
   #  whatever script is calling this to specify the -nocc flag.
   print "config spec not detected, inferring \"-nocc\" flag\n";

   # Use unshift rather than push so that we don't add any arguments after
   #  the -v argument.
   unshift @ARGV, '-nocc';
}

# get command line parameters
while ($_ = shift( @ARGV ))
{
   if(lc($_) eq '-h')
   {
      usage('');
   }
   elsif (lc($_) eq '-nocc')
   {
      $clearcase_flag = 0;
      $clean_flag = 0;
      $directory_structure = "flat";
   }
   elsif (lc($_) eq '-flat')
   {
      $directory_structure = "flat";
   }
   elsif (lc($_) eq '-contonerr')
   {
      $halt_on_error_flag = 0;
   }
   elsif ($_ eq '-64')
   {
      $sixty_four_bit_flag = 1;
   }
   elsif (lc($_) eq '-libero_soc')
   {
      $libero_soc_flag = 1;
   }
   elsif (lc($_) eq '-noclean')
   {
      $clean_flag = 0;
   }
   elsif(lc($_) eq '-buildid')
   {
      usage("Error: Improper code after -buildid") if ($ARGV[0] !~ /^[0-4dnxr]$/);
      foreach my $item (@ARGV)
      {
         usage("ERROR: Cannot set BUILDID twice.") if ($item eq "buildid" or $item eq "-buildid")
      }
      $build_id_flag = shift(@ARGV);
   }
   elsif(lc($_) eq '-v')
   {
      my $key;

      while ($key = shift( @ARGV ))
      {
         $params{$key} = shift( @ARGV );
         foreach (qw(-h -64 -nocc -noclean -buildid))
         {
            if ((lc($key) eq $_) or
                (lc($params{$key}) eq $_))
              {
                 usage("Error: $_ must precede -v as the -v flag should be last");
              }
           }
      }
   }
   else
   {
      $target = $_;
   }
}

# Make sure the user gave us a target:
usage( 'Target parameter required' ) if ($target eq "");

# Make sure the target they gave us was valid:
if (-d $target)
{
   if (! -f "$target/$build_file_name")
   {
      usage( "Target, \"$target\", is not a valid directory" );
   }
}
elsif (! -f $target)
{
   usage( "Target, \"$target\", is not a valid file or directory" );
}

# Handle build ID flag
if (defined($build_id_flag))
{
   if (($build_id_flag != 0) &&
       ($clearcase_flag == 0))
   {
      usage("Invalid Parameter Combination:\n" .
            "\t\"-buildid $build_id_flag\" cannot be used with -nocc");
   }
   else
   {
      $params{"BUILDID"} = get_build_id($build_id_flag);
   }
}

my $logpath = forward_slashify(get_abs_path( $target, "just directory" ));

$logpath .= 'reports/';

-d $logpath or mkdir( $logpath ) or die "MAIN:  Could not make directory: $logpath";

# Create log file:
my $logfile = $logpath . 'build_rtl.log';

if (($clearcase_flag != 0) &&
    (-f $logfile))
{
   indent_system( "cleartool uncheckout -keep $logfile", '' );
   indent_system( "cleartool checkout -unr -nc $logfile", '' );
}

my $tee;
{
   # route STDERR and STDOUT to screen and log
   $tee = new IO::Tee( \*STDOUT, "> $logfile" ) or die( "MAIN:  Could not open: $logfile" );
   tie *STDERR, 'IO::Tee', $tee;
   select( $tee );
}

print "\n\nA log of this build can be found at:\n\n   $logfile\n\n\n";

# Check whether rtlenv was used or not
if (-d "$target/syn/rtlenv")
{
   # Target is top level component
   $use_rtlenv = 1;
   $rtlenv_dir = "$target/syn/rtlenv";
}
elsif (-d "$target/../../tb/../syn/rtlenv")
{
   # Target is testbench of top level component
   $use_rtlenv = 1;
   $rtlenv_dir = "$target/../../syn/rtlenv";
}

if ($use_rtlenv == 1)
{
   $rtlenv_dir = get_abs_path($rtlenv_dir);
   $rtlenv_top = forward_slashify(get_abs_path("$rtlenv_dir/../.."));
   $rtlenv_top = (split '/', $rtlenv_top)[-1];  # Component name only
   print "Using RTLenv managed dependency directory for $rtlenv_top of: " .
         "$rtlenv_dir\n";
}

# Work from the ClearCase dynamic view drive as ClearCase and Xilinx tools
# don't seem to play nicely
if ($clearcase_flag != 0)
{
   my $view;

   if ( IN_WINDOWS )
   {
      my $ct = Win32::OLE->new('ClearCase.ClearTool')
         or die "MAIN:  Could not create ClearTool object\n";

      my $view_manager = new SEL::ClearCase::View;

      my $master_drive = $view_manager->parse_mounted_views->{SERVER};

      $master_drive =~ m/^[a-zA-Z]$/ or
         die "MAIN:  expected drive letter mapped to \"/view\", got: \"$master_drive\"";

      ( $view ) = $ct->CmdExec("pwv -s") =~ m/([\S]+)/ or
         die("MAIN:  Cleartool returned error: ", Win32::OLE->LastError(), "\n");

      my( $path ) = $ct->CmdExec("pwd") =~ m/(\S+)/ or
         die("MAIN:  Cleartool returned error: ", Win32::OLE->LastError(), "\n");

      $cc_root = substr("$path",0,2);
   }
   else
   {
      $view = system("cleartool pwv -s");
      chomp($view);

      $cc_root = $ENV{CLEARCASE_ROOT} . "/vobs";
   }

   print "Build conducted on the following ClearCase view:\n\n   $view\n\n";

   print "Clearcase Configuration Specification at time\n";
   print "  of build was:\n\n";
   indent_system( "cleartool catcs", '   ' );
   print "\n\n";
}

# Set up build environment
print "Setting Up Build Environment:\n\n";


print "Modifying Registry if necessary\n";
my @reg_file_list = ();
if ( IN_WINDOWS )
{
   # Check "tools" directories for registry entries to parse
   @reg_file_list = get_reg_file_list();

   # if there are registry files, perform special processing
   if ($reg_found)
   {
      print "Modifying Registry if necessary\n";
      # Get part of the registry information
      $tied_registry = $Registry->{"HKEY_LOCAL_MACHINE\\Software\\"};

      # Store old registry information so that it can be restored
      $Data::Dumper::Indent = 1;
      eval Data::Dumper->Dump([$tied_registry->{"Xilinx\\"}], [qw(old_registry)]);

      # write old registry data to a file for manual restore
      my $reg_file_name = "reg_restore.pl";
      print "**********************************************************\n";
      print "* To restore the registry, run $reg_file_name\n";
      print "**********************************************************\n";
      my $success = open (reg_restore, ">./$reg_file_name");
      if ($success)
      {
         print reg_restore "use strict;\n";
         print reg_restore "use Win32::TieRegistry 0.20 qw(\n";
         print reg_restore "                              TiedRef \$Registry\n";
         print reg_restore "                              ArrayValues 1  SplitMultis 1  AllowLoad 1\n";
         print reg_restore "                              REG_SZ REG_EXPAND_SZ REG_DWORD REG_BINARY REG_MULTI_SZ\n";
         print reg_restore "                              KEY_READ KEY_WRITE KEY_ALL_ACCESS\n";
         print reg_restore "                              );\n";
         print reg_restore "my ";
         print reg_restore Data::Dumper->Dump([$old_registry]);
         print reg_restore "\nmy \$tied_registry;\n";
         print reg_restore "\#Get part of the registry information\n";
         print reg_restore "\$tied_registry = \$Registry->{\"HKEY_LOCAL_MACHINE\\\\Software\\\\\"};\n";
         print reg_restore "\$tied_registry->{\"Xilinx\\\\\"} = \$VAR1;\n\n";
         close (reg_restore);
      }
      else
      {
         die ("MAIN:  couldn't open registry restore file: $!");
      }

      # Dangerous stuff - register signal handler to restore registry
      $SIG {'INT'} = 'sigint_restore_registry';

      # Process all of the registry files
      my $single_reg_file;
      foreach $single_reg_file (@reg_file_list)
      {
         if ($single_reg_file eq "") { next; } # Skip empty lines
         my $contents = extract_file($single_reg_file);
         my $registry = undef;
         eval $contents;
         defined( $registry ) or die "MAIN:  Could not process registry file $single_reg_file";

         print " Modifying Registry as required by tools at:\n   $_\n";

         # Append hash into registry
         $tied_registry->{"Xilinx\\"} = $registry;
      }
   }
}

my $ise_path        = "";
my $edk_path        = "";
my $vivado_path     = "";
my $vivado_sdk_path = "";
my $quartus_path    = "";
my $libero_soc_path = "";
my $env_vars      = {};
my @tool_paths    = ();

# Only change paths if ClearCase is available.  It doesn't make sense to change
#   the PATH environment to use ClearCase versions of tools when ClearCase is
#   not available.  Instead, assume the caller already has the tools in their
#   PATH.
if ($clearcase_flag != 0)
{
   $ise_path        = $cc_root . "/compilers/xilinx/ISE";
   $edk_path        = $cc_root . "/compilers/xilinx/EDK";
   $vivado_path     = $cc_root . "/compilers/xilinx/vivado";
   $vivado_sdk_path = $cc_root . "/compilers/xilinx/SDK";
   $quartus_path    = $cc_root . "/compilers/altera/quartus";
   $libero_soc_path = $cc_root . "/compilers/Microsemi/Libero_SOC";

   $env_vars =
   {
      SYNPLICITY_LICENSE_FILE => '1709@synplicity',
      SNPSLMD_LICENSE_FILE    => '1709@synplicity',
      SYNPLIFY_LICENSE_TYPE   => 'synplify_xilinxanalyst',
      XILINX                  => $ise_path,
      XILINX_EDK              => $edk_path,
      XILINX_VIVADO           => $vivado_path,
      XILINXD_LICENSE_FILE    => '2100@xilinx-lic1',
      QUARTUS_ROOTDIR         => $quartus_path,
      LM_LICENSE_FILE         => '1702@libero-lic' . $Config{path_sep} . '27011@altera-lic1',
      MICROSEMI_LIBERO_SOC    => $libero_soc_path,
   };

   # Below are version controlled tool paths that may or may not be accessible
   #  by the host system.  Perl is notably absent from this list because
   #  although it is a version controlled tool, perl has already been invoked
   #  to run this script.  Hot swapping the perl installation during the
   #  execution of a perl script is confusing and can be likened to the "dream
   #  within a dream" scenario of the movie "Inception".
   #
   # Historically, Perl has not been version controlled and as a consequence,
   #  has not been audited.  To date, the absence of Perl from version control
   #  has not been a liability for the perfect reproduction of release builds.
   #  Perl was added to version control by the tools group, however, their
   #  installation instructions at
   #     https://swtools.ad.selinc.com/wiki/index.php/Local_Perl
   #  indicate that it should be loaded and executed from a Snapshot view,
   #  making it inaccessible to ClearAudit.  So, auditing Perl is not
   #  specifically recommended.  However, if you insist on having version
   #  controlled perl to appear in your ClearCase build configuration records,
   #  you should make sure that your paths resolve to the appropriate view
   #  before you invoke the build_rtl script because the liability of
   #  hot-swapping Perl is larger than any apparent benefit.
   @tool_paths =
   (
      $cc_root. '/compilers/synplicity/Synplify/bin',
      $env_vars->{XILINX_EDK}      . '/xygwin/bin',
      $env_vars->{XILINX_EDK}      . '/gnu/microblaze/nt/bin',
      $env_vars->{XILINX_EDK}      . '/bin/nt',
      $env_vars->{XILINX_EDK}      . '/lib/nt',
      $env_vars->{XILINX}          . '/bin/nt',
      $env_vars->{XILINX}          . '/lib/nt',
      $env_vars->{QUARTUS_ROOTDIR} . '/sopc_builder/bin',
      $env_vars->{XILINX_VIVADO}   . '/bin',
      $vivado_sdk_path             . '/bin',
      $vivado_sdk_path             . '/gnuwin/bin',
   );
   if ($sixty_four_bit_flag != 0)
   {
      push @tool_paths, $env_vars->{QUARTUS_ROOTDIR} . '/bin64';
      if ( IN_WINDOWS )
      {
         push @tool_paths, $env_vars->{XILINX_VIVADO}   . '/lib/win64.o';
      }
      else
      {
         push @tool_paths, $env_vars->{XILINX_VIVADO}   . '/lib/lnx64.o';
      }
   }
   else
   {
      push @tool_paths, $env_vars->{QUARTUS_ROOTDIR} . '/bin';
      if ( IN_WINDOWS )
      {
         push @tool_paths, $env_vars->{XILINX_VIVADO}   . '/lib/win32.o';
      }
      else
      {
         push @tool_paths, $env_vars->{XILINX_VIVADO}   . '/lib/lnx64.o';
      }
   }
   # Libero SOC vs Libero IDE
   if ($libero_soc_flag != 0)
   {
      push @tool_paths, $env_vars->{MICROSEMI_LIBERO_SOC}   . '/Designer/bin';
   }
   else
   {
      push @tool_paths, '/compilers/microsemi/Libero/Designer/bin';
      push @tool_paths, '/compilers/microsemi/SoftConsole/Sourcery-G++/bin';
   }
};

# We will build a minimal set of paths required to build RTL which favor
#  version controlled tools where applicable.
my @new_paths = ();

# Parse the existing path to preserve a minimal subset of required directories
#  associated with the host operating system, ClearCase, and Perl.
# We know that perl is likely in the path given that we are a perl script
#  that is being ran. It stands to reason that the path to perl and any
#  libraries will be have the 'perl' token in it, so we parse for that.
my $regex = "\\s*" . $Config{path_sep} . "\\s*";
foreach (split($regex,$ENV{'PATH'}))
{
   if (! -d $_)
   {
      warn "\nWARNING: Host system PATH directory does not exist:\n  $_\n\n";
      next;
   }

   if ($clearcase_flag == 0)
   {
      # When not in clearcase retain the user's paths because build_rtl.pl
      # does not know how the system is configured.
      push @new_paths, $_;
   } elsif (
       (m/([a-zA-Z]:\\windows)/i) ||
       (m/([a-zA-Z]:\\winnt)/i)   ||
       (m/(\/bin)/i)              ||
       (m/(\/sbin)/i)             ||
       (m/(\/usr)/i)              ||
       (m/(\/usr\/sbin)/i)        ||
       (m/\\atria\\bin/i)         ||
       (m/\\clearcase\\bin/i)     ||
       (m/\/clearcase\/bin/i)     ||
       (m/\\IBM\\gsk8/i)          ||
       (m/\\IBM\\Rational/i)      ||
       (m/perl/i)                 ||
       (m/python/i)               ||
       (m/Active-HDL/i)           ||
       (m/MATLAB/i))
   {
      # Add important paths to new paths in the order
      #  that they are observed in the system path.
      push @new_paths, $_;
   }

}

# Iterate through the version controlled tool paths and add them to the
#  new_paths array if they are found to exist
foreach my $tool_path (@tool_paths)
{
   -d $tool_path or next;
   push @new_paths, $tool_path;
}

# Apply environment variable overrides
set_env_var( $_, $env_vars->{$_} ) foreach( keys( %$env_vars ) );

# Overwrite the host system path with our reduced set of paths
#  that favor version controlled tools.
# If our attempt to preserve the paths associate with perl fails, we will
#  issue a warning and fall back to deprecated behavior of adding a network
#  installation of perl.
$ENV{'PATH'} = join $Config{path_sep}, @new_paths;
if (system('perl -v >NUL 2>&1'))
{
   my $ccnas_perl = '\\\\ccnas\\netperl\\5.8\\ActiveState\\bin';
   print "WARNING:\n";
   print "   Perl not found\n";
   print "   Falling back to deprecated perl at:\n";
   print "      $ccnas_perl\n\n";
   -d $ccnas_perl or die "CCNAS perl not available";
   push @new_paths, $ccnas_perl;
}

# Rewrite the PATH, given that the ccnas perl installation may
#  have been added to the @new_paths array.
print " Defining the \"PATH\" environment variable with\n  the following " .
   scalar( @new_paths ) . " directories:\n   ";
print join( "\n   ", @new_paths ) . "\n\n";
$ENV{'PATH'} = join $Config{path_sep}, @new_paths;

print "Starting Build:\n";
build( $target, "", \%params );

if ($clean_flag == 0)
{
   print "\n\n";
   print "Warning: build_rtl.pl did not conduct a clean before building\n";
   print "          due to use of the -nocc and/or -noclean parameters\n";
}

my($sec,$mn,$hr,$day,$month,$yrOffset,$dayOfWeek,$julian,$daylightSav)=localtime(); #include build time in build log file
printf("\n\nClosing log at %02u:%02u:%02u on 20%02u-%02u-%02u.\n\n A log of this build can be found at:\n\n   $logfile\n\n\n",$hr,$mn,$sec,$yrOffset-100,$month+1,$day);
undef $tee;

# This routine exits, so there will be no return from it
sigint_restore_registry($err_found && $halt_on_error_flag);
exit ($err_found && $halt_on_error_flag);
