require 'rake'
require 'rake/testtask'
require 'rake/clean'
require 'rdoc/task'
require 'bundler/gem_tasks'

task default: :test
task spec: :test

Rake::TestTask.new do |t|
  t.pattern = 'spec/*_spec.rb'
end

RDOC_EXTRA_FILES = ['README.md','LICENSE']

RDoc::Task.new :rdoc do |rdoc|
  rdoc.rdoc_files.include(*RDOC_EXTRA_FILES, 'lib/**/*.rb')
  rdoc.title    = 'FileDiscard'
  rdoc.main     = 'README.md'
  rdoc.rdoc_dir = 'rdoc'
end

desc 'Start GitHub Readme Instant Preview service (see https://github.com/joeyespo/grip)'
task :grip do
  exec 'grip --gfm --context=bradrf/netagator'
end

CLOBBER.include 'coverage'
