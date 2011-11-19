require 'logger'

ActiveRecord::Base.establish_connection(:adapter => 'sqlite3', :database => ':memory:')
# ActiveRecord::Base.logger = ActiveSupport::BufferedLogger.new($stdout)

module SpecHelper
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def db_columns
      connection.columns(table_name).map(&:name).sort
    end

    def db_indexes
      connection.indexes(table_name).map(&:name).sort
    end

    def schema_columns
      table_definition.columns.map { |c| c.name.to_s }.sort
    end
  end
end

class Person < ActiveRecord::Base
  include SpecHelper
  schema do |s|
    s.string :name
  end
  timestamps
end

class Post < ActiveRecord::Base
  include SpecHelper

  key :title
  key :body
  key :category, :as => :references
  belongs_to :category
end

class Category < ActiveRecord::Base
  include SpecHelper

  key :title
  has_many :posts
end

class Animal < ActiveRecord::Base
  include SpecHelper

  key :name, :index => true
  index :id
end

class Pet < ActiveRecord::Base
  include SpecHelper

  key :name, :index => true
end
