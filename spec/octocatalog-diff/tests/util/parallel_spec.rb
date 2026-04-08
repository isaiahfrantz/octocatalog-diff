# frozen_string_literal: true

require_relative '../spec_helper'
require OctocatalogDiff::Spec.require_path('/util/parallel')
require 'logger'
require 'parallel'

describe OctocatalogDiff::Util::Parallel do
  before(:each) do
    ENV['OCTOCATALOG_DIFF_TEMPDIR'] = Dir.mktmpdir
  end

  after(:each) do
    OctocatalogDiff::Spec.clean_up_tmpdir(ENV['OCTOCATALOG_DIFF_TEMPDIR'])
    ENV.delete('OCTOCATALOG_DIFF_TEMPDIR')
  end

  context 'with parallel processing' do
    it 'should only Process.wait() its own children' do
      class Foo
        def one(arg, _logger = nil)
          'one ' + arg
        end

        def two(arg, _logger = nil)
          'two ' + arg
        end

        def dont_wait_me_bro(sleep_for = 1)
          # do we need a rescue block here?
          pid = fork do
            sleep sleep_for
            Kernel.exit! 0 # Kernel.exit! avoids at_exit from parents being triggered by children exiting
          end
          pid
        end

        def wait_on_me(pid)
          status = nil
          # just in case status never equals anything
          count = 100
          while status.nil? || count > 0
            count -= 1
            status = Process.waitpid2(pid, Process::WNOHANG)
          end
          status
        end
      end

      c = Foo.new
      # start my non-parallel process first
      just_a_guy = c.dont_wait_me_bro

      one = OctocatalogDiff::Util::Parallel::Task.new(method: c.method(:one), args: 'abc', description: 'test1')
      two = OctocatalogDiff::Util::Parallel::Task.new(method: c.method(:two), args: 'def', description: 'test2')
      result = OctocatalogDiff::Util::Parallel.run_tasks([one, two], nil, true)
      expect(result).to be_a_kind_of(Array)
      expect(result.size).to eq(2)

      one_result = result[0]
      expect(one_result).to be_a_kind_of(OctocatalogDiff::Util::Parallel::Result)
      expect(one_result.status).to eq(true)
      expect(one_result.exception).to eq(nil)
      expect(one_result.output).to match(/^one abc/)

      two_result = result[1]
      expect(two_result).to be_a_kind_of(OctocatalogDiff::Util::Parallel::Result)
      expect(two_result.status).to eq(true)
      expect(two_result.exception).to eq(nil)
      expect(two_result.output).to match(/^two def/)

      # just_a_guy should still be need to be waited
      result = c.wait_on_me(just_a_guy)
      expect(result).to be_a_kind_of(Array)
      # test result and check for error conditions
    end

    it 'should parallelize and return task results' do
      class Foo
        def one(arg, _logger = nil)
          'one ' + arg
        end

        def two(arg, _logger = nil)
          'two ' + arg
        end
      end

      c = Foo.new
      one = OctocatalogDiff::Util::Parallel::Task.new(method: c.method(:one), args: 'abc', description: 'test1')
      two = OctocatalogDiff::Util::Parallel::Task.new(method: c.method(:two), args: 'def', description: 'test2')
      result = OctocatalogDiff::Util::Parallel.run_tasks([one, two], nil, true)
      expect(result).to be_a_kind_of(Array)
      expect(result.size).to eq(2)

      one_result = result[0]
      expect(one_result).to be_a_kind_of(OctocatalogDiff::Util::Parallel::Result)
      expect(one_result.status).to eq(true)
      expect(one_result.exception).to eq(nil)
      expect(one_result.output).to match(/^one abc/)

      two_result = result[1]
      expect(two_result).to be_a_kind_of(OctocatalogDiff::Util::Parallel::Result)
      expect(two_result.status).to eq(true)
      expect(two_result.exception).to eq(nil)
      expect(two_result.output).to match(/^two def/)
    end

    it 'should handle a task that fails after other successes' do
      class Foo
        def one(arg, _logger = nil)
          File.open(File.join(ENV['OCTOCATALOG_DIFF_TEMPDIR'], 'one'), 'w') { |f| f.write '' }
          'one ' + arg
        end

        def two(_arg, _logger = nil)
          100.times do
            break if File.file?(File.join(ENV['OCTOCATALOG_DIFF_TEMPDIR'], 'one'))
            sleep 0.1
          end
          # Sometimes the system will still handle the second process if it's near-simultaneous
          # so sleep for a bit before exiting.
          sleep 0.5
          raise 'Two failed'
        end
      end

      c = Foo.new
      one = OctocatalogDiff::Util::Parallel::Task.new(method: c.method(:one), args: 'abc', description: 'test1')
      two = OctocatalogDiff::Util::Parallel::Task.new(method: c.method(:two), args: 'def', description: 'test2')
      result = OctocatalogDiff::Util::Parallel.run_tasks([one, two], nil, true)
      expect(result).to be_a_kind_of(Array)
      expect(result.size).to eq(2)

      one_result = result[0]
      expect(one_result).to be_a_kind_of(OctocatalogDiff::Util::Parallel::Result)
      expect(one_result.status).to eq(true)
      expect(one_result.exception).to eq(nil)
      expect(one_result.output).to eq('one abc')

      two_result = result[1]
      expect(two_result).to be_a_kind_of(OctocatalogDiff::Util::Parallel::Result)
      expect(two_result.status).to eq(false)
      expect(two_result.exception).to be_a_kind_of(RuntimeError)
      expect(two_result.exception.message).to eq('Two failed')
    end

    it 'should kill running tasks when one task fails' do
      class Foo
        def one(arg, _logger = nil)
          sleep 10
          File.open(File.join(ENV['OCTOCATALOG_DIFF_TEMPDIR'], 'one'), 'w') { |f| f.write '' }
          'one ' + arg
        end

        def two(_arg, _logger = nil)
          raise 'Two failed'
        end
      end

      c = Foo.new
      one = OctocatalogDiff::Util::Parallel::Task.new(method: c.method(:one), args: 'abc', description: 'test1')
      two = OctocatalogDiff::Util::Parallel::Task.new(method: c.method(:two), args: 'def', description: 'test2')
      result = OctocatalogDiff::Util::Parallel.run_tasks([one, two], nil, true)
      expect(result).to be_a_kind_of(Array)
      expect(result.size).to eq(2)

      one_result = result[0]
      expect(one_result).to be_a_kind_of(OctocatalogDiff::Util::Parallel::Result)
      expect(one_result.status).to eq(nil)
      expect(one_result.exception).to be_a_kind_of(OctocatalogDiff::Util::Parallel::IncompleteTask)
      expect(one_result.exception.message).to eq('Killed')
      expect(one_result.output).to eq(nil)

      two_result = result[1]
      expect(two_result).to be_a_kind_of(OctocatalogDiff::Util::Parallel::Result)
      expect(two_result.status).to eq(false)
      expect(two_result.exception).to be_a_kind_of(RuntimeError)
      expect(two_result.exception.message).to eq('Two failed')

      expect(File.file?(File.join(ENV['OCTOCATALOG_DIFF_TEMPDIR'], 'one'))).to eq(false)
    end

    it 'should log debug messages' do
      class Foo
        def my_method(arg, _logger = nil)
          arg
        end
      end

      c = Foo.new
      one = OctocatalogDiff::Util::Parallel::Task.new(method: c.method(:my_method), args: 'abc', description: 'test1')
      expect do
        logger = Logger.new(STDERR)
        OctocatalogDiff::Util::Parallel.run_tasks([one], logger, true)
      end.to output(/DEBUG.*Begin test1/).to_stderr_from_any_process

      expect do
        logger = Logger.new(STDERR)
        OctocatalogDiff::Util::Parallel.run_tasks([one], logger, true)
      end.to output(/DEBUG.*Success test1/).to_stderr_from_any_process
    end

    it 'should log error messages' do
      class Foo
        def my_method(arg, _logger = nil)
          raise arg
        end
      end

      c = Foo.new
      one = OctocatalogDiff::Util::Parallel::Task.new(method: c.method(:my_method), args: 'abc', description: 'test1')
      two = OctocatalogDiff::Util::Parallel::Task.new(method: c.method(:my_method), args: 'def', description: 'test2')
      expect do
        logger = Logger.new(STDERR)
        OctocatalogDiff::Util::Parallel.run_tasks([one, two], logger, true)
      end.to output(/DEBUG.*Begin test[12]/).to_stderr_from_any_process

      expect do
        logger = Logger.new(STDERR)
        OctocatalogDiff::Util::Parallel.run_tasks([one, two], logger, true)
      end.to output(/DEBUG.*Failed test[12]: RuntimeError (abc|def)/).to_stderr_from_any_process
    end

    it 'should return empty array when no tasks are passed' do
      result = OctocatalogDiff::Util::Parallel.run_tasks([], nil, true)
      expect(result).to eq([])
    end

    it 'should validate results when a validator method is provided' do
      class Foo
        def one(arg, _logger = nil)
          'one ' + arg
        end

        def two(arg, _logger = nil)
          'two ' + arg
        end

        def validate(arg, _logger = nil, _extra_args = {})
          arg =~ /^one/ || arg =~ /^two/ ? true : false
        end
      end

      c = Foo.new
      v = c.method(:validate)
      one = OctocatalogDiff::Util::Parallel::Task.new(method: c.method(:one), args: 'abc', description: 'test1', validator: v)
      two = OctocatalogDiff::Util::Parallel::Task.new(method: c.method(:two), args: 'def', description: 'test2', validator: v)
      result = OctocatalogDiff::Util::Parallel.run_tasks([one, two], nil, true)
      expect(result).to be_a_kind_of(Array)
      expect(result.size).to eq(2)

      expect(result[0].status).to eq(true)
      expect(result[1].status).to eq(true)
    end

    it 'should recognize invalid results when a validator method is provided' do
      class Foo
        def one(arg, _logger = nil)
          'one ' + arg
        end

        def two(arg, _logger = nil)
          sleep 1
          'two ' + arg
        end

        def validate(arg, _logger = nil, _extra_args = {})
          arg =~ /^one/ ? true : false
        end
      end

      c = Foo.new
      v = c.method(:validate)
      one = OctocatalogDiff::Util::Parallel::Task.new(method: c.method(:one), args: 'abc', description: 'test1', validator: v)
      two = OctocatalogDiff::Util::Parallel::Task.new(method: c.method(:two), args: 'def', description: 'test2', validator: v)
      result = OctocatalogDiff::Util::Parallel.run_tasks([one, two], nil, true)
      expect(result).to be_a_kind_of(Array)
      expect(result.size).to eq(2)

      expect(result[0].status).to eq(true)
      expect(result[1].status).to eq(false)
    end

    it 'should kill other tasks when a validator method fails' do
      class Foo
        def one(arg, _logger = nil)
          sleep 10
          'one ' + arg
        end

        def two(arg, _logger = nil)
          'two ' + arg
        end

        def validate(arg, _logger = nil, _extra_args = {})
          arg =~ /^one/ ? true : false
        end
      end

      c = Foo.new
      v = c.method(:validate)
      one = OctocatalogDiff::Util::Parallel::Task.new(method: c.method(:one), args: 'abc', description: 'test1', validator: v)
      two = OctocatalogDiff::Util::Parallel::Task.new(method: c.method(:two), args: 'def', description: 'test2', validator: v)
      result = OctocatalogDiff::Util::Parallel.run_tasks([one, two], nil, true)
      expect(result).to be_a_kind_of(Array)
      expect(result.size).to eq(2)

      expect(result[0].status).to eq(nil)
      expect(result[1].status).to eq(false)
    end
  end

  context 'with serial processing' do
    it 'should perform tasks' do
      class Foo
        def one(arg, _logger = nil)
          'one ' + arg + ' ' + Time.now.to_i.to_s
        end

        def two(arg, _logger = nil)
          sleep 1
          'two ' + arg + ' ' + Time.now.to_i.to_s
        end
      end

      c = Foo.new
      one = OctocatalogDiff::Util::Parallel::Task.new(method: c.method(:one), args: 'abc', description: 'test1')
      two = OctocatalogDiff::Util::Parallel::Task.new(method: c.method(:two), args: 'def', description: 'test2')
      result = OctocatalogDiff::Util::Parallel.run_tasks([one, two], nil, false)
      expect(result).to be_a_kind_of(Array)
      expect(result.size).to eq(2)

      one_result = result[0]
      expect(one_result).to be_a_kind_of(OctocatalogDiff::Util::Parallel::Result)
      expect(one_result.status).to eq(true)
      expect(one_result.exception).to eq(nil)
      expect(one_result.output).to match(/^one abc \d+$/)

      two_result = result[1]
      expect(two_result).to be_a_kind_of(OctocatalogDiff::Util::Parallel::Result)
      expect(two_result.status).to eq(true)
      expect(two_result.exception).to eq(nil)
      expect(two_result.output).to match(/^two def \d+$/)

      one_time = Regexp.last_match(1).to_i if one_result.output =~ /(\d+{1,1000})$/
      two_time = Regexp.last_match(1).to_i if two_result.output =~ /(\d+{1,1000})$/
      expect(one_time).to be < two_time
    end

    it 'should handle a task that fails after other successes' do
      class Foo
        def one(arg, _logger = nil)
          'one ' + arg
        end

        def two(_arg, _logger = nil)
          raise 'Two failed'
        end
      end

      c = Foo.new
      one = OctocatalogDiff::Util::Parallel::Task.new(method: c.method(:one), args: 'abc', description: 'test1')
      two = OctocatalogDiff::Util::Parallel::Task.new(method: c.method(:two), args: 'def', description: 'test2')
      result = OctocatalogDiff::Util::Parallel.run_tasks([one, two], nil, false)
      expect(result).to be_a_kind_of(Array)
      expect(result.size).to eq(2)

      one_result = result[0]
      expect(one_result).to be_a_kind_of(OctocatalogDiff::Util::Parallel::Result)
      expect(one_result.status).to eq(true)
      expect(one_result.exception).to eq(nil)
      expect(one_result.output).to eq('one abc')

      two_result = result[1]
      expect(two_result).to be_a_kind_of(OctocatalogDiff::Util::Parallel::Result)
      expect(two_result.status).to eq(false)
      expect(two_result.exception).to be_a_kind_of(RuntimeError)
      expect(two_result.exception.message).to eq('Two failed')
    end

    it 'should not perform tasks once one fails' do
      class Foo
        def one(_arg, _logger = nil)
          raise 'One failed'
        end

        def two(arg, _logger = nil)
          'two ' + arg
        end
      end

      c = Foo.new
      one = OctocatalogDiff::Util::Parallel::Task.new(method: c.method(:one), args: 'abc', description: 'test1')
      two = OctocatalogDiff::Util::Parallel::Task.new(method: c.method(:two), args: 'def', description: 'test2')
      result = OctocatalogDiff::Util::Parallel.run_tasks([one, two], nil, false)
      expect(result).to be_a_kind_of(Array)
      expect(result.size).to eq(2)

      one_result = result[0]
      expect(one_result).to be_a_kind_of(OctocatalogDiff::Util::Parallel::Result)
      expect(one_result.status).to eq(false)
      expect(one_result.exception).to be_a_kind_of(::RuntimeError)
      expect(one_result.exception.message).to eq('One failed')
      expect(one_result.output).to eq(nil)

      two_result = result[1]
      expect(two_result).to be_a_kind_of(OctocatalogDiff::Util::Parallel::Result)
      expect(two_result.status).to eq(nil)
      expect(two_result.exception).to be_a_kind_of(OctocatalogDiff::Util::Parallel::IncompleteTask)
      expect(two_result.exception.message).to eq('Killed')
    end

    it 'should log debug messages' do
      class Foo
        def my_method(arg, _logger = nil)
          arg
        end
      end

      c = Foo.new
      one = OctocatalogDiff::Util::Parallel::Task.new(method: c.method(:my_method), args: 'abc', description: 'test1')
      logger, logger_string = OctocatalogDiff::Spec.setup_logger
      OctocatalogDiff::Util::Parallel.run_tasks([one], logger, false)
      expect(logger_string.string).to match(/DEBUG.*Begin test1/)
      expect(logger_string.string).to match(/DEBUG.*Success test1/)
    end

    it 'should log error messages' do
      class Foo
        def my_method(arg, _logger = nil)
          raise arg
        end
      end

      c = Foo.new
      one = OctocatalogDiff::Util::Parallel::Task.new(method: c.method(:my_method), args: 'abc', description: 'test1')
      two = OctocatalogDiff::Util::Parallel::Task.new(method: c.method(:my_method), args: 'def', description: 'test2')
      logger, logger_string = OctocatalogDiff::Spec.setup_logger
      OctocatalogDiff::Util::Parallel.run_tasks([one, two], logger, false)
      expect(logger_string.string).to match(/DEBUG.*Begin test1/)
      expect(logger_string.string).to match(/DEBUG.*Failed test1: RuntimeError abc/)
    end

    it 'should return empty array when no tasks are passed' do
      result = OctocatalogDiff::Util::Parallel.run_tasks([], nil, false)
      expect(result).to eq([])
    end

    it 'should validate results when a validator method is provided' do
      class Foo
        def one(arg, _logger = nil)
          'one ' + arg
        end

        def two(arg, _logger = nil)
          'two ' + arg
        end

        def validate(arg, _logger = nil, _extra_args = {})
          arg =~ /^one/ || arg =~ /^two/ ? true : false
        end
      end

      c = Foo.new
      v = c.method(:validate)
      one = OctocatalogDiff::Util::Parallel::Task.new(method: c.method(:one), args: 'abc', description: 'test1', validator: v)
      two = OctocatalogDiff::Util::Parallel::Task.new(method: c.method(:two), args: 'def', description: 'test2', validator: v)
      result = OctocatalogDiff::Util::Parallel.run_tasks([one, two], nil)
      expect(result).to be_a_kind_of(Array)
      expect(result.size).to eq(2)

      expect(result[0].status).to eq(true)
      expect(result[1].status).to eq(true)
    end

    it 'should recognize invalid results when a validator method is provided' do
      class Foo
        def one(arg, _logger = nil)
          'one ' + arg
        end

        def two(arg, _logger = nil)
          'two ' + arg
        end

        def validate(arg, _logger = nil, _extra_args = {})
          arg =~ /^one/ ? true : false
        end
      end

      c = Foo.new
      v = c.method(:validate)
      one = OctocatalogDiff::Util::Parallel::Task.new(method: c.method(:one), args: 'abc', description: 'test1', validator: v)
      two = OctocatalogDiff::Util::Parallel::Task.new(method: c.method(:two), args: 'def', description: 'test2', validator: v)
      result = OctocatalogDiff::Util::Parallel.run_tasks([one, two], nil, false)
      expect(result).to be_a_kind_of(Array)
      expect(result.size).to eq(2)

      expect(result[0].status).to eq(true)
      expect(result[1].status).to eq(false)
    end

    it 'should not perform subsequent tasks when a validator method fails' do
      class Foo
        def one(arg, _logger = nil)
          'one ' + arg
        end

        def two(arg, _logger = nil)
          'two ' + arg
        end

        def validate(arg, _logger = nil, _extra_args = {})
          arg =~ /^one/ ? false : true
        end
      end

      c = Foo.new
      v = c.method(:validate)
      one = OctocatalogDiff::Util::Parallel::Task.new(method: c.method(:one), args: 'abc', description: 'test1', validator: v)
      two = OctocatalogDiff::Util::Parallel::Task.new(method: c.method(:two), args: 'def', description: 'test2', validator: v)
      result = OctocatalogDiff::Util::Parallel.run_tasks([one, two], nil, false)
      expect(result).to be_a_kind_of(Array)
      expect(result.size).to eq(2)

      expect(result[0].status).to eq(false)
      expect(result[1].status).to eq(nil)
    end
  end

  describe '#run_tasks' do
    it 'should raise ArgumentError when passed something that is not a task' do
      not_a_task = double('foo')
      task_array = [not_a_task]
      expect do
        OctocatalogDiff::Util::Parallel.run_tasks(task_array)
      end.to raise_error(ArgumentError, /Element .* must be a OctocatalogDiff::Util::Parallel::Task, not a /)
    end
  end

  context 'on_result: callback' do
    it 'invokes the callback for each completed task in parallel mode' do
      class OnResultFoo
        def work(arg, _logger = nil)
          arg
        end
      end

      c = OnResultFoo.new
      collected = []
      callback = ->(r) { collected << r.output }

      tasks = %w[alpha beta gamma].map do |a|
        OctocatalogDiff::Util::Parallel::Task.new(method: c.method(:work), args: a, description: a)
      end

      OctocatalogDiff::Util::Parallel.run_tasks(tasks, nil, true, false, on_result: callback)
      expect(collected.sort).to eq(%w[alpha beta gamma])
    end

    it 'invokes the callback for each completed task in serial mode' do
      class OnResultSerial
        def work(arg, _logger = nil)
          arg
        end
      end

      c = OnResultSerial.new
      collected = []
      callback = ->(r) { collected << r.output }

      tasks = %w[one two three].map do |a|
        OctocatalogDiff::Util::Parallel::Task.new(method: c.method(:work), args: a, description: a)
      end

      OctocatalogDiff::Util::Parallel.run_tasks(tasks, nil, false, false, on_result: callback)
      # Serial mode preserves order
      expect(collected).to eq(%w[one two three])
    end

    it 'receives a failed Result when a task raises in parallel mode' do
      class OnResultFail
        def boom(_arg, _logger = nil)
          raise 'on_result failure test'
        end
      end

      c = OnResultFail.new
      statuses = []
      callback = ->(r) { statuses << r.status }

      task = OctocatalogDiff::Util::Parallel::Task.new(method: c.method(:boom), args: 'x', description: 'boom')
      OctocatalogDiff::Util::Parallel.run_tasks([task], nil, true, false, on_result: callback)
      expect(statuses).to eq([false])
    end
  end

  context 'fail_fast: false' do
    it 'allows all parallel tasks to complete even when one fails' do
      class FailFastFoo
        def succeed(arg, _logger = nil)
          sleep 0.3
          File.open(File.join(ENV['OCTOCATALOG_DIFF_TEMPDIR'], arg), 'w') { |f| f.write '' }
          arg
        end

        def fail_task(_arg, _logger = nil)
          raise 'deliberate failure'
        end
      end

      c = FailFastFoo.new
      tasks = [
        OctocatalogDiff::Util::Parallel::Task.new(method: c.method(:succeed), args: 'file_a', description: 'a'),
        OctocatalogDiff::Util::Parallel::Task.new(method: c.method(:fail_task), args: 'x', description: 'fail'),
        OctocatalogDiff::Util::Parallel::Task.new(method: c.method(:succeed), args: 'file_b', description: 'b'),
      ]

      result = OctocatalogDiff::Util::Parallel.run_tasks(tasks, nil, true, false, fail_fast: false)

      expect(result[0].status).to eq(true)
      expect(result[1].status).to eq(false)
      expect(result[2].status).to eq(true)

      # Both 'succeed' tasks should have written their files
      expect(File.file?(File.join(ENV['OCTOCATALOG_DIFF_TEMPDIR'], 'file_a'))).to eq(true)
      expect(File.file?(File.join(ENV['OCTOCATALOG_DIFF_TEMPDIR'], 'file_b'))).to eq(true)
    end

    it 'stops after first failure in serial mode when fail_fast: true (default)' do
      class FailFastSerial
        def one(_arg, _logger = nil)
          raise 'one failed'
        end

        def two(arg, _logger = nil)
          arg
        end
      end

      c = FailFastSerial.new
      tasks = [
        OctocatalogDiff::Util::Parallel::Task.new(method: c.method(:one), args: 'a', description: 'one'),
        OctocatalogDiff::Util::Parallel::Task.new(method: c.method(:two), args: 'b', description: 'two'),
      ]

      result = OctocatalogDiff::Util::Parallel.run_tasks(tasks, nil, false, false, fail_fast: true)
      expect(result[0].status).to eq(false)
      expect(result[1].status).to eq(nil) # never ran
    end

    it 'continues after failure in serial mode when fail_fast: false' do
      class FailFastSerialContinue
        def one(_arg, _logger = nil)
          raise 'one failed'
        end

        def two(arg, _logger = nil)
          arg
        end
      end

      c = FailFastSerialContinue.new
      tasks = [
        OctocatalogDiff::Util::Parallel::Task.new(method: c.method(:one), args: 'a', description: 'one'),
        OctocatalogDiff::Util::Parallel::Task.new(method: c.method(:two), args: 'b', description: 'two'),
      ]

      result = OctocatalogDiff::Util::Parallel.run_tasks(tasks, nil, false, false, fail_fast: false)
      expect(result[0].status).to eq(false)
      expect(result[1].status).to eq(true)
      expect(result[1].output).to eq('b')
    end
  end

  context 'OCTOCATALOG_DIFF_TEMPDIR isolation in forked children' do
    it 'does not inherit the parent OCTOCATALOG_DIFF_TEMPDIR in nested parallel calls' do
      # The parent sets OCTOCATALOG_DIFF_TEMPDIR. The forked child must clear it so
      # any nested run_tasks_parallel call creates its own tempdir rather than nesting
      # inside the parent's directory (which causes ENOENT when paths get too deep).
      class TmpdirIsolation
        def check_env(_arg, _logger = nil)
          # Return the env var value as seen inside the fork
          ENV['OCTOCATALOG_DIFF_TEMPDIR'].to_s
        end
      end

      parent_tmpdir = ENV['OCTOCATALOG_DIFF_TEMPDIR']
      c = TmpdirIsolation.new
      task = OctocatalogDiff::Util::Parallel::Task.new(
        method: c.method(:check_env), args: nil, description: 'env_check'
      )

      result = OctocatalogDiff::Util::Parallel.run_tasks([task], nil, true)
      expect(result[0].status).to eq(true)
      # The child should have seen an empty/cleared env var
      expect(result[0].output).to eq('')
      # The parent's env var should be unchanged
      expect(ENV['OCTOCATALOG_DIFF_TEMPDIR']).to eq(parent_tmpdir)
    end
  end
end
