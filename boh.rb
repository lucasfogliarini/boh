#configurations
environment "config.action_mailer.delivery_method = :letter_opener
config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }
config.generators do |g|
  g.template_engine :slim
  g.javascripts false
  g.stylesheets false
  g.helper false
  g.test_framework false
end", env: 'development'
inject_into_file 'config/application.rb', after: "Rails::Application" do
 "\n\tconfig.i18n.default_locale = :'pt-BR'"
end
git :init
inject_into_file '.gitignore', after:'/tmp' do
 "\nconfig/database.yml"
end

#application file structure
file 'app/assets/stylesheets/base/.keep'
file 'app/assets/stylesheets/atoms/.keep'
file 'app/assets/stylesheets/molecules/.keep'
file 'app/assets/stylesheets/organisms/.keep'
file 'app/assets/stylesheets/pages/.keep'

file 'app/views/organisms/_header.html.slim'
file 'app/views/organisms/_footer.html.slim'
file 'app/views/organisms/_flash.html.slim', <<-RUBY
.flash
  - for key, msg in flash
    - flash_class = key.to_s == "alert" ? "alerts-error" : key
    div class="\#{flash_class} wrapper"
      div class="\#{flash_class}"
        = msg
RUBY

route "root 'pages#home'"
generate(:controller,"pages")
file 'app/views/pages/home.html.slim'
remove_file 'app/views/layouts/application.html.erb'
file 'app/views/layouts/application.html.slim', <<-RUBY
doctype 5
html
  head
    title = content_for?(:title) ? "\#{yield(:title)} - #{@app_name.capitalize}" : "#{@app_name.capitalize}"
    = favicon_link_tag 'favicon.png'
    = stylesheet_link_tag 'application', media: 'all'
    = javascript_include_tag 'application', 'data-turbolinks-track' => true
    = csrf_meta_tags
    = initjs_tag '#{@app_name.capitalize}'

  body [class="\#{params[:controller]} \#{params[:action]}"]
    = render "organisms/flash" unless flash.empty?
    = render "organisms/header"
    = yield
    = render 'organisms/footer'
RUBY

#gems
gem 'pg'
gem 'bootstrap-sass'
gem 'initjs'
gem 'slim-rails'
gem 'simple_form'
gem 'rails-i18n'
gem 'nprogress-rails'

devise = yes?("Devise?(y/n)")
gem 'devise' if devise

activeadmin = yes?("ActiveAdmin?(y/n)")
gem 'activeadmin', github: 'gregbell/active_admin' if activeadmin

enumerate_it = yes?("EnumerateIt?(y/n)")
gem 'enumerate_it' if enumerate_it

carrierwave = yes?("CarrierWave?(y/n)")
gem 'carrierwave' if carrierwave
gem 'fog' if carrierwave

gem_group :development, :test do
  gem 'pry-rails'
  gem 'rspec-rails'
  gem 'letter_opener'
end
#pundit = yes?("Pundit?")
#gem 'pundit' if pundit

run "bundle update"

after_bundle do
  database_name = ask("Tip the database_name:")
  user_db = ask("Tip the username:")
  password_db = ask("Tip the password:")
  file 'config/database-sample.yml', <<-YML
development:
  adapter: postgresql
  database: #{database_name}_development
  username:
  password:
  host: localhost
  poor: 5

test:
  adapter: postgresql
  database: #{database_name}_test
  username:
  password:
  host: localhost
  poor: 5

production:
  adapter: postgresql
  database: #{database_name}_production
  host: localhost
  poor: 5
YML
  file 'config/database.yml', <<-YML
development:
  adapter: postgresql
  database: #{database_name}_development
  username: #{user_db}
  password: #{password_db}
  host: localhost
  poor: 5

test:
  adapter: postgresql
  database: #{database_name}_test
  username: #{user_db}
  password: #{password_db}
  host: localhost
  poor: 5

production:
  adapter: postgresql
  database: #{database_name}_production
  host: localhost
  poor: 5
YML

  rake "db:create"

  generate("simple_form:install")
  generate("initjs:install")
  generate("rspec:install")
  generate("active_admin:install") if activeadmin
  generate("enumerate_it:install") if enumerate_it
  if devise
    generate("devise:install")
    inject_into_file 'config/initializers/devise.rb', force: true, after: "Devise.setup do |config|" do
      "\n\tconfig.scoped_views = false"
    end
  end

  if carrierwave
    file 'app/uploaders/file_uploader.rb', <<-RUBY
class FileUploader < CarrierWave::Uploader::Base
  def store_dir
    "uploads/\#{model.class.to_s.underscore}/\#{mounted_as}/\#{model.id}"
  end
end
RUBY

    inject_into_file 'config/secrets.yml', after: "development:" do
  "\n  aws_access_key_id: ''
  aws_secret_access_key: ''
  aws_bucket_name: ''"
    end
    inject_into_file 'config/secrets.yml', after: "production:" do
  "\n  aws_access_key_id: <%= ENV['AWS_ACCESS_KEY_ID'] %>
  aws_secret_access_key: <%= ENV['AWS_SECRET_ACCESS_KEY'] %>
  aws_bucket_name: <%= ENV['AWS_BUCKET_NAME'] %>"
    end

    initializer 'carrierwave.rb', <<-RUBY
CarrierWave.configure do |config|
  config.enable_processing = !(Rails.env.test?)
  config.storage = Rails.env.production? ? :fog : :file
  config.fog_credentials = {
    provider:              'AWS',
    aws_access_key_id:     Rails.application.secrets.aws_access_key_id,
    aws_secret_access_key: Rails.application.secrets.aws_secret_access_key,
  }
  config.fog_public = false
  config.fog_directory  = Rails.application.secrets.aws_bucket_name
  config.fog_attributes = { 'Cache-Control' => 'max-age=315576000' }
end
RUBY
  end

  rake "db:migrate"
end