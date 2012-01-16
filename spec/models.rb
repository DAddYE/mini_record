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
  has_many :articles
  has_many :posts
  has_many :items
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

class Tool < ActiveRecord::Base
  include SpecHelper

  has_and_belongs_to_many :purposes
end

class Purpose < ActiveRecord::Base
  include SpecHelper
  has_and_belongs_to_many :tools
end

class Publisher < ActiveRecord::Base
  include SpecHelper
  has_many :articles
  col :name
end

class Article < ActiveRecord::Base
  include SpecHelper
  key :title
  belongs_to :publisher
end

class Attachment < ActiveRecord::Base
  include SpecHelper
  key :name
  belongs_to :attachable, :polymorphic => true
end

class Account < ActiveRecord::Base
  include SpecHelper
  key :name
end

class Task < ActiveRecord::Base
  include SpecHelper
  belongs_to :author, :class_name => 'Account'
end
