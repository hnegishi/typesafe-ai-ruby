# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"
require "rubocop/rake_task"

Rake::TestTask.new(:test) do |t|
  t.libs << "test" << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
  t.warning = true
end

RuboCop::RakeTask.new

desc "Validate the RBS signatures in sig/"
task :rbs do
  sh "rbs -I sig -r logger -r uri -r net-http validate"
end

task default: %i[test rubocop rbs]
