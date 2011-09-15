# be sure to set up activerecord before you require this helper

class Person < ActiveRecord::Base
  include SpecHelper
  schema do |s|
    s.string :name
  end
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
class Dog < Pet; end
class Cat < Pet; end

class Vegetable < ActiveRecord::Base
  include SpecHelper

  set_primary_key :latin_name
  
  col :latin_name
  col :common_name
end

class User < ActiveRecord::Base
  include SpecHelper
  col :name
  col :surname
  col :role
  set_inheritance_column :role
end
class Administrator < User; end
class Customer < User; end

class Fake < ActiveRecord::Base
  include SpecHelper
  col :name, :surname
  col :category, :group, :as => :references
end

class AutomobileMakeModelYearVariant < ActiveRecord::Base
  include SpecHelper
  col :make_model_year_name
  add_index :make_model_year_name
end
