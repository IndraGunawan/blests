Knapsack::Distributors::BaseDistributor.class_eval do
  def all_tests
    @all_tests ||= begin
      test_files = Dir.glob(test_file_pattern).uniq.sort

      return test_files - ENV['BLESTS_EXCLUDE_TEST'].split(',').map(&:strip).reject(&:empty?) unless ENV['BLESTS_EXCLUDE_TEST'].nil? && ENV['BLESTS_EXCLUDE_TEST'].empty?

      test_files
    end
  end
end
