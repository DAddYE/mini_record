module MiniRecord
  module AutoSchema
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods

      def schema_tables
        @@_schema_tables ||= []
      end

      def table_definition
        return superclass.table_definition unless superclass == ActiveRecord::Base

        @_table_definition ||= begin
                                 tb = ActiveRecord::ConnectionAdapters::TableDefinition.new(connection)
                                 tb.primary_key(primary_key)
                                 tb
                               end
      end

      def indexes
        return superclass.indexes unless superclass == ActiveRecord::Base

        @_indexes ||= {}
      end

      def col(*args)
        return unless connection?

        options = args.extract_options!
        type  = options.delete(:as) || options.delete(:type) || :string
        index = options.delete(:index)
        args.each do |column_name|
          # Allow custom types like:
          #   t.column :type, "ENUM('EMPLOYEE','CLIENT','SUPERUSER','DEVELOPER')"
          if type.is_a?(String)
            table_definition.column(column_name, type, options.reverse_merge(:limit => 0))
          # else translate in:
          #   t.references :parent
          #   t.string     :name
          else
            table_definition.send(type, column_name, options)
          end
          # Get the formatted column name and add correctly index
          column_name = table_definition.columns[-1].name
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
      alias :key :col
      alias :property :col
      alias :field :col
      alias :attribute :col

      def timestamps
        col :created_at, :updated_at, :as => :datetime
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
      alias :keys :schema
      alias :properties :schema
      alias :fields :schema
      alias :attributes :schema

      def add_index(column_name, options={})
        index_name = connection.index_name(table_name, :column => column_name)
        indexes[index_name] = options.merge(:column => column_name)
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
        # Drop unsued tables
        (connection.tables - schema_tables).each do |name|
          connection.drop_table(name)
          schema_tables.delete(name)
        end
      end

      def auto_upgrade!
        return unless connection?

        if self == ActiveRecord::Base
          descendants.each(&:auto_upgrade!)
          clear_tables!
        else
          # Table doesn't exist, create it
          unless connection.tables.include?(table_name)
            # TODO: create_table options
            class << connection; attr_accessor :table_definition; end unless connection.respond_to?(:table_definition=)
            connection.table_definition = table_definition
            connection.create_table(table_name)
            connection.table_definition = ActiveRecord::ConnectionAdapters::TableDefinition.new(connection)
          end

          # Add this to our schema tables
          schema_tables << table_name unless schema_tables.include?(table_name)

          # Grab database columns
          fields_in_db = connection.columns(table_name).inject({}) do |hash, column|
            hash[column.name] = column
            hash
          end

          # Generate fields from associations
          if reflect_on_all_associations.any?
            reflect_on_all_associations.each do |association|
              foreign_key = association.options[:foreign_key] || "#{association.name.to_s}_id"
              type_key    = "#{association.name.to_s}_type"
              case association.macro
              when :belongs_to
                table_definition.column(foreign_key, :integer)
                if association.options[:polymorphic]
                  table_definition.column(type_key, :string)
                  add_index [foreign_key, type_key]
                else
                  add_index foreign_key
                end
              when :has_and_belongs_to_many
                table = if name = association.options[:join_table]
                          name.to_s
                        else
                          [table_name, association.name.to_s].sort.join("_")
                        end
                index = ""
                unless connection.tables.include?(table.to_s)
                  foreign_key             = association.options[:foreign_key] || "#{table.singularize}_id"
                  association_foreign_key = association.options[:association_foreign_key] || "#{association.name.to_s.singularize}_id"
                  connection.create_table(table, :id => false) do |t|
                    t.integer foreign_key
                    t.integer association_foreign_key
                  end
                  options_name = "index_#{table}_on_#{[foreign_key, association_foreign_key].map(&:to_sym) * '_and_'}"
                  if options_name.length > connection.index_name_length
                    association.options[:name] = options_name[0..connection.index_name_length-1]
                  end
                  connection.add_index table.to_sym, [foreign_key, association_foreign_key].map(&:to_sym), association.options
                end
                # Add join table to our schema tables
                schema_tables << table unless schema_tables.include?(table)
              end
            end
          end

          # Grab new schema
          fields_in_schema = table_definition.columns.inject({}) do |hash, column|
            hash[column.name.to_s] = column
            hash
          end

          # Add to schema inheritance column if necessary
          if descendants.present? && !fields_in_schema.include?(inheritance_column.to_s)
            table_definition.column inheritance_column, :string
          end

          # Remove fields from db no longer in schema
          (fields_in_db.keys - fields_in_schema.keys & fields_in_db.keys).each do |field|
            column = fields_in_db[field]
            connection.remove_column table_name, column.name
          end

          # Add fields to db new to schema
          (fields_in_schema.keys - fields_in_db.keys).each do |field|
            column  = fields_in_schema[field]
            options = {:limit => column.limit, :precision => column.precision, :scale => column.scale}
            options[:default] = column.default unless column.default.nil?
            options[:null]    = column.null    unless column.null.nil?
            connection.add_column table_name, column.name, column.type.to_sym, options
          end

          # Change attributes of existent columns
          (fields_in_schema.keys & fields_in_db.keys).each do |field|
            if field != primary_key #ActiveRecord::Base.get_primary_key(table_name)
              changed  = false  # flag
              new_type = fields_in_schema[field].type.to_sym
              new_attr = {}

              # First, check if the field type changed
              if fields_in_schema[field].sql_type.to_s.downcase != fields_in_db[field].sql_type.to_s.downcase
                logger.debug "[MiniRecord] Detected schema changed for #{table_name}.#{field}#type from " +
                             "#{fields_in_schema[field].sql_type.to_s.downcase.inspect} in #{fields_in_db[field].sql_type.to_s.downcase.inspect}" if logger
                changed = true
              end

              # Special catch for precision/scale, since *both* must be specified together
              # Always include them in the attr struct, but they'll only get applied if changed = true
              new_attr[:precision] = fields_in_schema[field][:precision]
              new_attr[:scale]     = fields_in_schema[field][:scale]

              # Next, iterate through our extended attributes, looking for any differences
              # This catches stuff like :null, :precision, etc
              fields_in_schema[field].each_pair do |att,value|
                next if att == :type or att == :base or att == :name # special cases
                value = true if att == :null && value.nil?
                if value != fields_in_db[field].send(att)
                  logger.debug "[MiniRecord] Detected schema changed for #{table_name}.#{field}##{att} "+
                               "from #{fields_in_db[field].send(att).inspect} in #{value.inspect}" if logger
                  new_attr[att] = value
                  changed = true
                end
              end

              # Change the column if applicable
              connection.change_column table_name, field, new_type, new_attr if changed
            end
          end

          # Remove old index
          # TODO: remove index from habtm t
          indexes_in_db = connection.indexes(table_name).map(&:name)
          (indexes_in_db - indexes.keys).each do |name|
            connection.remove_index(table_name, :name => name)
          end

          # Add indexes
          indexes.each do |name, options|
            options = options.dup
            unless connection.indexes(table_name).detect { |i| i.name == name }
              connection.add_index(table_name, options.delete(:column), options)
            end
          end

          # Reload column information
          reset_column_information
        end

      end
    end # ClassMethods
  end # AutoSchema
end # MiniRecord
