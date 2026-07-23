# frozen_string_literal: true

desc 'Run specs and static analysis'
namespace :spec do
  task validate: :environment do
    Rake::Task['rubocop'].invoke
    Rake::Task['brakeman'].invoke
    Rake::Task['spec'].invoke
  end
end

begin
  require 'rubocop/rake_task'
  RuboCop::RakeTask.new
rescue LoadError # rubocop not available outside dev/test
  nil
end
