# encoding: utf-8

module Nanoc
  # The in-memory representation of a nanoc site.
  class Site
    # @return [Nanoc::Configuration]
    attr_reader :config

    # @return [Enumerable<Nanoc::CodeSnippet>]
    attr_reader :code_snippets

    # @return [Enumerable<Nanoc::DataSource>]
    attr_reader :data_sources

    # @return [Enumerable<Nanoc::Item>]
    attr_reader :items

    # @return [Enumerable<Nanoc::Layout>]
    attr_reader :layouts

    # @param [Hash] data A hash containing the `:config`, `:code_snippets`, `:data_sources`, `:items` and `:layouts`.
    def initialize(data)
      @config        = data.fetch(:config)
      @code_snippets = data.fetch(:code_snippets)
      @data_sources  = data.fetch(:data_sources)
      @items         = data.fetch(:items)
      @layouts       = data.fetch(:layouts)
    end

    # Prevents all further modifications to itself, its items, its layouts etc.
    #
    # @return [void]
    def freeze
      super

      config.freeze_recursively

      items.freeze
      items.each(&:freeze)

      layouts.freeze
      layouts.each(&:freeze)

      code_snippets.freeze
      code_snippets.each(&:freeze)
    end
  end
end
