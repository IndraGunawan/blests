# frozen_string_literal: true

require 'json'
require 'parallel_tests/test/runner'

ParallelTests::Test::Runner.instance_eval do
  # Override to read knapsack master_report.json
  def runtimes(tests, options)
    lines = JSON.parse(File.read(options[:runtime_log]))
    lines.each_with_object({}) do |(test, time), times|
      times[test] = time.to_f if tests.include?(test)
    end
  end
end
