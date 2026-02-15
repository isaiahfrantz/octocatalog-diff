# frozen_string_literal: true

# Specify a puppet.conf file to be copied to the compilation directory.
# This file will be used during catalog compilation. The path can be absolute
# (starting with /) or relative to the basedir. Use --no-puppet-conf to disable.
# See also: --puppet-config for specifying individual settings.
# @param parser [OptionParser object] The OptionParser argument
# @param options [Hash] Options hash being constructed; this is modified in this method.
OctocatalogDiff::Cli::Options::Option.newoption(:puppet_conf) do
  has_weight 185

  def parse(parser, options)
    OctocatalogDiff::Cli::Options.option_globally_or_per_branch(
      parser: parser,
      options: options,
      cli_name: 'puppet-conf',
      option_name: 'puppet_conf',
      desc: 'Path to puppet.conf file to copy to compilation directory',
      post_process: lambda do |opts|
        raise ArgumentError, '--no-puppet-conf incompatible with --puppet-conf' if opts[:no_puppet_conf]
      end
    )

    parser.on('--no-puppet-conf', 'Disable puppet.conf file installation') do
      if options[:to_puppet_conf] || options[:from_puppet_conf]
        raise ArgumentError, '--no-puppet-conf incompatible with --puppet-conf'
      end
      options[:no_puppet_conf] = true
    end
  end
end
