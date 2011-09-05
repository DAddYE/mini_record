require 'mini_record/auto_migrations'

module MiniRecord
  module AutoSchema
    def self.included(base)
      base.extend(ClassMethods)
      base.send(:include, MiniRecord::AutoMigrations)
    end

    module ClassMethods
      def schema(options={}, &block)
        auto_create_table(table_name, options, &block)
        reset_column_information
      end
      alias :keys :schema
      alias :properties :schema
    end
  end # AutoSchema
end # MiniRecord
