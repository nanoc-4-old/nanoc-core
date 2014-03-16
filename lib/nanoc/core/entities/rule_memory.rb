# encoding: utf-8

module Nanoc

  class RuleMemory

    include Enumerable

    attr_reader :steps

    def initialize(item_rep)
      @item_rep = item_rep

      @steps = []
    end

    def add_filter(filter_name, params)
      @steps << Nanoc::RuleMemoryActions::Filter.new(filter_name, params)
    end

    def add_layout(layout_identifier, params)
      @steps << Nanoc::RuleMemoryActions::Layout.new(layout_identifier, params)
    end

    def add_snapshot(snapshot_name, path, final)
      step = Nanoc::RuleMemoryActions::Snapshot.new(snapshot_name, path, final)

      snapshot_added(snapshot_name)

      @steps << step
    end

    def add_write(path, snapshot_name)
      step = Nanoc::RuleMemoryActions::Write.new(path, snapshot_name)

      if snapshot_name
        snapshot_added(snapshot_name)
      end

      @steps << step
    end

    def serialize
      @steps.map { |s| s.serialize }
    end

    def each(&block)
      @steps.each(&block)
    end

  private

    def snapshot_added(name)
      @_snapshot_names ||= Set.new
      if @_snapshot_names.include?(name)
        raise Nanoc::Errors::CannotCreateMultipleSnapshotsWithSameName.new(@item_rep, name)
      else
        @_snapshot_names << name
      end
    end

  end

end
