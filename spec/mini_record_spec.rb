require File.expand_path('../spec_helper.rb', __FILE__)
require File.expand_path('../fake_model.rb', __FILE__)

describe MiniRecord do

  it 'works correctly' do
    # For unknown reason separate specs doesn't works
    Person.table_name.must_equal 'people'
    Person.db_columns.must_equal %w[id name]
    Person.column_names.must_equal Person.db_columns
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
    Person.count.must_equal 1
    person = Person.last
    person.name.must_equal 'foo'
    person.surname.must_be_nil
    person.update_attribute(:surname, 'bar')
    Person.db_columns.must_equal %w[id name surname]
    Person.column_names.must_equal Person.db_columns

    # Remove a column without lost data
    Person.class_eval do
      schema do |p|
        p.string :name
      end
    end
    person = Person.last
    person.name.must_equal 'foo'
    proc { person.surname }.must_raise NoMethodError
    Person.db_columns.must_equal %w[id name]
    Person.column_names.must_equal Person.db_columns

    # Change column without lost data
    Person.class_eval do
      schema do |p|
        p.text :name
      end
    end
    person = Person.last
    person.name.must_equal 'foo'
  end

  it 'should remove no tables, since Person is still defined' do
    ActiveRecord::Base.drop_unused_tables
    ActiveRecord::Base.connection.tables.must_equal %w[people]
    Person.count.must_equal 1
  end
end
