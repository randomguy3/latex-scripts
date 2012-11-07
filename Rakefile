##################
# Common Options #
##################
#
# Most projects will only need to touch the options in this section
#
# The only required option is $MAIN_JOB
#

# The LaTeX job name
# The output file will be this with '.pdf' appended
$MAIN_JOB = 'example-doc'

# The input file
# Default value is $MAIN_JOB.tex
$MAIN_FILE = 'example.tex'

# Other, independent jobs (eg: individual chapters)
# Format is
#   'job name' => 'job input file'
#$SIDE_JOBS = {
#  'part1' => 'part1.tex'
#}

# Header and footer files
# If you define \documentclass in a separate file, this should be
# given with $HEADER, and if you define \bibliography in a separate
# file, this should be given with $FOOTER.  This will help the script
# figure out what needs to be done.
# Note that this is the source file location, and so relative paths
# are important
#$HEADER = 'tex/header.tex'
#$FOOTER = 'tex/footer.tex'

# What to name the archive
# Defauls to $MAIN_JOB
$DIST_NAME = 'example-archive'

# Any non-standard files to copy into the build dir
# Paths are relative to the Rakefile
$EXTRA_INCLUDES = []


##################
# External Tools #
##################
#
# All the tool locations can be overridden with environment
# variables of the same name
#

# The LaTeX command (should be pdflatex)
# $LATEX = '/path/to/pdflatex'

# The BibTeX command
# $BIBTEX = '/path/to/bibtex'

# The dvips command, used if $LATEX_OUTPUT_FMT is 'dvi'
# $DVIPS = '/path/to/dvips'
# $DVIPS_OPTS = ['arg1', 'arg2']

# The ps2pdf command, used if $LATEX_OUTPUT_FMT is 'dvi'
# $PS2PDF = '/path/to/ps2pdf'
# $PS2PDF_OPTS = ['arg1', 'arg2']

# The epstopdf command, used to convert EPS files to PDF
# if $LATEX_OUTPUT_FMT is 'pdf'
# $EPSTOPDF = '/path/to/epstopdf'
# $EPSTOPDF_OPTS = ['arg1', 'arg2']


####################
# Advanced Options #
####################

# Basically controls whether LaTeX is used in pdflatex mode
# (directly producing PDF output) or normal LaTeX mode
# (producing DVI output which is then converted to postscript
# then PDF).  Can be 'pdf' or 'dvi'.
# Default is 'pdf' unless the documentclass is powerdot or prosper.
# $LATEX_OUTPUT_FMT = 'pdf'

# Output all the command results? (default: true)
# $VERBOSE_MSGS = false

# Where to put the build files (default: 'build')
# Can be overridden with the BUILD_DIR environment
# variable
# $BUILD_DIR = 'build'



# This next line is required: do not touch!
import 'build.rake'
