# frozen_string_literal: true

# When comparing file contents, strip trailing newlines from both files before
# the diff. This prevents spurious "No newline at end of file" messages when the
# only difference between two files is the presence or absence of a trailing newline.
#
# @param parser [OptionParser object] The OptionParser argument
# @param options [Hash] Options hash being constructed; this is modified in this method.
OctocatalogDiff::Cli::Options::Option.newoption(:ignore_file_end_newline) do
  has_weight 211

  def parse(parser, options)
    parser.on('--ignore-file-end-newline', 'Ignore trailing newlines in file comparison') do
      options[:ignore_file_end_newline] = true
    end
  end
end
