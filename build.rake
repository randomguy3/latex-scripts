#####################
# Utility functions #
#####################
#
# These functions do not depend on any script variables
#

def msg (m)
  puts "RAKE: " + m
  STDOUT.flush
end

def warn (m)
  puts ">>> WARNING: " + m
  STDOUT.flush
end

def stripcomments (line)
  percentidx = 0
  esc = false
  line.each_char do |c|
    if esc
      esc = false
    elsif c == '\\'
      esc = true
    elsif c == '%'
      break
    end
    percentidx += 1
  end
  line[0,percentidx]
end

####################################################################
# Stolen from
# http://svn.ruby-lang.org/repos/ruby/trunk/lib/shellwords.rb
# for compatibility with Ruby 1.8
def shellescape(str)
  str = str.to_s

  # An empty argument will be skipped, so return empty quotes.
  return "''" if str.empty?

  str = str.dup

  # Treat multibyte characters as is.  It is caller's responsibility
  # to encode the string in the right encoding for the shell
  # environment.
  str.gsub!(/([^A-Za-z0-9_\-.,:\/@\n])/, "\\\\\\1")

  # A LF cannot be escaped with a backslash because a backslash + LF
  # combo is regarded as line continuation and simply ignored.
  str.gsub!(/\n/, "'\n'")

  return str
end

def shelljoin(array)
  array.map { |arg| shellescape(arg) }.join(' ')
end
####################################################################

def slurp_citations(auxfile)
  cites = ""
  f = open(auxfile)
  f.each_line do |ln|
    if ln[/\\citation/,1]
      cites += ln
    end
  end
  f.close()
end

def same_citations?(auxfile1, auxfile2)
  return slurp_citations(auxfile1) == slurp_citations(auxfile2)
end

def has_citations? (auxfile)
  f = open(auxfile)
  found_cites = false
  f.each_line do |ln|
    if ln.start_with?"\\citation"
      found_cites = true
      break
    end
  end
  f.close
  found_cites
end



################################
# User configuration variables #
################################

if !(defined? $MAIN_JOB)
  fail "No MAIN_JOB given"
end
if !(defined? $MAIN_FILE)
  $MAIN_FILE = "#{$MAIN_JOB}.tex"
end
if !(defined? $SIDE_JOBS)
  $SIDE_JOBS = {}
elsif !($SIDE_JOBS.is_a? Hash)
  side_jobs = {}
  for j in $SIDE_JOBS
    side_jobs[j] = j + ".tex"
  end
  $SIDE_JOBS = side_jobs
end
if !(defined? $DIST_NAME)
  $DIST_NAME = $MAIN_JOB
end
if !(defined? $EXTRA_INCLUDES)
  $EXTRA_INCLUDES = []
end
if !(defined? $VERBOSE_MSGS)
  $VERBOSE_MSGS = false
end

RakeFileUtils.verbose($VERBOSE_MSGS)

if ENV['BUILD_DIR']
  $BUILD_DIR = ENV['BUILD_DIR']
end
if ENV['LATEX']
  $LATEX = ENV['LATEX']
end
if ENV['BIBTEX']
  $BIBTEX = ENV['BIBTEX']
end
if ENV['DVIPS']
  $BIBTEX = ENV['DVIPS']
end
if ENV['PS2PDF']
  $PS2PDF = ENV['PS2PDF']
end
if ENV['EPSTOPDF']
  $EPSTOPDF = ENV['EPSTOPDF']
end

if !(defined? $BUILD_DIR)
  $BUILD_DIR = 'build'
end
if !(defined? $LATEX)
  $LATEX = 'pdflatex'
end
if !(defined? $BIBTEX)
  $BIBTEX = 'bibtex'
end
if !(defined? $DVIPS)
  $DVIPS = 'dvips'
end
if !(defined? $DVIPS_OPTS)
  $DVIPS_OPTS = []
end
if !(defined? $PS2PDF)
  $PS2PDF = 'ps2pdf'
end
if !(defined? $PS2PDF_OPTS)
  $PS2PDF_OPTS = []
end
if !(defined? $EPSTOPDF)
  $EPSTOPDF = 'epstopdf'
end
if !(defined? $EPSTOPDF_OPTS)
  $EPSTOPDF_OPTS = []
end



######################
# Internal variables #
######################

$BUILD_FILES = []
$INCLUDE_FILES = Dir[ 'tex/*', 'figures/*', '*.bib' ] | $EXTRA_INCLUDES
$ALL_JOBS = $SIDE_JOBS.merge({$MAIN_JOB => $MAIN_FILE})
$ALL_JOBS.each_value {|v| $INCLUDE_FILES << v}
$INCLUDE_FILES << $HEADER if defined?$HEADER and !$INCLUDE_FILES.include?$HEADER
$INCLUDE_FILES << $FOOTER if defined?$FOOTER and !$INCLUDE_FILES.include?$FOOTER

