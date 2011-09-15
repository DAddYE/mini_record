require File.expand_path('../spec_helper.rb', __FILE__)

createdb_bin = ENV['TEST_CREATEDB_BIN'] || 'createdb'
dropdb_bin = ENV['TEST_DROPDB_BIN'] || 'dropdb'
username = ENV['TEST_POSTGRES_USERNAME'] || `whoami`.chomp
# password = ENV['TEST_POSTGRES_PASSWORD'] || 'password'
database = ENV['TEST_POSTGRES_DATABASE'] || 'test_mini_record'

system %{#{dropdb_bin} #{database}}
system %{#{createdb_bin} #{database}}

ActiveRecord::Base.establish_connection(
  'adapter' => 'postgresql',
  'encoding' => 'utf8',
  'database' => database,
  'username' => username,
  # 'password' => password
)

# require 'logger'
# ActiveRecord::Base.logger = ActiveSupport::BufferedLogger.new($stdout)

require File.expand_path('../models.rb', __FILE__)

require File.expand_path('../shared_examples.rb', __FILE__)
