# encoding: utf-8

module Nanoc

  # Represents the site configuration.
  class Configuration

    # Creates a new configuration with the given hash.
    #
    # @param [Hash] hash The actual configuration hash
    def initialize(hash)
      @hash = hash
    end

    # @see Hash#[]
    def [](key)
      @hash[key]
    end

    # @see Hash#fetch
    def fetch(key, value)
      @hash.fetch(key, value)
    end

    # @see Hash#[]=
    def []=(key, value)
      @hash[key] = value
    end

    # @return [String] The checksum for this configuration
    def checksum
      @hash.checksum
    end

    # @see Hash#freeze_recursively
    def freeze_recursively
      freeze
      @hash.freeze_recursively
    end

    # Returns an object that can be used for uniquely identifying objects.
    #
    # @return [Object] An unique reference to this object
    def reference
      :config
    end

  end

end
