require "bundler/gem_tasks"
require "rake/testtask"

# The Rails tests boot a Rails app, so they run in a process of their own.
# The other tests then prove that the gem works without Rails.
Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.test_files = FileList["test/snapsbrew/**/*_test.rb"]
end

namespace :test do
  Rake::TestTask.new(:rails) do |t|
    t.libs << "test"
    t.test_files = FileList["test/rails/**/*_test.rb"]
  end

  Rake::TestTask.new(:integration) do |t|
    t.libs << "test"
    t.test_files = FileList["test/integration/**/*_test.rb"]
  end
end

desc "Validate the RBS signatures in sig/"
task :rbs do
  sh "rbs -r net-http -r uri -r json -r openssl -I sig validate"
end

task default: %w[ test test:rails test:integration ]

# Never publish from a laptop. The release workflow builds the gem by hand.
Rake::Task["release"].clear
