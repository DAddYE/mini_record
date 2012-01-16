require 'logger'

ActiveRecord::Base.establish_connection(:adapter => 'sqlite3', :database => ':memory:')
# ActiveRecord::Base.logger = ActiveSupport::BufferedLogger.new($stdout)

class Person < ActiveRecord::Base
  schema do |s|
    s.string :name
  end
  timestamps
end

class Post < ActiveRecord::Base
  key :title
  key :body
  key :category, :as => :references
  belongs_to :category
end

class Category < ActiveRecord::Base
  key :title
  has_many :articles
  has_many :posts
  has_many :items
end

class Animal < ActiveRecord::Base
  key :name, :index => true
  index :id
end

class Pet < ActiveRecord::Base
  key :name, :index => true
end

class Tool < ActiveRecord::Base
  has_and_belongs_to_many :purposes
end

class Purpose < ActiveRecord::Base
  has_and_belongs_to_many :tools
end

class Publisher < ActiveRecord::Base
  has_many :articles
  col :name
end

class Article < ActiveRecord::Base
  key :title
  belongs_to :publisher
end

class Attachment < ActiveRecord::Base
  key :name
  belongs_to :attachable, :polymorphic => true
end

class Account < ActiveRecord::Base
  key :name
end

class Task < ActiveRecord::Base
  belongs_to :author, :class_name => 'Account'
end

class Activity < ActiveRecord::Base
  belongs_to :author, :class_name => 'Account', :foreign_key => 'custom_id'
end
