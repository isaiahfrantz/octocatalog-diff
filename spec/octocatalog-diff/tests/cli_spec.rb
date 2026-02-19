# frozen_string_literal: true

require_relative 'spec_helper'

require OctocatalogDiff::Spec.require_path('/api/v1')
require OctocatalogDiff::Spec.require_path('/cli')
require OctocatalogDiff::Spec.require_path('/errors')

describe OctocatalogDiff::Cli do
  describe '#parse_opts' do
    # There is more test coverage in cli/options for each specific
    # option that's recognized here.
    it 'should parse a basic option (in this case --hostname)' do
      argv = ['--hostname', 'octonode.rspec']
      result = OctocatalogDiff::Cli.parse_opts(argv)
      expect(result[:node]).to eq('octonode.rspec')
    end
  end

  describe '#cli' do
    context 'with --no-hiera-config' do
      it 'should not pass a hiera config file' do
        opts = { hiera_config: 'abcdefg', to_hiera_config: 'xyz123', from_hiera_config: 'qwerty' }
        argv = ['--no-hiera-config', '--catalog-only']
        answer = {
          ignore: [{ type: 'Class' }],
          no_hiera_config: true,
          catalog_only: true,
          from_env: 'origin/master',
          to_env: '.',
          colors: true,
          debug: false,
          quiet: false,
          storeconfigs_backend: 'puppetdb',
          format: :color_text,
          display_source_file_line: false,
          compare_file_text: true,
          display_datatype_changes: true,
          parallel: true,
          suppress_absent_file_details: true,
          hiera_path: 'hieradata',
          use_lcs: true
        }
        logger, _logger_str = OctocatalogDiff::Spec.setup_logger
        expect(described_class).to receive(:catalog_only).with(logger, answer)
        OctocatalogDiff::Cli.cli(argv, logger, opts)
      end
    end

    context 'Additional ARGV' do
      let(:default_argv) do
        [
          '--from-catalog',
          OctocatalogDiff::Spec.fixture_path('catalogs/tiny-catalog.json'),
          '--to-catalog',
          OctocatalogDiff::Spec.fixture_path('catalogs/tiny-catalog-2.json'),
          '--fact-file', # FIXME: Shouldn't be required here
          OctocatalogDiff::Spec.fixture_path('facts/valid-facts.yaml') # FIXME: Shouldn't be required here
        ]
      end

      it 'should have expected defaults' do
        # This exists to provide validity to the tests below. The defaults at the time of
        # this writing are debug OFF and colored text ON. If those defaults have changed,
        # the remaining tests may be broken.
        logger, logger_str = OctocatalogDiff::Spec.setup_logger
        result = OctocatalogDiff::Cli.cli(default_argv.dup, logger, {})
        expect(result).to eq(0)
        expect(logger_str.string).not_to match(/DEBUG/)

        logger, logger_str = OctocatalogDiff::Spec.setup_logger
        result2 = OctocatalogDiff::Cli.cli(default_argv.dup, logger, debug: true)
        expect(result2).to eq(0)
        expect(logger_str.string).to match(/DEBUG -- : Generating colored text output/)
      end

      it 'should accept an additional ARGV array with single element' do
        opts = { additional_argv: %w(--debug) }
        logger, logger_str = OctocatalogDiff::Spec.setup_logger
        result = OctocatalogDiff::Cli.cli(default_argv, logger, opts)
        expect(result).to eq(0)
        expect(logger_str.string).to match(/DEBUG -- : Generating colored text output/)
      end

      it 'should accept an additional ARGV array with multiple elements' do
        opts = { additional_argv: %w(--debug --no-color) }
        logger, logger_str = OctocatalogDiff::Spec.setup_logger
        result = OctocatalogDiff::Cli.cli(default_argv, logger, opts)
        expect(result).to eq(0)
        expect(logger_str.string).to match(/DEBUG -- : Generating non-colored text output/)
      end

      it 'should raise error if additional ARGV is not an array' do
        opts = { additional_argv: 'this is not an array' }
        logger, _logger_str = OctocatalogDiff::Spec.setup_logger
        expect do
          OctocatalogDiff::Cli.cli(default_argv, logger, opts)
        end.to raise_error(ArgumentError, /additional_argv must be array/)
      end

      it 'should run in parallel when multiple hostnames are given' do
        # Under rspec the parallel gem collides with octocatalog-diff's parallel execution
        # implementation, so work around by disabling octocatalog-diff's parallel execution
        # just for this one test.
        # With multiple nodes, output is buffered per-node and flushed to $stderr in sorted order.
        opts = { additional_argv: %w(--hostname octonode1.rspec,octonode2.rspec --no-parallel) }
        logger, _logger_str = OctocatalogDiff::Spec.setup_logger
        captured_stderr = StringIO.new
        original_stderr = $stderr
        $stderr = captured_stderr
        begin
          result = OctocatalogDiff::Cli.cli(default_argv.dup, logger, opts)
        ensure
          $stderr = original_stderr
        end
        expect(result).to eq(0)
        expect(captured_stderr.string).to match(/Catalogs compiled for octonode1.rspec/)
        expect(captured_stderr.string).to match(/Catalogs compiled for octonode2.rspec/)
      end

      it 'should print multi-node output sorted alphabetically by node name' do
        # Nodes are passed in reverse order (z before a) to prove sorting is applied
        opts = { additional_argv: %w(--hostname z_node.rspec,a_node.rspec --no-parallel) }
        logger, _logger_str = OctocatalogDiff::Spec.setup_logger
        captured_stderr = StringIO.new
        original_stderr = $stderr
        $stderr = captured_stderr
        begin
          OctocatalogDiff::Cli.cli(default_argv.dup, logger, opts)
        ensure
          $stderr = original_stderr
        end
        stderr_content = captured_stderr.string
        a_pos = stderr_content.index('a_node.rspec')
        z_pos = stderr_content.index('z_node.rspec')
        expect(a_pos).not_to be_nil
        expect(z_pos).not_to be_nil
        expect(a_pos).to be < z_pos
      end
    end

    context 'with cached master directory specified' do
      before(:all) do
        @git_checkout_dir = OctocatalogDiff::Spec.extract_fixture_repo('simple-repo')
        @cached_master_directory = Dir.mktmpdir
        logger, @logger_str = OctocatalogDiff::Spec.setup_logger
        argv = [
          '-f', 'master',
          '--to-catalog', OctocatalogDiff::Spec.fixture_path('catalogs/tiny-catalog-2.json'),
          '--fact-file', OctocatalogDiff::Spec.fixture_path('facts/valid-facts.yaml'),
          '--cached-master-dir', @cached_master_directory,
          '-o', File.join(@cached_master_directory, 'trashfile.txt'),
          '--no-parallel'
        ]
        opts = {
          debug: true,
          basedir: File.join(@git_checkout_dir, 'git-repo'),
          puppet_binary: OctocatalogDiff::Spec::PUPPET_BINARY,
          master_cache_branch: 'master'
        }
        @result = OctocatalogDiff::Cli.cli(argv, logger, opts)
      end

      after(:all) do
        OctocatalogDiff::Spec.clean_up_tmpdir(@git_checkout_dir)
        OctocatalogDiff::Spec.clean_up_tmpdir(@cached_master_directory)
      end

      it 'should store the cached catalog in the catalog cache directory' do
        catalog = File.join(@cached_master_directory, '.catalogs', 'my.rspec.node.json')
        expect(File.file?(catalog)).to eq(true)
      end

      it 'should log the proper messages' do
        # These messages come from another class, so spot-check a few to make sure the code ran properly
        str = @logger_str.string
        expect(str).to match(/Begin bootstrap cached master directory/)
        expect(str).to match(/Success bootstrap from_dir .* for master/)
        expect(str).to match(/Cached master directory bootstrapped to ff1928f3f8d9295c3f26b1de70977ed3eea9329e/)

        # This comes from the class and method under test
        expect(str).to match(/Cached master catalog for my.rspec.node/)
      end

      it 'should record the proper catalog-diff exit code' do
        expect(@result).to eq(2)
      end
    end

    context 'with :bootstrap_then_exit set' do
      it 'should construct catalog object and call bootstrap_then_exit' do
        expect(OctocatalogDiff::Util::Catalogs).to receive(:new).and_return('xxx')
        expect(described_class).to receive(:bootstrap_then_exit).and_return('yyy')
        result = described_class.cli(['--bootstrap-then-exit'])
        expect(result).to eq('yyy')
      end
    end
  end

  describe '#run_octocatalog_diff_buffered' do
    let(:from_catalog) { double('from_catalog', compilation_dir: nil) }
    let(:to_catalog)   { double('to_catalog',   compilation_dir: nil) }
    let(:catalog_diff_result) do
      double('catalog_diff', diffs: [], from: from_catalog, to: to_catalog)
    end

    before do
      allow(OctocatalogDiff::API::V1).to receive(:catalog_diff) do |opts|
        opts[:logger]&.info("Catalogs compiled for #{opts[:node]}")
        opts[:logger]&.info("Diffs computed for #{opts[:node]}")
        catalog_diff_result
      end
      allow(OctocatalogDiff::CatalogDiff::Display).to receive(:output).and_return('')
    end

    it 'returns a hash with :node, :catalog_diff, :log_content, and :diff_text keys' do
      result = OctocatalogDiff::Cli.run_octocatalog_diff_buffered('test.node', {}, Logger::INFO)
      expect(result).to be_a(Hash)
      expect(result).to include(:node, :catalog_diff, :log_content, :diff_text)
    end

    it 'sets :node to the given node name' do
      result = OctocatalogDiff::Cli.run_octocatalog_diff_buffered('test.node', {}, Logger::INFO)
      expect(result[:node]).to eq('test.node')
    end

    it 'captures log messages in :log_content instead of writing to a shared logger' do
      result = OctocatalogDiff::Cli.run_octocatalog_diff_buffered('test.node', {}, Logger::INFO)
      expect(result[:log_content]).to match(/Catalogs compiled for test\.node/)
      expect(result[:log_content]).to match(/Diffs computed for test\.node/)
    end

    it 'does not write log messages to $stderr during processing' do
      original_stderr = $stderr
      captured_stderr = StringIO.new
      $stderr = captured_stderr
      begin
        OctocatalogDiff::Cli.run_octocatalog_diff_buffered('test.node', {}, Logger::INFO)
      ensure
        $stderr = original_stderr
      end
      expect(captured_stderr.string).to be_empty
    end

    it 'respects the log level - filters messages below the threshold' do
      allow(OctocatalogDiff::API::V1).to receive(:catalog_diff) do |opts|
        opts[:logger]&.debug('debug message should be filtered')
        opts[:logger]&.info('info message should appear')
        catalog_diff_result
      end
      result = OctocatalogDiff::Cli.run_octocatalog_diff_buffered('test.node', {}, Logger::INFO)
      expect(result[:log_content]).not_to match(/debug message/)
      expect(result[:log_content]).to match(/info message/)
    end

    it 'returns :diff_text from Display.output' do
      allow(OctocatalogDiff::CatalogDiff::Display).to receive(:output).and_return('the diff text')
      result = OctocatalogDiff::Cli.run_octocatalog_diff_buffered('test.node', {}, Logger::INFO)
      expect(result[:diff_text]).to eq('the diff text')
    end

    it 'passes node name into options for catalog_diff' do
      expect(OctocatalogDiff::API::V1).to receive(:catalog_diff) do |opts|
        expect(opts[:node]).to eq('mynode.example.com')
        catalog_diff_result
      end
      OctocatalogDiff::Cli.run_octocatalog_diff_buffered('mynode.example.com', {}, Logger::INFO)
    end
  end

  describe '#setup_logger' do
    context 'with custom version specified in environment' do
      before(:each) do
        ENV['OCTOCATALOG_DIFF_CUSTOM_VERSION'] = '@d05c30152c897219367d586414ccb1f651ab7221'
      end

      after(:each) do
        ENV.delete 'OCTOCATALOG_DIFF_CUSTOM_VERSION'
      end

      it 'should log custom version' do
        logger, logger_str = OctocatalogDiff::Spec.setup_logger
        described_class.setup_logger(logger, { debug: true }, nil)
        expect(logger_str.string).to match(/Running octocatalog-diff @d05c30152c897219367d586414ccb1f651ab7221 with ruby/)
      end
    end

    context 'with default version' do
      before(:each) do
        ENV.delete 'OCTOCATALOG_DIFF_CUSTOM_VERSION'
      end

      it 'should log current version' do
        logger, logger_str = OctocatalogDiff::Spec.setup_logger
        described_class.setup_logger(logger, { debug: true }, nil)
        version = described_class::VERSION
        expect(logger_str.string).to match(/Running octocatalog-diff #{version} with ruby/)
      end
    end
  end

  describe '#setup_fact_overrides' do
    it 'should make no adjustments when there are no fact overrides' do
      options = {}
      OctocatalogDiff::Cli.setup_fact_overrides(options)
      expect(options).to eq({})
    end

    it 'should skip fact overrides that are not arrays' do
      options = { from_fact_override_in: true }
      OctocatalogDiff::Cli.setup_fact_overrides(options)
      expect(options).to eq(from_fact_override_in: true)
    end

    it 'should skip fact overrides that are empty arrays' do
      options = { from_fact_override_in: [] }
      OctocatalogDiff::Cli.setup_fact_overrides(options)
      expect(options).to eq(from_fact_override_in: [])
    end

    it 'should adjust options with one fact override' do
      options = { from_fact_override_in: ['foo=bar'] }
      OctocatalogDiff::Cli.setup_fact_overrides(options)
      expect(options[:from_fact_override]).to be_a_kind_of(Array)
      expect(options[:from_fact_override].size).to eq(1)
      ffo = options[:from_fact_override].first
      expect(ffo).to be_a_kind_of(OctocatalogDiff::API::V1::Override)
      expect(ffo.key).to eq('foo')
      expect(ffo.value).to eq('bar')
    end

    it 'should adjust options with multiple fact overrides' do
      options = { to_fact_override_in: ['foo=bar', 'baz=buzz'] }
      OctocatalogDiff::Cli.setup_fact_overrides(options)
      expect(options[:to_fact_override]).to be_a_kind_of(Array)
      expect(options[:to_fact_override].size).to eq(2)

      tfo = options[:to_fact_override]
      expect(tfo[0]).to be_a_kind_of(OctocatalogDiff::API::V1::Override)
      expect(tfo[0].key).to eq('foo')
      expect(tfo[0].value).to eq('bar')
      expect(tfo[1]).to be_a_kind_of(OctocatalogDiff::API::V1::Override)
      expect(tfo[1].key).to eq('baz')
      expect(tfo[1].value).to eq('buzz')
    end
  end

  describe '#setup_enc_overrides' do
    it 'should set up overrides for from and to' do
      options = {
        to_enc_override_in: ['foo=bar'],
        from_enc_override_in: ['baz=buzz']
      }
      OctocatalogDiff::Cli.setup_enc_overrides(options)
      expect(options[:to_enc_override]).to be_a_kind_of(Array)
      expect(options[:to_enc_override].size).to eq(1)
      expect(options[:to_enc_override].first).to be_a_kind_of(OctocatalogDiff::API::V1::Override)
      expect(options[:to_enc_override].first.key).to eq('foo')
      expect(options[:to_enc_override].first.value).to eq('bar')

      expect(options[:from_enc_override]).to be_a_kind_of(Array)
      expect(options[:from_enc_override].size).to eq(1)
      expect(options[:from_enc_override].first).to be_a_kind_of(OctocatalogDiff::API::V1::Override)
      expect(options[:from_enc_override].first.key).to eq('baz')
      expect(options[:from_enc_override].first.value).to eq('buzz')
    end
  end

  describe '#catalog_only' do
    context 'working catalog output to file' do
      before(:each) do
        catalog_json = File.read(OctocatalogDiff::Spec.fixture_path('catalogs/tiny-catalog.json'))
        catalogs = { to: OctocatalogDiff::Catalog.create(json: catalog_json) }
        d = double('OctocatalogDiff::Util::Catalogs')
        allow(OctocatalogDiff::Util::Catalogs).to receive(:new).and_return(d)
        allow(d).to receive(:catalogs).and_return(catalogs)
        logger, @logger_str = OctocatalogDiff::Spec.setup_logger
        @tmpdir = Dir.mktmpdir
        catfile = File.join(@tmpdir, 'catalog.json')
        @rc = OctocatalogDiff::Cli.catalog_only(logger, node: 'fizz', output_file: catfile)
      end

      after(:each) do
        OctocatalogDiff::Spec.clean_up_tmpdir(@tmpdir)
      end

      it 'should store the catalog and exit' do
        expect(File.file?(File.join(@tmpdir, 'catalog.json'))).to eq(true)
        expect(@rc).to eq(0)
        expect(@logger_str.string).to match(/Compiling catalog for fizz/)
        expect(@logger_str.string).to match(%r{Wrote catalog to .*/catalog.json})
      end
    end

    context 'working catalog output to screen' do
      it 'should output to STDOUT and exit' do
        catalog_json = File.read(OctocatalogDiff::Spec.fixture_path('catalogs/tiny-catalog.json'))
        catalogs = { to: OctocatalogDiff::Catalog.create(json: catalog_json) }
        d = double('OctocatalogDiff::Util::Catalogs')
        allow(OctocatalogDiff::Util::Catalogs).to receive(:new).and_return(d)
        allow(d).to receive(:catalogs).and_return(catalogs)
        logger, logger_str = OctocatalogDiff::Spec.setup_logger
        rexp = Regexp.new('"document_type": "Catalog"')
        expect { @rc = OctocatalogDiff::Cli.catalog_only(logger, node: 'fizz') }.to output(rexp).to_stdout
        expect(@rc).to eq(0)
        expect(logger_str.string).to match(/Compiling catalog for fizz/)
      end
    end
  end

  describe '#bootstrap_then_exit' do
    it 'should succeed and exit 0' do
      d = double('OctocatalogDiff::Util::Catalogs')
      allow(d).to receive(:bootstrap_then_exit)
      logger, logger_str = OctocatalogDiff::Spec.setup_logger
      rc = OctocatalogDiff::Cli.bootstrap_then_exit(logger, d)
      expect(rc).to eq(0)
      expect(logger_str.string).to eq('')
    end

    it 'should fail and exit 1 if BootstrapError occurs' do
      d = double('OctocatalogDiff::Util::Catalogs')
      allow(d).to receive(:bootstrap_then_exit).and_raise(OctocatalogDiff::Errors::BootstrapError, 'hello')
      logger, logger_str = OctocatalogDiff::Spec.setup_logger
      rc = OctocatalogDiff::Cli.bootstrap_then_exit(logger, d)
      expect(rc).to eq(1)
      expect(logger_str.string).to match(/--bootstrap-then-exit error: bootstrap failed \(hello\)/)
    end
  end
end
