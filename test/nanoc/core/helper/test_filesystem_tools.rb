# encoding: utf-8

class Nanoc::FilesystemToolsTest < Nanoc::TestCase

  def setup
    super
    skip_unless_have_symlink
  end

  def test_all_files_in_follows_symlinks_to_dirs
    if 'jruby' == RUBY_ENGINE && '1.7.4' == JRUBY_VERSION
      skip 'Symlink behavior on JRuby is known to be broken (see https://github.com/jruby/jruby/issues/1036)'
    end

    # Write sample files
    (0..15).each do |i|
      FileUtils.mkdir_p("dir#{i}")
      File.write("dir#{i}/foo.md", 'o hai')
    end
    (1..10).each do |i|
      File.symlink("../dir#{i}", "dir#{i - 1}/sub")
    end

    # Check
    # 11 expected files (follow symlink 10 times)
    # sort required because 10 comes before 2
    expected_files = [
      'dir0/foo.md',
      'dir0/sub/foo.md',
      'dir0/sub/sub/foo.md',
      'dir0/sub/sub/sub/foo.md',
      'dir0/sub/sub/sub/sub/foo.md',
      'dir0/sub/sub/sub/sub/sub/foo.md',
      'dir0/sub/sub/sub/sub/sub/sub/foo.md',
      'dir0/sub/sub/sub/sub/sub/sub/sub/foo.md',
      'dir0/sub/sub/sub/sub/sub/sub/sub/sub/foo.md',
      'dir0/sub/sub/sub/sub/sub/sub/sub/sub/sub/foo.md',
      'dir0/sub/sub/sub/sub/sub/sub/sub/sub/sub/sub/foo.md'
    ]
    actual_files = Nanoc::FilesystemTools.all_files_in('dir0').sort
    assert_equal expected_files, actual_files
  end

  def test_all_files_in_follows_symlinks_to_dirs_too_many
    # Write sample files
    (0..15).each do |i|
      FileUtils.mkdir_p("dir#{i}")
      File.write("dir#{i}/foo.md", 'o hai')
    end
    (1..15).each do |i|
      File.symlink("../dir#{i}", "dir#{i - 1}/sub")
    end

    assert_raises Nanoc::FilesystemTools::MaxSymlinkDepthExceededError do
      Nanoc::FilesystemTools.all_files_in('dir0')
    end
  end

  def test_all_files_in_relativizes_directory_names
    if 'jruby' == RUBY_ENGINE && '1.7.4' == JRUBY_VERSION
      skip 'Symlink behavior on JRuby is known to be broken (see https://github.com/jruby/jruby/issues/1036)'
    end

    FileUtils.mkdir('foo')
    FileUtils.mkdir('bar')

    File.write('foo/x.md', 'o hai from foo/x')
    File.write('bar/y.md', 'o hai from bar/y')

    File.symlink('../bar', 'foo/barlink')

    expected_files = [ 'foo/barlink/y.md', 'foo/x.md' ]
    actual_files   = Nanoc::FilesystemTools.all_files_in('foo').sort
    assert_equal expected_files, actual_files
  end

  def test_all_files_in_follows_symlinks_to_files
    # Write sample files
    File.write('bar', 'o hai from bar')
    FileUtils.mkdir_p('dir')
    File.write('dir/foo', 'o hai from foo')
    File.symlink('../bar', 'dir/bar-link')

    # Check
    expected_files = [ 'dir/bar-link', 'dir/foo' ]
    actual_files   = Nanoc::FilesystemTools.all_files_in('dir').sort
    assert_equal expected_files, actual_files
  end

  def test_resolve_symlink
    File.write('foo', 'o hai')
    File.symlink('foo', 'bar')
    File.symlink('bar', 'baz')
    File.symlink('baz', 'qux')

    expected = File.expand_path('foo')
    actual   = Nanoc::FilesystemTools.resolve_symlink('qux')
    assert_equal expected, actual
  end

  def test_resolve_symlink_too_many
    File.write('foo', 'o hai')
    File.symlink('foo', 'symlink-0')
    (1..7).each do |i|
      File.symlink("symlink-#{i - 1}", "symlink-#{i}")
    end

    # 5 is OK
    Nanoc::FilesystemTools.resolve_symlink('symlink-5')

    # More than 5 is not OK
    assert_raises Nanoc::FilesystemTools::MaxSymlinkDepthExceededError do
      Nanoc::FilesystemTools.resolve_symlink('symlink-6')
    end
  end

end
