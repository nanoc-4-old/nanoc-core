# encoding: utf-8

module Nanoc

  # Responsible for compiling a site’s item representations.
  #
  # The compilation process makes use of notifications (see
  # {Nanoc::NotificationCenter}) to track dependencies between items,
  # layouts, etc. The following notifications are used:
  #
  # * `compilation_started` — indicates that the compiler has started
  #   compiling this item representation. Has one argument: the item
  #   representation itself. Only one item can be compiled at a given moment;
  #   therefore, it is not possible to get two consecutive
  #   `compilation_started` notifications without also getting a
  #   `compilation_ended` notification in between them.
  #
  # * `compilation_ended` — indicates that the compiler has finished compiling
  #   this item representation (either successfully or with failure). Has one
  #   argument: the item representation itself.
  #
  # * `visit_started` — indicates that the compiler requires content or
  #   attributes from the item representation that will be visited. Has one
  #   argument: the visited item identifier. This notification is used to
  #   track dependencies of items on other items; a `visit_started` event
  #   followed by another `visit_started` event indicates that the item
  #   corresponding to the former event will depend on the item from the
  #   latter event.
  #
  # * `visit_ended` — indicates that the compiler has finished visiting the
  #   item representation and that the requested attributes or content have
  #   been fetched (either successfully or with failure)
  #
  # * `processing_started` — indicates that the compiler has started
  #   processing the specified object, which can be an item representation
  #   (when it is compiled) or a layout (when it is used to lay out an item
  #   representation or when it is used as a partial)
  #
  # * `processing_ended` — indicates that the compiler has finished processing
  #   the specified object.
  class Compiler

    extend Nanoc::Memoization

    # @group Accessors

    # @return [Nanoc::Site] The site this compiler belongs to
    attr_reader :site

    # FIXME ugly
    attr_reader :item_rep_store
    attr_reader :item_rep_writer
    attr_reader :outdatedness_checker

    # @group Public instance methods

    # Creates a new compiler for the given site
    #
    # @param [Nanoc::Site] site The site this compiler belongs to
    #
    # TODO document dependencies
    def initialize(site, dependencies={})
      @site = site
      @dependency_tracker     = dependencies[:dependency_tracker]
      @rules_store            = dependencies[:rules_store]
      @checksum_store         = dependencies[:checksum_store]
      @compiled_content_cache = dependencies[:compiled_content_cache]
      @rule_memory_store      = dependencies[:rule_memory_store]
      @snapshot_store         = dependencies[:snapshot_store]
      @item_rep_writer        = dependencies[:item_rep_writer]
      @rule_memory_calculator = dependencies[:rule_memory_calculator]
      @item_rep_store         = dependencies[:item_rep_store]
      @outdatedness_checker   = dependencies[:outdatedness_checker]
      @preprocessor           = dependencies[:preprocessor]
    end

    # Compiles the site and writes out the compiled item representations.
    #
    def run
      @preprocessor.run
      @dependency_tracker.start
      compile_reps(self.item_rep_store.reps)
      @dependency_tracker.stop
      store
      prune
    ensure
      # Cleanup
      FileUtils.rm_rf(Nanoc::Filter::TMP_BINARY_ITEMS_DIR)
      FileUtils.rm_rf(Nanoc::FilesystemItemRepWriter::TMP_TEXT_ITEMS_DIR)
    end

    # @group Private instance methods

    # Store the modified helper data used for compiling the site.
    #
    # @api private
    #
    # @return [void]
    def store
      # Calculate rule memory
      (self.item_rep_store.reps + @site.layouts).each do |obj|
        @rule_memory_store[obj] = @rule_memory_calculator[obj]
      end

      # Calculate checksums
      (site.items + site.layouts + site.code_snippets + [ site.config ]).each do |obj|
        @checksum_store[obj] = obj.checksum
      end
      @checksum_store[self.rules_collection] = @rules_store.rule_data

      # Store
      @checksum_store.store
      @compiled_content_cache.store
      @dependency_tracker.store
      @rule_memory_store.store
    end

    def write_rep(rep, path)
      @item_rep_writer.write(rep, path.to_s)
    end

    # @param [Nanoc::ItemRep] rep The item representation for which the
    #   assigns should be fetched
    #
    # @return [Hash] The assigns that should be used in the next filter/layout
    #   operation
    #
    # @api private
    def assigns_for(rep)
      if rep.snapshot_binary?(:last)
        content_or_filename_assigns = { :filename => rep.temporary_filenames[:last] }
      else
        content_or_filename_assigns = { :content => rep.stored_content_at_snapshot(:last) }
      end

      content_or_filename_assigns.merge({
        :item       => Nanoc::ItemView.new(rep.item, self.item_rep_store),
        :rep        => Nanoc::ItemRepView.new(rep, self.item_rep_store),
        :item_rep   => Nanoc::ItemRepView.new(rep, self.item_rep_store),
        :items      => Nanoc::ItemArray.new.tap { |a| site.items.each { |i| a << Nanoc::ItemView.new(i, self.item_rep_store) }},
        :layouts    => site.layouts,
        :config     => site.config,
        :site       => site,
        :_compiler  => self
      })
    end

    def rules_collection
      @rules_store.rules_collection
    end

  private

    # Compiles the given representations.
    #
    # @param [Array] reps The item representations to compile.
    #
    # @return [void]
    def compile_reps(reps)
      content_dependency_graph = Nanoc::DirectedGraph.new(reps)

      # Assign snapshots
      reps.each do |rep|
        rep.snapshots = @rule_memory_calculator.snapshots_for(rep)
      end

      # Attempt to compile all active reps
      loop do
        # Find rep to compile
        break if content_dependency_graph.roots.empty?
        rep = content_dependency_graph.roots.each { |e| break e }

        begin
          compile_rep(rep)
          content_dependency_graph.delete_vertex(rep)
          # TODO call store here for incremental compilation support
        rescue Nanoc::Errors::UnmetDependency => e
          content_dependency_graph.add_edge(e.rep, rep)
          unless content_dependency_graph.vertices.include?(e.rep)
            content_dependency_graph.add_vertex(e.rep)
          end
        end
      end

      # Check whether everything was compiled
      if !content_dependency_graph.vertices.empty?
        raise Nanoc::Errors::RecursiveCompilation.new(content_dependency_graph.vertices)
      end
    ensure
      Nanoc::NotificationCenter.remove(:processing_started, self)
      Nanoc::NotificationCenter.remove(:processing_ended,   self)
    end

    # Compiles the given item representation.
    #
    # This method should not be called directly; please use
    # {Nanoc::Compiler#run} instead, and pass this item representation's item
    # as its first argument.
    #
    # @param [Nanoc::ItemRep] rep The rep that is to be compiled
    #
    # @return [void]
    def compile_rep(rep)
      Nanoc::NotificationCenter.post(:compilation_started, rep)
      Nanoc::NotificationCenter.post(:processing_started,  rep)
      Nanoc::NotificationCenter.post(:visit_started,       rep.item)

      # Calculate rule memory if we haven’t yet done so
      @rule_memory_calculator.new_rule_memory_for_rep(rep)

      # Assign raw paths for non-snapshot rules
      rep.paths_without_snapshot = @rule_memory_calculator.write_paths_for(rep)

      if !rep.item.forced_outdated? && !@outdatedness_checker.outdated?(rep) && @compiled_content_cache[rep]
        # Reuse content
        Nanoc::NotificationCenter.post(:cached_content_used, rep)
        rep.content = @compiled_content_cache[rep]
      else
        @dependency_tracker.forget_dependencies_for(rep.item)

        # Recalculate content
        rep_proxy = Nanoc::ItemRepRulesProxy.new(rep, self)
        rules_collection.compilation_rule_for(rep).apply_to(rep_proxy, site)
        rep.snapshot(:last)
      end

      rep.compiled = true
      @compiled_content_cache[rep] = rep.content

      Nanoc::NotificationCenter.post(:visit_ended,       rep.item)
      Nanoc::NotificationCenter.post(:processing_ended,  rep)
      Nanoc::NotificationCenter.post(:compilation_ended, rep)
    rescue => e
      rep.forget_progress
      Nanoc::NotificationCenter.post(:compilation_failed, rep, e)
      raise e
    end

    def prune
      if self.site.config[:prune][:auto_prune]
        identifier = @item_rep_writer.class.identifier
        pruner_class = Nanoc::Pruner.named(identifier)
        exclude = self.site.config.fetch(:prune, {}).fetch(:exclude, [])
        pruner_class.new(self.site, :exclude => exclude).run
      end
    end

  end

end
