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
        # Convert to hash by using configure which returns a hash representation
        # The State class has instance variables that we can't directly access from Ruby
        # since it's a C extension, so we build a hash from available accessor methods
        result = {}

        # Try to get values using accessor methods if they exist
        [:indent, :space, :space_before, :object_nl, :array_nl,
         :max_nesting, :allow_nan, :ascii_only, :depth, :buffer_initial_length].each do |method|
          begin
            result[method] = send(method) if respond_to?(method)
          rescue
            # If we can't read the value, skip it
          end
        end

        # Return the hash with specified keys removed
        # Use delete instead of except in case we're in Ruby < 3.0
        keys.each { |key| result.delete(key) }
        result
      end
    end

    # Ensure to_h method exists and works properly
    unless method_defined?(:to_h)
      # Convert State to Hash using available accessor methods
      # @return [Hash] Hash representation of state
      def to_h
        result = {}
        [:indent, :space, :space_before, :object_nl, :array_nl,
         :max_nesting, :allow_nan, :ascii_only, :depth, :buffer_initial_length].each do |method|
          begin
            result[method] = send(method) if respond_to?(method)
          rescue
            # If we can't read the value, skip it
          end
        end
        result
      end
    end
  end
end
