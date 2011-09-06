require 'logger'

ActiveRecord::Base.establish_connection(:adapter => 'sqlite3', :database => ':memory:')
# ActiveRecord::Base.connection.tables.each { |t| ActiveRecord::Base.connection.drop_table(t) }
# ActiveRecord::Base.logger = Logger.new($stdout)

module SpecHelper
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def db_columns
      connection.columns(table_name).map(&:name)
    end

    def schema_columns
      table_definition.columns.map { |c| c.name.to_s }
    end
  end
end

class Person < ActiveRecord::Base
  include SpecHelper
  schema do |s|
    s.string :name
  end
end

class Post < ActiveRecord::Base
  include SpecHelper

  key.string :title
  key.string :body
  key.references :category
  belongs_to :category
end

class Category < ActiveRecord::Base
  include SpecHelper

  key.string :title
  has_many :posts
end
