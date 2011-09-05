require 'rubygems' unless defined?(Gem)
require 'active_record'
require 'mini_record/auto_schema'

ActiveRecord::Base.send(:include, MiniRecord::AutoSchema)
