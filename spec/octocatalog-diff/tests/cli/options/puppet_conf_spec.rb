# frozen_string_literal: true

require_relative '../options_helper'

describe OctocatalogDiff::Cli::Options do
  describe '#opt_puppet_conf' do
    include_examples 'global string option', 'puppet-conf', :puppet_conf

    it 'should handle --no-puppet-conf' do
      result = run_optparse(['--no-puppet-conf'])
      expect(result.key?(:puppet_conf)).to eq(false)
      expect(result[:no_puppet_conf]).to eq(true)
    end

    it 'should error when --puppet-conf and --no-puppet-conf are both specified' do
      expect { run_optparse(['--puppet-conf', 'adflkadfs', '--no-puppet-conf']) }.to raise_error(ArgumentError)
      expect { run_optparse(['--no-puppet-conf', '--puppet-conf', 'adflkadfs']) }.to raise_error(ArgumentError)
    end
  end
end
