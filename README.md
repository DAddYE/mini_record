[![Build Status](https://secure.travis-ci.org/DAddYE/mini_record.png)](http://travis-ci.org/DAddYE/mini_record)


MiniRecord is a **micro** extension for the `ActiveRecord` gem.

MiniRecord will allow you to create/edit/manage columns, directly in your **model**.


## Features

* Define columns/properties inside your model
* Perform migrations automatically
* Auto upgrade your schema
* Add, Remove, Change **columns**
* Add, Remove, Change **indexes**

## Instructions

What you need is to move/remove your `db/schema.rb`.
This avoid conflicts.

Add to your `Gemfile`:

```sh
gem 'mini_record'
```

To optionally block any destructive actions on the database, create a file `config/initializers/mini_record.rb` and add:

```ruby
MiniRecord.configure do |config|
  config.destructive = false
end
```

That's all!

## Examples

Remember that inside properties you can use all migrations methods,
see [documentation](http://api.rubyonrails.org/classes/ActiveRecord/Migration.html)

```ruby
class Post < ActiveRecord::Base
  field :title_en, :title_jp
  field :description_en, :description_jp, as: :text
  field :permalink, index: true, limit: 50
  field :comments_count, as: :integer
  field :category, as: :references, index: true
end
Post.auto_upgrade!
```

Instead of `field` you can pick an alias: `key, field, property, col`

If the option `:as` is omitted, minirecord will assume it's a `:string`.

Remember that as for `ActiveRecord` you can choose different types:

```ruby
:primary_key, :string, :text, :integer, :float, :decimal, :datetime, :timestamp, :time,
:date, :binary, :boolean, :references, :belongs_to, :timestamp
```

You can also provide other options like:

```ruby
:limit, :default, :null, :precision, :scale

# example
class Foo < ActiveRecord::Base
  field :title, default: "MyTitle" # as: :string is not necessary since is a default
  field :price, as: :decimal, scale: 8, precision: 2
end
```

See [ActiveRecord::TableDefinition](http://api.rubyonrails.org/classes/ActiveRecord/ConnectionAdapters/TableDefinition.html)
for more details.

### Perform upgrades

Finally, when you execute `MyModel.auto_upgrade!`, missing columns, indexes and tables will be created on the fly. 

Indexes and columns present in the db but **not** in your model schema/definition will be **deleted** also from your db.

### Single Table Inheritance

MiniRecord as ActiveRecord support STI:

```ruby
  class Pet < ActiveRecord::Base; end
  class Dog < Pet; end
  class Cat < Pet; end
  ActiveRecord::Base.auto_upgrade!
```

When you perform `ActiveRecord::Base.auto_upgrade!`, just **1** table will be created with the `type` column (indexed as well).

### ActiveRecord Relations

MiniRecord has built-in support of `belongs_to`, _polymorphic associations_ as well with _habtm_ relations. 

You don't need to do anything in particular, is not even necessary define the field for them since they will be handled automatically.

#### belongs_to
```ruby
class Address < ActiveRecord::Base
  belongs_to :person
end
```
Will result in a indexed `person_id` column. You can use a different one using the `foreign_key` option:

```ruby
belongs_to :person, foreign_key: :person_pk
```

#### belongs_to with foreign key in database

```ruby
class Address < ActiveRecord::Base
  belongs_to :person
  index :person_id, foreign: true
end
```

This is the same example, but foreign key will be added to the database with help of
[foreigner](https://github.com/matthuhiggins/foreigner) gem.

In this case you have more control (if needed).

To remove the key please use `:foreign => false`
If you simple remove the index, the foreign key will not be removed.

#### belongs_to (polymorphic)

```ruby
class Address < ActiveRecord::Base
  belongs_to :addressable, polymorphic: true
end
```

Will create an `addressable_id` and an `addressable_type` column with composite indexes:

```ruby
add_index(:addresses), [:addressable_id, :addressable_type]
```

#### habtm
```ruby
class Address < ActiveRecord::Base
  has_and_belongs_to_many :people
end
```

Will generate a "addresses_people" (aka: join table) with indexes on the id columns

### Adding a new column

Super easy, open your model and just add it:

```ruby
class Post < ActiveRecord::Base
  field :title
  field :body, as: :text # <<- this
  field :permalink, index: true
  field :comments_count, as: :integer
  field :category, as: :references, index: true
end
Post.auto_upgrade!
```

So now when you invoke `MyModel.auto_upgrade!` a diff between the old schema an the new one will detect changes and create the new column.

### Removing a column

It's exactly the same as in the previous example.

### Rename columns

Simply adding a `rename_field` declaration and mini_record will do a `connection.rename_column` in the next `auto_upgrade!` but **only** if the db has the old column and not the new column. 

This means that you still need to have a `field` declaration for the new column name so subsequent `MyModel.auto_upgrade!` will not remove the column. 

You are free to leave the `rename_field` declaration in place or you can remove it once the new column exists in the db.

Moving from:
```ruby
class Vehicle < ActiveRecord::Base
  field :color
end
```

To:
```ruby
class Vehicle < ActiveRecord::Base
  rename_field :color, new_name: :body_color
  field :body_color
end
```

Then perhaps later:
```ruby
class Vehicle < ActiveRecord::Base
  rename_field :color, new_name: :body_color
  rename_field :body_color, new_name: :chassis_color
  field :chassis_color
end
```

### Change the type of columns

Where when you rename a column the task should be _explicit_ changing the type is _implicit_.

This means that if you have

```ruby
field :total, as: :integer
```

and later on you'll figure out that you wanted a `float`

```ruby
field :total, as: :float
```

Will automatically change the type the the first time you'll invoke `auto_upgrade`.


### Add/Remove indexes

In the same way we manage columns MiniRecord will detect new indexes and indexes that needs to be removed.

So when you perform `MyModel.auto_upgrade!` a SQL command like:

```SQL
PRAGMA index_info('index_people_on_name')
CREATE INDEX "index_people_on_surname" ON "people" ("surname")
```

A quick hint, sometimes index gets too verbose/long:

```ruby
class Fox < ActiveRecord::Base
  field :foo, index: true
  field :foo, index: :custom_name
  field :foo, index: [:foo, :bar]
  field :foo, index: { column: [:branch_id, :party_id], unique: true, name: 'by_branch_party' }
end
```

Here is where `add_index` comes handy, so you can rewrite the above in:

```ruby
class Fox < ActiveRecord::Base
  field :foo
  add_index :foo
  add_index :custom_name
  add_index [:foo, :bar]
  add_index [:branch_id, :party_id], unique: true, name: 'by_branch_party'
end
```

### Suppress default indexes for associations

If you do not need the default index for a `belongs_to` or `has_and_belongs_to_many` relationship, such as if you are using a composite index instead, you can suppress it from being created (or remove it) using `suppress_index` on the association:

```ruby
class PhoneNumber < ActiveRecord::Base
  field :position
  belongs_to :person
  suppress_index :person
  add_index [:person_id, :position]
end
```

### Passing options to Create Table

If you need to pass particular options to your `CREATE TABLE` statement, you can do so with `create_table` in the Model:

```ruby
class Fox < ActiveRecord::Base
  create_table :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci'
  field :foo
end
```

## Contributors

A special thanks to all who have contributed in this project:

* Dmitriy Partsyrniy
* Steven Garcia
* Carlo Bertini
* Nate Wiger
* Dan Watson
* Guy Boertje
* virtax
* Nagy Bence
* Takeshi Yabe
* blahutka
* 4r2r

## Author

DAddYE, you can follow me on twitter [@daddye](http://twitter.com/daddye) or take a look at my site [daddye.it](http://www.daddye.it)

## Copyright

Copyright (C) 2011-2014 Davide D'Agostino - [@daddye](http://twitter.com/daddye)

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the “Software”), to deal in the Software without restriction, including without
limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,
and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
