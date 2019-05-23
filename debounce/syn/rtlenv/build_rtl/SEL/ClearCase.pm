################################################################################
# COPYRIGHT (c) Schweitzer Engineering Labs, Pullman, Washington
#
# This package contains various utility functions for ClearCase.
#
# This module is intended to work with perl 5.8 or later with Microsoft Windows
# (it may happen to work on other platforms like Linux, but is not as regularly
# tested there).
#
################################################################################
package SEL::ClearCase;

use strict;
use warnings;
use Carp qw(cluck croak confess);
use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION $DEBUG);

use Exporter;
$VERSION = 1.6;
@ISA = qw(Exporter);

@EXPORT      = qw( componentize_xpn
                   find_CC_view_tag
                   is_tip_ver
                   in_mvfs
                   get_xpn_basename
                   norm_xpn
                   setcs_from_file
                   split_cc_xpn
                   strip_idstr
                   strip_xpn
                   strip_xpn_prefix);      # Symbols to autoexport (:DEFAULT tag)

@EXPORT_OK   = qw( r_clean
                   del_attributes
                   set_attributes
                   get_element_attributes
                   get_version_attributes
                   get_view_path
                   get_volume_fstype
                   get_pn_attributes);     # Symbols to export on request

%EXPORT_TAGS = ( );                        # Define names for sets of symbols

use Carp;
use Cwd qw(abs_path getcwd cwd);
use File::Basename qw(dirname basename);
use File::Copy;
use File::Find;
use File::Path;
use File::Spec;

use lib File::Spec->canonpath(dirname(abs_path(__FILE__)) . "/..");

use SEL::ClearTool;
use SEL::Utilities;
use SEL::FileUtils;

local ${^WIN32_SLOPPY_STAT} = 1;

sub get_view_only_dirs {
################################################################################
# SUBROUTINE:  get_view_only_dirs - Returns the list of view private dirs in a directory tree
#
# INPUTS:  $dir - The directory to be searched.
#
# RETURNS: A list of view private directories
################################################################################
   my ($dir) = @_;

   my @dir_list;

   my @vo_list = ct_array_handler("ls -recurse -view_only $dir");
   #
   # Derived objects are listed with some kind of timestamp, e.g.:
   #    \dir1\dir2\filename.ext@@14-Sep.09:49.123456
   # Using the "-short" argument to cleartool unfortunately does not filter it out, so
   # we have to do it here:
   #
   foreach my $file (@vo_list)
   {
      my ($fpath, $extended_path) = split(/@@/, $file);
      if (-d $fpath)
      {
         if ( !(defined($extended_path) && $extended_path =~ /CHECKEDOUT/) ) # Ignore checkouts
         {
            push(@dir_list,$fpath);
         }
      }
   }
   return @dir_list;
}

sub get_view_only_files {
################################################################################
# SUBROUTINE:  get_view_only_files - Returns the list of view private files in a directory tree
#                                    
# INPUTS: dir - The directory to be searched.
#
# RETURNS: The list of view privates
################################################################################
   my ($dir) = @_;

   my @file_list;

   my @vo_list = ct_array_handler("ls -recurse -view_only $dir");
   #
   # Derived objects are listed with some kind of timestamp, e.g.:
   #    \dir1\dir2\filename.ext@@14-Sep.09:49.123456
   # Using the "-short" argument to cleartool unfortunately does not filter it out, so
   # we have to do it here:
   #
   foreach my $file (@vo_list)
   {
      my ($fpath, $extended_path) = split(/@@/, $file);
      if (-f $fpath)
      {
         if ( !(defined($extended_path) && $extended_path =~ /CHECKEDOUT/) ) # Ignore checkouts
         {
            push(@file_list, $fpath);  # Only save $fpath and ignore $timestamp
         }
      }
   }
   return @file_list;
}

sub r_clean {
################################################################################
# SUBROUTINE:  r_clean - Removes view private files in a directory tree
#
# INPUTS: $target_dir - The directory to be searched.
#         $backup_dir - deprecated place to put files
#         $verbose    - deprecated
#         $indent     - deprecated
#
# RETURNS: The list of view privates
################################################################################
   my($target_dir, $backup_dir, $verbose, $indent) = @_; # Only $target_dir is used

   my @view_only_files = get_view_only_files($target_dir);
   my @files_to_delete = ();

   foreach my $file (@view_only_files) {
      if (index($file,'.keep') < 0) {
         print "Deleting view-specific file: $file\n";
         push(@files_to_delete, $file);
      }
      else {
         print "Skipping keep file: $file\n";
      }
   }
   unlink(@files_to_delete);

   my @dirlist = get_view_only_dirs($target_dir);
   
   @dirlist = sort {$b cmp $a} @dirlist; # sort in reverse order
   foreach my $d (@dirlist)
   {
      rmdir($d);
   }
}

