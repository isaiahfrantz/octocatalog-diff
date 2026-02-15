# frozen_string_literal: true

# Monkey patch for JSON::Ext::Generator::State to add Ruby 3.0+ Hash methods
# that are expected by Puppet 8 but not present in the C-extension State class.
#
# Ruby 3.0 added Hash#except, but JSON::Ext::Generator::State (a C extension class)
# doesn't have this method, causing "undefined method `except'" errors when
# Puppet tries to treat State objects as Hashes.

require 'json'

if defined?(JSON::Ext::Generator::State)
  # Only patch if we're using the C extension version of JSON
  class JSON::Ext::Generator::State
    # Add the except method if it doesn't already exist
    unless method_defined?(:except)
      # Returns a hash excluding the given keys, similar to Hash#except added in Ruby 3.0
      # @param keys [Array] Keys to exclude
      # @return [Hash] New hash without the specified keys
      def except(*keys)
        to_h.except(*keys)
      end
    end

    # Ensure to_h method exists and works properly
    unless method_defined?(:to_h)
      # Convert State to Hash
      # @return [Hash] Hash representation of state
      def to_h
        {
          indent: @indent,
          space: @space,
          space_before: @space_before,
          object_nl: @object_nl,
          array_nl: @array_nl,
          max_nesting: @max_nesting,
          allow_nan: @allow_nan,
          ascii_only: @ascii_only,
          depth: @depth,
          buffer_initial_length: @buffer_initial_length
        }.compact
      end
    end
  end
end
