# encoding: utf-8

module Nanoc

  class RuleMemoryAction

    def serialize
      raise NotImplementedError.new('Nanoc::RuleMemoryAction subclasses must implement #serialize and #to_s')
    end

    def to_s
      raise NotImplementedError.new('Nanoc::RuleMemoryAction subclasses must implement #serialize and #to_s')
    end

    def inspect
      "<%s %s>" % [ self.class.to_s, self.serialize[1..-1].map { |e| e.inspect }.join(', ') ]
    end

  end

end
