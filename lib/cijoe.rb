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
            test -z "$(git config cijoe.runner)"
        })

      exec "git config --unset #{key}", options
    end
    
  end

  def cijoe
    gem 'cijoe'

    file '/srv/cijoe', :ensure => :directory, :owner => configuration[:user]
    file '/srv/cijoe/public', :ensure => :directory, :owner => configuration[:user]

    project      = configuration[:application]
    repo         = configuration[:repository]
    project_path = "/srv/cijoe/#{project}"

    exec "git clone #{repo} #{project_path}",
      :alias => "clone #{project}",
      :user => configuration[:user],
      :unless => "test -d /srv/cijoe/#{project}",
    :require => file('/srv/cijoe')

    git_config 'cijoe.runner', configuration[:cijoe][:runner],
      :cwd => project_path,
      :require => exec("clone #{project}"),
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


    with_options :cwd => project_path, :require => exec("clone #{project}"), :user => configuration[:user] do |project_checkout|
      project_checkout.git_config 'cijoe.user', configuration[:cijoe][:user]
      project_checkout.git_config 'cijoe.pass', configuration[:cijoe][:pass]
      project_checkout.git_config 'campfire.user', configuration[:cijoe][:campfire][:user]
      project_checkout.git_config 'campfire.pass', configuration[:cijoe][:campfire][:pass]
      project_checkout.git_config 'campfire.subdomain', configuration[:cijoe][:campfire][:subdomain]
      project_checkout.git_config 'campfire.room', configuration[:cijoe][:campfire][:room]
      project_checkout.git_config 'campfire.ssl', configuration[:cijoe][:campfire][:ssl]
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
      :alias => 'cijoe_vhost'

    a2ensite 'cijoe', :require => file('cijoe_vhost')
  end

end
