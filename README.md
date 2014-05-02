# Moonshine_Cijoe

### A plugin for [Moonshine](http://github.com/railsmachine/moonshine)

A plugin for installing and managing cijoe.

### Instructions

Install the plugin:

    # Rails 2.x
    script/plugin install git://github.com/railsmachine/moonshine_cijoe.git
    # Rails 3.x
    script/rails plugin install git://github.com/railsmachine/moonshine_cijoe.git

Configure it in config/moonshine.yml:

   :repository: git@github.com:ACCOUNT/REPO.git # required, probably already set
   :application: APPLICATION
   :cijoe:
     :version: x.y.z # defaults to :latest
     :runner: rake # thing to run, required
     :user: cijoe # optional, to add http auth
     :password: zomgsosecure # optional, to add http auth
     :campfire: # optional, for campfire notification
       :token:
       :subdomain:
       :room: 
       :ssl: true
    :domain: foo.bar.com # domain to virtualhost responds to


Add the recipe to your manifest, ie <tt>app/manifests/application\_manifest.rb</tt>. You may want to only do this on staging, ie:

    on_stage :staging do
      recipe :cijoe
    end

***

Unless otherwise specified, all content copyright &copy; 2014, [Rails Machine, LLC](http://railsmachine.com)
