require 'rubygems'
require 'cijoe'

use Rack::CommonLogger

# HAX for http://github.com/defunkt/cijoe/issues/issue/16
$project_path = '/srv/cijoe/<%= project %>'
CIJoe::Server.configure do |config|
  config.set :project_path, '/srv/cijoe/<%= project %>'
  config.set :show_exceptions, true
  config.set :lock, true
end

run CIJoe::Server

