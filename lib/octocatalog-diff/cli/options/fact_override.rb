# frozen_string_literal: true

# Allow override of facts on the command line. Fact overrides can be supplied for the 'to' or 'from' catalog,
# or for both. There is some attempt to handle data types here (since all items on the command line are strings)
# by permitting a data type specification as well.
OctocatalogDiff::Cli::Options::Option.newoption(:fact_override) do
  has_weight 320

  def parse(parser, options)
    # Set 'fact_override_in' because more processing is needed, once the command line options
    # have been parsed, to make this into the final form 'fact_override'.
    # Avoid Array parsing here so JSON values with commas stay intact.
    parser.on('--fact-override STRING', 'Override fact globally') do |x|
      options[:to_fact_override_in] ||= []
      options[:from_fact_override_in] ||= []
      options[:to_fact_override_in] << x
      options[:from_fact_override_in] << x
    end
    parser.on('--to-fact-override STRING', 'Override fact for the to branch') do |x|
      options[:to_fact_override_in] ||= []
      options[:to_fact_override_in] << x
    end
    parser.on('--from-fact-override STRING', 'Override fact for the from branch') do |x|
      options[:from_fact_override_in] ||= []
      options[:from_fact_override_in] << x
    end
  end
end
