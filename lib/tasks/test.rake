# frozen_string_literal: true

desc 'Run specs and static analysis'
namespace :spec do
  task validate: :environment do
    Rake::Task['rubocop'].invoke
    Rake::Task['brakeman'].invoke
    Rake::Task['spec'].invoke
  end
end

unless Rails.env.production?
  begin
    require 'rubocop/rake_task'
    RuboCop::RakeTask.new
  rescue LoadError
    # rubocop is unavailable in deployment bundles (e.g. RAILS_ENV=foreman built
    # with BUNDLE_WITHOUT="development test"). Skip defining the lint task so that
    # rake db:migrate and other tasks still load.
  end
end