if !(defined? $LATEX_OUT_FMT)
  $LATEX_OUT_FMT = 'pdf'
  def check_for_bad_classes(file)
    found = false
    dvi_classes = ['powerdot',
                   'prosper']
    f = open(file)
    i = 0
    f.each_line do |ln|
      match_data = stripcomments(ln).match(/\\documentclass(?:\[[^\]]*\])?\{([^}]*)\}/)
      if match_data
        doc_class = match_data[1]
        if dvi_classes.include?doc_class
          $LATEX_OUT_FMT = 'dvi'
        end
        found = true
        break
      end
      # only bother checking the first 50 lines
      if i >= 50
        break
      end
      i += 1
    end
    f.close
    return found
  end
  if not check_for_bad_classes($MAIN_FILE)
    if defined?$HEADER and File.exists?$HEADER
      check_for_bad_classes($HEADER)
    end
  end
end

$LATEX_CMD = [$LATEX, '-interaction=nonstopmode', '-halt-on-error']
$LATEX_CMD += ['-fmt', 'latex', '-output-format', $LATEX_OUT_FMT]
if defined? $LATEX_OPTS
  $LATEX_CMD += $LATEX_OPTS
end
$BIBTEX_CMD = [$BIBTEX, '-terse']
if defined? $BIBTEX_OPTS
  $BIBTEX_CMD += $BIBTEX_OPTS
end



#######################
# Auxillary functions #
#######################

# latex draft mode does not create the pdf (or look at images)
def run_latex_draft (dir, name, file)
  command = $LATEX_CMD + ['-draftmode', '-jobname', name, file]
  output = ""
  Dir.chdir(dir) do
    output = `#{shelljoin command}`
    if $? != 0
      puts output
      fail "RAKE: LaTeX error in job #{name}."
    end
    # When in DVI mode, the DVI file will be created even with -draftmode
    rm_f "#{name}.#{$LATEX_OUT_FMT}"
  end
end

def run_latex (dir, name, file, depth=0)
  command = $LATEX_CMD + ['-jobname', name, file]
  output = ""
  Dir.chdir(dir) do
    output = `#{shelljoin command}`
  end
  if $? != 0
    puts output
    fail "RAKE: LaTeX error in job #{name}."
  else
    if output["Rerun to get cross-references right."]
      if depth > 4
        fail "Failed to resolve all cross-references after 4 attempts"
      else
        msg "Rebuilding #{name} to get cross-references right"
        run_latex dir, name, file, (depth+1)
      end
    end
  end
end

def check_log(logfile)
  f = open(logfile)
  has_todos = false
  bad_cites = []
  bad_refs = []
  f.each_line do |ln|
    if ln["unresolved-TODO"]
      has_todos = true
    end
    bc = ln[/LaTeX Warning: Citation `([^']*)' on page/,1]
    if bc
      bad_cites << bc
    end
    br = ln[/LaTeX Warning: Reference `([^']*)' on page/,1]
    if br
      bad_refs << br
    end
  end
  f.close

  has_problems = false
  if has_todos
    warn 'you have TODOs left'
    has_problems = true
  end
  if bad_cites.length > 0
    warn "the following citations were unresolved: #{bad_cites.join(', ')}"
    has_problems = true
  end
  if bad_refs.length > 0
    warn "the following references were unresolved: #{bad_refs.join(', ')}"
    has_problems = true
  end
  return !has_problems
end

def open_pdf(file)
  msg "Opening application to view PDF"
  apps = ['xdg-open', # linux
          'open',     # mac
          'start']    # windows
  success = apps.detect do
    |app| system(app, file)
  end
  if !success
    fail "Could not figure out how to open the PDF file"
  end
end

$_BIBS_CACHE = {}
def get_bibs?(texfile)
  if $_BIBS_CACHE.has_key?texfile
    return $_BIBS_CACHE[texfile]
  end
  f = open(texfile)
  bibfiles = []
  f.each_line do |ln|
    bibs = stripcomments(ln).scan(/\\bibliography\{([^}]*)\}/)
    for b in bibs
      bibfiles << "#{$BUILD_DIR}/#{b[0].strip}.bib"
    end
  end
  f.close
  if defined?$FOOTER and File.exists?$FOOTER
    f = open($FOOTER)
    bibfiles = []
    f.each_line do |ln|
      bibs = stripcomments(ln).scan(/\\bibliography\{([^}]*)\}/)
      for b in bibs
        bibfiles << "#{$BUILD_DIR}/#{b[0].strip}.bib"
      end
    end
    f.close
  end
  $_BIBS_CACHE[texfile] = bibfiles
  return bibfiles
