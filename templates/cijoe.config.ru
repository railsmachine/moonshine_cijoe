require 'rubygems'
require 'cijoe'

use Rack::CommonLogger

CIJoe::Server.configure do |config|
  config.set :project_path, '/srv/cijoe/<%= project %>'
  config.set :show_exceptions, true
  config.set :lock, true
end

run CIJoe::Server

