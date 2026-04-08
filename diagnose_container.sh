#!/bin/bash
# Diagnostic script to verify octocatalog-diff 2.5.0 fix in container

echo "=== Diagnostic Script for octocatalog-diff 2.5.0 ==="
echo

echo "1. Ruby version:"
ruby --version
echo

echo "2. Octocatalog-diff version:"
octocatalog-diff --version
echo

echo "3. Puppet version:"
puppet --version
echo

echo "4. JSON gem version:"
ruby -e "require 'json'; puts JSON::VERSION"
echo

echo "5. Check if monkey patch file exists in gem:"
MONKEY_PATCH=$(ruby -e "puts File.join(Gem::Specification.find_by_name('octocatalog-diff').gem_dir, 'lib/octocatalog-diff/monkey_patches/json_state.rb')")
echo "   Path: $MONKEY_PATCH"
if [ -f "$MONKEY_PATCH" ]; then
    echo "   ✓ File exists"
else
    echo "   ✗ File NOT found"
fi
echo

echo "6. Check if puppet.sh has the fix:"
PUPPET_SH=$(ruby -e "puts File.join(Gem::Specification.find_by_name('octocatalog-diff').gem_dir, 'scripts/puppet/puppet.sh')")
echo "   Path: $PUPPET_SH"
if grep -q "OCD_JSON_STATE_PATCH" "$PUPPET_SH"; then
    echo "   ✓ puppet.sh has OCD_JSON_STATE_PATCH check"
    echo "   Relevant lines:"
    grep -A2 "OCD_JSON_STATE_PATCH" "$PUPPET_SH" | sed 's/^/     /'
else
    echo "   ✗ puppet.sh does NOT have the fix"
fi
echo

echo "7. Test monkey patch loads in Ruby:"
ruby -e "
require 'octocatalog-diff'
require 'json'
if defined?(JSON::Ext::Generator::State)
  state = JSON::Ext::Generator::State.new
  if state.respond_to?(:except)
    puts '   ✓ Monkey patch loaded: except method exists'
  else
    puts '   ✗ Monkey patch NOT loaded: except method missing'
    exit 1
  end
else
  puts '   ⚠  JSON::Ext not loaded (using pure Ruby JSON)'
end
"
echo

echo "8. Test monkey patch via RUBYOPT (simulating Puppet):"
export RUBYOPT="-r${MONKEY_PATCH%.rb}"
ruby -e "
require 'json'
if defined?(JSON::Ext::Generator::State)
  state = JSON::Ext::Generator::State.new
  if state.respond_to?(:except)
    puts '   ✓ Monkey patch works via RUBYOPT'
  else
    puts '   ✗ Monkey patch NOT working via RUBYOPT'
    exit 1
  end
end
"
echo

echo "9. Check lib/octocatalog-diff.rb loads monkey patch:"
GEM_LOADER=$(ruby -e "puts File.join(Gem::Specification.find_by_name('octocatalog-diff').gem_dir, 'lib/octocatalog-diff.rb')")
if grep -q "monkey_patches/json_state" "$GEM_LOADER"; then
    echo "   ✓ lib/octocatalog-diff.rb requires monkey patch"
else
    echo "   ✗ lib/octocatalog-diff.rb does NOT require monkey patch"
fi
echo

echo "10. Check lib/octocatalog-diff/catalog/computed.rb sets env var:"
COMPUTED_RB=$(ruby -e "puts File.join(Gem::Specification.find_by_name('octocatalog-diff').gem_dir, 'lib/octocatalog-diff/catalog/computed.rb')")
if grep -q "OCD_JSON_STATE_PATCH" "$COMPUTED_RB"; then
    echo "   ✓ computed.rb sets OCD_JSON_STATE_PATCH environment variable"
else
    echo "   ✗ computed.rb does NOT set OCD_JSON_STATE_PATCH"
fi
echo

echo "=== End of Diagnostics ==="
echo
echo "If any checks show ✗, the gem installation may be incomplete."
echo "Try: gem uninstall octocatalog-diff --all && gem install octocatalog-diff-2.5.0.gem"
