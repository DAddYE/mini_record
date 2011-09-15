require File.expand_path('../spec_helper.rb', __FILE__)

ActiveRecord::Base.establish_connection(:adapter => 'sqlite3', :database => ':memory:')

# require 'logger'
# ActiveRecord::Base.logger = ActiveSupport::BufferedLogger.new($stdout)

require File.expand_path('../models.rb', __FILE__)

require File.expand_path('../shared_examples.rb', __FILE__)
