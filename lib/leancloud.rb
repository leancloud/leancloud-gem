#!/usr/bin/env ruby

require 'yaml'
require 'xcodeproj'
require 'open-uri'
require 'colorize'
require 'fileutils'
require 'erb'

# Main class
class LeanCloud
  include ERB::Util

  def initialize
    @root_path  = 'LeanCloud'
    @stash_dir  = 'Stash'
    @stash_path = File.join(@root_path, @stash_dir)
    @sdk_path   = File.join(@stash_path, 'Frameworks.zip')
    @frameworks_path = File.join(@stash_path, 'Frameworks')
    @modules_path = File.join(@stash_path, 'Modules')
    @leanfile_path = 'Leanfile'
    @lean_group = 'LeanCloud'
    @sdk_prefix = 'AVOSCloud'
    @sdk_url_prefix = 'https://download.avoscloud.com/1/downloadSDK?'

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
    targets = project.targets.select { |target| target.name.eql?(name) }
    target  = targets.first
    patch_sdk_version(target) if target
    target
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
    show_error('Leanfile has syntax error:')
    puts(e.message)
    exit
  end

  def make_validation
    exit_with_error('Version not specified') unless version
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

  def sdk_query_string
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

    Dir.glob("#{@modules_path}/**/*.framework").each do |framework|
      FileUtils.mv(framework, @root_path)
    end
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
    system("rm -rf #{@stash_path}")
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
    add_system_frameworks
    add_system_libraries
    save_project
  end

  def finish
    show_success('Install succeeded')
  end

  def show_error(msg)
    puts(msg.colorize(:red))
  end

  def show_success(msg)
    puts(msg.colorize(:green))
  end

  def show_message(msg)
    puts("==> #{msg}")
  end

  def exit_with_error(msg)
    show_error(msg)
    exit
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
end