sub setcs_from_file {
   my ($cspec_path, $viewname) = @_;
   my $view_prefix = q{};

   my $curr_viewname = ct_line_handler('pwv -short');
   confess("ERROR: Failed to get current view context: ($?)") if (!$curr_viewname);

   my $viewroot_prefix = (IN_WINDOWS) ? 'M:/' : '/view/';
   $view_prefix = $viewroot_prefix . $viewname;
   if ($curr_viewname ne $viewname)
   {
      if (! -d $view_prefix) # Is the requested view already started?
      {
         ct_line_handler("startview $viewname");
         if ($? != 0)
         {
            confess("ERROR:\tFailed to start view: $viewname\n");
         }
      }
   }
   ct_line_handler("setcs -tag $viewname \"$cspec_path\"");
   if ($? != 0)
   {
      confess("ERROR:\tFailed to set config spec ('$cspec_path') to $viewname\n");
   }
   return $view_prefix;
}

#
# Utility routine for set_attributes (see below)
#
# If mkattr fails, print the appropriate warning, based on the options supplied.
# If '-replace' is not used and an existing file/version already has an
# existing attribute, mkattr is expected to fail.
#
sub warn_on_set_attr_failure {
   my ($noreplace, $key, $file, $ct_line) = @_;
   
   if (rindex($file, 'CHECKEDOUT') > 0)
   {
      warn("WARNING: mkattr failed: '$file' is checked out\n");
   }
   elsif (!defined($noreplace) && !$noreplace)    # failed with default '-replace'
   {
      warn("WARNING: mkattr failed: could not set attribute $key on '$file'\n");
   }
   elsif (defined($noreplace)                     # failed without '-replace'
       && $noreplace
       && index($ct_line, 'already has an attribute') > 0)
   {
      # Not an error condition with noreplace.
      # Output simple one line notification about skipped attribute.
      # In the case of rec_setter.pl, the $file already printed.
      warn("WARNING: mkattr failed: '$key' already exists and was NOT replaced.\n");
   }
   elsif (! -f $file)
   {
      warn("WARNING: mkattr failed: '$file' does not exist\n");
   }
   elsif (ct_line_handler("lscheckout -s '$file'"))
   {
      warn("WARNING: mkattr failed: '$file' is checked out\n");
   }
}

