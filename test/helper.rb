# encoding: utf-8

# Setup coverage
require 'coveralls'
Coveralls.wear!

# Load unit testing stuff
begin
  require 'minitest/autorun'
  require 'mocha/setup'
  require 'yard'
rescue => e
  $stderr.puts "To run the nanoc unit tests, you need minitest and mocha."
  raise e
end

# Load nanoc
$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + '/../lib'))
require 'nanoc-core'

# Load miscellaneous requirements
require 'stringio'
require 'tmpdir'

module Nanoc::TestHelpers

  LIB_DIR = File.expand_path(File.dirname(__FILE__) + '/../lib')

  def in_site(params={})
    # Build site name
    site_name = params[:name]
    if site_name.nil?
      @site_num ||= 0
      site_name = "site-#{@site_num}"
      @site_num += 1
    end

    # Create site
    unless File.directory?(site_name)
      FileUtils.mkdir_p(site_name)
      FileUtils.cd(site_name) do
        create_site_here(params)
      end
    end

    # Yield site
    FileUtils.cd(site_name) do
      yield
    end
  end

  def site_here
    Nanoc::SiteLoader.new.load
  end

  def compile_site_here
    Nanoc::CompilerBuilder.new.build(site_here).run
  end

  def create_site_here(params={})
    # Build rules
    rules_content = <<EOS
compile '/**/*' do
  {{compilation_rule_content}}

  if item.binary?
    write item.identifier, :snapshot => :last
  elsif item.identifier.match?('/index.*')
    write '/index.html', :snapshot => :last
  else
    write item.identifier.without_ext + '/index.html', :snapshot => :last
  end
end

layout '/**/*', :erb
EOS
    rules_content.gsub!('{{compilation_rule_content}}', params[:compilation_rule_content] || '')

    FileUtils.mkdir_p('content')
    FileUtils.mkdir_p('layouts')
    FileUtils.mkdir_p('lib')
    FileUtils.mkdir_p('output')

    if params[:has_layout]
      File.open('layouts/default.html', 'w') do |io|
        io.write('... <%= @yield %> ...')
      end
    end

    File.write('nanoc.yaml', 'stuff: 12345')
    File.write('Rules', rules_content)
  end

  def setup
    # Enter tmp
    @tmp_dir = Dir.mktmpdir('nanoc-test')
    @orig_wd = FileUtils.pwd
    FileUtils.cd(@tmp_dir)
  end

  def teardown
    # Exit tmp
    FileUtils.cd(@orig_wd)
    FileUtils.rm_rf(@tmp_dir)
  end

  def capturing_stdio(&block)
    # Store
    orig_stdout = $stdout
    orig_stderr = $stderr

    # Run
    $stdout = StringIO.new
    $stderr = StringIO.new
    yield
    { :stdout => $stdout.string, :stderr => $stderr.string }
  ensure
    # Restore
    $stdout = orig_stdout
    $stderr = orig_stderr
  end

  # Adapted from http://github.com/lsegal/yard-examples/tree/master/doctest
  def assert_examples_correct(object)
    P(object).tags(:example).each do |example|
      # Classify
      lines = example.text.lines.map do |line|
        [ line =~ /^\s*# ?=>/ ? :result : :code, line ]
      end

      # Join
      pieces = []
      lines.each do |line|
        if !pieces.empty? && pieces.last.first == line.first
          pieces.last.last << line.last
        else
          pieces << line
        end
      end
      lines = pieces.map { |p| p.last }

      # Test
      b = binding
      lines.each_slice(2) do |pair|
        actual_out   = eval(pair.first, b)
        expected_out = eval(pair.last.match(/# ?=>(.*)/)[1], b)

        assert_equal expected_out, actual_out,
          "Incorrect example:\n#{pair.first}"
      end
    end
  end

  def assert_contains_exactly(expected, actual)
    assert_equal expected.size, actual.size,
      'Expected %s to be of same size as %s' % [actual.inspect, expected.inspect]
    remaining = actual.dup.to_a
    expected.each do |e|
      index = remaining.index(e)
      remaining.delete_at(index) if index
    end
    assert remaining.empty?,
      'Expected %s to contain all the elements of %s' % [actual.inspect, expected.inspect]
  end

  def assert_raises_frozen_error
    error = assert_raises(RuntimeError, TypeError) { yield }
    assert_match(/(^can't modify frozen |^unable to modify frozen object$)/, error.message)
  end

  def with_env_vars(hash, &block)
    orig_env_hash = ENV.to_hash
    hash.each_pair { |k,v| ENV[k] = v }
    yield
  ensure
    orig_env_hash.each_pair { |k,v| ENV[k] = v }
  end

  def on_windows?
    Nanoc.on_windows?
  end

  def have_command?(cmd)
    which, null = on_windows? ? ["where", "NUL"] : ["which", "/dev/null"]
    system("#{which} #{cmd} > #{null} 2>&1")
  end

  def have_symlink?
    File.symlink nil, nil
  rescue NotImplementedError
    return false
  rescue
    return true
  end

  def skip_unless_have_command(cmd)
    skip "Could not find external command \"#{cmd}\"" unless have_command?(cmd)
  end

  def skip_unless_have_symlink
    skip "Symlinks are not supported by Ruby on Windows" unless have_symlink?
  end

end

class Nanoc::TestCase < Minitest::Test

  include Nanoc::TestHelpers

end

# Unexpected system exit is unexpected
::Minitest::Test::PASSTHROUGH_EXCEPTIONS.delete(SystemExit)

# A more precise inspect method for Time improves assert failure messages.
#
class Time
  def inspect
    strftime("%a %b %d %H:%M:%S.#{"%06d" % usec} %Z %Y")
  end
end
