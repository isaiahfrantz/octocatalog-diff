#!/usr/bin/env bash

# Script to run Puppet. The default implementation here is simply to pass
# through the command line arguments (which are likely to be numerous when
# compiling a catalog).

if [ -z "$OCD_PUPPET_BINARY" ]; then
  echo "Error: PUPPET_BINARY must be set"
  exit 255
fi

# Load JSON State monkey patch for Ruby 3.0+ / Puppet 8 compatibility
# This adds the 'except' method to JSON::Ext::Generator::State
if [ -n "$OCD_JSON_STATE_PATCH" ]; then
  export RUBYOPT="-r${OCD_JSON_STATE_PATCH} ${RUBYOPT}"
fi

"$OCD_PUPPET_BINARY" "$@"