sub set_attributes {
##########################################################################################
# SUBROUTINE:  set_attributes - Set attributes on a file version (default) or element
#
# INPUTS:  $attr_hash - A hash where the key is the attribute and the value is the value to be set.
#          $fpath     - File element path (no version information) to set the attribute on
#          $elem_attr - (optional) Boolean indicating that the attributes are to be set on the element
#          $version   - (optional) string indicating specific version to set attribute on (defaults to
#                       version selected by the view).
#          $noreplace - (optional) Don't use '-replace' argument with the mkattr command.
#                       By default, '-replace' is used; 1 means don't use '-replace'.
#
# RETURNS: $attr_counter - Number of attributes actually set
##########################################################################################
   my ($attr_hash, $fpath, $elem_attr_in, $version_in, $noreplace) = @_;
   my $attr_counter = 0;

   my $version      = (defined($version_in)   && $version_in)   ? $version_in   : '';
   my $elem_attr    = (defined($elem_attr_in) && $elem_attr_in) ? $elem_attr_in : '';
   
   my $version_arg  = $version ? "-version $version" : '';
   my $replace      = (defined($noreplace) && $noreplace) ? '' : '-replace'; 

   if ($version && $elem_attr) # Conflicting options, no idea what to do
   {
      Carp::confess("ERROR: Must specify that attributes are applied to either
                    an element or a version (not both)\n");
   }
   if (ref($attr_hash) ne 'HASH')
   {
      Carp::confess("ERROR: First argument must be hash reference\n");
   }
   else
   {
      my $fpath_targ = $elem_attr ? strip_idstr($fpath) . '@@' : $fpath;      
      while ((my $key, my $value) = each %{$attr_hash})
      {
         my $cmd = qq{mkattr $replace $version_arg $key '\"$value\"' "$fpath_targ"};
         my $ct_line = ct_line_handler($cmd);
         if ($?)   # Warn on failure
         {
            warn_on_set_attr_failure($noreplace, $key, $fpath, $ct_line);
         }
         else
         {
            ++$attr_counter;
         }
      }
   }
   return $attr_counter;
}

# Generic method (but slower on Windows) to get attributes for a given path
sub get_pn_attributes { # Works for element and version paths
   my $ct_out = ct_line_handler("desc -aattr -all '$_[0]'");
   return parse_kv_lines($ct_out, '"');
}

# Windows specific helper for get_element_attributes() and get_version_attributes()
# Output identical to get_pn_attributes(), but uses CAL API via COM/OLE
sub get_pn_attributes_win {
   my ($pn_in, $mode_in) = @_;
   my %ret_hash = ();
   my $mode = (defined($mode_in) && $mode_in) ? 1 : 0;
   
   my $cca = get_cca_ole_handler();
   my $cc_obj = $mode ? $cca->Element($pn_in) : $cca->Version($pn_in);
   if (!$cc_obj) {
      warn("***********************************************\n");
      warn("ERROR:\tUnable to get OLE object for '$pn_in' (is path a symlink?)\n");
      warn("***********************************************\n");
      return \%ret_hash;
   }

   my $enum = Win32::OLE::Enum->new($cc_obj->Attributes);
   if (my $err = Win32::OLE->LastError()) {
      my $err_num = sprintf("0x%08x", $err); # Get numerical error code
      Carp::cluck("ClearCase.Application OLE error: $err ($err_num)");
   }
   elsif($enum) {
      while (defined(my $AttrItem = $enum->Next)) {
         $ret_hash{$AttrItem->Type->Name} = $AttrItem->Value;
      }
   }
   return \%ret_hash;
}

# Given an XPN as input, return 1 if it is the latest version on it's branch
sub is_tip_ver
{
   my $xpn_in = $_[0];
   my $retval = 0;
   my ($lhs, $rhs) = path_rsplit($xpn_in);
   my $latest_path = $lhs . 'LATEST';
   my $latest_ver = ct_line_handler("desc -fmt \"%Xn\" $latest_path");
   $retval = 1 if (norm_xpn($xpn_in) eq norm_xpn($latest_ver));
   return $retval, $latest_ver;
}

sub get_element_attributes {
################################################################################
# SUBROUTINE:  get_element_attributes - Get attributes on a file element
#
# INPUTS:  $cc_file  - the file element to get attributes for
#
# RETURNS:           - hashref of attribute value pairs
################################################################################
   my ($pn_in) = $_[0];
   my $pn = strip_idstr($pn_in);
   return IN_WINDOWS ? get_pn_attributes_win($pn, 1) : get_pn_attributes($pn . '@@');
}

sub get_version_attributes {
################################################################################
# SUBROUTINE:  get_version_attributes - Get attributes on a file version
#
# INPUTS:  $cc_file  - the version to get attributes for
#
# RETURNS:           - hashref of attribute value pairs
################################################################################
   return IN_WINDOWS ? get_pn_attributes_win($_[0]) : get_pn_attributes($_[0]);
}

sub del_attributes {
################################################################################
# SUBROUTINE:  del_attributes - Delete attributes on a file
#
# INPUTS: $attr_list - The list of attributes to be deleted
#         $file      - The file name to delete attributes from
#         $elem_attr - (optional) indicates this is an element attribute
#         $version   - (optional) specific version to delete atribute from
#                      (defaults to version selected by the view)
#
# RETURNS: $attr_counter - Number of attributes actually deleted
################################################################################
   my( $attr_list, $file, $elem_attr, $version ) = @_;

   my $attr_counter = 0;
   my $version_arg = ($version && !$elem_attr) ? "-version $version" : '';

   foreach(@$attr_list) {
      my $cmd = "rmattr $version_arg $_ ";
      $cmd .= ($elem_attr ? "'$file\@\@'" : "'$file'");
      my $ct_line = ct_line_handler($cmd);
      if ($?)
      {
         warn("WARNING: Could not delete $_ attribute from '$file'\n");
      }
      else
      {
         ++$attr_counter;
      }
   }
   return $attr_counter;
}

sub find_CC_view_tag {
#########################################?######################################
# SUBROUTINE: find_CC_view_tag() - Find the ClearCase view tag
#
# INPUTS:  $fpath - Pathname to search for a view tag in.
#
# RETURNS: '' (empty string) if the view tag is not found, otherwise a
#             string corresponding to the view tag
#
# NOTES:   An example of a CLEARCASE_VIEW_TAG would be "garepa_ux_view"
#########################################?######################################
   (my $fpath = $_[0]) =~ tr/\\/\//;    # Make a forward slashified copy
   my $retval = '';
   if ($fpath =~ /^[mM]\:\/([^\/]+)/)   # Does it have a M:/<view-name> prefix?
   {
      $retval = $1;
   }
   elsif ($fpath =~ /^\/view\/(.+)\/vobs/) # /view/<view-name>/.../ prefix?
   {
      $retval = $1;
   }
   return $retval;
}

sub strip_xpn_prefix {
################################################################################
# SUBROUTINE: strip_xpn_prefix() - Strip the host specific prefix that exists in
#                                  a ClearCase extended pathname (XPN).
#
# INPUTS: $xpn_input - A ClearCase extended pathname
#
# NOTES: There are four cases that look like this:
# 1) /view/garepa_ux_view/vobs/tools/source/bin2hex/bin2hex.c@@/main/5
# 2) /vobs/tools/source/bin2hex/bin2hex.c@@/main/5
# 3) M:/garepa_ux_view/tools/source/bin2hex/bin2hex.c@@/main/5
# 4) W:/tools/source/bin2hex/bin2hex.c@@/main/5
#
# In cases 1) and 2) the checkin occured in a Unix-like environment.
# In cases 3) and 4) the checkin occured in a Windows-based environment.
#
# In the examples above, this subroutine will return the same result for all
# four cases:
#
#   /tools/source/bin2hex/bin2hex.c@@/main/5
################################################################################
   warn("**** WARNING: Use of strip_xpn_prefix is deprecated; use norm_xpn instead\n");
   return norm_xpn($_[0]);
}

sub get_xpn_basename {
################################################################################
# SUBROUTINE:  get_xpn_basename - Returns the basename of a ClearCase extended pathname,
#                                 disregarding the extended portion of the path (@@...)
#
# INPUTS: $cc_xpn - A ClearCase extended pathname (XPN) string.
#
# RETURNS: The basename (filename.ext) portion of a path.
################################################################################
   my ($dir, $basename) = path_rsplit(norm_xpn(strip_idstr($_[0])));
   return $basename;
}

sub split_cc_xpn {
################################################################################
# SUBROUTINE: split_cc_xpn() - Split up a ClearCase extended pathname into parts.
#
# INPUTS:  $xpn_input  - A ClearCase extended pathname (XPN)
#
# RETURNS: $filename   - Name of the file in the XPN
#          $cc_br_path - Full XPN path to the file (excluding the version number)
#          $cc_version - Version number of the XPN path received (if a regular
#                        path is provided, this is 0)
################################################################################
   my $xpn = norm_xpn($_[0]);
   my ($dirpath, $filename, $branch, $version) = componentize_xpn($xpn);
   my $full_brpath = ($branch) ? '@@' . $branch : ''; # re-add '@@'
   return ($filename, join('',$dirpath,$filename,$full_brpath), $version);
}

sub strip_idstr {
################################################################################
# SUBROUTINE:  strip_idstr - Strips the extended part of a ClearCase pathname
#
# INPUTS:  $cc_xpn - A ClearCase extended pathname (XPN) string.
#
# RETURNS: A regular path string, without extended version info (@@/main/...).
#
#          e.g. "/tools/bin/blah.pl@@/main/garepa_dev" would be transformed to:
#               "/tools/bin/blah.pl"
################################################################################
   my ($cc_xpn) = $_[0];
   my $retstr = $cc_xpn;
   my $idx = rindex($cc_xpn, '@@');
   if ($idx > 0) {                          # Did we find a match for '@@'?
      $retstr = substr($cc_xpn, 0, $idx) ;  # Yes, so skip that data
   }
   return $retstr;
}

sub strip_xpn { # Wrapper routine kept here for backwards compatibility
   warn("**** WARNING: Use of strip_xpn is deprecated; use strip_idstr instead\n");
   return strip_idstr($_[0]);
}

# Normalize an XPN: strip any surrounding whitespace, and any view specific
# prefix (e.g. M:/<view-name>/ or /view/<view-name>/) so that paths are
# comparable.
sub norm_xpn {
   my ($xpn_in) = $_[0];
   (my $ret_xpn = $xpn_in) =~ s/^\s+//; # Strip leading whitespace
   $ret_xpn =~ s/\s+$//;                # Strip trailing whitespace
   $ret_xpn =~ tr/\\/\//;               # Substitute '/' for '\' path separators
   $ret_xpn =~ s/^\/view\/.+\/vobs//;   # Strip /view/<view-name>/vobs prefix
   $ret_xpn =~ s/^\/vobs//;             # Strip /vobs prefix
   $ret_xpn =~ s/^[mM]\:\/[^\/]+//;     # Strip M:/<view-name>/ prefix 
   $ret_xpn =~ s/^[A-Za-z]\://;         # Strip drive letter, e.g. 'W:/'
   return $ret_xpn;
}

# Takes in a ClearCase extended pathname (XPN) and returns it's component parts.
# Assumes input has already been sanitized or 'normalized' with forward-slash
# (i.e. '/') path-separators.
sub componentize_xpn {
   my ($xpn) = $_[0];
   my ($branch, $version) = ('') x 2;
   
   # A derived-object path may have a date and id format like so:
   #   (dirpath)(filename)@@dd-mmm.hh:mm.nnnnnn OR
   #   (dirpath)(filename)@@--dd-mm.hh:mm.nnnnn
   # Also note that the part following the '@@' (idstr) has a ':' (colon)
   
   my $ridx = rindex($xpn, '@@'); # Where is the last '@@' substr?
   my ($elem_path, $idstr) = (substr($xpn,0,$ridx), substr($xpn, $ridx + 2));
   my ($dirpath, $filename) = path_rsplit($elem_path);
   
   if ($idstr)
   {
      if (index($idstr,':') != -1) # Derived-object?
      {
         $version = $idstr; # Yes, only DOs have a colon (':') char in them
      }
      else
      {
         ($branch, $version) = path_rsplit($idstr);
      }
   }
   return ($dirpath, $filename, $branch, $version);
}

# Returns true (1) if the path corresponds to a valid path in a ClearCase view
sub in_mvfs
{
   my ($in_path) = @_;
   my $retval    = 0; # Assume 0 (false/no) by default

   if ($in_path && !has_invalid_path_ptns($in_path))
   {
      if (IN_WINDOWS)
      {
         my $colon_idx = index($in_path, ':');
         my $colon_path = ($colon_idx > 0) ? ($in_path) : (getcwd());
         my $drive_letter = substr($colon_path, 0, 1);
         my $fstype = get_volume_fstype($drive_letter);
         $retval = 1 if ($fstype eq 'MVFS'); # Volume type is MVFS
      }
      else # Note: we don't ask the OS if a path is in an MVFS filesystem here;
      {    # which means non-Windows systems have lesser assurance.
         my $view_pfx1 = '/view/';
         my $view_pfx2 = '/vobs/';
         my $fpath_pfx = substr($in_path, 0, length($view_pfx1));
         if ($fpath_pfx eq $view_pfx1 || $fpath_pfx eq $view_pfx2)
         {
            $retval = 1;
         }
      }      
   }
   return $retval;
}

sub get_view_path {
   ######################################0####################################
   # FUNCTION NAME:  get_view_path()
   #
   # DESCRIPTION:    gets the path prefix of the present working view
   #
   #  USAGE:         $viewpath = get_view_path();
   #
   #  RETURNS:       Prefix path of the present working view; this is typically
   #                 a drive-mapped path (W:\, Y:\, M:\<view-name>) on Windows
   #                 or a path with a 'vobs' prefix on unix systems:
   #                 (/view/<view-name>/vobs or /vobs)
   ##########################################################################
   my $retval = '';
   (my $cwd = getcwd()) =~ tr/\\/\//;
   
   if (in_mvfs($cwd)) # If we're in an MVFS, we can determine prefix from cwd
   {
      my @p = split('/', $cwd); # -> 2-elem array if 'M:' path, 1-elem otherwise
      if (IN_WINDOWS) # p == 'M:' or 'W:', ... etc
      {
         $retval = (uc($p[0]) eq 'M:') ? ("$p[0]/$p[1]") : ($p[0]);
      }
      else
      {
         $retval = ($p[1] eq 'view') ? ("/$p[1]/$p[2]/vobs") : ('/vobs');
      }
   }
   else # Not in mvfs (possibly in a snapshot), need to ask ClearCase
   {
      ($retval = ct_line_handler('pwv -root')) =~ tr/\\/\//;
   }
   return $retval;
}

1;
