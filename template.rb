RAILS_RESTRICTION = '~> 5.2.0'

Callback = Struct.new(:method, :args)
@@after_bundle_callbacks = []

def apply_template
  check_rails_version
  add_webpacker_with_react
  add_tailwind_css
  add_jquery
  add_slim
  add_simple_form
  add_devise_with_omniauth_strategies
  add_rspec
  add_dotenv
  add_annotate
  add_guard_with_livereload_and_rspec
  add_shrine_with_aws_s3
  add_welcome_controller

  after_bundle do
    @@after_bundle_callbacks.each { |c| send(c[:method], *c[:args]) }

    git add: '.'
    git commit: "-m 'Initial commit'"
  end
end

def check_rails_version
  requirement = Gem::Requirement.new(RAILS_RESTRICTION)
  rails_version = Gem::Version.new(Rails::VERSION::STRING)
  return if requirement.satisfied_by?(rails_version)

  STDERR.puts(
    "[rails-prototyping-template]: This template requires Rails #{RAILS_RESTRICTION}. " \
    "You are using #{rails_version}.")
  exit(false)
end

def add_webpacker_with_react
  gem 'webpacker'

  erb = <<-ERB

    <%= stylesheet_pack_tag 'application' %>
    <%= javascript_pack_tag 'application' %>
  ERB
  insert_into_file(
    'app/views/layouts/application.html.erb', erb, before: /\s\s<\/head>/
  )

  @@after_bundle_callbacks.push(Callback.new('rails_command', 'webpacker:install'))
  @@after_bundle_callbacks.push(Callback.new('rails_command', 'webpacker:install:react'))
end

def add_tailwind_css
  @@after_bundle_callbacks.push(Callback.new('run', 'yarn add tailwindcss'))
  @@after_bundle_callbacks.push(Callback.new(
    'run', './node_modules/.bin/tailwind init tailwind.js'))
  @@after_bundle_callbacks.push(Callback.new(
    'append_to_file', ['.postcssrc.yml', '  tailwindcss: "./tailwind.js"']))
  @@after_bundle_callbacks.push(Callback.new(
    'create_file', ['app/javascript/packs/tailwindcss/preflight.css', '@tailwind preflight;']))
  @@after_bundle_callbacks.push(Callback.new(
    'create_file', ['app/javascript/packs/tailwindcss/components.css', '@tailwind components;']))
  @@after_bundle_callbacks.push(Callback.new(
    'create_file', ['app/javascript/packs/tailwindcss/utilities.css', '@tailwind utilities;']))
  @@after_bundle_callbacks.push(Callback.new(
    'create_file',
    ['app/javascript/packs/components.css', '/* Your custom component classes go here :) */']))
  @@after_bundle_callbacks.push(Callback.new(
    'create_file',
    ['app/javascript/packs/utilities.css', '/* Your custom utilities go here :) */']))
  @@after_bundle_callbacks.push(Callback.new(
    'create_file',
    [
      'app/javascript/packs/application.css',
<<-CSS
@import "tailwindcss/preflight";
@import "tailwindcss/components";
@import "components";
@import "tailwindcss/utilities";
@import "utilities";
CSS
    ]))
  @@after_bundle_callbacks.push(Callback.new(
    'append_to_file', ['app/javascript/packs/application.js', "import './application.css';"]))
end

def add_jquery
  gem 'jquery-rails'
  insert_into_file(
    'app/assets/javascripts/application.js',
    "\n//= require jquery",
    after: /\/\/= require rails-ujs/)
end

def add_slim
  gem 'slim-rails'
end

def add_simple_form
  gem 'simple_form'
  generate 'simple_form:install'
end

