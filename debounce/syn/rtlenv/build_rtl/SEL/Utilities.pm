################################################################################
# COPYRIGHT (C) 2015 Schweitzer Engineering Labs, Pullman, Washington
#
# This package contains various utility functions
#
# NOTE: This module must work on Windows, Linux and Solaris
#
################################################################################

package SEL::Utilities;

use strict;
use warnings;
use v5.10;        # Needed for IP and SHA perl packages.
use Cwd;
use Carp;
use Digest::MD5;
use Digest::SHA;
use Fcntl;
use File::Basename;
use File::Copy;
use File::Glob qw(bsd_glob);
use File::Spec;
use MIME::Base64;
use Net::SMTP;

use constant IN_WINDOWS => $^O =~ /MSWin32|Windows_NT|msys/i;
use constant SEL_SMTP_SERVER => 'mail.ad.selinc.com';

use vars qw( @ISA @EXPORT @EXPORT_OK $VERSION );

use Exporter;
$VERSION = 1.4;
@ISA = qw( Exporter );

@EXPORT      = qw( compute_md5sum
                   compute_sha1sum
                   extract_file
                   forward_slashify
                   IN_WINDOWS
                   is_unc_path
                   is_weekday
                   parse_kv_lines
                   Send_email
                   Send_SEL_email
                   trim_whitespace);

@EXPORT_OK   = qw( add_indents_to_lines
                   execute_command
                   extend
                   flatten
                   get_abs_path
                   get_unix_relative_path
                   get_yesno_answer
                   indent_system
                   set_env_var
                   touch_file);              # Symbols to export on request

sub set_env_var {
   my( $key, $val, $indent ) = @_;
   #############################################################################
   # DESCRIPTION:   This function sets the environment variable identified
   #                by the key parameter to the value identified by the
   #                val parameter.
   #
   # USAGE:         set_env_var( 'XILINX', 'W:/tools/compilers/xilinx' );
   #
   # INPUTS:        $key    - Environment variable name.
   #                $val    - Environment variable value
   #                $indent - A string to prepend to each output
   #                          line of this function (optional).
   #
   # OUTPUTS:       Prints the environment variable change
   #############################################################################
   $indent = $indent ? $indent : '';
   if (! exists( $ENV{$key} ))
   {
      print "${indent}Adding Environment Variable, \"$key=$val\"\n${indent}\n";
   }
   elsif( $ENV{$key} ne $val )
   {
      print "${indent}Changing $key environment variable from:\n";
      print "${indent}   \"$ENV{$key}\"\n";
      print "${indent} to \"$val\"\n${indent}\n";
   }
   $ENV{$key} = $val;
}

sub get_abs_path {
   my( $target, $only_dir  ) = @_;
   #############################################################################
   # DESCRIPTION:   This function gets the absolute path to the file or
   #                directory specified by the relative path argument
   #
   # USAGE:         $abs_path = get_abs_path( '../../somefile.exe' );
   #
   # INPUTS:        $target -  A string specifying a relative path to a file.
   #
   #                $only_dir (optional)
   #                   Setting this to a true value will cause only the
   #                   absolute path to the directory to be returned,
   #                   even if the target is a file.
   #
   # RETURNS:       The absolute path to the target parameter using DOS/UNIX slash
   #                convention as appropriate. Directory paths are terminated with a slash.
   #                Zero is returned if target does not exist.
   #############################################################################
   my $dir = cwd();
   my $path;
   my $filename;

   if (-d $target)
   {
      $path = $target;
   }
   else # assume that client sent us a valid filename string
   {
      my ($target_base, $target_dir, $target_ext) = fileparse( $target, '\..*' );
      $filename = $target_base . $target_ext;
      $path = $target_dir;
   }
   chdir( $path ) or return (0);
   $path = cwd() . '/';  # unix convention
   if (IN_WINDOWS) {
      $path =~ s/\//\\/g;   # dos  convention
   }

   if ((! $only_dir) and $filename)
   {
      $path .= $filename;
   }
   chdir( $dir );
   return ($path);
}

sub add_indents_to_lines {
   my( $str, $indent ) = @_;
   #############################################################################
   # DESCRIPTION:   This function allows you to prepend an indentation string
   #                to each line of a multi-line string parameter.
   #
   # USAGE:         $indented_str = add_indents_to_lines( $str, "\t" );
   #
   # INPUTS:        $str    - A string, multiline to make this function useful.
   #                $indent - A string to prepend to each line of the str
   #                          parameter, three spaces is used if this parameter
   #                          is omitted (optional).
   #
   # RETURNS:       The string with indentations prepended
   #############################################################################
   $indent = defined $indent ? $indent : '   ';
   my @lines = split "\n", $str;
   $str =  $indent . join( "\n$indent", @lines ) . "\n";
   return ($str);
}

