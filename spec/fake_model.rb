require 'logger'

ActiveRecord::Base.establish_connection(:adapter => 'sqlite3', :database => ':memory:')
# ActiveRecord::Base.connection.tables.each { |t| ActiveRecord::Base.connection.drop_table(t) }
# ActiveRecord::Base.logger = Logger.new($stdout)

class Person < ActiveRecord::Base
  properties do |p|
    p.string :name
  end

  # Testing purpose
  def self.db_columns
    connection.columns(table_name).map(&:name)
  end

  def self.schema_columns
    table_definition = ActiveRecord::ConnectionAdapters::TableDefinition.new(connection)
    table_definition.columns.map(&:name)
  end
end
