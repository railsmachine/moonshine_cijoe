module Cijoe
  def self.included(manifest)
    manifest.class_eval do
      extend ClassMethods

      configure :cijoe => { :campfire => {} }
    end
  end

  module ClassMethods
    def cijoe_template_dir
      @cijoe_template_dir ||= Pathname.new(__FILE__).dirname.dirname.join('templates')
    end
  end

  # TODO move this somewhere else... maybe a puppet type?
  def git_config(key, value, options = {})
    if value.present?
      options = options.reverse_merge(
        :unless => %Q{
            git config #{key} && test "#{value}" = "$(git config #{key})"
        })
      exec "git config #{key} '#{value}'", options
    else
      options = options.reverse_merge(:unless => %Q{
            test "$(git config #{key})" = ""
        })

      exec "git config --unset #{key} || true", options
    end
    
  end

  def cijoe
    gem 'cijoe',
      :ensure => (configuration[:cijoe][:version] || :present)
    if File.exist? "#{cofiguration[:deploy_to]}/current/Gemfile.lock"
      gem 'bundler'
    end

    file '/srv/cijoe', :ensure => :directory, :owner => configuration[:user]
    file '/srv/cijoe/public', :ensure => :directory, :owner => configuration[:user]

    project      = configuration[:application]
    repo         = configuration[:repository]
    project_path = "/srv/cijoe/#{project}"
    file "/srv/cijoe/#{project}/log", :ensure => :directory, :owner => configuration[:user], :require => [exec("cijoe clone #{project}")]

    exec "git clone #{repo} #{project_path}",
      :alias => "cijoe clone #{project}",
      :user => configuration[:user],
      :unless => "test -d /srv/cijoe/#{project}",
      :require => file('/srv/cijoe')

    exec "cd /srv/cijoe/#{project} && git submodule init && git submodule update",
      :alias => "cijoe submodules",
      :user  => configuration[:user],
      :require => exec("cijoe clone #{project}")

    
    exec "cd /srv/cijoe/#{project} && bundle install",
      :alias => 'cijoe bundle',
      :user => configuration[:user],
      :onlyif => "test -f /srv/cijoe/#{project}/Gemfile.lock",
      :require => [ exec("cijoe clone #{project}", exec('cijoe submodules'), package('bundler') ]
    
    if configuration[:rubygems_version] && configuration[:rubygems_version] > '1.4.2'
      package 'bundler',
        :provider => :gem,
        :ensure => :latest
    else
      package 'bundler',
        :provider => :gem,
        :ensure => '1.0.9'
    end

    git_config 'cijoe.runner', configuration[:cijoe][:runner],
      :cwd => project_path,
      :require => [ exec('cijoe bundle'), exec('cijoe submodules') ],
      :user => configuration[:user]

    htpasswd = '/srv/cijoe/htpasswd'
    if configuration[:cijoe][:user] && configuration[:cijoe][:pass]
      file htpasswd, :ensure => :file, :owner => configuration[:user], :mode => '644'

      exec "htpasswd #{configuration[:cijoe][:user]}",
        :command => "htpasswd -b #{htpasswd} #{configuration[:cijoe][:user]} #{configuration[:cijoe][:pass]}",
        :unless  => "grep '#{configuration[:cijoe][:user]}' #{htpasswd}"
    else
      file htpasswd, :ensure => :absent
    end


    with_options :cwd => project_path, :require => exec("cijoe clone #{project}"), :user => configuration[:user], :notify => service('apache2') do |project_checkout|
      project_checkout.git_config 'cijoe.user', configuration[:cijoe][:user]
      project_checkout.git_config 'cijoe.pass', configuration[:cijoe][:pass]
      project_checkout.git_config 'campfire.user',  configuration[:cijoe][:campfire] &&configuration[:cijoe][:campfire][:user]
      project_checkout.git_config 'campfire.pass', configuration[:cijoe][:campfire] && configuration[:cijoe][:campfire][:pass]
      project_checkout.git_config 'campfire.subdomain', configuration[:cijoe][:campfire] && configuration[:cijoe][:campfire][:subdomain]
      project_checkout.git_config 'campfire.room', configuration[:cijoe][:campfire] && configuration[:cijoe][:campfire][:room]
      project_checkout.git_config 'campfire.ssl', configuration[:cijoe][:campfire] && configuration[:cijoe][:campfire][:ssl]
    end

    if configuration[:cijoe][:campfire].present?
      gem 'tinder'
    end

    file '/srv/cijoe/config.ru',
      :content => template(cijoe_template_dir.join('cijoe.config.ru'), binding)

    file '/etc/apache2/sites-available/cijoe',
      :content => template(cijoe_template_dir.join('cijoe.vhost.erb'), binding),
      :ensure => :file,
      :mode => '644',
      :notify => service('apache2'),
      :alias => 'cijoe_vhost',
      :require => [exec('cijoe bundle')]

    a2ensite 'cijoe', :require => file('cijoe_vhost')

    if configuration[:database][:test][:adapter] == "sqlite" ||
      configuration[:database][:test][:adapter] == "sqlite3"
      # generally needed for the test db
      package 'sqlite3-ruby',
        :provider => :gem,
        :ensure => "1.2.5",
        :require => package('sqlite3')
      package 'sqlite3',
        :provider => :apt,
        :ensure => :present
    end
  end
end