end
def get_bibs_from_jobfile?(jobfile)
  jobname = File.basename(jobfile).sub(/\.[^.]+$/, '')
  inputFile = $ALL_JOBS.fetch(jobname, jobname+'.tex')
  get_bibs?(inputFile)
end
def get_bibs_for_job?(jobname)
  inputFile = $ALL_JOBS.fetch(jobname, jobname+'.tex')
  get_bibs?(inputFile)
end

# proc to convert a job file (eg: the aux or pdf file) to
# an input file
jobFileToInputFile = proc { |fname|
  jobname = File.basename(fname).sub(/\.[^.]+$/, '')
  $BUILD_DIR + '/' + $ALL_JOBS.fetch(jobname, jobname+'.tex')
}

bblFileIfHasBibs = proc { |jobfile|
  if not get_bibs_from_jobfile?(jobfile).empty?
    [jobfile.sub(/\.[^.]+$/, '.bbl')]
  else
    []
  end
}

mainJobBblFile = proc {
  if not get_bibs_for_job?($MAIN_JOB).empty?
    ["#{$BUILD_DIR}/#{$MAIN_JOB}.bbl"]
  else
    []
  end
}



#####################################################
# Rules to create the various files and directories #
#####################################################

directory $BUILD_DIR
directory $DIST_NAME

rexp_safe_build_dir = Regexp.quote($BUILD_DIR)

# Copy files to the build directory
for f in $INCLUDE_FILES
  if File.extname(f) == '.eps' and $LATEX_OUT_FMT == 'pdf'
    fbase = File.basename f, '.eps'
    fbuild = "#{$BUILD_DIR}/#{fbase}.pdf"
    $BUILD_FILES << fbuild
    file fbuild => [$BUILD_DIR,f] do |t|
      command = [$EPSTOPDF] + $EPSTOPDF_OPTS + ['--outfile='+t.name, t.prerequisites[1]]
      output = ""
      output = `#{shelljoin command}`
      if $? != 0
        puts "#{shelljoin command}"
        puts output
        fail "RAKE: Could not create PDF file from EPS #{name}."
      end
    end
  else
    fbase = File.basename f
    fbuild = "#{$BUILD_DIR}/#{fbase}"
    $BUILD_FILES << fbuild
    file fbuild => [$BUILD_DIR,f] do |t|
      cp t.prerequisites[1], t.name
    end
  end
end

# If we're using LaTeX in DVI mode, convert to PDF (via PS)
if $LATEX_OUT_FMT == 'dvi'
  rule '.ps' => ['.dvi'] do |t|
    psfile = t.name
    dvifile = psfile.sub(/\.[^.]+$/, '.dvi')
    command = [$DVIPS] + $DVIPS_OPTS + ['-o', psfile, dvifile]
    output = ""
    msg "Converting DVI file to Postscript"
    output = `#{shelljoin command} 2>&1`
    if $? != 0
      puts output
      fail "RAKE: Could not create PS file from DVI #{dvifile}."
    end
  end
  rule( /^#{rexp_safe_build_dir}\/[^\/]*\.pdf$/ => [
         proc {|pdf_file| pdf_file.sub(/\.[^.]+$/, '.ps') }
        ]) do |t|
    pdffile = t.name
    psfile = pdffile.sub(/\.[^.]+$/, '.ps')
    command = [$PS2PDF] + $PS2PDF_OPTS + [psfile, pdffile]
    output = ""
    msg "Converting Postscript file to PDF"
    output = `#{shelljoin command}`
    if $? != 0
      puts output
      fail "RAKE: Could not create PDF file from PS #{psfile}."
    end
  end
elsif $LATEX_OUT_FMT != 'pdf'
  fail "Unknown LaTeX output format \"#{$LATEX_OUT_FMT}\""
end

# Create bibliographies
rule( /^#{rexp_safe_build_dir}\/[^\/]*\.bbl$/ =>
      proc {|bbl_file|
        [bbl_file.sub(/\.[^.]+$/, '.aux')]+
          get_bibs_from_jobfile?(bbl_file)
      }) do |t|
  bbl_file = t.name
  jobname = File.basename(bbl_file, '.bbl')
  aux = bbl_file.sub(/\.[^.]+$/, '.aux')
  old_aux = aux + ".last_bib_run"
  if has_citations?(aux)
    force = true
    if File.exists?(bbl_file)
      force = t.prerequisites.detect do |p|
        p.end_with?(".bib") and File.stat(p).mtime >= File.stat(bbl_file).mtime
      end
    end
    if force or !File.exists?old_aux or !same_citations?(aux,old_aux)
      msg 'Running BibTeX'
      command = $BIBTEX_CMD + [jobname]
      Dir.chdir($BUILD_DIR) do
        system(*command)
      end
      unless $? == 0
        fail "RAKE: BibTeX error in job #{jobname}."
      end
    end
  else
    if !File.exists?old_aux or !same_citations?(aux,old_aux)
      # we would normally have run it; say why we aren't
      msg 'No citations; skipping BibTeX'
    end
    if File.exists?(bbl_file)
      rm bbl_file
    end
  end
  cp aux, old_aux
