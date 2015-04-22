# -*- coding: utf-8 -*-

require 'yaml'
require 'json'
require 'net/http'
require 'xcodeproj'
require 'open-uri'
require 'fileutils'
require 'mustache'
require 'erb'

module LeanCloud

  # LeanCloud SDK installer
  class Installer < LeanObject

    include ERB::Util

    LEANFILE_PATH        = 'Leanfile'
    LEANCLOUD_SDK_ROOT   = 'LeanCloud'
    LEANCLOUD_SDK_GROUP  = 'LeanCloud'
    LEANCLOUD_SDK_PREFIX = 'AVOSCloud'

    def initialize
      @leanfile_path   = LEANFILE_PATH
      @root_path       = LEANCLOUD_SDK_ROOT
      @stash_name      = 'Stash'
      @stash_path      = File.join(@root_path, @stash_name)
      @sdk_path        = File.join(@stash_path, 'Frameworks.zip')
      @frameworks_path = File.join(@stash_path, 'Frameworks')
      @modules_path    = File.join(@stash_path, 'Modules')
      @lean_group      = LEANCLOUD_SDK_GROUP
      @sdk_prefix      = LEANCLOUD_SDK_PREFIX
      @sdk_url_prefix  = 'https://download.avoscloud.com/1/downloadSDK?'

      @system_frameworks = %w(
        CFNetwork
        SystemConfiguration
        MobileCoreServices
        CoreTelephony
        CoreLocation
        CoreGraphics
        QuartzCore
        Security
      )

      @system_libraries = %w(icucore)

      @lean_component_map = {
        'basic' => '基础模块',
        'SNS'   => '社交模块',
        'IM'    => '实时通信'
      }
    end

    private

    attr_accessor :config
    attr_accessor :version
    attr_accessor :base_sdk_version
    attr_accessor :target

    def version
      @version ||= config['version']
    end

    def base_sdk_version
      @base_sdk_version ||= config['base_sdk_version']
    end

    def target
      @target ||= target_with_name(config['target'])
    end

    def patch_sdk_version(target)
      version = base_sdk_version
      target.define_singleton_method(:sdk_version) do
        version
      end
    end

    def target_with_name(name)
      if name
        targets = project.targets.select { |target| target.name.eql?(name) }
        target  = targets.first
        patch_sdk_version(target) if target
        target
      else
        name = File.basename(project.path, '.*')
        target_with_name(name)
      end
    end

    def search_single_xcodeproj
      projects = Dir.glob('*.xcodeproj')

      if projects.length == 0
        exit_with_error('No Xcode project found')
      elsif projects.length > 1
        exit_with_error('Too many Xcode projects, please specify one in Leanfile')
      end

      projects.first
    end

    def project_path
      if config['xcodeproj']
        path = config['xcodeproj']
        path = path + '.xcodeproj' unless path.end_with?('.xcodeproj')
        path
      else
        search_single_xcodeproj
      end
    end

    def project
      @proj ||= Xcodeproj::Project.open(project_path)
    rescue RuntimeError
      nil
    end

    def read_leanfile
      unless File.readable?(@leanfile_path)
        exit_with_error('Can not find a readable Leanfile')
      end

      self.config = YAML.load(File.read(@leanfile_path))

    rescue SyntaxError => e
      exit_with_error("Leanfile has syntax error: #{e.message}")
    end

    def make_validation
      exit_with_error('Base SDK version not specified') unless base_sdk_version
      exit_with_error("Project #{project_path} can not be opened") unless project
      exit_with_error('Target not found') unless target
    end

    def create_directory_tree
      FileUtils.mkdir_p(@frameworks_path)
      FileUtils.mkdir_p(@modules_path)
    end

    def param_join(hash)
      hash.map { |k, v| "#{k}=#{v}" }.join('&')
    end

    def lean_components
      components = config['components']

      if components.is_a?(Array)
        result = components.uniq
        result.delete('basic')
        result
      else
        []
      end
    end

    def component_param_arr
      result = [url_encode(@lean_component_map['basic'])]

      lean_components.each do |key|
        next unless @lean_component_map.key?(key)
        result << url_encode(@lean_component_map[key])
      end

      result
    end

    def fetch_latest_version
      json = Net::HTTP.get(URI('https://download.leancloud.cn/sdk/latest.json'))
      version_info = JSON.parse(json)
      version_info['ios']
    end

    def sdk_query_string
      version = fetch_latest_version if version.nil?

      hash = {
        'type' => 'ios',
        'components' => component_param_arr.join(','),
        'version' => "v#{version}"
      }

      param_join(hash)
    end

    def generate_sdk_url
      @sdk_url_prefix + sdk_query_string
    end

    def download_framework
      sdk_url = generate_sdk_url

      show_message('Downloading LeanCloud SDK')

      open(@sdk_path, 'wb') do |file|
        file << open(sdk_url).read
      end
    rescue SocketError
      exit_with_error('Download LeanCloud SDK failed')
    end

    def frameworks_entries
      entries = []

      Dir.glob("#{@root_path}/*").select do |entry|
        next unless entry.end_with?('.framework')
        entries << entry
      end

      entries
    end

    def move_components
      frameworks_entries.each do |framework|
        FileUtils.rm_rf(framework)
      end

      Dir.glob("#{@frameworks_path}/**/*.framework").each do |framework|
        FileUtils.mv(framework, @root_path)
      end

      Dir.glob("#{@modules_path}/**/*.framework").each do |framework|
        FileUtils.mv(framework, @root_path)
      end
    end

    def clean_stash
      system("rm -rf #{@stash_path}")
    end

    def unzip_sdk
      show_message('Unpacking LeanCloud SDK package')

      quiet = '> /dev/null 2>&1'
      unzip_cmd = <<-EOS
        unzip -q #{@sdk_path} -d #{@frameworks_path} #{quiet}
        unzip -q #{@frameworks_path}/\\*.zip -d #{@modules_path} #{quiet}
      EOS

      system(unzip_cmd)
      move_components
    end

    def lean_group
      project[@lean_group] || project.new_group(@lean_group)
    end

    def remove_legency_frameworks
      phase = target.frameworks_build_phase

      references = []
      phase.files.each do |ref|
        file = ref.file_ref
        references << file if file.name.include?(@sdk_prefix)
      end

      references.each { |ref| phase.remove_file_reference(ref) }

      lean_group.clear
    end

    def add_frameworks
      show_message('Integrating frameworks')

      frameworks_entries.each do |entry|
        ref = lean_group.new_reference(entry)
        target.frameworks_build_phase.add_file_reference(ref)
      end
    end

    def add_build_setting(key, value)
      target.build_configurations.each do |bc|
        values = []
        origin_values = bc.build_settings[key]
        values.push(origin_values).flatten! if origin_values
        values << value unless values.include?(value)
        bc.build_settings[key] = values
      end
    end

    def add_framework_search_path
      add_build_setting('FRAMEWORK_SEARCH_PATHS', "\"$(SRCROOT)/#{@root_path}\"")
    end

    def add_linker_flags_if_needed
      if Gem::Version.new(base_sdk_version) < Gem::Version.new('5.0')
        add_build_setting('OTHER_LDFLAGS', '-fobjc-arc')
      end
    end

    def save_project
      project.save
    end

    def add_system_frameworks
      target.add_system_frameworks(@system_frameworks)
    end

    def add_system_libraries
      target.add_system_libraries(@system_libraries)
    end

    def integrate_sdk
      unzip_sdk
      remove_legency_frameworks
      add_frameworks
      add_framework_search_path
      add_linker_flags_if_needed
      add_system_frameworks
      add_system_libraries
      save_project
    end

    def finish
      show_success('Install succeeded')
    end

    public

    def install(file = nil)
      @leanfile_path = file if file

      read_leanfile
      make_validation
      create_directory_tree
      download_framework
      integrate_sdk
      finish
    end

    def destroy
      clean_stash
    end

  end

end
