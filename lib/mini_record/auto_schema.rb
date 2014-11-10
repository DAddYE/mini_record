module MiniRecord
  module AutoSchema
    def self.included(base)
      base.extend(ClassMethods)
    end
    
    module ClassMethods
      def init_table_definition(connection)
        #connection.create_table(table_name) unless connection.table_exists?(table_name)

        case ActiveRecord::ConnectionAdapters::TableDefinition.instance_method(:initialize).arity
        when 1
          # Rails 3.2 and earlier
          ActiveRecord::ConnectionAdapters::TableDefinition.new(connection)
        when 4
          # Rails 4
          ActiveRecord::ConnectionAdapters::TableDefinition.new(connection.native_database_types, table_name, false, {})
        when -5
          # Rails 4.1
          ActiveRecord::ConnectionAdapters::TableDefinition.new(connection.native_database_types, table_name, false, {}, nil)
        else
          raise ArgumentError,
            "Unsupported number of args for ActiveRecord::ConnectionAdapters::TableDefinition.new()"
        end
      end
      
      def schema_tables
        @@_schema_tables ||= []
      end

      def table_definition
        return superclass.table_definition unless (superclass == ActiveRecord::Base) || (superclass.respond_to?(:abstract_class?) && superclass.abstract_class?)

        @_table_definition ||= begin
          tb = init_table_definition(connection)
          tb.primary_key(primary_key)
          tb
        end
      end

      def indexes
        return superclass.indexes unless (superclass == ActiveRecord::Base) || (superclass.respond_to?(:abstract_class?) && superclass.abstract_class?)

        @_indexes ||= {}
      end

      def indexes_in_db
        connection.indexes(table_name).inject({}) do |hash, index|
          hash[index.name] = index
          hash
        end
      end

      def get_sql_field_type(field)
        if ActiveRecord::VERSION::MAJOR.to_i < 4
          field.sql_type.to_s.downcase
        else
          connection.type_to_sql(field.type.to_sym, field.limit, field.precision, field.scale)
        end
      end

      def rename_fields
        @rename_fields ||= {}
      end

      def fields
        table_definition.columns.inject({}) do |hash, column|
          hash[column.name] = column
          hash
        end
      end

      def fields_in_db
        connection.columns(table_name).inject({}) do |hash, column|
          hash[column.name] = column
          hash
        end
      end

      def rename_field(*args)
        return unless connection?

        options    = args.extract_options!
        new_name   = options.delete(:new_name)
        old_name   = args.first
        if old_name && new_name
          rename_fields[old_name] = new_name
        end
      end
      alias :rename_key       :rename_field
      alias :rename_property  :rename_field
      alias :rename_col       :rename_field

      def field(*args)
        return unless connection?

        options    = args.extract_options!
        type       = options.delete(:as) || options.delete(:type) || :string
        index      = options.delete(:index)

        args.each do |column_name|

          # Allow custom types like:
          #   t.column :type, "ENUM('EMPLOYEE','CLIENT','SUPERUSER','DEVELOPER')"
          if type.is_a?(String)
            # will be converted in: t.column :type, "ENUM('EMPLOYEE','CLIENT')"
            table_definition.column(column_name, type, options.reverse_merge(:limit => 0))
          else
            # wil be converted in: t.string :name
            table_definition.send(type, column_name, options)
          end

          # Get the correct column_name i.e. in field :category, :as => :references
          column_name = table_definition.columns[-1].name

          # Parse indexes
          case index
          when Hash
            add_index(options.delete(:column) || column_name, index)
          when TrueClass
            add_index(column_name)
          when String, Symbol, Array
            add_index(index)
          end
        end
      end
      alias :key       :field
      alias :property  :field
      alias :col       :field

      def timestamps
        field :created_at, :updated_at, :as => :datetime, :null => false
      end

      def reset_table_definition!
        @_table_definition = nil
      end
      alias :reset_schema! :reset_table_definition!

      def schema
        reset_table_definition!
        yield table_definition
        table_definition
      end

      def add_index(column_name, options={})
        index_name = connection.index_name(table_name, :column => column_name)
        indexes[index_name] = options.merge(:column => column_name) unless indexes.key?(index_name)
        index_name
      end
      alias :index :add_index

      def connection?
        !!connection
      rescue Exception => e
        puts "\e[31m%s\e[0m" % e.message.strip
        false
      end

      def clear_tables!
        return unless MiniRecord.configuration.destructive == true 
        (connection.tables - schema_tables).each do |name|
          connection.drop_table(name)
          schema_tables.delete(name)
        end
      end

      def foreign_keys
        # fk cache to minimize quantity of sql queries
        @foreign_keys ||= {}
        @foreign_keys[:table_name] ||= connection.foreign_keys(table_name)
      end

      # Remove foreign keys for indexes with :foreign=>false option
      def remove_foreign_keys
        return unless MiniRecord.configuration.destructive == true 
        indexes.each do |name, options|
          if options[:foreign]==false
            foreign_key = foreign_keys.detect { |fk| fk.options[:column] == options[:column].to_s }
            if foreign_key
              connection.remove_foreign_key(table_name, :name => foreign_key.options[:name])
              foreign_keys.delete(foreign_key)
            end
          end
        end
      end

      # Add foreign keys for indexes with :foreign=>true option, if the key doesn't exists
      def add_foreign_keys
        indexes.each do |name, options|
          if options[:foreign]
            column = options[:column].to_s
            unless foreign_keys.detect { |fk| fk[:options][:column] == column }
              to_table = reflect_on_all_associations.detect { |a| a.foreign_key.to_s==column }.table_name
              connection.add_foreign_key(table_name, to_table, options)
              foreign_keys << { :options=> { :column=>column } }
            end
          end
        end
      end

      def auto_upgrade!
        return unless connection?
        return if respond_to?(:abstract_class?) && abstract_class?

        if self == ActiveRecord::Base
          descendants.each(&:auto_upgrade!)
          clear_tables!
        else
          # If table doesn't exist, create it
          unless connection.tables.include?(table_name)
            # TODO: create_table options
            class << connection; attr_accessor :table_definition; end unless connection.respond_to?(:table_definition=)
            connection.table_definition = table_definition
            connection.create_table(table_name)
            connection.table_definition = init_table_definition(connection)
          end

          # Add this to our schema tables
          schema_tables << table_name unless schema_tables.include?(table_name)

          # Generate fields from associations
          if reflect_on_all_associations.any?
            reflect_on_all_associations.each do |association|
              foreign_key = association.options[:foreign_key] || "#{association.name}_id"
              type_key    = "#{association.name.to_s}_type"
              case association.macro
              when :belongs_to
                field foreign_key, :as => :integer unless fields.key?(foreign_key.to_s)
                if association.options[:polymorphic]
                  field type_key, :as => :string unless fields.key?(type_key.to_s)
                  index [foreign_key, type_key]
                else
                  index foreign_key
                end
              when :has_and_belongs_to_many
                table = if name = association.options[:join_table]
                          name.to_s
                        else
                          [table_name, association.name.to_s].sort.join("_")
                        end
                unless connection.tables.include?(table.to_s)
                  foreign_key             = association.options[:foreign_key] || association.foreign_key
                  association_foreign_key = association.options[:association_foreign_key] || association.association_foreign_key
                  connection.create_table(table, :id => false) do |t|
                    t.integer foreign_key
                    t.integer association_foreign_key
                  end
                  index_name = connection.index_name(table, :column => [foreign_key, association_foreign_key])
                  index_name = index_name[0...connection.index_name_length] if index_name.length > connection.index_name_length
                  connection.add_index table, [foreign_key, association_foreign_key], :name => index_name, :unique => true
                end
                # Add join table to our schema tables
                schema_tables << table unless schema_tables.include?(table)
              end
            end
          end

          # Add to schema inheritance column if necessary
          if descendants.present?
            field inheritance_column, :as => :string unless fields.key?(inheritance_column.to_s)
            index inheritance_column
          end

          # Group Destructive Actions
          if MiniRecord.configuration.destructive == true 
            
            # Rename fields
            rename_fields.each do |old_name, new_name|
              old_column = fields_in_db[old_name.to_s]
              new_column = fields_in_db[new_name.to_s]
              if old_column && !new_column
                connection.rename_column(table_name, old_column.name, new_name)
              end
            end
            
            # Remove fields from db no longer in schema
            columns_to_delete = fields_in_db.keys - fields.keys & fields_in_db.keys
            columns_to_delete.each do |field|
              column = fields_in_db[field]
              connection.remove_column table_name, column.name
            end
            
            # Change attributes of existent columns
            (fields.keys & fields_in_db.keys).each do |field|
              if field != primary_key #ActiveRecord::Base.get_primary_key(table_name)
                changed  = false  # flag
                new_attr = {}

                # Special catch for precision/scale, since *both* must be specified together
                # Always include them in the attr struct, but they'll only get applied if changed = true
                new_attr[:precision] = fields[field][:precision]
                new_attr[:scale]     = fields[field][:scale]

                # If we have precision this is also the limit
                fields[field][:limit] ||= fields[field][:precision]

                # Next, iterate through our extended attributes, looking for any differences
                # This catches stuff like :null, :precision, etc
                # Ignore junk attributes that different versions of Rails include
                [:name, :limit, :precision, :scale, :default, :null].each do |att|
                  value = fields[field][att]
                  value = true if att == :null && value.nil?

                  # Skip unspecified limit/precision/scale as DB will set them to defaults,
                  # and on subsequent runs, this will be erroneously detected as a change.
                  next if value.nil? and [:limit, :precision, :scale].include?(att)

                  old_value = fields_in_db[field].send(att)
                  if value != old_value
                    logger.debug "[MiniRecord] Detected schema change for #{table_name}.#{field}##{att} " +
                                 "from #{old_value.inspect} to #{value.inspect}" if logger
                    new_attr[att] = value
                    changed = true
                  end
                end

                # Change the column if applicable
                new_type = fields[field].type.to_sym
                connection.change_column table_name, field, new_type, new_attr if changed
              end
            end
            
            remove_foreign_keys if connection.respond_to?(:foreign_keys)

            # Remove old index
            index_names = indexes.collect{ |name, opts| (opts[:name] || name).to_s }
            (indexes_in_db.keys - index_names).each do |name|
              connection.remove_index(table_name, :name => name)
            end
            
          end

          # Add fields to db new to schema
          columns_to_add = fields.keys - fields_in_db.keys
          columns_to_add.each do |field|
            column  = fields[field]
            options = {:limit => column.limit, :precision => column.precision, :scale => column.scale}
            options[:default] = column.default unless column.default.nil?
            options[:null]    = column.null    unless column.null.nil?
            connection.add_column table_name, column.name, column.type.to_sym, options
          end

          # Add indexes
          indexes.each do |name, options|
            options = options.dup
            index_name = (options[:name] || name).to_s
            unless connection.indexes(table_name).detect { |i| i.name == index_name }
              connection.add_index(table_name, options.delete(:column), options)
            end
          end

          add_foreign_keys if connection.respond_to?(:foreign_keys)

          # Reload column information
          reset_column_information
        end
      end
    end # ClassMethods
  end # AutoSchema
end # MiniRecord
