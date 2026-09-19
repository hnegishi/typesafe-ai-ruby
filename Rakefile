# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"
require "rubocop/rake_task"

Rake::TestTask.new(:test) do |t|
  t.libs << "test" << "lib"
  t.test_files = FileList["test/typesafe/**/*_test.rb"]
  t.warning = true
end

namespace :test do
  desc "Run the live API tests (requires TYPESAFE_API_KEY)"
  Rake::TestTask.new(:integration) do |t|
    t.libs << "test" << "lib"
    t.test_files = FileList["test/integration/**/*_test.rb"]
    t.warning = true
  end
end

RuboCop::RakeTask.new

desc "Validate the RBS signatures in sig/"
task :rbs do
  sh "rbs -I sig -r logger -r uri -r net-http validate"
end

task default: %i[test rubocop rbs]
