# encoding: utf-8

module Nanoc
  module RuleMemoryActions
    class Filter < Nanoc::RuleMemoryAction
      # filter :foo
      # filter :foo, params

      def initialize(filter_name, params)
        @filter_name = filter_name
        @params      = params
      end

      def serialize
        [:filter, @filter_name, @params]
      end

      def to_s
        "filter #{@filter_name.inspect}, #{@params.inspect}"
      end
    end
  end
end
