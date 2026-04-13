# frozen_string_literal: true

# Provide a directory containing per-node facts update files. For the "to" catalog only,
# if a file named #{node}.yaml exists in this directory, its key-value pairs will be merged
# over the facts for that node before catalog compilation. Fact overrides (--fact-override,
# --to-fact-override) are applied after this merge.
# @param parser [OptionParser object] The OptionParser argument
# @param options [Hash] Options hash being constructed; this is modified in this method.
OctocatalogDiff::Cli::Options::Option.newoption(:facts_update_dir) do
  has_weight 152

  def parse(parser, options)
    parser.on('--to-facts-update-dir DIRECTORY',
              'Directory with per-node facts update YAML files (format: <hostname>_facts_updates.yaml); merged into "to" catalog facts before overrides') do |x|
      raise Errno::ENOENT, "--to-facts-update-dir '#{x}' is not a directory" unless File.directory?(x)
      options[:to_facts_update_dir] = x
    end
  end
end