end

rule( /^#{rexp_safe_build_dir}\/[^\/]*\.#{$LATEX_OUT_FMT}$/ =>
     ([jobFileToInputFile,bblFileIfHasBibs]+$BUILD_FILES)) do |t|
  jobname = File.basename(t.name, '.' + $LATEX_OUT_FMT)
  inputfile = jobFileToInputFile.call(t.name)
  msg "Building #{jobname}"
  run_latex $BUILD_DIR, jobname, File.basename(inputfile)
end

rule( /^#{rexp_safe_build_dir}\/[^\/]*\.aux$/ => ([jobFileToInputFile]+$BUILD_FILES)) do |t|
  jobname = File.basename(t.name, '.aux')
  inputfile = jobFileToInputFile.call(t.name)
  msg "Building #{jobname} to find refs"
  run_latex_draft $BUILD_DIR, jobname, File.basename(inputfile)
end

rule( /^[^\/]*\.pdf$/ => [proc {|f|"#{$BUILD_DIR}/"+f}]) do |t|
  cp "#{$BUILD_DIR}/"+t.name, t.name
end

# the log won't be accurate until the final version has been
# produced
rule '.log' => ['.'+$LATEX_OUT_FMT]



##############################
# Tasks for the user to call #
##############################

$SIDE_JOBS.each_key do |job|
  desc "Check for problems with the LaTeX document for the #{job} job"
  task "check-#{job}" => ["#{$BUILD_DIR}/#{job}.log"] do |t|
    check_log(t.prerequisites[0])
  end

  desc "Create the #{job}.pdf file"
  task "build-#{job}" => ["check-#{job}", "#{job}.pdf"]

  desc "Create the #{job}.pdf file and open it in a PDF viewer"
  task "view-#{job}" => ["#{job}.pdf"] do |t|
    open_pdf(t.prerequisites[0])
  end
end

desc "Check for problems with the LaTeX document (eg: unresolved references)"
task :check => ["#{$BUILD_DIR}/#{$MAIN_JOB}.log"] do |t|
  check_log(t.prerequisites[0])
end
task :check_final => "#{$BUILD_DIR}/#{$MAIN_JOB}.log" do
  is_ok = check_log("#{$BUILD_DIR}/#{$MAIN_JOB}.log")
  if !is_ok
    fail "There are still problems with the LaTeX document (see above)"
  end
end

desc "Create a draft version of the main PDF file (#{$MAIN_JOB}.pdf) [default]"
task :draft => ["check", "#{$MAIN_JOB}.pdf"]
task :default => [:draft]

desc "Create the final version of the main PDF file (#{$MAIN_JOB}.pdf)"
task :final => [:check_final,"#{$MAIN_JOB}.pdf"]

desc "Create the main PDF file and open it in a PDF viewer"
task :view => ["#{$MAIN_JOB}.pdf"] do
  open_pdf("#{$MAIN_JOB}.pdf")
end

desc "Create a tar archive containing all the source files"
task :tar => [$DIST_NAME] do
  msg "Creating (#{$DIST_NAME}.tar.gz)"
  rm_f "#{$DIST_NAME}.tar.gz"
  files = $INCLUDE_FILES
  cp files, $DIST_NAME
  system('tar', 'czf', "#{$DIST_NAME}.tar.gz", $DIST_NAME)
  rm_rf $DIST_NAME
end

desc "Create a tar archive suitable for uploading to the arXiv"
# We don't include the bibfiles for arXiv
task :arxiv => [$DIST_NAME,mainJobBblFile] do
  msg "Creating (#{$DIST_NAME}-arxiv.tar.gz)"
  rm_f "#{$DIST_NAME}-arxiv.tar.gz"
  files = $INCLUDE_FILES+mainJobBblFile.call()
  cp files, $DIST_NAME
  system('tar', 'czf', "#{$DIST_NAME}-arxiv.tar.gz", $DIST_NAME)
  rm_rf $DIST_NAME
end

desc "Remove all build files and archives"
task :clean do
  msg "Deleting build directory and archive"
  rm_rf [$BUILD_DIR, "#{$DIST_NAME}.tar.gz", "#{$DIST_NAME}-arxiv.tar.gz"]
end

