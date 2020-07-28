################################################################################
# COPYRIGHT (C) Schweitzer Engineering Labs, Pullman, Washington
#
# This package contains various file and file path related utility sub-routines
#
################################################################################

package SEL::FileUtils;

use Exporter;

use strict;
use warnings;

use Carp qw(confess cluck);
use Cwd qw(abs_path);
use File::Basename;
use File::Copy;
use File::Temp qw(tempdir);

use lib File::Spec->canonpath(dirname(abs_path(__FILE__)) . "/..");
use SEL::Utilities;

use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);

$VERSION = 1.20;

@ISA = qw(Exporter);

@EXPORT      = qw(abs_pname
                  bin_extract_file
                  copy_file
                  files_in_dir
                  find_tempdir
                  get_volume_fstype
                  has_invalid_path_ptns
                  is_dir_empty
                  move_file
                  path_rsplit);
@EXPORT_OK   = qw();
%EXPORT_TAGS = ();

BEGIN
{
   if (IN_WINDOWS)
   {
      require Win32::File;
      Win32::File->import(qw[SetAttributes NORMAL]);
      ${^WIN32_SLOPPY_STAT} = 1;
   }
}

# Safe version of rel2abs() that preserves '/' path separators.
sub abs_pname
{
   my ($pname_orig) = $_[0];
   my $ret_pname = $pname_orig;
   if (!File::Spec->file_name_is_absolute($ret_pname))
   {
      $ret_pname = File::Spec->rel2abs($ret_pname);
      $ret_pname =~ tr/\\/\//; 
      # ^-- Note: rel2abs() is destructive of it's input--it modifies the
      # path separators (e.g. '/' to '\'), presumably assuming that '\' is
      # desired on Windows, but we always normalize to use '/' everywhere.
   }
   return $ret_pname;
}

# On terminal servers, TEMP may include a trailing session number.
# $ENV{TEMP} with number folder at the end doesn't match Registry TEMP.
# Remove the last \<number> folder if it exists.
sub find_tempdir
{
   my $retval = File::Spec->tmpdir();
   if ($retval && $retval =~ /(.*)\\\d+$/)
   {
      $retval = $1;
   }
   return $retval;
}

#
# Given $src and $dst inputs, calls copy() or move() depending on $mode;
# if $mode is true, copy() is called -- otherwise move() is used.
#
# On success, 0 is returned, otherwise:
# 1 - $src and $dst path inputs are identical
# 2 - copy() or move() call failed
#
sub copy_or_move
{
   my ($src_fpath, $dst_dir, $mode) = @_;
   my $retval = 0; # Success
   
   my $dst_fpath = File::Spec->catfile($dst_dir, basename($src_fpath));
   
   if ($src_fpath eq $dst_fpath)
   {
      $retval = 1; # Failure -- src/dst can't be identical
   }
   else
   {
      SetAttributes($dst_fpath, NORMAL()) if (IN_WINDOWS && $dst_fpath);
      my $fn_ref = ($mode) ? \&File::Copy::copy : \&File::Copy::move;
      
      if ($fn_ref->($src_fpath, $dst_fpath))
      {
         SetAttributes($dst_fpath, NORMAL()) if (IN_WINDOWS);
      }
      else
      {
         $retval = 2; # copy/move failed (exceedingly rare - hardware going bad?)
      }      
   }
   return $retval;
}

sub copy_file
{
   return copy_or_move($_[0], $_[1], 1);
}

sub move_file
{
   return copy_or_move($_[0], $_[1], 0);
}

sub files_in_dir
{
   my ($dirname) = @_;
   opendir(my $dh, $dirname) or confess("opendir($dirname) failed: $!");
   my @files = grep { $_ ne '.' && $_ ne '..' } readdir $dh;
   closedir $dh or confess("closedir($dirname) failed: $!");
   return \@files;
}

