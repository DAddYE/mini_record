require 'rubygems'
require 'bundler/gem_tasks'
require 'rake'
require 'rake/testtask'

%w(install release).each do |task|
  Rake::Task[task].enhance do
    sh "rm -rf pkg"
  end
end

Rake::TestTask.new(:test) do |test|
  test.libs << 'test'
  test.test_files = Dir['test/**/test_*.rb']
  test.verbose = true
end

task :default => :test
task :spec    => :test
