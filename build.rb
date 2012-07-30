if !$MAIN_JOB
  fail "No MAIN_JOB given"
end
if !$DIST_NAME
  $DIST_NAME = $MAIN_JOB
end
if !$EXTRA_INCLUDES
  $EXTRA_INCLUDES = []
end

RakeFileUtils.verbose($VERBOSE_MSGS)

# internal
$BUILD_FILES = []
$MAIN_FILE = $MAIN_JOB + '.tex'
$INCLUDE_FILES = Dir[ 'tex/*', 'figures/*'] | $EXTRA_INCLUDES
$INCLUDE_FILES << $MAIN_FILE

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
  $BIBTEX = ENV['PS2PDF']
end

if !$BUILD_DIR
  $BUILD_DIR = 'build'
end
if !$LATEX
  $LATEX = 'pdflatex'
end
if !$BIBTEX
  $BIBTEX = 'bibtex'
end
if !defined?($DRAFT)
  $DRAFT = true
end
if !$DVIPS
  $DVIPS = 'dvips'
end
if !$DVIPS_OPTS
  $DVIPS_OPTS = []
end
if !$PS2PDF
  $PS2PDF = 'ps2pdf'
end
if !$PS2PDF_OPTS
  $PS2PDF_OPTS = []
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

if !$LATEX_OUT_FMT
  $LATEX_OUT_FMT = 'pdf'
  dvi_classes = ['powerdot',
                 'prosper']
  f = open($MAIN_FILE)
  f.each_line do |ln|
    match_data = stripcomments(ln).match(/\\documentclass(?:\[[^\]]*\])?\{([^}]*)\}/)
    if match_data
      doc_class = match_data[1]
      if dvi_classes.include?doc_class
        $LATEX_OUT_FMT = 'dvi'
      end
      break
    end
  end
  f.close
end
$BUILD_OUTPUT = "#{$BUILD_DIR}/#{$MAIN_JOB}.#{$LATEX_OUT_FMT}"

if $LATEX_OUT_FMT == 'dvi'
  file "#{$BUILD_DIR}/#{$MAIN_JOB}.ps" => [$BUILD_OUTPUT] do |t|
    command = [$DVIPS] + $DVIPS_OPTS + ['-o', t.name, t.prerequisites[0]]
    output = ""
    msg "Converting DVI file to Postscript"
    output = `#{shelljoin command} 2>&1`
    if $? != 0
      puts output
      fail "RAKE: Could not create PS file from DVI #{name}."
    end
  end
  file "#{$BUILD_DIR}/#{$MAIN_JOB}.pdf" => ["#{$BUILD_DIR}/#{$MAIN_JOB}.ps"] do |t|
    command = [$PS2PDF] + $PS2PDF_OPTS + [t.prerequisites[0], t.name]
    output = ""
    msg "Converting Postscript file to PDF"
    output = `#{shelljoin command}`
    if $? != 0
      puts output
      fail "RAKE: Could not create PDF file from PS #{name}."
    end
  end
elsif $LATEX_OUT_FMT != 'pdf'
  fail "Unknown LaTeX output format \"#{$LATEX_OUTPUT_FORMAT}\""
end

def msg (m)
  puts "RAKE: " + m
  STDOUT.flush
end

def warn (m)
  puts ">>> WARNING: " + m
  STDOUT.flush
end

def warn_need_for_final (m)
  if $DRAFT
    warn (m)
  else
    fail '!!! ERROR: ' + m
  end
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


$LATEX_CMD = [$LATEX, '-interaction=nonstopmode', '-halt-on-error']
$LATEX_CMD += ['-fmt', 'latex', '-output-format', $LATEX_OUT_FMT]
if $LATEX_OPTS
  $LATEX_CMD += $LATEX_OPTS
end
$BIBTEX_CMD = [$BIBTEX, '-terse']
if $BIBTEX_OPTS
  $BIBTEX_CMD += $BIBTEX_OPTS
end

# latex draft mode does not create the pdf (or look at images)
def run_latex_draft (dir, name, file)
  command = $LATEX_CMD + ['-draftmode', '-jobname', name, file]
  output = ""
  Dir.chdir(dir) do
    output = `#{shelljoin command}`
  end
  if $? != 0
    puts output
    fail "RAKE: LaTeX error in job #{name}."
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
        msg "Rebuilding #{file} to get cross-references right"
        run_latex dir, name, file, (depth+1)
      end
    end
  end
end

for f in $INCLUDE_FILES
  fbase = File.basename f
  fbuild = "#{$BUILD_DIR}/#{fbase}"
  $BUILD_FILES << fbuild
  file fbuild => [$BUILD_DIR,f] do |t|
    cp t.prerequisites[1], t.name
  end
end

if $DRAFT
  file "#{$BUILD_DIR}/#{$MAIN_FILE}" do
    f = open("#{$BUILD_DIR}/#{$MAIN_FILE}", 'a')
    f.write("\n\\def\\realjobname{#{$MAIN_JOB}}\n")
    f.close
  end
end

def has_cites (auxfile)
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

