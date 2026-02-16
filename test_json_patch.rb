#!/usr/bin/env ruby

require_relative 'lib/octocatalog-diff'
require 'json'

puts "Ruby version: #{RUBY_VERSION}"
puts "JSON version: #{JSON::VERSION}"

if defined?(JSON::Ext::Generator::State)
  puts "\n✓ JSON::Ext::Generator::State is defined (using C extension)"

  state = JSON::Ext::Generator::State.new
  puts "\nTesting methods on JSON::Ext::Generator::State instance:"

  puts "  - respond_to?(:except): #{state.respond_to?(:except)}"
  puts "  - respond_to?(:to_h): #{state.respond_to?(:to_h)}"

  if state.respond_to?(:except)
    begin
      result = state.except(:foo, :bar)
      puts "  - except() works! Returns: #{result.class}"
    rescue => e
      puts "  - except() FAILED: #{e.class}: #{e.message}"
      puts "    Backtrace:"
      e.backtrace.first(5).each { |line| puts "      #{line}" }
    end
  else
    puts "  - except() method NOT FOUND - monkey patch did not apply!"
  end

  if state.respond_to?(:to_h)
    begin
      hash = state.to_h
      puts "  - to_h() works! Returns: #{hash.class} with #{hash.keys.size} keys"
      puts "    Keys: #{hash.keys.inspect}"
    rescue => e
      puts "  - to_h() FAILED: #{e.class}: #{e.message}"
    end
  end
else
  puts "\n⚠ JSON::Ext::Generator::State NOT defined (using pure Ruby JSON)"
  puts "This is fine - the monkey patch is only needed for the C extension version"
end

puts "\nMonkey patch file exists: #{File.exist?('lib/octocatalog-diff/monkey_patches/json_state.rb')}"
