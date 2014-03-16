# encoding: utf-8

class Nanoc::ItemRepViewForFilteringTest < Nanoc::TestCase

  def setup
    super

    @snapshot_store = Nanoc::SnapshotStore::InMemory.new
    @content = Nanoc::TextualContent.new('blah blah blah', File.absolute_path('content/somefile.md'))
    @item = Nanoc::Item.new(@content, {}, '/index.md')
    @item_rep = Nanoc::ItemRep.new(@item, :foo, :snapshot_store => @snapshot_store, config: Nanoc::Configuration.new({}))
    def @item_rep.compiled_content(params={}) ; "default content at #{params[:snapshot].inspect}" ; end
    def @item_rep.path(params={}) ; "default path at #{params[:snapshot].inspect}" ; end
    def @item_rep.raw_path(params={}) ; "default raw path at #{params[:snapshot].inspect}" ; end
    @item_rep_store = Nanoc::ItemRepStore.new([ @item_rep ])

    @subject = Nanoc::ItemRepViewForFiltering.new(@item_rep, @item_rep_store)
  end

  def test_resolve
    assert_equal @item_rep, @subject.resolve
  end

  def test_name
    assert_equal :foo, @subject.name
  end

  def test_compiled_content
    assert_equal 'default content at :qux', @subject.compiled_content(:snapshot => :qux)
  end

  def test_path
    assert_equal 'default path at :qux', @subject.path(:snapshot => :qux)
  end

  def test_raw_path
    assert_equal 'default raw path at :qux', @subject.raw_path(:snapshot => :qux)
  end

  def test_item
    refute_equal @item, @subject.item
    assert_equal @item, @subject.item.resolve
  end

  def test_inspect
    assert_match(/Nanoc::ItemRep*/, @subject.inspect)
  end

end