def find_bibfiles
  f = open($MAIN_FILE)
  allbibs = []
  f.each_line do |ln|
    bibs = stripcomments(ln).scan(/\\bibliography\{([^}]*)\}/)
    for b in bibs
      b = b[0].strip
      if File.exists?("#{b}.bib")
        file "#{$BUILD_DIR}/#{b}.bib" => [$BUILD_DIR,"#{b}.bib"] do |t|
          cp t.prerequisites[1], t.name
        end
        allbibs << "#{$BUILD_DIR}/#{b}.bib"
      elsif File.exists?("#{b}.bbl")
        file "#{$BUILD_DIR}/#{b}.bbl" => [$BUILD_DIR,"#{b}.bbl"] do |t|
          cp t.prerequisites[1], t.name
        end
      else
        warn "Could not find bibliography file #{b}.bib or #{b}.bbl, referenced from #{$MAIN_FILE}"
      end
    end
  end
  f.close

  if allbibs.length > 0
    file "#{$BUILD_DIR}/#{$MAIN_JOB}.bbl" => allbibs+["#{$BUILD_DIR}/#{$MAIN_JOB}.aux"] do |t|
      aux = "#{$BUILD_DIR}/#{$MAIN_JOB}.aux"
      old_aux = "#{$BUILD_DIR}/#{$MAIN_JOB}.last_bib_run.aux"
      if has_cites(aux)
        force = true
        if File.exists?(t.name)
          force = t.prerequisites.detect do |p|
            p.end_with?(".bib") and File.stat(p).mtime >= File.stat(t.name).mtime
          end
        end
        if force or !File.exists?old_aux or !identical?(aux,old_aux)
          msg 'Running BibTeX'
          command = $BIBTEX_CMD + [$MAIN_JOB]
          Dir.chdir($BUILD_DIR) do
            system(*command)
          end
          unless $? == 0
            fail "RAKE: BibTeX error in job #{$MAIN_JOB}."
          end
        end
      elsif !File.exists?old_aux or !identical?(aux,old_aux)
        msg 'No citations; skipping BibTeX'
        if File.exists?(t.name)
          rm t.name
        end
      end
      cp aux, old_aux
    end
    file $BUILD_OUTPUT => "#{$BUILD_DIR}/#{$MAIN_JOB}.bbl"
  end
end
find_bibfiles


task :default => [:draft]

task :setdraft do
  $DRAFT = true
end

task :setfinal do
  $DRAFT = false
end

task :draft => [
  :setdraft,
  "#{$BUILD_DIR}/#{$MAIN_JOB}.pdf",
  :check] do
 
  cp "#{$BUILD_DIR}/#{$MAIN_JOB}.pdf", "#{$MAIN_JOB}.pdf"
end

task :final => [
  :clean,
  :setfinal,
  "#{$BUILD_DIR}/#{$MAIN_JOB}.pdf",
  :check] do
 
  cp "#{$BUILD_DIR}/#{$MAIN_JOB}.pdf", "#{$DIST_NAME}.pdf"
end

task :check => $BUILD_OUTPUT do
  f = open("#{$BUILD_DIR}/#{$MAIN_JOB}.log")
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

  if has_todos
    warn_need_for_final 'you have TODOs left'
  end
  if bad_cites.length > 0
    warn_need_for_final "the following citations were unresolved: #{bad_cites.join(', ')}"
  end
  if bad_refs.length > 0
    warn_need_for_final "the following references were unresolved: #{bad_refs.join(', ')}"
  end
end

file $BUILD_OUTPUT => $BUILD_FILES do
  msg "Building #{$MAIN_FILE}"
  run_latex $BUILD_DIR, $MAIN_JOB, $MAIN_FILE
end

directory $BUILD_DIR
directory $DIST_NAME

file "#{$BUILD_DIR}/#{$MAIN_JOB}.aux" => ($BUILD_FILES+[$MAIN_FILE]) do
  msg "Building #{$MAIN_FILE} to find refs"
  run_latex_draft $BUILD_DIR, $MAIN_JOB, $MAIN_FILE
end

task :clean do
  msg "Deleting build directory and archive"
  rm_rf [$BUILD_DIR, "#{$DIST_NAME}.tar.gz"]
end

task :tar => [$DIST_NAME] do
  msg "Creating (#{$DIST_NAME}.tar.gz)"
  rm_f "#{$DIST_NAME}.tar.gz"
  cp $INCLUDE_FILES, $DIST_NAME
  system('tar', 'czf', "#{$DIST_NAME}.tar.gz", $DIST_NAME)
  rm_rf $DIST_NAME
end

task :view => ["#{$BUILD_DIR}/#{$MAIN_JOB}.pdf"] do
  msg "Opening application to view PDF"
  apps = ['xdg-open', # linux
          'open',     # mac
          'start']    # windows
  success = apps.detect do
    |app| system(app, "#{$BUILD_DIR}/#{$MAIN_JOB}.pdf")
  end
  if !success
    fail "Could not figure out how to open the PDF file"
  end
end

