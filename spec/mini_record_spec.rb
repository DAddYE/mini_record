require File.expand_path('../spec_helper.rb', __FILE__)
require File.expand_path('../models.rb', __FILE__)

describe MiniRecord do

  it 'has #schema inside model' do
    # For unknown reason separate specs doesn't works
    ActiveRecord::Base.connection.table_exists?(Person.table_name).must_equal false
    Person.auto_upgrade!
    Person.table_name.must_equal 'people'
    Person.db_columns.sort.must_equal %w[id name]
    Person.column_names.must_equal Person.db_columns
    Person.column_names.must_equal Person.schema_columns
    person = Person.create(:name => 'foo')
    person.name.must_equal 'foo'
    proc { person.surname }.must_raise NoMethodError

    # Add a column without lost data
    Person.class_eval do
      schema do |p|
        p.string :name
        p.string :surname
      end
    end
    Person.auto_upgrade!
    Person.count.must_equal 1
    person = Person.last
    person.name.must_equal 'foo'
    person.surname.must_be_nil
    person.update_attribute(:surname, 'bar')
    Person.db_columns.sort.must_equal %w[id name surname]
    Person.column_names.must_equal Person.db_columns

    # Remove a column without lost data
    Person.class_eval do
      schema do |p|
        p.string :name
      end
    end
    Person.auto_upgrade!
    person = Person.last
    person.name.must_equal 'foo'
    proc { person.surname }.must_raise NoMethodError
    Person.db_columns.sort.must_equal %w[id name]
    Person.column_names.must_equal Person.db_columns
    Person.column_names.must_equal Person.schema_columns

    # Change column without lost data
    Person.class_eval do
      schema do |p|
        p.text :name
      end
    end
    person = Person.last
    person.name.must_equal 'foo'
  end

  it 'has #key,col,property inside model' do
    ActiveRecord::Base.connection.table_exists?(Post.table_name).must_equal false
    ActiveRecord::Base.connection.table_exists?(Category.table_name).must_equal false
    Post.auto_upgrade!; Category.auto_upgrade!
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
      key.string :name
      key.references :category
    end
    Post.auto_upgrade!
    post = Post.first
    post.name.must_be_nil
    post.category.must_equal category
    post.wont_respond_to :title
  end

  it 'has indexes inside model' do
    # Check indexes
    Animal.auto_upgrade!
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
      key.integer :category_id
      index :category_id
    end
    Animal.auto_upgrade!
    Animal.db_columns.must_include "category_id"
    Animal.db_indexes.must_equal((indexes_was << "index_animals_on_category_id").sort)
  end
end
