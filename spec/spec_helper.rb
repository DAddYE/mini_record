require 'rubygems' unless defined?(Gem)
require 'bundler/setup'
require 'mini_record'
require 'minitest/autorun'

module SpecHelper
  module ClassMethods
    def db_columns
      connection.columns(table_name).map(&:name).sort
    end

    def db_indexes
      connection.indexes(table_name).map(&:name).sort
    end

    def schema_columns
      table_definition.columns.map { |c| c.name.to_s }.sort
    end

    def reset!
      reset
    end
  end
end

ActiveRecord::Base.extend(SpecHelper::ClassMethods)
