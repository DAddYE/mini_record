require "bundler/gem_tasks"
require "rake"
require "rake/testtask"

Rake::TestTask.new(:test) do |test|
  test.libs << 'spec'
  test.test_files = Dir['spec/**/*_spec.rb']
  test.verbose = true
end

task :default => :test
task :spec    => :test
