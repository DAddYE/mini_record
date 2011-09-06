MiniRecord is a micro extension for our `ActiveRecord` gem.
With it you can add the ability to create columns outside the default schema, directly
in your **model** in a similar way that you just know in others projects
like  DataMapper or  MongoMapper.

My inspiration come from this handy [project](https://github.com/pjhyett/auto_migrations).

## Features

* Define columns/properties inside your model
* Perform migrations automatically
* Auto upgrade your schema, so if you know what you are doing you don't lost your existing data!
* Add, Remove, Change Columns; Add, Remove, Change indexes

## Instructions

What you need is to move/remove `db/migrations` and `db/schema.rb`.
It's no more necessary and it avoid conflicts.

Add to your `Gemfile`:

``` rb
gem 'mini_record'
```

That's all!

## Examples

Remember that inside properties you can use all migrations methods,
see [documentation](http://api.rubyonrails.org/classes/ActiveRecord/Migration.html)

``` rb
class Person < ActiveRecord::Base
  schema do |s|
    s.string  :name
    s.integer :address_id
  end
  belongs_to :address
end

# you can use also this way
class Address < ActiveRecord::Base
  key.string  :city
  key.string  :state
  key.integer :number
  has_many :people
end

# or this
class Address < ActiveRecord::Base
  col.string  :city
  col.string  :state
  col.integer :number
  has_many :people
end

# or this
class Address < ActiveRecord::Base
  property.string  :city
  property.string  :state
  property.integer :number
  has_many :people
end

```

Once you bootstrap your **app**, missing columns and tables will be created on the fly.

### Adding a new column

Super easy, open your model and just add it:

``` rb
class Person < ActiveRecord::Base
  schema do |s|
    s.string  :name
    s.string  :surname # <<- this
    s.integer :address_id
  end
  belongs_to :address
end

# or if you use others ways
class Person < ActiveRecord::Base
  col.string  :name
  col.string  :surname # <<- this
  col.integer :address_id
  belongs_to :address
end
```

So now when you start your **webserver** you can see an `ALTER TABLE` statement, this mean that your existing
records are happy and safe.

### Removing a column

It's exactly the same, but the column will be _really_ deleted without affect other columns.

### Change columns

It's not possible for us know when/what column you have renamed, but we can know if you changed the `type` so
if you change `t.string :name` to `t.text :name` we are be able to perform an `ALTER TABLE`

## Warnings

This software is not yet tested in a production project, now is only heavy development and if you can
pleas fork it, find bug add a spec and then come back with a pull request. Thanks!


## Author

DAddYE, you can follow me on twitter [@daddye](http://twitter.com/daddye) or take a look at my site [daddye.it](http://www.daddye.it)

## Copyright

Copyright (C) 2011 Davide D'Agostino - [@daddye](http://twitter.com/daddye)

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the “Software”), to deal in the Software without restriction, including without
limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,
and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
