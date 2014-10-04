require 'rubygems' unless defined?(Gem)
require 'active_record'
require 'mini_record/configuration'
require 'mini_record/auto_schema'

MiniRecord.configure do |config|
end
ActiveRecord::Base.send(:include, MiniRecord::AutoSchema)
