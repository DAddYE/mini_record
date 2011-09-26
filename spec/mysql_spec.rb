require File.expand_path('../spec_helper.rb', __FILE__)

bin = ENV['TEST_MYSQL_BIN'] || 'mysql'
username = ENV['TEST_MYSQL_USERNAME'] || 'root'
password = ENV['TEST_MYSQL_PASSWORD'] || 'password'
database = ENV['TEST_MYSQL_DATABASE'] || 'test_mini_record'
cmd = "#{bin} -u #{username} -p#{password}"

`#{cmd} -e 'show databases'`
unless $?.success?
  $stderr.puts "Skipping mysql tests because `#{cmd}` doesn't work"
  exit 0
end

system %{#{cmd} -e "drop database #{database}"}
system %{#{cmd} -e "create database #{database}"}

ActiveRecord::Base.establish_connection(
  'adapter' => 'mysql',
  'encoding' => 'utf8',
  'database' => database,
  'username' => username,
  'password' => password
)

# require 'logger'
# ActiveRecord::Base.logger = ActiveSupport::BufferedLogger.new($stdout)

require File.expand_path('../models.rb', __FILE__)

require File.expand_path('../shared_examples.rb', __FILE__)
