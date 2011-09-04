require 'rubygems' unless defined?(Gem)
require 'active_record'
require 'mini_record/properties'

ActiveRecord::Base.send(:include, MiniRecord::Properties)
