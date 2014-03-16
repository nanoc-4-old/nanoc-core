# encoding: utf-8

module Nanoc

  # Represents an item representation, but provides an interface that is
  # easier to use when writing compilation and routing rules. It is also
  # responsible for fetching the necessary information from the compiler, such
  # as assigns.
  #
  # The API provided by item representation proxies allows layout identifiers
  # to be given as literals instead of as references to {Nanoc::Layout}.
  class ItemRepViewForRuleProcessing

    extend Forwardable

    # TODO do not delegate :item (return item view instead)
    def_delegators :@item_rep, :item, :name, :binary, :binary?, :compiled_content, :has_snapshot?, :path

    # @param [Nanoc::ItemRep] item_rep The item representation that this
    #   proxy should behave like
    #
    # @param [Nanoc::Compiler] compiler The compiler that will provide the
    #   necessary compilation-related functionality.
    def initialize(item_rep, compiler)
      @item_rep = item_rep
      @compiler = compiler
    end

    # Runs the item content through the given filter with the given arguments.
    # This method will replace the content of the `:last` snapshot with the
    # filtered content of the last snapshot.
    #
    # This method is supposed to be called only in a compilation rule block
    # (see {Nanoc::CompilerDSL#compile}).
    #
    # @see Nanoc::ItemRep#filter
    #
    # @param [Symbol] name The name of the filter to run the item
    #   representations' content through
    #
    # @param [Hash] args The filter arguments that should be passed to the
    #   filter's #run method
    #
    # @return [void]
    def filter(name, args={})
      assigns = @compiler.assigns_for(@item_rep)
      @item_rep.filter(name, args, assigns)
    end

    # Lays out the item using the given layout. This method will replace the
    # content of the `:last` snapshot with the laid out content of the last
    # snapshot.
    #
    # This method is supposed to be called only in a compilation rule block
    # (see {Nanoc::CompilerDSL#compile}).
    #
    # @see Nanoc::ItemRep#layout
    #
    # @param [String] layout_identifier The identifier of the layout to use
    #
    # @return [void]
    def layout(layout_identifier, extra_filter_args={})
      layout = layout_with_identifier(layout_identifier)
      filter_name, filter_args = @compiler.rules_collection.filter_for_layout(layout)
      filter_args = filter_args.merge(extra_filter_args)

      assigns = @compiler.assigns_for(@item_rep)
      @item_rep.layout(layout, filter_name, filter_args, assigns)
    end

    def write(path, params={})
      @compiler.write_rep(@item_rep, path)

      if params.has_key?(:snapshot)
        @item_rep.snapshot(params[:snapshot], path: path)
      end
    end

    def snapshot(snapshot, params={})
      @item_rep.snapshot(snapshot, params)
    end

  private

    def layouts
      @compiler.site.layouts
    end

    def layout_with_identifier(layout_identifier)
      layout_identifier = Nanoc::Identifier.coerce(layout_identifier)
      layout = layouts.find { |l| l.identifier == layout_identifier }
      raise Nanoc::Errors::UnknownLayout.new(layout_identifier) if layout.nil?
      layout
    end

  end

end
