# frozen_string_literal: true

require_relative '../options_helper'

describe OctocatalogDiff::Cli::Options do
  describe '#opt_to_facts_update_dir' do
    it 'should accept a valid directory' do
      dir = OctocatalogDiff::Spec.fixture_path('facts/facts-update-dir')
      result = run_optparse(['--to-facts-update-dir', dir])
      expect(result[:to_facts_update_dir]).to eq(dir)
    end

    it 'should raise an error if the directory does not exist' do
      expect do
        run_optparse(['--to-facts-update-dir', '/nonexistent/path/that/does/not/exist'])
      end.to raise_error(Errno::ENOENT, /--to-facts-update-dir/)
    end

    it 'should only set to_facts_update_dir, not from' do
      dir = OctocatalogDiff::Spec.fixture_path('facts/facts-update-dir')
      result = run_optparse(['--to-facts-update-dir', dir])
      expect(result[:to_facts_update_dir]).to eq(dir)
      expect(result[:from_facts_update_dir]).to be_nil
    end
  end
end