sub indent_system {
   my( $cmd, $indent ) = @_;
   #############################################################################
   # DESCRIPTION:   This function executes a command string and prints the
   #                indented output.
   #
   # USAGE:         indent_system( 'dir.exe', "#" );
   #
   # INPUTS:        $cmd    - Command string to execute
   #                $indent - String to prepend to three space indentation for
   #                          output printing
   #
   # RETURNS:       prints command execution output to screen
   #############################################################################
   my $indent_prefix = defined $indent ? $indent : q{};

   open SYS, "$cmd 2>&1 |" or croak "ERROR:\tCannot pipe from $cmd: $!";
   my $dir = cwd();;
   print "${indent_prefix}Running the following command (from $dir):\n${indent_prefix} \"$cmd\"\n${indent_prefix}\n";

   $indent_prefix .= '   ';

   while (<SYS>)
   {
      print "${indent_prefix}$_";
   }
   print "${indent_prefix}\n";
   if (! close SYS)
   {
      print "${indent_prefix}   *** ERROR: $!, $?\n";
   }
}

sub extract_file {
   #############################################################################
   # DESCRIPTION:   This function extracts the contents of a file and returns
   #                them in a string.  Program will die if the file cannot be
   #                opened.  By default, contents of the file is returned in
   #                textmode which may rewrite newlines.
   #
   # USAGE:         my $contents = extract_file( "file.txt" );    # text mode
   #                my $contents = extract_file( "file.txt", 1);  # binary mode
   #
   # INPUTS:        $file    - Full path to the desired file
   #                $binmode - Binary mode (optional); any non-empty value
   #
   # RETURNS:       $data - File contents as a scalar string
   #############################################################################
   my ($file, $binmode) = @_;
   local $/ = undef;
   local *SOMEFILE;
   open(SOMEFILE, $file) or Carp::confess("Could not open \"$file\": $!");
   binmode(SOMEFILE) if (defined($binmode) && $binmode);
   my $data = <SOMEFILE>;
   close(SOMEFILE) or Carp::confess("Could not close \"$file\": $!");
   return $data;
}

sub execute_command {
################################################################################
#  DESCRIPTION: Execute a shell command.
#
#  INPUTS:     $command - the command to be executed.
#              $debug   - indication that the command should be printed
################################################################################
   my $command = shift;
   my $debug = shift;

   my $msg = '';         # error message string

   if ($debug) {
      print $command . "\n";
   }
   else {
      my $sys_return = system($command);
      if ($sys_return != 0) {
         if ($sys_return == 0xff00) {
            $msg = "ERROR:\tCommand failed - error is $! from command:\n$command\n";
            croak $msg;
         }
         elsif (($sys_return & 0xff) == 0) {
            $sys_return >>= 8;
            $msg = "ERROR:\tNon-zero exit status $sys_return from command:\n$command\n";
            croak $msg;
         }
         else {
            $msg = "ERROR:\tRan with ";
            if (($sys_return & 0x80) != 0) {
               $sys_return &= ~0x80;
               $msg .= "core dump from ";
            }
            $msg .= "signal $sys_return from command:\n$command";
            croak $msg;
         } # signal
      } # non error return
   } # run command, don't just print it
}

sub compute_md5sum {
################################################################################
# DESCRIPTION:   Calculate the md5 checksum of a given file.
#
# INPUTS:        $file - Pathname to a file.
#
# RETURNS:       md5sum of the file, a 32-character alpha-numeric string.
################################################################################
   my ($file) = @_;
   my $retval = q{};

   if (-s $file) {   # If the file size is nonzero, then proceed
      my $o_retval = sysopen(FHANDLE, $file, O_RDONLY);
      if (!$o_retval) {
          Carp::confess("Failed to open \"$file\": $!");
      }
      else {
          binmode(FHANDLE);
          $retval = Digest::MD5->new->addfile(*FHANDLE)->hexdigest;
          close(FHANDLE) || Carp::confess("Could not close \"$file\": $!");;
      }
   }
   return $retval;
}

