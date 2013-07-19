require File.expand_path('../helper.rb', __FILE__)

describe MiniRecord do

  before do
    ActiveRecord::Base.clear_reloadable_connections!
    ActiveRecord::Base.clear_cache!
    ActiveRecord::Base.clear_active_connections!
    conn.tables.each { |table| silence_stream(STDERR) { conn.execute "DROP TABLE IF EXISTS #{table}" } }
    ActiveRecord::Base.descendants.each { |klass| Object.send(:remove_const, klass.to_s) if Object.const_defined?(klass.to_s) }
    ActiveSupport::DescendantsTracker.direct_descendants(ActiveRecord::Base).clear
    load File.expand_path('../models.rb', __FILE__)
    ActiveRecord::Base.auto_upgrade!
  end

  it 'has #schema inside model' do
    assert_equal 'people', Person.table_name
    assert_equal %w[created_at id name updated_at], Person.db_columns.sort
    assert_equal Person.db_columns, Person.column_names.sort
    assert_equal Person.schema_columns, Person.column_names.sort

    # Check surname attribute
    person = Person.create(:name => 'foo')
    assert_equal 'foo', person.name
    assert_raises(NoMethodError){ person.surname }

    # Test the timestamp columns exist
    assert_respond_to person, :created_at
    assert_respond_to person, :updated_at

    # Add a column without lost data
    Person.class_eval do
      schema do |p|
        p.string :name
        p.string :surname
      end
      timestamps
    end
    Person.auto_upgrade!
    assert_equal 1, Person.count

    person = Person.last
    assert_equal 'foo', person.name
    assert_nil person.surname

    person.update_column(:surname, 'bar')
    assert_equal %w[created_at id name surname updated_at], Person.db_columns.sort

    # Remove a column without lost data
    Person.class_eval do
      schema do |p|
        p.string :name
      end
      timestamps
    end
    Person.auto_upgrade!
    person = Person.last
    assert_equal 'foo', person.name
    assert_raises(NoMethodError) { person.surname }
    assert_equal %w[created_at id name updated_at], Person.db_columns
    assert_equal Person.column_names.sort, Person.db_columns
    assert_equal Person.column_names.sort, Person.schema_columns

    # Change column without lost data
    Person.class_eval do
      schema do |p|
        p.text :name
      end
    end
    person = Person.last
    assert_equal 'foo', person.name
  end

  it 'has #key,col,property,attribute inside model' do
    assert_equal Post.column_names.sort,     Post.db_columns
    assert_equal Category.column_names.sort, Category.schema_columns

    # Check default properties
    category = Category.create(:title => 'category')
    post = Post.create(:title => 'foo', :body => 'bar', :category_id => category.id)
    post = Post.first
    assert_equal 'foo', post.title
    assert_equal 'bar', post.body
    assert_equal category, post.category


    # Remove a column
    Post.reset_table_definition!
    Post.class_eval do
      col :name
      col :category, :as => :references
    end
    Post.auto_upgrade!
    refute_includes %w[title body], Post.db_columns

    post = Post.first
    assert_nil post.name
    assert_equal category, post.category
    assert_raises(NoMethodError, ActiveModel::MissingAttributeError) { post.title }
  end

  it 'has indexes inside model' do
    # Check indexes
    assert Animal.db_indexes.size > 0
    assert_equal Animal.db_indexes, Animal.indexes.keys.sort


    # Remove an index
    indexes_was = Animal.db_indexes
    Animal.indexes.delete(indexes_was.pop)
    Animal.auto_upgrade!
    assert_equal indexes_was, Animal.indexes.keys
    assert_equal indexes_was, Animal.db_indexes

    # Add a new index
    Animal.class_eval do
      col :category, :as => :references, :index => true
    end
    Animal.auto_upgrade!
    new_indexes = indexes_was + %w[index_animals_on_category_id]
    assert_includes Animal.db_columns, 'category_id'
    assert_equal new_indexes.sort, Animal.db_indexes
  end

  it 'not add already defined indexes' do
    class Foo < ActiveRecord::Base
      index :customer_id, :unique => true, :name => 'by_customer'
      belongs_to :customer
    end
    Foo.auto_upgrade!
    assert_equal 1, Foo.db_indexes.size
    assert_includes Foo.db_indexes, 'by_customer'
  end

  it 'works with STI' do
    class Dog < Pet; end
    class Cat < Pet; end
    class Kitten < Cat; end
    ActiveRecord::Base.auto_upgrade!

    # Check inheritance column
    assert_includes Pet.db_columns, "type"

    # Now, let's we know if STI is working
    Pet.create(:name => "foo")
    Dog.create(:name => "bar")
    Kitten.create(:name => 'foxy')
    assert_equal 1, Dog.count
    assert_equal 'bar', Dog.first.name
    assert_equal 3, Pet.count
    assert_equal %w[foo bar foxy], Pet.all.map(&:name)
    assert_equal 'bar', Dog.first.name

    # What's happen if we change schema?
    assert_equal Dog.table_definition, Pet.table_definition
    assert_equal Dog.indexes, Pet.indexes

    Dog.class_eval do
      col :bau
    end
    ActiveRecord::Base.auto_upgrade!
    assert_includes Dog.schema_columns, 'bau'
    assert_includes Pet.db_columns, 'bau'
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
    assert_equal 'role', User.inheritance_column

    Administrator.create(:name => "Davide", :surname => 'DAddYE')
    Customer.create(:name => "Foo", :surname => "Bar")
    assert_equal 1, Administrator.count
    assert_equal 'Davide', Administrator.first.name
    assert_equal 1, Customer.count
    assert_equal 'Foo', Customer.first.name
    assert_equal 2, User.count
    assert_equal 'Administrator', User.first.role
    assert_equal 'Customer', User.last.role
    assert_includes User.db_indexes, 'index_users_on_role'
  end

  it 'allow multiple columns definitions' do
    class Fake < ActiveRecord::Base
      col :name, :surname
      col :category, :group, :as => :references
    end
    Fake.auto_upgrade!
    Fake.create(:name => 'foo', :surname => 'bar', :category_id => 1, :group_id => 2)
    fake = Fake.first
    assert_equal 'foo', fake.name
    assert_equal 'bar', fake.surname
    assert_equal 1, fake.category_id
    assert_equal 2, fake.group_id
  end

  it 'allow custom query' do
    skip unless conn.adapter_name =~ /mysql/i

    class Foo < ActiveRecord::Base
      col :name, :as => "ENUM('foo','bar')"
    end
    Foo.auto_upgrade!
    assert_match /ENUM/, Foo.queries

    Foo.auto_upgrade!
    assert_empty Foo.queries
    assert_equal %w[id name], Foo.db_columns
    assert_equal %w[id name], Foo.schema_columns

    foo = Foo.create(:name => 'test')
    assert_empty Foo.first.name

    foo.update_column(:name, 'foo')

    assert_equal 'foo', Foo.first.name
  end

  describe 'relation #belongs_to' do

    it 'creates a column and index based on relation' do
      Article.create(:title => 'Hello', :publisher_id => 1)
      Article.first.tap do |a|
        assert_equal 'Hello', a.title
        assert_equal 1, a.publisher_id
      end
      assert_includes Article.db_indexes, 'index_articles_on_publisher_id'

      # Ensure that associated field/index is not deleted on upgrade
      Article.auto_upgrade!
      assert_equal 1, Article.first.publisher_id
      assert_includes Article.db_indexes, 'index_articles_on_publisher_id'
    end

    it 'removes a column and index when relation is removed' do
      class Foo < ActiveRecord::Base
        key :name
        belongs_to :image, :polymorphic => true
      end
      Foo.auto_upgrade!
      assert_includes Foo.db_columns, 'name'
      assert_includes Foo.db_columns, 'image_type'
      assert_includes Foo.db_columns, 'image_id'
      assert_includes Foo.db_indexes, 'index_foos_on_image_id_and_image_type'

      Foo.class_eval do
        reset_table_definition!
        reflections.clear
        indexes.clear
        key :name
      end
      Foo.auto_upgrade!
      assert_includes Foo.db_columns, 'name'
      refute_includes Foo.db_columns, 'image_type'
      refute_includes Foo.db_columns, 'image_id'
      assert_empty Foo.db_indexes
    end

    it 'creates columns and index based on polymorphic relation' do
      Attachment.create(:name => 'Avatar', :attachable_id => 1, :attachable_type => 'Post')
      Attachment.first.tap do |attachment|
        assert_equal 'Avatar', attachment.name
        assert_equal 1, attachment.attachable_id
        assert_equal 'Post', attachment.attachable_type
      end
      index = 'index_attachments_on_attachable_id_and_attachable_type'
      assert_includes Attachment.db_indexes, index

      # Ensure that associated fields/indexes are not deleted on subsequent upgrade
      Attachment.auto_upgrade!
      assert_equal 1, Attachment.first.attachable_id
      assert_equal 'Post', Attachment.first.attachable_type
      assert_includes Attachment.db_indexes, index
    end

    it 'should support :class_name' do
      assert_includes Task.schema_columns, 'author_id'
      assert_includes Task.db_columns, 'author_id'
    end

    it 'should support :foreign_key' do
      assert_includes Activity.schema_columns, 'custom_id'
      assert_includes Activity.db_columns, 'custom_id'
    end

    it 'should memonize in schema relationships' do
      silence_stream(STDERR) { conn.create_table('foos') }
      conn.add_column :foos, :name, :string
      conn.add_column :foos, :bar_id, :integer
      conn.add_index  :foos, :bar_id
      class Foo < ActiveRecord::Base
        col :name
        belongs_to :bar
      end
      assert_includes Foo.db_columns, 'name'
      assert_includes Foo.db_columns, 'bar_id'
      assert_includes Foo.db_indexes, 'index_foos_on_bar_id'

      Foo.auto_upgrade!
      assert_includes Foo.schema_columns, 'name'
      assert_includes Foo.schema_columns, 'bar_id'
      assert_includes Foo.indexes, 'index_foos_on_bar_id'
    end

    it 'should add new columns without lost belongs_to schema' do
      publisher  = Publisher.create(:name => 'foo')
      article = Article.create(:title => 'bar', :publisher => publisher)
      assert article.valid?
      assert_includes Article.indexes, 'index_articles_on_publisher_id'

      # Here we perform a schema change
      Article.key :body
      Article.auto_upgrade!
      article.reload
      assert_nil article.body

      article.update_column(:body, 'null')
      assert_equal 'null', article.body

      # Finally check the index existance
      assert_includes Article.db_indexes, 'index_articles_on_publisher_id'
    end

    it 'should not override previous defined column relation' do
      class Foo < ActiveRecord::Base
        key :user, :as => :references, :null => false, :limit => 4
        belongs_to :user
      end
      Foo.auto_upgrade!
      assert_equal 4, Foo.db_fields[:user_id].limit
      assert_equal false, Foo.db_fields[:user_id].null
    end

    it 'add/remove foreign key with :foreign option, when Foreigner gem used on mysql' do
      skip unless conn.adapter_name =~ /mysql/i

      class Book < ActiveRecord::Base
        belongs_to :publisher
        index :publisher_id, :foreign => true
      end
      Book.auto_upgrade!

      assert_includes Book.db_columns, 'publisher_id'
      assert_includes Book.db_indexes, 'index_books_on_publisher_id'

      assert connection.foreign_keys(:books).detect {|fk| fk.options[:column] == 'publisher_id'}

      Object.send(:remove_const, :Book)
      class Book < ActiveRecord::Base
        belongs_to :publisher
         index :publisher_id, :foreign => false
      end
      Book.auto_upgrade!

      assert_nil connection.foreign_keys(:books).detect {|fk| fk.options[:column] == 'publisher_id'}
    end

    it 'add/remove named foreign key with :foreign option, when Foreigner gem used on mysql' do
      skip unless conn.adapter_name =~ /mysql/i

      class Book < ActiveRecord::Base
        belongs_to :publisher
        index :publisher_id, :name => 'my_super_publisher_id_fk', :foreign => true
      end
      Book.auto_upgrade!

      assert_includes Book.db_columns, 'publisher_id'
      assert_includes Book.db_indexes, 'my_super_publisher_id_fk'

      assert connection.foreign_keys(:books).detect {|fk| fk.options[:column] == 'publisher_id'}

      Object.send(:remove_const, :Book)
      class Book < ActiveRecord::Base
        belongs_to :publisher
        index :publisher_id, :name => 'my_super_publisher_id_fk', :foreign => false
      end
      Book.auto_upgrade!

      assert_nil connection.foreign_keys(:books).detect {|fk| fk.options[:column] == 'publisher_id'}
      Object.send(:remove_const, :Book)
    end

    it 'support :foreign option in the index with custom :foreign_key in the belong_to association' do
      skip unless conn.adapter_name =~ /mysql/i

      class Book < ActiveRecord::Base
        belongs_to :second_publisher, :foreign_key => 'second_publisher_id', :class_name => 'Publisher'
        index :second_publisher_id, :foreign => true
      end
      Book.auto_upgrade!

      assert_includes Book.db_columns, 'second_publisher_id'
      assert_includes Book.db_indexes, 'index_books_on_second_publisher_id'

      assert connection.foreign_keys(:books).detect {|fk| fk.options[:column] == 'second_publisher_id'}

      Object.send(:remove_const, :Book)
      class Book < ActiveRecord::Base
        belongs_to :second_publisher, :foreign_key => 'second_publisher_id', :class_name => 'Publisher'
        index :second_publisher_id, :foreign => false
      end
      Book.auto_upgrade!

      assert_nil connection.foreign_keys(:books).detect {|fk| fk.options[:column] == 'second_publisher_id'}
    end

  end

  describe 'relation #habtm' do
    it 'creates a join table with indexes for has_and_belongs_to_many relations' do
      tables = Tool.connection.tables
      assert_includes tables, 'purposes_tools'

      index = 'index_purposes_tools_on_tool_id_and_purpose_id'
      assert_includes Tool.connection.indexes('purposes_tools').map(&:name), index

      # Ensure that join table is not deleted on subsequent upgrade
      Tool.auto_upgrade!
      assert_includes tables, 'purposes_tools'
      assert_includes Tool.connection.indexes('purposes_tools').map(&:name), index
    end

    it 'drops join table if has_and_belongs_to_many relation is deleted' do
      Tool.schema_tables.delete('purposes_tools')
      refute_includes ActiveRecord::Base.schema_tables, 'purposes_tools'

      ActiveRecord::Base.clear_tables!
      refute_includes Tool.connection.tables, 'purposes_tools'
    end

    it 'has_and_belongs_to_many with custom join_table and foreign keys' do
      class Foo < ActiveRecord::Base
        has_and_belongs_to_many :watchers, :join_table => :watching, :foreign_key => :custom_foo_id, :association_foreign_key => :customer_id
      end
      Foo.auto_upgrade!
      assert_includes conn.tables, 'watching'

      cols = conn.columns('watching').map(&:name)
      refute_includes cols, 'id'
      assert_includes cols, 'custom_foo_id'
      assert_includes cols, 'customer_id'
    end

    it 'creates a join table with indexes with long indexes names' do
      class Foo < ActiveRecord::Base
        has_and_belongs_to_many :people,   :join_table  => :long_people,
                                           :foreign_key => :custom_long_long_long_long_id,
                                           :association_foreign_key => :customer_super_long_very_long_trust_me_id
      end
      Foo.auto_upgrade!
      index_name = 'index_long_people_on_custom_long_long_long_long_id_and_customer_super_long_very_long_trust_me_id'[0...conn.index_name_length]
      assert_includes conn.tables, 'people'
      assert_includes conn.indexes(:long_people).map(&:name), index_name
    end

    it 'adds unique index' do
      page = Page.create(:title => 'Foo')
      photogallery = Photogallery.create(:title => 'Bar')
      assert photogallery.valid?

      photogallery.pages << page
      refute_empty Photogallery.queries
      assert_includes photogallery.reload.pages, page
      assert_raises(ActiveRecord::RecordNotUnique, ActiveRecord::StatementInvalid){ photogallery.pages << page }
    end
  end

  it 'should add multiple index' do
    class Foo < ActiveRecord::Base
      key :name, :surname, :index => true
    end
    Foo.auto_upgrade!
    assert_includes Foo.db_indexes, 'index_foos_on_name'
    assert_includes Foo.db_indexes, 'index_foos_on_surname'
  end

  it 'should create a unique index' do
    class Foo < ActiveRecord::Base
      key :name, :surname
      add_index([:name, :surname], :unique => true)
    end
    Foo.auto_upgrade!
    db_indexes = Foo.connection.indexes('foos')[0]
    assert_equal 'index_foos_on_name_and_surname', db_indexes.name
    assert db_indexes.unique
    assert_equal %w[name surname], db_indexes.columns.sort
  end

  it 'should change #limit' do
    class Foo < ActiveRecord::Base
      key :number, :as => :integer
      key :string, :limit => 100
    end
    Foo.auto_upgrade!
    assert_match /CREATE TABLE/, Foo.queries

    Foo.auto_upgrade!
    refute_match /alter/i, Foo.queries

    # According to this:
    # https://github.com/rails/rails/blob/master/activerecord/lib/active_record/connection_adapters/abstract_mysql_adapter.rb#L476-487
    Foo.key :number, :as => :integer, :limit => 4
    Foo.auto_upgrade!
    case conn.adapter_name
    when /sqlite/i
      # In sqlite there is a difference between limit: 4 and limit: 11
      assert_match 'altered', Foo.queries
      assert_equal 4, Foo.db_fields[:number].limit
      assert_equal 4, Foo.schema_fields[:number].limit
    when /mysql/i
      # In mysql according to this: http://goo.gl/bjZE7 limit: 4 is same of limit:11
      assert_empty Foo.queries
      assert_equal 4, Foo.db_fields[:number].limit
      assert_equal 4, Foo.schema_fields[:number].limit
    when /postgres/i
      # In postgres limit: 4 will be translated to nil
      assert_match /ALTER COLUMN "number" TYPE integer$/, Foo.queries
      assert_equal nil, Foo.db_fields[:number].limit
      assert_equal   4, Foo.schema_fields[:number].limit
    end

    # Change limit to string
    Foo.key :string, :limit => 255
    Foo.auto_upgrade!
    refute_empty Foo.queries
    assert_equal 255, Foo.db_fields[:string].limit
  end

  it 'should change #null' do
    class Foo < ActiveRecord::Base
      key :string
    end
    Foo.auto_upgrade!
    assert Foo.db_fields[:string].null

    # Same as above
    Foo.key :string, :null => true
    Foo.auto_upgrade!
    refute_match /alter/i, Foo.queries
    assert Foo.db_fields[:string].null

    Foo.key :string, :null => nil
    Foo.auto_upgrade!
    refute_match /alter/i, Foo.queries
    assert Foo.db_fields[:string].null

    Foo.key :string, :null => false
    Foo.auto_upgrade!
    assert_match /alter/i, Foo.queries
    refute Foo.db_fields[:string].null
  end

  it 'should change #scale #precision' do
    class Foo < ActiveRecord::Base
      field :currency, :as => :decimal, :precision => 8, :scale => 2
    end
    Foo.auto_upgrade!
    assert_equal 8, Foo.db_fields[:currency].precision
    assert_equal 2, Foo.db_fields[:currency].scale
    assert_equal 8, Foo.db_fields[:currency].limit

    Foo.auto_upgrade!
    refute_match /alter/i, Foo.queries

    Foo.field :currency, :as => :decimal, :precision => 4, :scale => 2, :limit => 5
    Foo.auto_upgrade!
    assert_match /alter/i, Foo.queries
    assert_equal 4, Foo.db_fields[:currency].precision
    assert_equal 2, Foo.db_fields[:currency].scale
    assert_equal 4, Foo.db_fields[:currency].limit
  end
end
