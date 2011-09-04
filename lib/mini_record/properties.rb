require 'mini_record/auto_migrations'

module MiniRecord
  module Properties
    def self.included(base)
      base.extend(ClassMethods)
      base.send(:include, MiniRecord::AutoMigrations)
    end

    module ClassMethods
      def properties(options={}, &block)
        auto_create_table(table_name, options, &block)
        reset_column_information
      end
      alias :keys :properties
    end
  end # Properties
end # MiniRecord
