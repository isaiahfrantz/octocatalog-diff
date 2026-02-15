# frozen_string_literal: true

# Specify puppet configuration settings to write to puppet.conf in the compilation directory.
# Settings should be in the format 'setting=value' for the [main] section, or
# 'section/setting=value' for other sections (e.g., 'agent/server=puppet.example.com').
# Multiple settings can be specified by using this option multiple times.
# If used with --puppet-conf, these settings override values from the file.
# @param parser [OptionParser object] The OptionParser argument
# @param options [Hash] Options hash being constructed; this is modified in this method.
OctocatalogDiff::Cli::Options::Option.newoption(:puppet_config) do
  has_weight 186

  def parse(parser, options)
    OctocatalogDiff::Cli::Options.option_globally_or_per_branch(
      parser: parser,
      options: options,
      cli_name: 'puppet-config',
      option_name: 'puppet_config',
      desc: 'Puppet config settings (setting=value or section/setting=value)',
      datatype: [],
      validator: lambda do |settings|
        settings.each do |setting|
          unless setting =~ %r{\A[\w/]+=.+\z}
            raise ArgumentError, "Invalid puppet config format '#{setting}'. Expected 'setting=value' or 'section/setting=value'"
          end
        end
        true
      end
    )
  end
end