sub compute_sha1sum {
################################################################################
# DESCRIPTION: Calculate the SHA-1 checksum of a given file.
#
# INPUTS:      $file - Pathname to a file.
#
# OUTPUTS:     SHA-1 sum of the file, a 40-character alpha-numeric string.
################################################################################
   my ($file) = @_;
   my $retval = q{};

   if (-s $file) {   # If the file size is nonzero, then proceed
      my $o_retval = sysopen(FHANDLE, $file, O_RDONLY);
      if (!$o_retval) {
          Carp::confess("Failed to open \"$file\": $!");
      }
      else {
          binmode(FHANDLE);
          $retval = Digest::SHA->new("SHA-1")->addfile(*FHANDLE)->hexdigest;
          close(FHANDLE) || Carp::confess("Could not close \"$file\": $!");;
      }
   }
   return $retval;
}

################################################################################
# DESCRIPTION: Send_SEL_email() - Send e-mail from one email address to one (or more)
#              addresses and include optional attachments.  Uses only CORE perl
#              modules (Net::SMTP and MIME-Base64).
#
# INPUTS: $from         - E-mail address of the sender
#         $to           - E-mail address(es) to send to
#         $subject      - Subject of the e-mail
#         $body         - Message of the e-mail
#         $attachments  - Filename or array reference to multiple filenames
#                         of file(s) to attach (optional).
#         $cc           - E-mail address(es) to CC: the email to
#
# NOTES: Send_SEL_email() does not check for valid email addresses.
#        If an attachment file specification doesn't exist it will WARN and continue.
#        Email will be sent even with invalid addresses or missing attachments.
################################################################################
sub Send_SEL_email {
   my ($from, $to, $subject, $body, $attachments, $cc) = @_;

   my $mult_to_recips = ref($to) eq 'ARRAY' ? 1 : 0;  # Are there multiple to: recipients?
   my $mult_cc_recips = (defined($cc) && ref($cc) eq 'ARRAY') ? 1 : 0;  # Are there multiple cc: recipients?
   my $smtp = Net::SMTP->new(SEL_SMTP_SERVER);        # SMTP server

   $smtp->mail($from);                                # Sender's address here
   $smtp->to($mult_to_recips ? @$to : $to, {SkipBad => 1});
   $smtp->cc($mult_cc_recips ? @$cc : $cc, {SkipBad => 1}) if (defined($cc));
   $smtp->data();                                     # Start the mail

   # Send the header.
   my $display_to = 'To: ' . (($mult_to_recips) ? (join(', ', @$to) . "\n") : ("$to\n"));

   $smtp->datasend("Subject: $subject\n");
   $smtp->datasend("From: $from\n");
   $smtp->datasend($display_to);
   if (defined($cc))
   {
      my $display_cc = 'Cc: ' . (($mult_cc_recips) ? (join(', ', @$cc) . "\n") : ("$cc\n"));
      $smtp->datasend($display_cc);
   }

   # MIME boundary format is very picky.  Exact newlines required.
   $smtp->datasend("MIME-Version: 1.0\n");
   my $boundary = "====" . time() . "====";
   $smtp->datasend("Content-Type: multipart/mixed; boundary=\"$boundary\"\n");
   $boundary = '--' . $boundary;
   $smtp->datasend("\n");
   $smtp->datasend($boundary);
   $smtp->datasend("\n");
   $smtp->datasend("Content-Type: text/plain\n\n");

   # If in GSD environment we don't pass the information or attachments in the email.
   #   GSD ips -> 10.90. or 10.96, or host domain has selgs.sel in it.
   require Sys::Hostname;
   require Socket;
   my $host = Sys::Hostname::hostname();
   my $address_ipv4 = Socket::inet_ntoa(scalar gethostbyname($host));
   my $inGSD = 0;    # Default to not in GSD.
   if (($address_ipv4 =~ m/^10\.9[0|6]\./))
   {
      $inGSD = 1;    # Okay this is in GSD.
      $body = "Please log into a GSD system and review activities or log files on the $host system.\n";
   }

   # Send the body.
   $smtp->datasend("$body\n");

   # Add attachements if there are any
   if (defined($attachments) && $attachments)
   {
      my $contents;
      my $shortname;
      my $attachedref;

      # If array reference with multiple files to attach.
      if (ref($attachments))
      {
         $attachedref = $attachments;
      }
      else
      {
         # A single file, make it the only element in an array.
         push @$attachedref, $attachments;
      }

      # Attach each file encoded in Base64.
      foreach my $afile (@$attachedref)
      {
         # If the file has something in it, then we'll attach it.
         if (-s $afile)
         {
            # If in GSD environment just add paths to the attachments and not the attachments themselves.
            if ($inGSD == 1)
            {
               # Send file location.
               $smtp->datasend("Reference file on $host at: $afile\n");
            }
            else
            {
               $smtp->datasend("\n");
               $smtp->datasend($boundary);
               $smtp->datasend("\n");

               # Open the file and encode its contents.
               if (open(ATTACHED, $afile))
               {
                  # Get the contents of the file
                  binmode ATTACHED;
                  {
                     local $/;
                     $contents = MIME::Base64::encode_base64(<ATTACHED>);
                  }
                  close(ATTACHED);

                  $shortname = basename($afile);
                  $smtp->datasend("Content-Type: application/octet-stream; name=\"$afile\"\n");
                  $smtp->datasend("Content-Transfer-Encoding: base64\n");
                  $smtp->datasend("Content-Disposition: attachment; filename=\"$shortname\"\n");
                  $smtp->datasend($contents);
               }
               else
               {
                  # Couldn't open it.  Not attached.
                  my $errmsg = "WARNING\tCould not attach \"$afile\": $!";

                  # Add it to the email.
                  $smtp->datasend("Content-Type: text/plain\n");
                  $smtp->datasend("\n");
                  $smtp->datasend("\n");
                  $smtp->datasend("$errmsg\n");

                  # Also warn the local execution user.
                  Carp::carp($errmsg);
               }
            }
         }
      }
   }
   $smtp->datasend("\n");
   $smtp->datasend("$boundary--\n");         # End boundary
   $smtp->dataend();                         # Finish sending the mail
   $smtp->quit;                              # Close the SMTP connection
}

