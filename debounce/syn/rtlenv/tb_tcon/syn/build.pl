##################################################################
# Copyright (c) 2018, Schweitzer Engineering Laboratories, Inc.
# SEL Confidential
# This file is used by the build_rtl.pl script
##################################################################

$VARS =
{
  # Valid values:
  #  FLI  : For use with Modelsim's FLI
  SIM_ARCH => "FLI",
  SHARED_LIB => ""
};

$DOCS =
[
  "$MYDIR../doc/tb_tcon.md",
];

$SOURCES =
[
  do
  {
    my $dll_name = "";
    if ( $VARS->{SHARED_LIB} ne "")
    {
      if ( $VARS->{SIM_ARCH} eq "FLI" )
      {
        if ( $^O =~ /MSWin32|Windows_NT/i )
        {
          $dll_name = $VARS->{SHARED_LIB} . ".dll";
        }
        else
        {
          $dll_name = $VARS->{SHARED_LIB} . ".so";
        }
      }
      else
      {
        die "Unsupported simulation architecture: '$VARS->{SIM_ARCH}'\n";
      }
    }
    else
    {
      die "SHARED_LIB build variable must be specified for tb_tcon.\n";
    }

    # Suck in the template
    open(my $fin, "<", "$MYDIR../src/tcon_template.vhd") || die "Unable to open tcon_template.vhd";
    my @data = <$fin>;
    close($fin);

    # Do the replacement
    map { $_ =~ s/<dll_name>/$dll_name/g } @data;

    # Dump out the result
    open(my $fout, ">", "tb_tcon.vhd") || die "Unable to write to tb_tcon.vhd";
    $fout->print(@data);
    close($fout);

    "tb_tcon.vhd"
  },
];
