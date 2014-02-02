# encoding: utf-8

class Nanoc::DataSources::FilesystemTest < Nanoc::TestCase

  def setup
    super

    @old_pwd = Dir.getwd
    create_site_here
    FileUtils.cd('content')
    config = Nanoc::SiteLoader::DEFAULT_DATA_SOURCE_CONFIG
    @data_source = Nanoc::DataSources::Filesystem.new(nil, nil, config)
  end

  def teardown
    FileUtils.cd(@old_pwd)

    super
  end

  def test_all_base_filenames_in
    File.write('index.html',        'x')
    File.write('reviews.html',      'x')
    File.write('reviews.html.yaml', 'x')
    File.write('meta.yaml',         'x')

    expected_filenames = %w( ./index.html ./reviews.html ./meta ).sort
    actual_filenames   = @data_source.send(:all_base_filenames_in, '.').sort

    assert_equal(expected_filenames, actual_filenames)
  end

  def test_all_base_filenames_in_without_stray_files
    FileUtils.mkdir_p('foo')
    File.write('foo/ugly.html',      'stuff')
    File.write('foo/ugly.html~',     'stuff')
    File.write('foo/ugly.html.orig', 'stuff')
    File.write('foo/ugly.html.rej',  'stuff')
    File.write('foo/ugly.html.bak',  'stuff')

    expected_filenames = %w( ./foo/ugly.html )
    actual_filenames   = @data_source.send(:all_base_filenames_in, '.')

    assert_equal(expected_filenames, actual_filenames)
  end

  def test_binary_extension?
    assert @data_source.send(:binary_extension?, 'foo')
    refute @data_source.send(:binary_extension?, 'txt')
  end

  def test_content_and_attributes_for_file_with_metadata
    filename = 'foo.txt'
    data = "---\nfoo: 123\n---\n\nHello!"
    File.write(filename, data)

    actual_content, actual_attributes =
      @data_source.send(:content_and_attributes_for_file, filename)

    expected_content, expected_attributes =
      "Hello!", { "foo" => 123 }

    assert_equal expected_content, actual_content.string
    assert_equal expected_attributes, actual_attributes
  end

  def test_content_and_attributes_for_file_without_metadata
    filename = 'foo.txt'
    data = "stuff and stuff"
    File.write(filename, data)

    actual_content, actual_attributes =
      @data_source.send(:content_and_attributes_for_file, filename)

    expected_content, expected_attributes =
      data, {}

    assert_equal expected_content, actual_content.string
    assert_equal expected_attributes, actual_attributes
  end

  def test_content_and_attributes_for_file_with_incorrectly_formatted_metadata_section
    filename = 'foo.txt'
    data = "-----\nfoo: 123\n-----\n\nHello!"
    File.write(filename, data)

    actual_content, actual_attributes =
      @data_source.send(:content_and_attributes_for_file, filename)

    expected_content, expected_attributes =
      data, {}

    assert_equal expected_content, actual_content.string
    assert_equal expected_attributes, actual_attributes
  end

  def test_content_and_attributes_for_file_with_not_enough_separators
    filename = 'foo.txt'
    data = "---\nfoo: 123\n-----\n\nHello!"
    File.write(filename, data)

    assert_raises(Nanoc::DataSources::Filesystem::EmbeddedMetadataParseError) do
      @data_source.send(:content_and_attributes_for_file, filename)
    end
  end

  def test_content_and_attributes_for_file_with_invalid_yaml
    filename = 'foo.txt'
    data = "---\nfoo : bar : baz\n---\n\nHello!"
    File.write(filename, data)

    assert_raises(Nanoc::DataSources::Filesystem::CannotParseYAMLError) do
      @data_source.send(:content_and_attributes_for_file, filename)
    end
  end

  def test_content_and_attributes_for_file_with_diff
    filename = 'foo.txt'
    data = "--- a/foo\n" \
      "+++ b/foo\n" \
      "blah blah\n"
    File.write(filename, data)

    actual_content, actual_attributes =
      @data_source.send(:content_and_attributes_for_file, filename)

    expected_content, expected_attributes =
      data, {}

    assert_equal expected_content, actual_content.string
    assert_equal expected_attributes, actual_attributes
  end

  def test_items
    FileUtils.mkdir_p('content')
    File.write('content/foo.html',      'stuff')
    File.write('content/foo.html.yaml', 'ugly: true')

    items = @data_source.items
    assert_equal 1, items.size
    assert_equal 'stuff',        items.first.content.string
    assert_equal '/foo.html',    items.first.identifier.to_s
    assert_equal({ ugly: true }, items.first.attributes)
  end

  def test_items_binary
    FileUtils.mkdir_p('content')
    File.write('content/foo.txt', 'stuff')
    File.write('content/foo.jpg', 'stuff')

    items = @data_source.items
    assert_equal 2, items.size
    refute items.find { |i| i.identifier == '/foo.txt' }.binary?
    assert items.find { |i| i.identifier == '/foo.jpg' }.binary?
  end

  def test_read_default_encoding
    File.write('foo.txt', 'Hëllö')
    assert_equal 'Hëllö', @data_source.read('foo.txt')
  end

  def test_parse_utf8_bom
    File.open('test.html', 'w') do |io|
      io.write [ 0xEF, 0xBB, 0xBF ].map { |i| i.chr }.join
      io.write "---\n"
      io.write "utf8bomawareness: high\n"
      io.write "---\n"
      io.write "content goes here\n"
    end

    result = @data_source.instance_eval { content_and_attributes_for_file('test.html') }
    assert_equal('content goes here', result[0].string)
    assert_equal({ 'utf8bomawareness' => 'high' }, result[1])
  end

  def test_read_other_encoding
    File.write('foo.txt', 'Hëllö'.encode('ISO-8859-1'))

    error = assert_raises(ArgumentError) do
      @data_source.read('foo.txt')
    end
    assert_equal 'invalid byte sequence in UTF-8', error.message

    begin
      @data_source.config[:encoding] = 'ISO-8859-1'
      assert_equal 'Hëllö', @data_source.read('foo.txt')
    ensure
      @data_source.config[:encoding] = 'UTF-8'
    end
  end

  def test_read_utf8_bom
    File.write('test.html', [ 0xEF, 0xBB, 0xBF ].map { |i| i.chr }.join + 'stuff')

    assert_equal 'stuff', @data_source.read('test.html')
  end

  def test_setup
    # Recreate files
    @data_source.setup

    # Ensure essential files have been recreated
    assert(File.directory?('content/'))
    assert(File.directory?('layouts/'))

    # Ensure no non-essential files have been recreated
    assert(!File.file?('content/index.html'))
    assert(!File.file?('layouts/default.html'))
    refute(File.directory?('lib/'))
  end

  def test_items_in_custom_dirs
    FileUtils.mkdir_p('foo')
    File.write('foo/foo.html',      'stuff')
    File.write('foo/foo.html.yaml', 'ugly: true')

    begin
      @data_source.config[:content_dir] = 'foo'
      items = @data_source.items
      assert_equal 1, items.size
      assert_equal 'stuff',        items.first.content.string
      assert_equal '/foo.html',    items.first.identifier.to_s
      assert_equal({ ugly: true }, items.first.attributes)
    ensure
      @data_source.config[:content_dir] = 'content'
    end
  end

  def test_layouts_in_custom_dirs
    FileUtils.mkdir_p('foo')
    File.write('foo/foo.html',      'stuff')
    File.write('foo/foo.html.yaml', 'ugly: true')

    begin
      @data_source.config[:layouts_dir] = 'foo'
      layouts = @data_source.layouts
      assert_equal 1, layouts.size
      assert_equal 'stuff',        layouts.first.content.string
      assert_equal '/foo.html',    layouts.first.identifier.to_s
      assert_equal({ ugly: true }, layouts.first.attributes)
    ensure
      @data_source.config[:layouts_dir] = 'layouts'
    end
  end

  def test_item_with_identifier
    FileUtils.mkdir_p('content')
    FileUtils.mkdir_p('content/meh')

    File.write('content/foo.md',          'stuff')
    File.write('content/foo.md.yaml',     'ugly: true')
    File.write('content/bar.md',          'stuff')
    File.write('content/bar.md.yaml',     'ugly: true')
    File.write('content/meh/bar.md',      'stuff')
    File.write('content/meh/bar.md.yaml', 'ugly: true')

    assert_nil @data_source.item_with_identifier('heh')
    assert_nil @data_source.item_with_identifier('content/foo.md')
    refute_nil @data_source.item_with_identifier('/foo.md')
    refute_nil @data_source.item_with_identifier('/bar.md')
    refute_nil @data_source.item_with_identifier('/meh/bar.md')
    assert_nil @data_source.item_with_identifier('foo.md')
  end

  def test_glob_items
    FileUtils.mkdir_p('content')
    FileUtils.mkdir_p('content/meh')

    File.write('content/foo.md',          'stuff')
    File.write('content/foo.md.yaml',     'ugly: true')
    File.write('content/bar.md',          'stuff')
    File.write('content/bar.md.yaml',     'ugly: true')
    File.write('content/meh/bar.md',      'stuff')
    File.write('content/meh/bar.md.yaml', 'ugly: true')

    assert_equal 0, @data_source.glob_items('heh').size
    assert_equal 0, @data_source.glob_items('*.md').size
    assert_equal 2, @data_source.glob_items('/*.md').size
    assert_equal 0, @data_source.glob_items('content/*.md').size
    assert_equal 3, @data_source.glob_items('/**/*.md').size
    assert_equal 2, @data_source.glob_items('/**/bar.md').size
  end

end