################################################################################
# NOTES: Skeleton function preserved for backards compatibility.
################################################################################
sub Send_email {
   my ($from, $to, $subject, $body, $attachments) = @_;
   Send_SEL_email($from, $to, $subject, $body, $attachments);
}

################################################################################
# DESCRIPTION: Change backslashes to forward slashes.
#
# INPUTS:      $_[0] The path to be changed from windows to Unix slashes
################################################################################
sub forward_slashify {
   my $retval = $_[0];
   $retval =~ tr/\\/\//;
   return $retval;
}

################################################################################
# DESCRIPTION:  Convert a 'from' and a 'to' directory path to a UNIX style
#               relative directory path from 'from' to 'to'.  All elements of
#               the path are assumed to be directories, forward and back
#               slashes are equivalent, and drive letters are stripped.
#
# INPUTS: $path_from  - 'from' directory path
#         $path_to    - 'to' directory path
#
# USAGE: get_unix_relative_path('c:\joe', 'g:\bill/sue') returns '../bill/sue'
#
################################################################################
sub get_unix_relative_path
{
   my ($path_from, $path_to) = @_;

   my $retval;

   # Convert the paths to absolute so that abs2rel will work
   my $abs_path_from = File::Spec->canonpath ($path_from);
   my $abs_path_to = File::Spec->canonpath ($path_to);

   # Get rid of drive letters
   $abs_path_to =~ s/^ *[a-zA-Z]://;
   $abs_path_from =~ s/^ *[a-zA-Z]://;

   # convert to UNIX relative path
   $retval = forward_slashify(File::Spec->abs2rel($abs_path_to, $abs_path_from));
   return $retval;
}

################################################################################
# DESCRIPTION:  Print a message until the user types a word beginning
#               with 'y' or 'n'.  Obviously the question will not get
#               to the user if STDOUT is redirected.
#
# INPUTS: $message - The message to be printed
################################################################################
sub get_yesno_answer
{
   my ($question) = @_;

   my $retval;
   my $yes_no;
   my $new_question = "$question (y\/n)?  ";

   print "$question?  ";
   $yes_no = <STDIN>;
   while (!defined $yes_no || (!($yes_no =~ m/^[yYnN]\n/)))
   {
      print $new_question;
      $yes_no = <STDIN>;
   }

   if ($yes_no =~ m/^[Yy]/)
   {
      $retval = 1;
   }
   else
   {
      $retval = 0;
   }

   return $retval;
}

sub is_unc_path
{
   my $retval = 0;
   my $fpath_in = shift;
   (my $fpath = $fpath_in) =~ tr/\\/\//;
   (my $front_four = substr($fpath, 0, 4)) =~ tr/\\/\//;
   my $front_two   = substr($front_four, 0, 2);
   # In Windows, '\\.\' can be used as a prefix to use paths longer than 259
   # characters (which is not a UNC path) so those paths aren't invalid.
   if ($fpath_in && $front_four ne '//./')
   {
      $retval = 1 if ($front_two eq '//'); # UNC prefix?
   }
   return $retval;
}