sub is_dir_empty
{
   my ($dirname) = @_;
   my $retval = 0;
   opendir(my $dh, $dirname) or confess("opendir($dirname) failed: $!");
   my $num_files = scalar(grep( !/^\.\.?$/, readdir($dh)));
   $retval = 1 if ($num_files == 0);
   closedir $dh or confess("closedir($dirname) failed: $!");
   return $retval;
}

sub bin_extract_file
{
   return extract_file($_[0], 1);
}

# This routine is win32-specific at this time, as it's not known how to
# reliably get the same data from Linux.
sub get_volume_fstype
{
   my ($drive_letter) = @_;

   require Win32::OLE; # Win32::OLE ClearCase.ClearTool
   require Win32::API; # kernel32::GetVolumeInformation for get_volume_fstype()

   # GetVolumeInformation expects a fixed-length return buffer into which it writes the FS type string
   # buffer is 255 bytes long. we should be able to identify the filesystem name with much less than that
   my $null_delim = "\x00";
   my $fstype_buf = $null_delim x 255;
   my $volume_buf = $null_delim x 255;

   # set up GetVolumeInformation call, retrieving only FS type name
   # http://search.cpan.org/~cosimo/Win32-API-0.59/API.pm#IMPORTING_A_FUNCTION_WITH_A_PARAMETER_LIST
   # Win32::API->new(<library name>, <function name>, <parameter list types>, <return type>)
   my $w = new Win32::API('kernel32', 'GetVolumeInformation', 'PPNPPPPN', 'I');

   # http://msdn.microsoft.com/en-us/library/windows/desktop/aa364993(v=vs.85).aspx
   #
   # BOOL WINAPI GetVolumeInformation(
   #  __in_opt   LPCTSTR lpRootPathName,           // A pointer to a string that contains the root directory of the volume to be described.
   #  __out      LPTSTR lpVolumeNameBuffer,        // An optional pointer, null in this case because we are not using this feature
   #  __in       DWORD nVolumeNameSize,            // Size in bytes of the destination pointer above
   #  __out_opt  LPDWORD lpVolumeSerialNumber,     // optional pointer, null
   #  __out_opt  LPDWORD lpMaximumComponentLength, // optional pointer, null
   #  __out_opt  LPDWORD lpFileSystemFlags,        // optional pointer, null
   #  __out      LPTSTR lpFileSystemNameBuffer,    // buffer receiving the file system type name
   #  __in       DWORD nFileSystemNameSize         // size of the receiving buffer (to avoid overruns)
   #);

   my $res = $w->Call($drive_letter . ":\\",
                      $volume_buf,
                      length($volume_buf),
                      pack('L', 0),
                      pack('L', 0),
                      pack('L', 0),
                      $fstype_buf,
                      length($fstype_buf));
   if (!$res) {
      confess("ERROR:\t" . "GetVolumeInformation() failed: "
              . Win32::FormatMessage(Win32::GetLastError()));
   }
   # Find first contiguous string, not including trailing null bytes
   my $fstype = substr($fstype_buf, 0, index($fstype_buf, $null_delim));

   return $fstype;
}

sub has_invalid_path_ptns
{
   my ($in_fpath) = $_[0];
   my $retval = 0;
   if ($in_fpath)
   {
      $retval += 1 if (is_unc_path($in_fpath));    # UNC prefix
      my $cntrl_re = qr/ ^ [[:cntrl:]]+ $ /x;
      $retval += 2 if ($in_fpath =~ /$cntrl_re/);  # Typically SUB/CTRL+Z 
   }                                               # from Linux builds.
   return $retval;
}

# Return the right-most path component, and it's prefix
# Note: this helper routine not only provides some common re-usable code, but
# also works around a bug in the basename() built-in in perl, which returns
# the wrong path component for XPN paths.
sub path_rsplit
{
   my $p = $_[0];
   my $sep1 = rindex($p, '/');
   my $sep2 = rindex($p, "\\");
   my $sep_max_idx = $sep1 > $sep2 ? $sep1 + 1 : $sep2 + 1;
   my $lhs = substr($p, 0, $sep_max_idx);
   my $rhs = substr($p, $sep_max_idx);
   return ($lhs, $rhs);
}

1;
