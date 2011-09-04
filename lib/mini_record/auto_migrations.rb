require 'active_support/core_ext/class/attribute_accessors'

module MiniRecord

  module AutoMigrations
    def self.included(base)
      base.extend ClassMethods
      class << base
        cattr_accessor :tables_in_schema, :indexes_in_schema
        self.tables_in_schema, self.indexes_in_schema = [], []
      end
    end

    module ClassMethods
      def auto_create_table(table_name, options, &block)

        (self.tables_in_schema ||= []) << table_name

        # Table doesn't exist, create it
        unless connection.tables.include?(table_name)
          return connection.create_table(table_name, options, &block)
        end

        # Grab database columns
        fields_in_db = connection.columns(table_name).inject({}) do |hash, column|
          hash[column.name] = column
          hash
        end

        # Grab schema columns (lifted from active_record/connection_adapters/abstract/schema_statements.rb)
        table_definition = ActiveRecord::ConnectionAdapters::TableDefinition.new(connection)
        primary_key = options[:primary_key] || "id"
        table_definition.primary_key(primary_key) unless options[:id] == false

        # Return the table definition
        yield table_definition

        # Grab new schema
        fields_in_schema = table_definition.columns.inject({}) do |hash, column|
          hash[column.name.to_s] = column
          hash
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
          options[:default] = column.default if !column.default.nil?
          options[:null]    = column.null    if !column.null.nil?
          connection.add_column table_name, column.name, column.type.to_sym, options
        end

        # Change attributes of existent columns
        (fields_in_schema.keys & fields_in_db.keys).each do |field|
          if field != primary_key #ActiveRecord::Base.get_primary_key(table_name)
            changed  = false  # flag
            new_type = fields_in_schema[field].type.to_sym
            new_attr = {}

            # First, check if the field type changed
            if fields_in_schema[field].type.to_sym != fields_in_db[field].type.to_sym
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
              if !value.nil? && value != fields_in_db[field].send(att)
                new_attr[att] = value
                changed = true
              end
            end

            # Change the column if applicable
            connection.change_column table_name, field, new_type, new_attr if changed
          end
        end
      end

      def drop_unused_tables
        (connection.tables - tables_in_schema - %w(schema_info schema_migrations)).each do |table|
          connection.drop_table table
        end
      end

      def drop_unused_indexes
        tables_in_schema.each do |table_name|
          indexes_in_db = connection.indexes(table_name).map(&:name)
          (indexes_in_db - indexes_in_schema & indexes_in_db).each do |index_name|
            connection.remove_index table_name, :name => index_name
          end
        end
      end
    end # ClassMethods
  end # Migrations
end # ActiveKey
