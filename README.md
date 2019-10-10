# Blests

Blests is combination of knapsack (https://rubygems.org/gems/knapsack) and parallel_tests (https://rubygems.org/gems/parallel_tests). Knapsack will distribute tests across parallel job and parallel_test and running that test by parallel_tests to every available processors with single master-report.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'blests'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install blests

## Usage

by default if you enable the `parallel` in your gitlab job specs, there are `CI_NODE_INDEX` and `CI_NODE_TOTAL` environment variables set to every job, knapsack will distribute the test files by using this env.

```rb
# add this line to spec/spec_helper.rb
require 'knapsack'
Knapsack::Adapters::RspecAdapter.bind
```

```sh
export BLESTS_PARALLEL_WORKERS=2      # Number of parallel process, typically number of processors. if using kubernetes please set this env or it will use all node processors
export BLESTS_PRINT_TEST_FILES=trye   # Print tests files that will run in this job
export PARALLEL_TEST_FIRST_IS_1=true  # ENV['TEST_ENV_NUMBER'] will start from 1 otherwise ''

# Create test-db and load schema
bundle exec rake blests:create blests:load_schema

# Running tests
bundle exec rake blests:rspec[test_result_dir]  # all test result will be written to `test_result_dir`
```

## Development

Run `rake spec` to run the tests.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags.

## Contributing

Bug reports and pull requests are welcome on Github at https://github.com/IndraGunawan/blests

## License

[MIT](LICENSE)
