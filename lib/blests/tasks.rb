# frozen_string_literal: true

require 'rake'
require 'parallel_tests'
require 'knapsack'
require 'fileutils'

module Blests
  module Tasks
    class << self
      def rails_env
        ENV['RAILS_ENV'] || 'test'
      end

      def workers(options = {})
        cpu_num = options[:count] if options[:count].to_s =~ /^\d*$/
        return ['-n', "#{cpu_num}"] unless cpu_num.to_s.empty?

        return ['-n', "#{ENV['BLESTS_PARALLEL_WORKERS']}"] if ENV['BLESTS_PARALLEL_WORKERS'] =~ /^\d*$/

        []
      end
    end
  end
end

namespace :blests do
  desc 'Create test databases via db:create --> blests:create[num_cpus]'
  task :create, [:count] do |_, args|
    # ParallelTests::CLI.new.run(['--type', 'test', '--prefix-output-with-test-env-number'] + Blests::Tasks.workers(args) + ['--exec', "rake db:create RAILS_ENV=#{Blests::Tasks.rails_env}"])
    parallel_parameter = Blests::Tasks.workers(args)
    rargs = []
    rargs <<  parallel_parameter[1] if parallel_parameter.length == 2

    Rake::Task['parallel:create'].invoke(*rargs)
  end

  desc 'Drop test databases via db:drop --> blests:drop[num_cpus]'
  task :drop, [:count] do |_, args|
    # ParallelTests::CLI.new.run(['--type', 'test', '--prefix-output-with-test-env-number'] + Blests::Tasks.workers(args) + ['--exec', "rake db:drop RAILS_ENV=#{Blests::Tasks.rails_env} DISABLE_DATABASE_ENVIRONMENT_CHECK=1"])
    parallel_parameter = Blests::Tasks.workers(args)
    rargs = []
    rargs <<  parallel_parameter[1] if parallel_parameter.length == 2

    Rake::Task['parallel:drop'].invoke(*rargs)
  end

  desc 'Check for pending migrations and load the test schema --> blests:prepare[num_cpus]'
  task :test_prepare, [:count] do |_, args|
    ParallelTests::CLI.new.run(['--type', 'test', '--prefix-output-with-test-env-number'] + Blests::Tasks.workers(args) + ['--exec', "rake db:test:prepare RAILS_ENV=#{Blests::Tasks.rails_env}"])
  end

  desc 'Load dumped schema for test databases via db:schema:load --> blests:load_schema[num_cpus]'
  task :load_schema, [:count] do |_, args|
    # ParallelTests::CLI.new.run(['--type', 'test', '--prefix-output-with-test-env-number'] + Blests::Tasks.workers(args) + ['--exec', "rake db:schema:load RAILS_ENV=#{Blests::Tasks.rails_env} DISABLE_DATABASE_ENVIRONMENT_CHECK=1"])
    parallel_parameter = Blests::Tasks.workers(args)
    rargs = []
    rargs <<  parallel_parameter[1] if parallel_parameter.length == 2

    Rake::Task['parallel:load_schema'].invoke(*rargs)
  end

  desc 'Run RSpec'
  task :rspec, [:count, :report_path, :test_pattern] do |_,args|
    opts = [args[:count], args[:report_path], args[:test_pattern]]

    parallel_tests_opts = ['--type', 'rspec']
    rspec_opts = []

    cpu_num = opts.shift if opts.first.to_s =~ /^\d*$/
    parallel_tests_opts += cpu_num.to_s.empty? ? Blests::Tasks.workers(args) : ['-n', "#{cpu_num}"]
    report_path = opts.shift.to_s
    test_pattern = opts.shift.to_s

    unless report_path.empty?
      # Define knapsack_report_path and create if not exists to avoid knapsack error
      knapsack_report_path = File.join(File.expand_path(report_path), 'knapsack', 'master_report.json')

      # Knapsack partial report of pod and process and create directory if not exists
      knapsack_partial_report_path = File.join(File.dirname(knapsack_report_path), 'partial')
      FileUtils.mkdir_p(knapsack_partial_report_path) unless File.directory?(knapsack_partial_report_path)

      File.open(knapsack_report_path, 'w') { |f| f.write({}.to_json) } unless File.file?(knapsack_report_path)

      ENV['KNAPSACK_REPORT_PATH'] = knapsack_report_path
      ENV['KNAPSACK_GENERATE_REPORT'] = 'true'

      parallel_tests_opts += ['--group-by', 'runtime', '--runtime-log', "#{knapsack_report_path}", '--allowed-missing', '100']
      # rspec_opts += ['--format', 'ParallelTests::RSpec::RuntimeLogger', '--out', "#{File.join(report_path, 'parallel_runtime_rspec.log')}"]
    end

    config = {}
    config[:test_file_pattern] = test_pattern unless test_pattern.empty?
    Knapsack.report.config(config) unless config.empty?

    allocator = Knapsack::AllocatorBuilder.new(Knapsack::Adapters::RSpecAdapter).allocator
    rspec_opts += ['--default-path', "#{allocator.test_dir}"]

    if ENV['BLESTS_PRINT_TEST_FILES'] =~ /^true$/i
      Knapsack.logger.info
      Knapsack.logger.info 'Report specs:'
      Knapsack.logger.info allocator.report_node_tests
      Knapsack.logger.info
      Knapsack.logger.info 'Leftover specs:'
      Knapsack.logger.info allocator.leftover_node_tests
      Knapsack.logger.info
    end

    ParallelTests::CLI.new.run(parallel_tests_opts + ['--'] + rspec_opts + ['--'] + allocator.node_tests)
  end

  desc 'Merge knapsack partial report to master report'
  task :merge_report, [:report_path] do |_,args|
    abort('please provide report_path argument.') if args[:report_path].to_s.empty?

    absolute_report_path = File.expand_path(args[:report_path])
    puts "Processing report from #{absolute_report_path}"

    master_report_path = File.join(absolute_report_path, 'master_report.json')
    master_report = begin
      JSON.parse(File.read(master_report_path))
    rescue Errno::ENOENT, JSON::ParserError
      {}
    end

    Dir.glob(File.join(absolute_report_path, 'partial', '*.json')).each do |r|
      master_report.merge! JSON.parse(File.read(r))
      puts "- Merge partial report #{r}"
    end

    File.write(master_report_path, JSON.pretty_generate(master_report))
    puts "Master report #{master_report_path}"

    FileUtils.remove_dir(File.join(absolute_report_path, 'partial'), true)
  end
end
