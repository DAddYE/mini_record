require 'rubygems' unless defined?(Gem)
require 'bundler/setup'
require 'mini_record'
require 'minitest/autorun'

class ActiveRecord::Base
  class << self
    attr_accessor :logs

    def db_columns
      connection.columns(table_name).map(&:name).sort
    end

    def db_indexes
      connection.indexes(table_name).map(&:name).sort
    end

    def schema_columns
      table_definition.columns.map { |c| c.name.to_s }.sort
    end

    def queries(pragma=false)
      ActiveRecord::Base.logs.string.gsub(/\e\[[\d;]+m/, '').lines.reject { |l| !pragma && l =~ /pragma/i }.join("\n")
    end

    def auto_upgrade!
      ActiveRecord::Base.logs = StringIO.new
      ActiveRecord::Base.logger = ActiveSupport::BufferedLogger.new(ActiveRecord::Base.logs)
      silence_stream(STDERR) { super }
    end
  end
end # ActiveRecord::Base

# Setup Adatper
case ENV['DB']
when 'mysql'
  ActiveRecord::Base.establish_connection(:adapter => 'mysql', :database => 'test', :user => 'root')
when 'pg', 'postgresql'
  ActiveRecord::Base.establish_connection(:adapter => 'postgresql', :database => 'test', :user => 'postgres', :host => 'localhost')
else
  ActiveRecord::Base.establish_connection(:adapter => 'sqlite3', :database => ':memory:')
end


# Some helpers to minitest
class MiniTest::Spec
  def connection
    ActiveRecord::Base.connection
  end
  alias :conn :connection
end
