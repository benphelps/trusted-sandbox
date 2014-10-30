require 'trusted_sandbox'
require 'thor'

module TrustedSandbox
  class Cli < Thor
    desc 'install', 'Creates trusted_sandbox.yml in `config`, if this directory exists, or in the current directory otherwise'
    def install
      curr_dir_file = 'trusted_sandbox.yml'
      config_dir_file = 'config/trusted_sandbox.yml'

      puts "#{curr_dir_file} already exists" or return if File.exist?(curr_dir_file)
      puts "#{config_dir_file} already exists" or return if File.exist?(config_dir_file)

      target_file = Dir.exist?('config') ? config_dir_file : curr_dir_file

      puts "Creating #{target_file}"
      FileUtils.cp File.expand_path('../config/trusted_sandbox.yml', __FILE__), target_file
    end

    desc 'test', 'Checks Trusted Sandbox can connect to Docker'
    def test
      TrustedSandbox.test_connection
      puts 'Trusted Sandbox seems to be configured correctly!'
    end

    desc 'ssh UID', 'Launch a container with shell and mount the code folder. Works only if keep_code_folders is true. UID is the suffix of the code folder'
    def ssh(uid)
      raise 'keep_code_folders must be set to true' unless TrustedSandbox.config.keep_code_folders
      local_code_dir = File.join TrustedSandbox.config.host_code_root_path, uid
      `docker run -it -v #{local_code_dir}:/home/sandbox/src --entrypoint="/bin/bash" #{TrustedSandbox.config.docker_image_name} -s`
    end

    desc 'generate_image VERSION', 'Creates the Docker image files and places them into the `trusted_sandbox_images` directory. Default version is 2.1.2'
    def generate_image(image_version = '2.1.2')
      target_dir = 'trusted_sandbox_images'
      target_image_path = "#{target_dir}/#{image_version}"
      gem_image_path = File.expand_path("../server_images/#{image_version}", __FILE__)

      puts "Image #{image_version} does not exist" unless Dir.exist?(gem_image_path)
      puts "Directory #{target_image_path} already exists" or return if Dir.exist?(target_image_path)

      puts "Copying #{image_version} into #{target_image_path}"
      FileUtils.mkdir_p target_dir
      FileUtils.cp_r gem_image_path, target_image_path
    end

    desc 'set_quotas QUOTA_KB', 'Sets the quota for all the UIDs in the pool. This requires additional installation. Refer to the README file.'
    def set_quotas(quota_kb)
      from = TrustedSandbox.config.pool_min_uid
      to = TrustedSandbox.config.pool_max_uid
      puts "Configuring quota for UIDs [#{from}..#{to}]"
      (from..to).each do |uid|
        `setquota -u #{uid} 0 #{quota_kb} 0 0 /`
      end
    end

    desc 'reset_uid_pool UID', 'Release the provided UID from the UID-pool. If the UID is omitted, all UIDs that were reserved will be released, effectively resetting the pool'
    def reset_uid_pool(uid = nil)
      if uid
        TrustedSandbox.uid_pool.release uid
      else
        TrustedSandbox.uid_pool.release_all
      end
    end
  end
end