# is_weekday() takes input from what is returned by localtime()
sub is_weekday
{
   my $retval = 0;
   my @tval = @_;
   if ($tval[6] >= 1 && # Monday or later
       $tval[6] <= 5)   # Friday or earlier
   {
      $retval = 1;
   }
   return $retval;
}

sub trim_whitespace
{
   my $retval = $_[0];
   $retval =~ s/^\s+//; # Strip leading whitespace, if any
   $retval =~ s/\s+$//; # Strip trailing whitespace, if any
   return $retval;
}

sub touch_file {
   my( $file, $indent ) = @_;
   #############################################################################
   # DESCRIPTION:   This function touches the target file or directory. If
   #                a directory is passed all files within are recursively
   #                touched. This is useful for inserting files into
   #                configuration records during audited builds that would
   #                otherwise not be included. Examples include Specs,
   #                Tests, etc...
   #
   # USAGE:         touch_file( 'spec.doc' );
   #
   # INPUTS:        $file   - A file or directory path and/or name of file to be
   #                          touched.
   #                $indent - A string to prefix all output messages (optional)
   #
   # RETURNS:       0 if object was touched
   #############################################################################
   $indent = $indent ? $indent : '';

   my $target = get_abs_path( $file );

   if (-d $target)
   {
      print "${indent}Directory: $target\n";
      my @targets = bsd_glob( $target . '*' );
      foreach( @targets )
      {
         touch_file( $_, $indent . '  ' );
      }
   }
   elsif (-f $target)
   {
      print "${indent}File: $target\n";
      # Open and close the file ... so clearaudit will pick it up.
      open(TEMPFILE, "< $target") or warn( "Can not open $target for touching" );
      my $junk = getc TEMPFILE;
      close(TEMPFILE);

   }
   else
   {
      print "${indent}Error: \"$file\" does not exist\n";
      return (-1);
   }
   return (0);
}

# Utility routine from Perl Cookbook, Chapter 2 ("Numbers")
sub dec2bin {
   return unpack('B32', pack('N', shift)); # 'N' -> network order aka "Big Endian"
}

# Flatten a nested array
sub flatten {
   return map { ref $_ ? flatten(@{$_}) : $_ } @_;
}

# Extend an array with $val if $elem is an array, otherwise return new array
# containing [$elem, $val];
sub extend {
   return ref($_[0]) ? ((push @{$_[0]}, $_[1]), $_[0]) : [$_[0], $_[1]];
}

################################################################################
# DESCRIPTION: Parse <key> = <value> pairs in line separated text
#
# INPUTS:  $encby  - Whether the value is enclosed by a char -- such as ' or "
#          $delim  - Delimiter separating the key and value ('=' default)
#          $nvtrim - Should whitespace in the value should be removed? (default true)
#          $cmtp   - Comment prefix ('#' default) to be ignored
#
# USAGE:   my $kv = parse_kv_lines($lines);
#          my $kv = parse_kv_lines($lines, '"');
#
# RETURNS: $kvs    - hash of key/value pairs, for every unique key encountered.
################################################################################
sub parse_kv_lines {
   my ($txt, $encby, $delim, $nvtrim, $cmtp) = @_;
   my %kvs = ();                                    # Return hash of k/v pairs
   $encby  = ''  if (!defined($encby));
   $nvtrim = ''  if (!defined($nvtrim));
   $delim  = '=' if (!defined($delim) || !$delim);  # Default to '=' separator
   $cmtp   = '#' if (!defined($cmtp)  || !$cmtp);
   my @lines = grep /$delim/, split/[\r\n]+/, $txt; # Get delim lines (e.g. '=')
   for my $line (@lines)
   {
      my $cmt_idx  = index($line, $cmtp);           # Is there comment data?
      my $l        = $cmt_idx == -1 ? $line : substr($line, 0, $cmt_idx);
      next if (!$l || $cmt_idx == 0);   # Skip comment-only lines
      my $didx     = index($l, $delim);
      my $lidx     = $encby ? index($l, $encby)  + 1 : $didx + 1;
      my $ridx     = $encby ? rindex($l, $encby) - 1 : length($l) - 1;
      my $name     = trim_whitespace(substr($l,0,$didx));
      my $val      = substr($l, $lidx, $ridx - $lidx + 1);
      $val         = trim_whitespace($val) if (!$nvtrim);
      $kvs{$name}  = $kvs{$name} ? extend($kvs{$name},$val) : $val;
   }
   return \%kvs;
}

1;
