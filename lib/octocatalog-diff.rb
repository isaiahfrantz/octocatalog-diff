# These are all the classes we believe people might want to call directly, so load
# them in response to a 'require octocatalog-diff'.

# Load monkey patches first to ensure compatibility with Ruby 3+ and Puppet 8
require_relative 'octocatalog-diff/monkey_patches/json_state'

loads = %w(api/v1 bootstrap catalog cli errors facts puppetdb version)
loads.each { |f| require_relative "octocatalog-diff/#{f}" }
