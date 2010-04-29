namespace :moonshine do
  task :apply_ci_manifest do
    sh "sudo RAILS_ENV=#{RAILS_ENV} shadow_puppet app/manifests/ci_manifest.rb"
  end
end

namespace :moonshine do
  namespace :gems do
    %w(development test cucumber).each do |environment|
      environment_path = Pathname.new(RAILS_ROOT).join('config', 'environments', "#{environment}.rb")
      if environment_path.exist?
        task environment do
          RAILS_ENV = environment
          Rake::Task[:environment].invoke
          
          gem_array = Rails.configuration.gems.reject{|g| g.frozen? && !g.framework_gem?}.map do |gem|
            hash = { :name => gem.name }
            hash.merge!(:source => gem.source) if gem.source
            hash.merge!(:version => gem.requirement.to_s) if gem.requirement
            hash
          end
          if (RAILS_GEM_VERSION rescue false)
            gem_array << {:name => 'rails', :version => RAILS_GEM_VERSION }
          else
            gem_array << {:name => 'rails'}
          end
          config_path = File.join(Dir.pwd, 'config', 'gems', "#{environment}.yml")
          FileUtils.mkdir_p File.dirname(config_path)
          File.open( config_path, 'w' ) do |out|
            YAML.dump(gem_array, out )
          end
          puts "#{config_path} has been updated with your application's gem"
          puts "dependencies. Please commit these changes to your SCM."
        end
      end
    end
  end
end
