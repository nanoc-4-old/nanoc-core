# encoding: utf-8

class Nanoc::IdentifierTest < Nanoc::TestCase

  def new_from_string(string)
    Nanoc::Identifier.from_string(string)
  end

  def test_examples
    YARD.parse(File.dirname(__FILE__) + '/../../../../lib/nanoc/core/entities/identifier.rb')

    assert_examples_correct 'Nanoc::Identifier#+'
    assert_examples_correct 'Nanoc::Identifier#append_component'
    assert_examples_correct 'Nanoc::Identifier#extension'
    assert_examples_correct 'Nanoc::Identifier#in_dir'
    assert_examples_correct 'Nanoc::Identifier#match?'
    assert_examples_correct 'Nanoc::Identifier#parent'
    assert_examples_correct 'Nanoc::Identifier#to_s'
    assert_examples_correct 'Nanoc::Identifier#with_ext'
    assert_examples_correct 'Nanoc::Identifier#without_ext'
  end

  def test_from_string
    assert_equal %w( ), self.new_from_string('').components

    assert_equal %w( foo bar ), self.new_from_string('foo/bar').components
    assert_equal %w( foo bar ), self.new_from_string('/foo/bar').components
  end

  def test_from_string_invalid
    assert_raises(Nanoc::Errors::IdentifierCannotEndWithSlashError) do
      self.new_from_string('/')
    end

    assert_raises(Nanoc::Errors::IdentifierCannotEndWithSlashError) do
      self.new_from_string('/foo/')
    end
  end

  def test_coerce
    string     = '/foo/bar'
    identifier = Nanoc::Identifier.from_string(string)

    assert_equal %w( foo bar ), Nanoc::Identifier.coerce(string).components
    assert_equal %w( foo bar ), Nanoc::Identifier.coerce(identifier).components
  end

  def test_equal
    a = self.new_from_string('/foo/bar')
    b = self.new_from_string('foo/bar')

    refute a.equal?(b)

    assert a.eql?(b)
    assert a == b
    assert a === b
  end

  def test_to_s
    assert_equal '/foo/bar.md', self.new_from_string('/foo/bar.md').to_s
    assert_equal '/foo.md',     self.new_from_string('/foo.md').to_s
  end

  def test_parent
    assert_equal '/foo/bar', self.new_from_string('/foo/bar/qux').parent.to_s
    assert_equal '/foo',     self.new_from_string('/foo/bar').parent.to_s
    assert_nil self.new_from_string('/foo').parent
  end

  def test_match?
    assert self.new_from_string('foo/bar/qux.md').match?('/foo/*/qux.*')
    assert !self.new_from_string('foo/bar/qux.md').match?('foo/*/qux.*')

    assert self.new_from_string('src/file.c').match?('/src/file.[ch]')
    assert !self.new_from_string('src/file.m').match?('/src/file.[ch]')

    assert !self.new_from_string('foo/bar/baz/qux.c').match?('/foo/*.c')

    # { } is not supported (yet)
    assert !self.new_from_string('src/file.md').match?('/src/file.{md,txt}')
    assert !self.new_from_string('src/file.bbq').match?('/src/file.{md,txt}')
  end

  def test_with_ext_without_extension
    assert_equal '/foo.md', self.new_from_string('/foo').with_ext('md').to_s
  end

  def test_with_ext_with_extension
    assert_equal '/foo.md', self.new_from_string('/foo.txt').with_ext('md').to_s
  end

  def test_without_ext_without_extension
    assert_equal '/foo', self.new_from_string('/foo').without_ext.to_s
  end

  def test_without_ext_with_extension
    assert_equal '/foo', self.new_from_string('/foo.txt').without_ext.to_s
  end

  def test_extension_with_extension
    assert_equal 'md', self.new_from_string('/foo.md').extension
  end

  def test_extension_without_extension
    assert_equal nil, self.new_from_string('/foo').extension
  end

  def test_in_dir
    assert_equal '/foo/index.md',   self.new_from_string('/foo.md').in_dir.to_s
    assert_equal '/foo/index.html', self.new_from_string('/foo.md').in_dir.with_ext('html').to_s
    assert_equal '/foo/index.html', self.new_from_string('/foo.md').with_ext('html').in_dir.to_s
  end

  def test_append_component
    assert_equal '/foo/bar', self.new_from_string('/foo').append_component('bar').to_s
  end

  def test_plus
    assert_equal '/fooSTUFF', self.new_from_string('/foo') + 'STUFF'
  end

end
