# https://gist.github.com/ahoward/4025400
namespace :db do
  task :create_indexes do
    require 'rubygems'
    require 'bundler'
    Bundler.setup(:default, (ENV['RACK_ENV'] || 'development').to_sym)
    require './app.rb'

    to_index_models = [] 

    ObjectSpace.each_object(Module) do |object|
      begin
        to_index_models.push(object) if object.respond_to?(:create_indexes)
      rescue e
        warn "failed on: #{object}.respond_to?(:create_indexes)"
      end
    end

    to_index_models.sort! do |a, b|
      a.name <=> b.name
    end

    to_index_models.uniq!

    to_index_models.each do |model|
      begin
        model.create_indexes
        puts "indexed: #{model}"
      rescue e
        warn "failed on: #{model}#create_indexes"
      end
    end
  end
end
