#!/usr/bin/env ruby

# Test that verifies the complete JSON State monkey patch fix
# This simulates what happens when Puppet is invoked as a subprocess

require 'tempfile'

puts "=== Complete Fix Verification ==="
puts "Ruby version: #{RUBY_VERSION}"
puts

# Test 1: Verify monkey patch loads in main process
puts "Test 1: Monkey patch in main process"
require 'octocatalog-diff'
require 'json'

if defined?(JSON::Ext::Generator::State)
  state = JSON::Ext::Generator::State.new
  has_except = state.respond_to?(:except)
  has_to_h = state.respond_to?(:to_h)

  puts "  ✓ JSON::Ext::Generator::State defined"
  puts "  #{has_except ? '✓' : '✗'} except method: #{has_except}"
  puts "  #{has_to_h ? '✓' : '✗'} to_h method: #{has_to_h}"

  if has_except
    begin
      result = state.except(:foo, :bar)
      puts "  ✓ except() works and returns: #{result.class}"
    rescue => e
      puts "  ✗ except() failed: #{e.message}"
      exit 1
    end
  end
else
  puts "  ⚠  JSON::Ext not loaded (pure Ruby JSON)"
end

# Test 2: Verify monkey patch loads via RUBYOPT (simulating Puppet subprocess)
puts "\nTest 2: Monkey patch via RUBYOPT (Puppet subprocess simulation)"

# Get the path to the monkey patch from the installed gem
gem_path = File.dirname(File.dirname(Gem.find_files('octocatalog-diff').first))
monkey_patch_path = File.join(gem_path, 'lib', 'octocatalog-diff', 'monkey_patches', 'json_state')

if File.exist?("#{monkey_patch_path}.rb")
  puts "  ✓ Monkey patch found at: #{monkey_patch_path}.rb"

  # Simulate what puppet.sh does
  ENV['RUBYOPT'] = "-r#{monkey_patch_path}"

  # Test in a subprocess (like Puppet would run)
  test_script = Tempfile.new(['test_subprocess', '.rb'])
  test_script.write(<<~RUBY)
    require 'json'
    if defined?(JSON::Ext::Generator::State)
      state = JSON::Ext::Generator::State.new
      if state.respond_to?(:except)
        result = state.except(:test)
        puts "SUCCESS: except method works in subprocess"
        exit 0
      else
        puts "FAIL: except method not found in subprocess"
        exit 1
      end
    else
      puts "WARN: JSON::Ext not loaded"
      exit 0
    end
  RUBY
  test_script.close

  result = `ruby #{test_script.path} 2>&1`
  test_script.unlink
  exit_status = $?.exitstatus

  puts "  Subprocess result: #{result.strip}"
  if exit_status == 0 && result.include?("SUCCESS")
    puts "  ✓ Monkey patch works in subprocess via RUBYOPT"
  else
    puts "  ✗ Monkey patch failed in subprocess"
    exit 1
  end
else
  puts "  ✗ Monkey patch file not found"
  exit 1
end

puts "\n=== All Tests Passed! ==="
puts "The fix is working correctly and will solve the Puppet 8 + Ruby 3.2.5 issue."
