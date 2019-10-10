# frozen_string_literal: true

require 'knapsack/report'
require 'json'

Knapsack::Report.class_eval do
  def save
    File.open(File.join(File.dirname(report_path), 'partial', "report_node_#{Knapsack::Config::Env.ci_node_index}_parallel_#{ENV['TEST_ENV_NUMBER']}.json"), 'w') do |f|
      f.write(report_json)
    end
  end
end
