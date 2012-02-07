require File.expand_path('../spec_helper.rb', __FILE__)

describe MiniRecord do

  before do
    ActiveRecord::Base.descendants.each { |klass| Object.send(:remove_const, klass.to_s) }
    ActiveSupport::DescendantsTracker.direct_descendants(ActiveRecord::Base).clear
    load File.expand_path('../models.rb', __FILE__)
    ActiveRecord::Base.auto_upgrade!
  end

  it 'has #schema inside model' do
    Person.table_name.must_equal 'people'
    Person.db_columns.sort.must_equal %w[created_at id name updated_at]
    Person.column_names.sort.must_equal Person.db_columns.sort
    Person.column_names.sort.must_equal Person.schema_columns.sort
    person = Person.create(:name => 'foo')
    person.name.must_equal 'foo'
    proc { person.surname }.must_raise NoMethodError

    # Test the timestamp columns exist
    person.must_respond_to :created_at
    person.must_respond_to :updated_at

    # Add a column without lost data
    Person.class_eval do
      schema do |p|
        p.string :name
        p.string :surname
      end
      timestamps
    end
    Person.auto_upgrade!
    Person.count.must_equal 1
    person = Person.last
    person.name.must_equal 'foo'
    person.surname.must_be_nil
    person.update_attribute(:surname, 'bar')
    Person.db_columns.sort.must_equal %w[created_at id name surname updated_at]
    # Person.column_names.must_equal Person.db_columns

    # Remove a column without lost data
    Person.class_eval do
      schema do |p|
        p.string :name
      end
      timestamps
    end
    Person.auto_upgrade!
    person = Person.last
    person.name.must_equal 'foo'
    proc { person.surname }.must_raise NoMethodError
    Person.db_columns.sort.must_equal %w[created_at id name updated_at]
    Person.column_names.sort.must_equal Person.db_columns.sort
    Person.column_names.sort.must_equal Person.schema_columns.sort

    # Change column without lost data
    Person.class_eval do
      schema do |p|
        p.text :name
      end
    end
    person = Person.last
    person.name.must_equal 'foo'
  end

  it 'has #key,col,property,attribute inside model' do
    Post.column_names.sort.must_equal Post.db_columns
    Category.column_names.sort.must_equal Category.schema_columns

    # Check default properties
    category = Category.create(:title => 'category')
    post = Post.create(:title => 'foo', :body => 'bar', :category_id => category.id)
    post = Post.first
    post.title.must_equal 'foo'
    post.body.must_equal 'bar'
    post.category.must_equal category


    # Remove a column
    Post.reset_table_definition!
    Post.class_eval do
      col :name
      col :category, :as => :references
    end
    Post.auto_upgrade!
    post = Post.first
    post.name.must_be_nil
    post.category.must_equal category
    proc { post.title }.must_raise ActiveModel::MissingAttributeError
  end

  it 'has indexes inside model' do
    # Check indexes
    Animal.db_indexes.size.must_be :>, 0
    Animal.db_indexes.must_equal Animal.indexes.keys.sort

    indexes_was = Animal.db_indexes

    # Remove an index
    Animal.indexes.delete(indexes_was.pop)
    Animal.auto_upgrade!
    Animal.indexes.keys.sort.must_equal indexes_was
    Animal.db_indexes.must_equal indexes_was

    # Add a new index
    Animal.class_eval do
      col :category, :as => :references, :index => true
    end
    Animal.auto_upgrade!
    Animal.db_columns.must_include "category_id"
    Animal.db_indexes.must_equal((indexes_was << "index_animals_on_category_id").sort)
  end

  it 'works with STI' do
    class Dog < Pet; end
    class Cat < Pet; end
    ActiveRecord::Base.auto_upgrade!

    # Check inheritance column
    Pet.db_columns.must_include "type"

    # Now, let's we know if STI is working
    Pet.create(:name => "foo")
    Dog.create(:name => "bar")
    Dog.count.must_equal 1
    Dog.first.name.must_equal "bar"
    Pet.count.must_equal 2
    Pet.all.map(&:name).must_equal ["foo", "bar"]

    # Check that this doesn't break things
    Dog.first.name.must_equal "bar"

    # What's happen if we change schema?
    Dog.table_definition.must_equal Pet.table_definition
    Dog.indexes.must_equal Pet.indexes
    Dog.class_eval do
      col :bau
    end
    ActiveRecord::Base.auto_upgrade!
    Dog.schema_columns.must_include "bau"
    Pet.db_columns.must_include "bau"
    # Dog.new.must_respond_to :bau
    # Cat.new.must_respond_to :bau
  end

  it 'works with custom inheritance column' do
    class User < ActiveRecord::Base
      col :name
      col :surname
      col :role
      def self.inheritance_column; 'role'; end
    end

    class Administrator < User; end
    class Customer < User; end

    User.auto_upgrade!
    User.inheritance_column.must_equal 'role'
    Administrator.create(:name => "Davide", :surname => 'DAddYE')
    Customer.create(:name => "Foo", :surname => "Bar")
    Administrator.count.must_equal 1
    Administrator.first.name.must_equal "Davide"
    Customer.count.must_equal 1
    Customer.first.name.must_equal "Foo"
    User.count.must_equal 2
    User.first.role.must_equal "Administrator"
    User.last.role.must_equal "Customer"
  end

  it 'allow multiple columns definitions' do
    class Fake < ActiveRecord::Base
      col :name, :surname
      col :category, :group, :as => :references
    end
    Fake.auto_upgrade!
    Fake.create(:name => 'foo', :surname => 'bar', :category_id => 1, :group_id => 2)
    fake = Fake.first
    fake.name.must_equal 'foo'
    fake.surname.must_equal 'bar'
    fake.category_id.must_equal 1
    fake.group_id.must_equal 2
  end

  it 'creates a column and index based on belongs_to relation' do
    Article.create(:title => 'Hello', :publisher_id => 1)
    Article.first.tap do |a|
      a.title.must_equal 'Hello'
      a.publisher_id.must_equal 1
    end
    Article.db_indexes.must_include 'index_articles_on_publisher_id'
    # Ensure that associated field/index is not deleted on upgrade
    Article.auto_upgrade!
    Article.first.publisher_id.must_equal 1
    Article.db_indexes.must_include 'index_articles_on_publisher_id'
  end

  it 'removes a column and index when belongs_to relation is removed' do
    class Foo < ActiveRecord::Base
      key :name
      belongs_to :image, :polymorphic => true
    end
    Foo.auto_upgrade!
    Foo.db_columns.must_include 'name'
    Foo.db_columns.must_include 'image_type'
    Foo.db_columns.must_include 'image_id'
    Foo.db_indexes.must_include 'index_foos_on_image_id_and_image_type'
    Foo.class_eval do
      reset_table_definition!
      reflections.clear
      indexes.clear
      key :name
    end
    Foo.auto_upgrade!
    Foo.db_columns.must_include 'name'
    Foo.db_columns.wont_include 'image_type'
    Foo.db_columns.wont_include 'image_id'
    Foo.db_indexes.must_be_empty
  end

  it 'creates columns and index based on belongs_to polymorphic relation' do
    Attachment.create(:name => 'Avatar', :attachable_id => 1, :attachable_type => 'Post')
    Attachment.first.tap do |attachment|
      attachment.name.must_equal 'Avatar'
      attachment.attachable_id.must_equal 1
      attachment.attachable_type.must_equal 'Post'
    end
    index = 'index_attachments_on_attachable_id_and_attachable_type'
    Attachment.db_indexes.must_include index
    # Ensure that associated fields/indexes are not deleted on subsequent upgrade
    Attachment.auto_upgrade!
    Attachment.first.attachable_id.must_equal 1
    Attachment.first.attachable_type.must_equal 'Post'
    Attachment.db_indexes.must_include index
  end

  it 'creates a join table with indexes for has_and_belongs_to_many relations' do
    tables = Tool.connection.tables
    tables.must_include('purposes_tools')
    index = 'index_purposes_tools_on_purposes_tool_id_and_purpose_id'
    Tool.connection.indexes('purposes_tools').map(&:name).must_include index
    # Ensure that join table is not deleted on subsequent upgrade
    Tool.auto_upgrade!
    tables.must_include('purposes_tools')
    Tool.connection.indexes('purposes_tools').map(&:name).must_include index
  end

  it 'creates a join table with indexes for has_and_belongs_to_many relations with long name' do
    tables = Photogallery.connection.tables
    tables.must_include('pages_photogalleries')
    index = 'index_pages_photogalleries_on_pages_photogallery_id_and_photogallery_id'[0..63]
    Tool.connection.indexes('pages_photogalleries').map(&:name).must_include index
    # Ensure that join table is not deleted on subsequent upgrade
    Tool.auto_upgrade!
    tables.must_include('pages_photogalleries')
    Tool.connection.indexes('pages_photogalleries').map(&:name).must_include index
  end

  it 'drops join table if has_and_belongs_to_many relation is deleted' do
    Tool.schema_tables.delete('purposes_tools')
    ActiveRecord::Base.schema_tables.wont_include('purposes_tools')
    ActiveRecord::Base.clear_tables!
    Tool.connection.tables.wont_include('purposes_tools')
  end

  it 'has_and_belongs_to_many with custom join_table and foreign keys' do
    class Foo < ActiveRecord::Base
      has_and_belongs_to_many :watchers, :join_table => :watchers, :foreign_key => :custom_foo_id, :association_foreign_key => :customer_id
    end
    Foo.auto_upgrade!
    conn = ActiveRecord::Base.connection
    conn.tables.must_include 'watchers'
    cols = conn.columns('watchers').map(&:name)
    cols.wont_include 'id'
    cols.must_include 'custom_foo_id'
    cols.must_include 'customer_id'
  end

  it 'should support #belongs_to with :class_name' do
    Task.schema_columns.must_include 'author_id'
    Task.db_columns.must_include 'author_id'
  end

  it 'should support #belongs_to with :foreign_key' do
    Activity.schema_columns.must_include 'custom_id'
    Activity.db_columns.must_include 'custom_id'
  end

  it 'should memonize in schema relationships' do
    conn = ActiveRecord::Base.connection
    conn.create_table('foos')
    conn.add_column :foos, :name, :string
    conn.add_column :foos, :bar_id, :integer
    conn.add_index  :foos, :bar_id
    class Foo < ActiveRecord::Base
      col :name
      belongs_to :bar
    end
    Foo.db_columns.must_include 'name'
    Foo.db_columns.must_include 'bar_id'
    Foo.db_indexes.must_include 'index_foos_on_bar_id'
    Foo.auto_upgrade!
    Foo.schema_columns.must_include 'name'
    Foo.schema_columns.must_include 'bar_id'
    Foo.indexes.must_include 'index_foos_on_bar_id'
  end

  it 'should add new columns without lost belongs_to schema' do
    publisher  = Publisher.create(:name => 'foo')
    article = Article.create(:title => 'bar', :publisher => publisher)
    article.valid?.must_equal true
    Article.indexes.must_include 'index_articles_on_publisher_id'
    # Here we perform a schema change
    Article.key :body
    Article.auto_upgrade!
    article.reload
    article.body.must_be_nil
    article.update_attribute(:body, 'null')
    article.body.must_equal 'null'
    # Finally check the index existance
    Article.db_indexes.must_include 'index_articles_on_publisher_id'
  end

  it 'should add multiple index' do
    class Foo < ActiveRecord::Base
      key :name, :surname, :index => true
    end
    Foo.auto_upgrade!
    Foo.db_indexes.must_include 'index_foos_on_name'
    Foo.db_indexes.must_include 'index_foos_on_surname'
  end

  it 'should create a unique index' do
    class Foo < ActiveRecord::Base
      key :name, :surname
      add_index([:name, :surname], :unique => true)
    end
    Foo.auto_upgrade!
    db_indexes = Foo.connection.indexes('foos')[0]
    db_indexes.name.must_equal 'index_foos_on_name_and_surname'
    db_indexes.unique.must_equal true
    db_indexes.columns.sort.must_equal ['name', 'surname']
  end
end