def add_devise_with_omniauth_strategies
  gem 'devise'
  gem 'omniauth-google-oauth2'
  gem 'omniauth-facebook'
  gem 'omniauth-twitter'
  gem 'omniauth-github'
  environment(
    "config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }",
    env: 'development')

  @@after_bundle_callbacks.push(Callback.new('generate', 'devise:install'))
  @@after_bundle_callbacks.push(Callback.new('generate', 'devise:views'))
  code = <<-CODE
  config.omniauth :google_oauth2, ENV['GOOGLE_CLIENT_ID'], ENV['GOOGLE_CLIENT_SECRET'], {}
  config.omniauth :facebook, ENV['FACEBOOK_KEY'], ENV['FACEBOOK_SECRET'], {}
  config.omniauth :twitter, ENV['TWITTER_KEY'], ENV['TWITTER_SECRET'], {}
  config.omniauth :github, ENV['GITHUB_KEY'], ENV['GITHUB_SECRET'], {}
  CODE
  @@after_bundle_callbacks.push(Callback.new(
    'insert_into_file',
    [
      'config/initializers/devise.rb',
      code,
      after: /# config.omniauth :github, 'APP_ID', 'APP_SECRET', scope: 'user,public_repo'\s/
    ]))
end

def add_rspec
  gem_group :development, :test do
    gem 'rspec-rails', '~> 3.7'
  end

  @@after_bundle_callbacks.push(Callback.new('generate', 'rspec:install'))
end

def add_dotenv
  gem_group :development, :test do
    gem 'dotenv-rails'
  end
  create_file '.env'
  create_file '.env.local'
  append_to_file '.gitignore', "\n.env.local\n\n"
end

def add_annotate
  gem_group :development do
    gem 'annotate'
  end
end

def add_guard_with_livereload_and_rspec
  gem_group :development do
    gem 'guard'
    gem 'guard-rspec', require: false
    gem 'guard-livereload', '~> 2.5', require: false
    gem 'rack-livereload'
  end
  environment(
    "config.middleware.insert_after ActionDispatch::Static, Rack::LiveReload",
    env: 'development')

  @@after_bundle_callbacks.push(Callback.new('run', 'bundle exec guard init'))
  @@after_bundle_callbacks.push(Callback.new('run', 'bundle exec guard init livereload'))
  @@after_bundle_callbacks.push(Callback.new('run', 'bundle exec guard init rspec'))
end

def add_shrine_with_aws_s3
  gem 'shrine', '~> 2.0'
  gem 'aws-sdk-s3', '~> 1.2'

  initializer 'shrine.rb', <<-CODE
  require 'shrine'

  if Rails.env.production?
    require 'shrine/storage/s3'

    s3_options = {
      access_key_id: ENV['S3_ACCESS_KEY_ID'],
      secret_access_key: ENV['S3_SECRET_ACCESS_KEY'],
      region: ENV['S3_REGION'],
      bucket: ENV['S3_BUCKET']
    }

    Shrine.storages = {
      cache: Shrine::Storage::S3.new(prefix: 'cache', **s3_options),
      store: Shrine::Storage::S3.new(prefix: 'store', **s3_options)
    }
  else
    require 'shrine/storage/file_system'
    Shrine.storages = {
      cache: Shrine::Storage::FileSystem.new('public', prefix: 'uploads/cache'),
      store: Shrine::Storage::FileSystem.new('public', prefix: 'uploads/store')
    }
  end

  Shrine.plugin :activerecord
  Shrine.plugin :cached_attachment_data
  CODE
end

def add_welcome_controller
  route "root to: 'welcome#index'"

  @@after_bundle_callbacks.push(Callback.new('generate', [:controller, 'welcome']))
  @@after_bundle_callbacks.push(Callback.new(
    'create_file',
    [
      'app/views/welcome/index.html.slim',
<<-SLIM
div.w-screen.h-screen.bg-red.flex.items-center.justify-center
  h1.text-white.font-sans Hello, World!
SLIM
    ]))
end

# Accept relative paths inside Thor methods.
def source_paths
  [__dir__]
end

apply_template
