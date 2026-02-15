# frozen_string_literal: true

require_relative '../options_helper'

describe OctocatalogDiff::Cli::Options do
  describe '#opt_puppet_config' do
    # Custom tests instead of shared example because values must match setting=value format
    it 'should set options[:from_puppet_config] and options[:to_puppet_config] when --puppet-config is set' do
      result = run_optparse(['--puppet-config', 'setting_a=value_a'])
      expect(result[:from_puppet_config]).to eq(['setting_a=value_a'])
      expect(result[:to_puppet_config]).to eq(['setting_a=value_a'])
    end

    it 'should use specific values and global values' do
      result = run_optparse(['--puppet-config', 'setting_a=value_a', '--from-puppet-config', 'setting_b=value_b'])
      expect(result[:from_puppet_config]).to eq(['setting_a=value_a', 'setting_b=value_b'])
      expect(result[:to_puppet_config]).to eq(['setting_a=value_a'])
    end

    it 'should not set options when no default is specified' do
      result = run_optparse(['--from-puppet-config', 'setting_a=value_a'])
      expect(result[:from_puppet_config]).to eq(['setting_a=value_a'])
      expect(result.key?(:to_puppet_config)).to be(false)
    end

    it 'should raise error for invalid setting format' do
      expect { run_optparse(['--puppet-config', 'invalid-format-no-equals']) }.to raise_error(ArgumentError)
    end

    it 'should accept valid setting=value format' do
      result = run_optparse(['--puppet-config', 'basemodulepath=/opt/modules'])
      expect(result[:to_puppet_config]).to eq(['basemodulepath=/opt/modules'])
      expect(result[:from_puppet_config]).to eq(['basemodulepath=/opt/modules'])
    end

    it 'should accept section/setting=value format' do
      result = run_optparse(['--puppet-config', 'agent/server=puppet.example.com'])
      expect(result[:to_puppet_config]).to eq(['agent/server=puppet.example.com'])
      expect(result[:from_puppet_config]).to eq(['agent/server=puppet.example.com'])
    end

    it 'should handle multiple settings' do
      result = run_optparse([
        '--puppet-config', 'basemodulepath=/opt/modules',
        '--puppet-config', 'environment_timeout=unlimited'
      ])
      expect(result[:to_puppet_config]).to eq(['basemodulepath=/opt/modules', 'environment_timeout=unlimited'])
      expect(result[:from_puppet_config]).to eq(['basemodulepath=/opt/modules', 'environment_timeout=unlimited'])
    end
  end
end
