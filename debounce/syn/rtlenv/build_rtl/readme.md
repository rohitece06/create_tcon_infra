<a name=toc-introduction></a>
# Introduction
This document describes the purpose and use of the build_rtl.pl build
script, and how to write a build file.

GIT is the controlling repository for build_rtl.  The latest version of this 
document can always be found at:

https://bitbucket.metro.ad.selinc.com/projects/CCRTLTOOLS/repos/build_rtl/

<a name=toc-table-of-contents></a>
## Table of Contents
 - [Introduction](#toc-introduction)
   * [Table of Contents](#toc-table-of-contents)
 - [build_rtl Installation](#toc-build_rtl-installation)
   * [Installation of build_rtl](#toc-installation-of-build_rtl)
   * [Running build_rtl](#toc-running-build_rtl)
 - [General Input File Syntax](#toc-general-input-file-syntax)
   * [Lexical Conventions](#toc-lexical-conventions)
   * [String literals](#toc-string-literals)
   * [Initializing Arrays](#toc-initializing-arrays)
   * [Initializing Hashes](#toc-initializing-hashes)
 - [Build Files](#toc-build-files)
   * [VARS Contents](#toc-vars-contents)
   * [TEMPDIRS Contents](#toc-tempdirs-contents)
   * [DOCS Contents](#toc-docs-contents)
   * [PRECOMMANDS and COMMANDS Contents](#toc-precommands-and-commands-contents)
   * [SOURCES Contents](#toc-sources-contents)
   * [COMPONENTS Contents](#toc-components-contents)
   * [TEMPFILES Contents](#toc-tempfiles-contents)
 - [Notes about build files](#toc-notes-about-build-files)
 - [Appendix A - Example Build File](#toc-appendix-a-example-build-file)

<a name=toc-build_rtl-installation></a>
# build_rtl Installation

Because this tool uses Perl, you must first verify that you have Perl
available on your machine. Follow the recommendations on the SWTools
WIKI to obtain the latest release of SEL Perl:

https://confluence.metro.ad.selinc.com/display/PERL/Perl+Home

<a name=toc-installation-of-build_rtl></a>
## Installation of build_rtl

For GIT users you must clone down the build_rtl.pl script from
Bitbucket. Build_rtl.pl supports a flat folder structure where all GIT
repositories are cloned into the same base folder (i.e. `c:\git\tools,
c:\git\tb_comp1, c:\git\uut1, etc`). You can also choose to
reproduce the Clearcase vob/folder structure with your GIT repositories,
however, doing so will require that you override the
`$directory_structure` flag in you top level build.pl file (see [Running
build_rtl.pl](#toc-running-build_rtl) and [Appendix A](#toc-appendix-a-example-build-file)
for more information). 

Alternatively, build_rtl.pl supports the directory structure managed by
RTLenv (dependencies placed in syn\\rtlenv). RTLenv’s managed dependency
directory is automatically detected and used if present.

For Clearcase users build_rtl.pl is already installed in ClearCase in
the \\tools VOB. To utilize the build_rtl.pl, a line may need to be
added to the ClearCase "config spec." The following line will ensure
that the correct libraries are used:

`element /tools/bin/... .../main/LATEST`

or

`element /tools/... .../main/LATEST`

<a name=toc-running-build_rtl></a>
## Running build_rtl

You can run build_rtl from either UNIX or a DOS prompt with the
following command:

`perl /tools/bin/build_rtl.pl <target directory> <options>`

Where

`<target directory>` is the component's top level directory, usually contains 
at least the syn, src and doc directories.

`<options>` is one or more of the following:

- `-h` Usage information will be displayed.

- `-64` Use this flag to specify 64-bit tools in ClearCase.

- `-LIBERO_SOC` Use this flag to specify Microsemi’s Libero SoC instead of
Libero IDE.

- `-nocc` Allows build_rtl.pl to run on systems that do not have dynamic
  ClearCase. **Notes:**
  * Since cleaning is dependent on ClearCase, the -nocc flag also has the
  effect of implementing the -noclean flag. If -nocc is used for release
  builds, ensure that a "clean" transpires before build_rtl.pl is
  invoked.  
  * Since the -buildid feature is dependent on ClearCase, its use is
  mutually exclusive with the -nocc flag

  * The build script checks for the existence of cleartool and
  automatically forces `-nocc` when it is not found.

- `-noclean` The 'syn' directory of all components will not be cleaned.

- `-buildid [0-4,D,N,X,R]` This parameter will take the build id for the
current build from a file located in the syn directory called
build_id.txt. The build id is as follows major.minor.release.build. `-buildid` 
option must be followed by a number, 0 through 4, X, N, D, or R:
  * `0` do not increment the build number,
  * `1` increments the build number,
  * `2` increments release and zeroes build,
  * `3` increments minor and zeroes release and build,
  * `4` increments major and zeroes the rest
  * `D` increments the build number, sets upper two bits of release to 00 for
    developer build
  * `N` increments the build number, sets upper two bits of release to 01
    for night build
  * `X` increments the build number, sets upper two bits of release to 10
    for X release
  * `R` increments the build number, sets upper two bits of release to 11
    for R release

- `-CONTONERR` Use this flag to instruct build_rtl.pl to NOT halt on error
conditions.

- `-v <name1> <value1> <name2> <value2>` This allows variables from the target 
component to be overridden at the command line with one or more name value pairs. 
This is useful for performing many build permutations without modifying the 
build.pl file every time. This is primarily a development testing feature that 
should not be used for release builds.  The `-v` must be the last comand line 
argument.

**Note:** Build_rtl.pl attempts to automatically determine when the `-nocc` flag
should be specified. If the drive you are executing build_rtl.pl from
does not contain a clearcase config spec the `-nocc` flag is automatically
added and a note is added to the build log.

**Note:** By default, this script cleans all non-version-controlled objects out of
the syn directories of the target component and all child components
when executed from a clearcase drive. Do not use the syn directory as a
repository for non-version controlled objects.

**Note:** In order to use the `–buildid` option you must have a variable in the VARS
section of build.pl called BUILDID that is an 8 digit hex number. Also
required is a text file in the syn directory called build_id.txt. This
file must contain a build id of the format d.d.d.d where d is a decimal
between 0 and 255. This file must be checked in to clearcase or it will
be deleted by the build process. As builds are made the newest build id
is appended to the bottom of the file with the date and time of the
build. For automatically incrementing options of D, N, X, and R rollover
conditions of the 4<sup>th</sup> digit are automatically handled such
that the 3<sup>rd</sup> digit will increment on a rollover. This
effectively creates a 2-bit field for build type and a 14-bit field for
build number. Rollover of the 14-bit field (which is extremely unlikely
to happen) will be handled by making the 14-bit field roll over to zero.

### Internal Flags:
As an alternative to command line paramemters you may override the following 
internal flags in your top level build.pl file with this syntax

`our $flag_name = value;`

The following flags have been defined:
 - `$clearcase_flag` default=1, set to 0 with `-nocc`
 - `$clean_flag` default=1, set to 0 with `-nocc` or `-noclean`
 - `$halt_on_error_flag` default=1, set to 0 with `-CONTONERR`
 - `$directory_structure` default=clearcase, set to flat with `-nocc` or `-flat`
 - `$sixty_four_bit_flag` default=0, set to 1 with `-64`
 - `$libero_soc_flag` default=0, set to 1 with `-LIBERO_SOC`

**Note:** This override method has priority over command line flags

<a name=toc-general-input-file-syntax></a>
# General Input File Syntax

The input file to build_rtl is written in Perl. For this reason, the
entire file must follow Perl's syntax. What follows is a very brief
introduction to those parts of the Perl syntax that are universally
applicable to the input file.

<a name=toc-lexical-conventions></a>
## Lexical Conventions

A **build** consists of one or more **input units** that are stored in
**files**, which should be loosely organized as a general tree (in
reality the files could be organized as a graph, complete with cycles,
but the build would probably not terminate). Within each input unit, an
optional COMPONENTS section lists the branches from that part of the
tree. The tree of files is processed in depth-first search order. Within
the input unit, the input is free form - white space between lexical
items doesn't matter. All statements end in a '**;'** (semicolon), like
C.

**Comments** begin with **#** (pound sign). Everything after the #,
and up to the end of the line is ignored.

**Identifiers** are composed of upper or lower case letters, numbers,
and the underscore '_'. They cannot start with a number. Identifiers
are case sensitive (like all of Perl).

<a name=toc-string-literals></a>
## String literals

A variable that holds a single value (either numeric or a character
string) is called a **scalar**. Scalars are accessed by prefixing an
identifier with '$'. Scalars are assigned to using '=' as in
<scalar> = <expression>;

**Example:**
```
$Stuff = 5;
$Thingy = "my thing";
```

There are several ways of quoting **strings** in Perl, corresponding to
the three quote characters on the keyboard. If a string is quoted with '
(an apostrophe) the text is interpreted literally - no variable
expansion takes place. To include an apostrophe in the string, you must
escape it with a backslash `\`.

**Example:**
```
$word = 'don\'t'; #word gets the string don't
$myWord = 'the$word'; #my word gets the string the$word
```

If a string is quoted with " (double quotes) any variable between the
pair of quotes is interpolated unless the $ is preceded by a backslash
'\\' character – that is, it gets replaced with a string representing
its contents. To include double quote in the string, you must escape it
with a backslash `\`.

**Examples:**
```
$Thingy = "my thing";
$Stuff = "This is $Thingy"; #Stuff gets This is my thing
$Stuff = "This is \$Thingy"; #Stuff gets This is $Thingy
```

If a string is quoted with \` (back tick) the text inside the back ticks
is executed as a separate process, and the standard output of the
command is returned as the value of the string. Back ticks perform
variable interpolation, and to include a back tick in the string, you
must escape it with a backslash `\`.

**Example:**

```$dir = `ls`; #the dir variable gets the results of the ls command```

<a name=toc-initializing-arrays></a>
## Initializing Arrays

An array is a named list, and a list is an ordered collection of
scalars. Space for lists are dynamically allocated and removed from the
program's memory. In build_rtl, lists are constructed by putting a set
of scalar values in order between parentheses.

**Example:**

`@things = ["my thing","your thing","his thing","her thing"];`

The values within an array in build_rtl are used by build_rtl, but
would not normally be referred to by the users. For this reason,
accessing the contents of an array will not be discussed.

<a name=toc-initializing-hashes></a>
## Initializing Hashes

A hash is an associative array, which means that the array is indexed
using arbitrary string values. Elements of an associative array are
referred to as "key" and "value" pairs - the "key" is used to find the
element of the array that has the "value". In build_rtl, lists are
constructed by putting a set of scalar values in order between braces,
and using the => operator between the key and the value pairs.

**Example:**
```
$MYDIR = '.'; #build_rtl managed variable included here for easy of understanding 

$MY_HASH =
{
  # KEY => "QUOTED VALUE",
  KEY_1 => "key_1_value",                 #Example of a normal
                                          #string
  ANOTHER_KEY => "$MYDIR\\another_temp"   #Example of a string
                                          #with substitution
};
```

To get a value from the hash, use the arrow operator and braces to refer
to the key as in:

`<hash> -> {<key>}`

**Examples:**

Continuing with the above example we have
```
$MY_HASH -> {KEY_1}       # key_1_value
$MY_HASH -> {ANOTHER_KEY} # .\another_temp
```
In addition to the standard perl syntax, build_rtl also incorporates
the perl POSIX module. Some care should be taken in using syntax from
this module since its contents are somewhat operating system dependent.
Using operating system dependent constructs will make your build file
less portable.

<a name=toc-build-files></a>
# Build Files

The build files are comprised of a series of array and hash variables,
known to build_rtl, that are populated with values that the build_rtl
program can use to perform a build. Not all of the variables need to be
populated for every type of build. For example, small components may
only require use of the SOURCES variable.

The variables should be in the order defined in the table below, and the
VARS variable must be lexically before any of the other variables. The
table below summarizes the variables that are used, and their purpose:

<table>
  <thead>
    <tr class="header">
      <th><strong>Variable</strong></th>
      <th><strong>Purpose</strong></th>
    </tr>
  </thead>
  <tbody>
    <tr class="odd">
      <td>MYDIR</td>
      <td>When defining paths relative to where this build file lives, precede 
          the path with the "$MYDIR" variable which qualifies the home 
          of this file. This is important since this file could be built by a 
          parent project in a completely different working directory. The MYDIR 
          variable is available for use, but the user cannot set it.</td>
    </tr>
    <tr class="even">
      <td>VARS</td>
      <td>This structure is populated with defined strings that you want to use 
          within your build. All variables used within the script must be 
          declared in VARS.</td>
    </tr>
    <tr class="odd">
      <td>TEMPDIRS</td>
      <td>This variable is used to define any temporary directories that may be 
          required by the build.</td>
    </tr>
    <tr class="even">
      <td>COMPONENTS</td>
      <td>The COMPONENTS variable contains a list of paths to other build files 
          that are to be built. The build files in the COMPONENTS variable will 
          be built before the current file.</td>
    </tr>
    <tr class="odd">
      <td>PRECOMMANDS</td>
      <td>The PRECOMMANDS variable contains a list of commands, which will be 
          executed in order. These are executed after all COMPONENTS have been 
          built.</td>
    </tr>
    <tr class="even">
      <td>SOURCES</td>
      <td>The SOURCES variable contains a list of source units that are to be 
          acted on by the instructions in the TEMPFILES, or parent. The SOURCES 
          list is evaluated and constructed after PRECOMMANDS execute.</td>
    </tr>
    <tr class="odd">
      <td>TEMPFILES</td>
      <td>The TEMPFILES variable contains a list of file names, and the file 
          contents that the build is to create as part of its process. The 
          temporary files are created after SOURCES are evaluated.</td>
    </tr>
    <tr class="even">
      <td>DOCS</td>
      <td>The DOCS variable of the build file is used to manually include these 
          files in a configuration record. The DOCS list is evaluated after 
          temporary files are created.</td>
    </tr>
    <tr class="odd">
      <td>COMMANDS</td>
      <td>The commands variable contains a list of commands, which will be 
          executed in order. The COMMANDS list is executed after the DOCS list 
          is evaluated.</td>
    </tr>
  </tbody>
</table>

The paragraphs that follow contain detailed descriptions of how these
variables are to be initialized in the build file.

<a name=toc-vars-contents></a>
## VARS Contents

The purpose of the VARS variable is to define strings that are either
used frequently within the build file, or to create a section of code
for values that change frequently. The hash key is used to select the
value with the following syntax:

The VARS contents are defined within a Perl hash so that the syntax must
correspond with the initialization of a Perl hash. The following is an
example of a valid VARS section:

```
$VARS =
{
  # KEY => "QUOTED VALUE",
  PROJECT => "top_meter",
  OUTPUT => "$MYDIR\\..\\..\\..\\include\\top_meter.hex"
};
```

**Note:** In the above example, $VARS->{PROJECT} will translate to
"top_meter", and $VARS->{OUTPUT} will translate to
".\\..\\..\\..\\include\\top_meter.hex".

<a name=toc-tempdirs-contents></a>
## TEMPDIRS Contents

This variable is used to define any temporary directories that may be
required by the build. The build script prior to executing anything in
the COMMANDS section will create each of the directories listed in this
section. If the directory paths given in the right side of the hash are
not qualified with the $MYDIR variable, the directory will be created in
an arbitrary working directory defined by the parent project. If this is
built as a top-level project, the directories will be created in this
directory. The script will terminate if it is not possible to create one
of these directories.

The TEMPDIRS contents are defined within a Perl hash so that the syntax
must correspond with the initialization of a Perl hash. The following is
an example of a valid TEMPDIRS section:

```
$MYDIR = "."; #build_rtl managed variable included here for easy of understanding

$TEMPDIRS =
{
  # KEY => "QUOTED VALUE",
  TRANSLATE_TEMP => "translate_temp",     #Example of a normal
                                          #string
  ANOTHER_TEMP => "$MYDIR\\another_temp", #Example of a string
                                          #with substitution
  YAT => '$MYDIR\\another_temp'           #Example of a string
                                          #without substitution
};
```

In the above example, TRANSLATE_TEMP will create a directory
"translate_temp", ANOTHER_TEMP will create a directory
".\\another_temp" and YAT will create a directory
"$MYDIR\\another_temp" regardless of the contents of $MYDIR.

To access that directory within the build file you should use the same
syntax as for VARS, but using TEMPDIRS, so that the TRANSLATE_TEMP
directory would be accessed via the following syntax:
```
$TEMPDIRS->{TRANSLATE_TEMP}
```

<a name=toc-docs-contents></a>
## DOCS Contents

SEL uses configuration records in ClearCase to determine the set of
files that are a part of a particular release. For files that are either
the input or the output of a build, the configuration record is
automatically updated by the functions within ClearCase. It is often the
case that other files such as documentation should be included within a
release, but because they are not a part of the build it is not taken
care of automatically. The DOCS variable of the build file is used to
manually include these files in a configuration record.

Within the DOCS section, you may specify either a directory or a file.
If you specify a directory, all files and directories within it will be
recursively added to the configuration record.

The DOCS contents are defined within a Perl array so that the syntax
must correspond with the initialization of a Perl array. The following
is an example of a valid DOCS section:

```
$DOCS =
[
  "$MYDIR\\..\\doc",
];
```

<a name=toc-precommands-and-commands-contents></a>
## PRECOMMANDS and COMMANDS Contents

The precommands and commands variables contains a list of commands,
which will be executed in order. If any given command fails, the
following command(s) will still execute if and only if the CONTONERR
flag was specified. This is the result of a compromise in favor of
having a more legible output log, so you should review the log to see
what actually transpired. This is a great place to utilize defined
variables

The PRECOMMANDS/COMMANDS contents are defined within a Perl array so
that the syntax must correspond with the initialization of a Perl array.
The following is an example of a valid COMMANDS section:

```
$COMMANDS =
[
  # Synthesis
  "$MYDIR\\..\\..\\..\\..\\compilers
  \\Synplify_75\\bin\\" .
  
  "synplify $VARS->{SYNPLICITY_FILE} -tcl
  $VARS->{SYNPLICITY_TCL}",
  "echo After Synthesis with Synplicity is complete, Press Any" .
  " Key to Continue!",
  "pause",
  
  # Print out the synthesis report
  "type $VARS->{PROJECT}.srr"
];
```

<a name=toc-sources-contents></a>
## SOURCES Contents

The SOURCES variable contains a list of source units that are to be
acted on by the instructions in the COMMANDS variable or TEMPFILES or
parent. There is no need to define sources specific to components since
the component projects define their own sources and pass the information
to the parent. The sources structure inherits the sources of any
components that it includes.

The SOURCES contents are defined within a Perl array so that the syntax
must correspond with the initialization of a Perl array. The following
is an example of a valid SOURCES section:

```
$SOURCES =
[
  # Project Package(s):
  "$MYDIR\\..\\src\\top_meter_pkg.vhd",
  # Project Source(s):
  "$MYDIR\\..\\src\\top_meter.vhd",
];
```

It is important to note that the source units in SOURCES will be
processed in the order that they appear within the SOURCES section. This
is important because when synthesizing code, Synplify requires a
specific synthesis order. All sub entities of a particular component
must appear before a calling entity in the compilation batch file. For
example, top_meter_pkg.vhd is a dependency of top_meter.vhd. For this
reason, top_meter_pkg.vhd must be listed before top_meter.vhd.
Similarly, individual components containing build.pl scripts must ensure
that their build.pl files define SOURCES in the proper order. For
example, if component A needs to make use of the log() function defined
in the math_func.vhd package, then the build.pl file for component A
must have the math_func.vhd file in SOURCES ahead of A.vhd.

<a name=toc-components-contents></a>
## COMPONENTS Contents

The COMPONENTS variable contains a list of paths to other build files
that are to be built. The build files in the COMPONENTS variable will be
built before the current file. You can pass parameters to components by
following the path with a semicolon. Following the semicolon, use comma-
delimited key/value pairs to define parameters. These parameters will
overwrite or be added to the "VARS" variable hash of the component
project. This is a great way to change parameters of dynamically created
vendor intellectual property cores!

The COMPONENTS contents are defined within a Perl array so that the
syntax must correspond with the initialization of a Perl array. The
following is an example of a valid COMPONENTS section:
```
$COMPONENTS =
[
  # Project Specific Component(s):
  "$MYDIR\\..\\..\\data_acq",
  
  # Common Component(s):
  "$MYDIR\\components\\rtl\\coldfire_async_if",
  "$MYDIR\\components\\rtl\\decoder_2815",
  
  "$MYDIR\\rtl\\uart ; RX_FIFO_DEPTH=>32,
  TX_FIFO_DEPTH=>128",
];
```

<a name=toc-tempfiles-contents></a>
## TEMPFILES Contents
The TEMPFILES variable contains a list of file names, and the file
contents that the build is to create as part of its process. Dynamically
generated temp files are defined in the TEMPFILES array reference of
hashes, with each hash representing one temp file. A separate hash
defines each file with two key/value pairs, with the array containing
the entire set of defined files. The first key in the hash, NAME,
defines the name and path of where the temp file is to be generated. You
define the text to include in a value associated with the TEXT key. This
is also a great place to utilize project variables.

Usually one of these files needs to contain a list of component sources.
This is accomplished by using the following syntax:

`<<< <some_prefix> SOURCES <some_postfix> >>>`

For example, assume a component has two source files called source1.vhd
and source2.vhd. The use of the tag detailed above would yield the
following listing in you text file:

``` 
<some_prefix> source1.vhd <some_postfix>
<some_prefix> source2.vhd <some_postfix>
```

The TEMPFILES contents are defined within a Perl hash so that the syntax
must correspond with the initialization of a Perl hash. The following is
an example of a valid TEMPFILES section:
```
$TEMPFILES =
[
  {
    NAME => $VARS->{SYNPLICITY_TCL},
    TEXT => "project -run",
  },
  {
    NAME => $VARS->{SYNPLICITY_FILE},
    TEXT => "#
             ##-- Synplicity, Inc.
             ##-- Synplify version 7.3
             ##-- Project file top_meter.prj.
             ##-- Generated using ISE.
             #implementation: top_meter
             impl -add \"top_meter\"
             <<<add_file {SOURCES}>>>
            ",
  }
];
```

<a name=toc-notes-about-build-files></a>
# Notes about build files
-   Build files are to be called "build.pl" and are to be placed in the
    syn directory of component projects
-   **Build files must be checked in under version control as the "syn"
    directory is purged of all non-version controlled objects as part of
    the cleaning process in clearcase**
-   The build files are syntactically correct Perl files. Perl
    references may be informative if more information about build file
    data structures is desired.
-   The build files expect that .\\reports\\build_rtl.log is a
    ClearCase element in the VOB to be built, and they will check out
    that file and write a new version of it each time the script is run
    when executed from a ClearCase drive.
-   The script changes registry values for the Xilinx compiler. Every
    attempt is made to change the registry values back to their original
    version automatically, but the script creates a "reg_restore.pl"
    script in the directory that the script was run from that you might
    run manually to revert your registry to the previous version if
    those attempts fail.
-   All paths should use the Linux convention of forward slashes.
    Windows operating systems accept either forward slashes or
    backslashes so using forward slashes maximizes our compatibility. If
    backslashes are used they must be escaped (i.e. double backslash
    “\\\\”).
-   ALWAYS use relative paths to ensure that the build system is not
    dependent on ClearCase views, drive mappings, etc.
-   When defining paths relative to where this build file lives, precede
    the path with the "$MYDIR" variable which qualifies the home of this
    file. This is important since this file could be built by a parent
    project in a completely different working directory.

<a name=toc-appendix-a-example-build-file></a>
# Appendix A - Example Build File
```
####################################################################
# Copyright (c) 2018 Schweitzer Engineering Laboratories, Inc.
# SEL Confidential
#
# This file is used by the build_rtl.pl script
#
# Anything following a pound sign (#) on a line is a comment
#
# Since backslashes are an escape character in Perl, which
# interprets this file, the backslash itself must be escaped.
# You can do so by using a double slash convention,
# such as "\\" within path defines
#
# ALWAYS use relative paths to ensure that the build system
# is not dependent on ClearCase views, drive mappings, so
# on and so forth
#
# When defining paths relative to where this build file lives,
# precede the path with the "$MYDIR" variable which qualifies
# the home of this file. This is important since this file
# could be built by a parent project in a completely different
# working directory.
#
# Internal flags may optionally be forced in the top level build.pl
# file. The following example shows how to force a Git
# installation to use the clearcase folder structure.
our $clearcase_flag = 0;
our $directory_structure = “clearcase”;

# Populate the following data structure with variables that you
# may need to use more than once or need to modify frequently.
# You can then use them elsewhere with the
#   $VARS->{KEY}
# convention anywhere where would otherwise put the actual text.
# This will ease maintenance of this file.
$VARS =
{
  # KEY => "QUOTED VALUE",
  PROJECT => "top_meter",
  DEVICE => "xc2s100-tq144-5",

  # File included in actual firmware build
  OUTPUT => "$MYDIR/../../../include/top_meter.hex",

  # UCF source file
  UCF_FILE => "$MYDIR/../src/top_meter.ucf",
  
  # Version controlled synplicity constraints file
  SYNPLICITY_CONSTRAINTS => "$MYDIR/../src/top_meter.sdc",
  
  # Names of temp files to be generated:
  SYNPLICITY_FILE => "top_meter.prj",
  SYNPLICITY_TCL => "top_meter_map.tcl",
  BITGEN_FILE => "bitgen.ut",
  IMPACT_FILE => "impact_batch.txt",
};

# Define temporary directories that may be required by your tools
# within the following Perl hash reference:
# Note that the directory paths are not qualified with the $MYDIR
# variable, this means that the directories will be created in
# an arbitrary working directory defined by the parent project.
# If this is built as a top level project, they will be created
# in this directory.

$TEMPDIRS =
{
  # KEY => "QUOTED VALUE",
  TRANSLATE_TEMP => "translate_temp",
};

# If you want to use your directory definition elsewhere in this
# file,
# put $TEMPDIRS->{KEY}, in place of the actual path.
# Documents that should be included in the configuration record
# associated with this build go into the following Perl array
# reference.
# You can specify a directory or a file. If you specify a directory,
# all files and directories within it will be recursively added
# to the configuration record. Use this for Specs, Tests, Design
# Documents, etc

$DOCS =
[
  "$MYDIR/../doc",
];

# Precommands that are to be executed as part of this build go into
# the following array reference. The precommands within will be
# executed in order prior to generating the list of sources. A good
# example of uses for Precommands is to generate vendor IP source.
# This is a great place to utilize defined variables.

$PRECOMMANDS =

[
  # Generate tool IP
  "qsys-generate --simulation=VHDL " .
  " --output-directory=$MYDIR\\..\\syn" .
  " $MYDIR\\..\\src\\dma_engine_avalonmm_irb_bfm.qsys",
];

# Commands that are to be executed as part of this build go into
# the following array reference. The commands within will be
# executed in order.
# This is a great place to utilize defined variables.

$COMMANDS =
[
  # Synthesis
  "$MYDIR/../../../../compilers/synplicity/Synplify_75/bin/" .
  "synplify $VARS->{SYNPLICITY_FILE} -tcl
  $VARS->{SYNPLICITY_TCL}",
  
  # Synplicity doesn't like batch mode use, so it doesn't block
  # this script from execution We can still do it the old fashioned
  # way
  "echo After Synthesis with Synplicity is complete, Press Any" .
  " Key to Continue!",
  "pause",
  
  # Print out the synthesis report
  "type $VARS->{PROJECT}.srr",
  
  # Translate
  "ngdbuild -p $VARS->{DEVICE} -dd $TEMPDIRS->{TRANSLATE_TEMP} -uc
  VARS->{UCF_FILE} $VARS->{PROJECT}.edn $VARS->{PROJECT}.ngd",
  
  # Map
  "map -p $VARS->{DEVICE} -cm speed -pr b -k 4 -c 100 -tx off -o
  VARS->{PROJECT}_map.ncd $VARS->{PROJECT}.ngd $VARS-
  {PROJECT}.pcf",
  
  # Place and Route
  "par -w -ol med -pl med -t 1 $VARS->{PROJECT}_map.ncd $VARS-
  >{PROJECT}.ncd $VARS->{PROJECT}.pcf",
  
  # Check out the version controlled "bit" file so that we can
  # overwrite it
  "cleartool checkout -unr -nc $VARS->{PROJECT}.bit",
  
  # Generate BIT Programming File
  "bitgen -f $VARS->{BITGEN_FILE} $VARS->{PROJECT}.ncd",
  
  # Generate SVF File
  "impact.exe -batch $VARS->{IMPACT_FILE}",
  
  # Generate XSVF File
  "$MYDIR/../../../../tools/bin/svf2xsvf_41i.exe -d -fpga –I
  $VARS->{PROJECT}.svf -o $VARS->{PROJECT}.xsvf",
  
  # Generate HEX File
  "$MYDIR/../../../../tools/bin/bin2hex.exe $VARS-
  {PROJECT}.xsvf $VARS->{PROJECT}.hex",
  
  # Check out output file so that we can store our new hex file
  # there
  "cleartool checkout -unr -nc $VARS->{OUTPUT}",
  
  # Copy HEX file to include directory
  "copy $VARS->{PROJECT}.hex $VARS->{OUTPUT}",
  
];

# Project sources get included in the following
# array reference. There is no need to define sources
# specific to components since the component projects
# define their own sources and pass the information
# to the parent

$SOURCES =
[

  # Project Package(s):
  "$MYDIR/../src/top_meter_pkg.vhd",
  
  # Project Source(s):
  "$MYDIR/../src/top_meter.vhd",

];

# Components get included in the following array reference.
# You can pass parameters to components by following the
# path with a semicolon. Following the semicolon, use comma-
# delimited key/value pairs to define parameters. These
# parameters will overwrite or be added to the "VARS" variable
# hash of the component project. This is a great way to change
# parameters of dynamically created vendor intellectual property
# cores!

$COMPONENTS =
[
  # Project Specific Component(s):
  "$MYDIR/../../data_acq",

  # Common Component(s):
  "$MYDIR/../../../../components/rtl/coldfire_async_if",
  "$MYDIR/../../../../components/rtl/decoder_2815",
  "$MYDIR/../../../../components/rtl/edge_recorder",
  "$MYDIR/../../../../components/rtl/encoder_2815",
  "$MYDIR/../../../../components/rtl/gpsb_control",
  "$MYDIR/../../../../components/rtl/gpsb_master",
  "$MYDIR/../../../../components/rtl/uart ; RX_FIFO_DEPTH=>32, TX_FIFO_DEPTH=>128",
];

# Dynamically generated temp files are defined in the following
# array reference of hashes
# Each hash represents one temp file. It is defined by multiple
# key/value pairs. The first one, NAME, defines the name and
# path of where the temp file is to be generated.
# You define the text to include in a value associated with a
# TEXT key. This is also a great place to utilize project
# variables.
# Usually one of these files needs to contain a list of component
# sources. This is accomplished by using the following syntax
# <<< some prefix SOURCES some postfix >>>
#
# For example, assume a component has two source files called
# source1.vhd and source2.vhd. The use of the tag detailed above
# would yield the following listing in you text file:
#
# some prefix source1.vhd some postfix
# some prefix source2.vhd some postfix

$TEMPFILES =
[
    {
      NAME => $VARS->{SYNPLICITY_TCL},
      TEXT => "project -run",
    },
    {
      NAME => $VARS->{SYNPLICITY_FILE},
      TEXT => "#
               ##-- Synplicity, Inc.
               ##-- Synplify version 7.3
               ##-- Project file top_meter.prj.
               ##-- Generated using ISE.
               
               #implementation: top_meter
               impl -add \"top_meter\"
               
               ##device options
               proc findmatch {spec args} { set arglist [join
                 $args \" \"]; set idx [lsearch -glob
                 $arglist \$spec]; if {\$idx != -1} {
                 return [lindex \$arglist \$idx]; } else {
                 return \$spec; } }
               proc findpackage {spec} { findmatch \$spec
                 [partdata -package [part]]}
               proc findgrade {spec} { findmatch \$spec
                 [partdata -grade [part]]}
               set_option -technology SPARTAN2
               set_option -part xc2s100
               set_option -package [findpackage {tq144}]
               set_option -speed_grade [findgrade {-5}]
               
               ## Libraries
               
               ## Source files - Automatically inserted by
               ## tools/bin/build_rtl.pl
               <<<add_file {SOURCES}>>>
               
               ## Additional compile options
               set_option -symbolic_fsm_compiler 1
               set_option -resource_sharing 1
               set_option -default_enum_encoding default
               set_option -top_module top_meter
               
               ## Additional map options
               set_option -frequency 65
               set_option -fanout_limit 100
               set_option -disable_io_insertion 0
               
               ## Additional simulation options
               set_option -write_verilog 0
               set_option -write_vhdl 0
               
               ## Additional placeAndRoute options
               set_option -write_apr_constraint 1
               
               ## Additional implAttr options
               set_option -num_critical_paths 0
               set_option -num_startend_points 0
               set_option -compiler_compatible 0
               
               ## Set result format/file last
               project -result_file {./$VARS->{PROJECT}.edn}
               
               ## Constraint file
               add_file -constraint {$VARS->{SYNPLICITY_CONSTRAINTS}}

              ",
    },
    {
      NAME => $VARS->{BITGEN_FILE},
      TEXT => "-w
               -g DebugBitstream:No
               -g Binary:no
               -g Gclkdel0:11111
               -g Gclkdel1:11111
               -g Gclkdel2:11111
               -g Gclkdel3:11111
               -g ConfigRate:4
               -g CclkPin:PullUp
               -g M0Pin:PullDown
               -g M1Pin:PullDown
               -g M2Pin:PullUp
               -g ProgPin:PullUp
               -g DonePin:PullUp
               -g TckPin:PullUp
               -g TdiPin:PullUp
               -g TdoPin:PullUp
               -g TmsPin:PullUp
               -g UnusedPin:PullUp
               -g UserID:0xFFFFFFFF
               -g StartUpClk:JtagClk
               -g DONE_cycle:4
               -g GTS_cycle:5
               -g GSR_cycle:6
               -g GWE_cycle:6
               -g LCK_cycle:NoWait
               -g Security:None
               -g DonePipe:No
               -g DriveDone:No
              ",
    },
    {
      NAME => $VARS->{IMPACT_FILE},
      TEXT => "setPreference -pref UserLevel:NOVICE
               setPreference -pref MessageLevel:DETAILED
               setPreference -pref ConcurrentMode:FALSE
               setPreference -pref UseHighz:FALSE
               setPreference -pref ConfigOnFailure:STOP
               setPreference -pref StartupCLock:AUTO_CORRECTION
               setPreference -pref AutoSignature:FALSE
               setPreference -pref KeepSVF:TRUE
               setPreference -pref svfUseTime:FALSE
               setPreference -pref UserLevel:NOVICE
               setPreference -pref MessageLevel:DETAILED
               setPreference -pref ConcurrentMode:FALSE
               setPreference -pref UseHighz:FALSE
               setPreference -pref ConfigOnFailure:STOP
               setPreference -pref StartupCLock:AUTO_CORRECTION
               setPreference -pref AutoSignature:FALSE
               setPreference -pref KeepSVF:TRUE
               setPreference -pref svfUseTime:FALSE
               setMode -bsfile
               setCable -port svf -file $VARS->{PROJECT}.svf
               addDevice -position 1 -file $VARS->{PROJECT}.bit
               Program -p 1
               quit
  
              ",
    },
];
```