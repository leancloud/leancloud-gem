module LeanCloud

  # Leanfile template initializer
  class Initializer < LeanObject

    def initialize(opts)
      @options = opts
      @leanfile_path = LeanCloud::Installer::LEANFILE_PATH
    end

    private

    attr_accessor :options

    def template
      @template ||= <<-EOT.gsub(/^[ \t]+/, '')
      # Leanfile
      # -*- mode: yaml -*- vim:ft=yaml

      ---
      # LeanCloud SDK version
      version: {{version}}

      # Your project base SDK version
      base_sdk_version: {{base_sdk_version}}

      # Your project name (optional)
      # If empty, defaults to the single project in current directory
      xcodeproj: {{xcodeproj}}

      # Target name of your project (optional)
      # If empty, defaults to the target which matches project's name
      target: {{target}}

      # LeanCloud SDK components
      components:
      {{#components}}
      - {{value}}
      {{/components}}
      EOT
    end

    def validate_version_number(version)
      if !version.nil? and !Gem::Version.correct?(version)
        exit_with_error("Illegal version numner: #{version}")
      end
    end

    def validate_options
      validate_version_number(options[:sdk_version])
      validate_version_number(options[:ios_version])
    end

    def component_list(components)
      result = []

      unless components.nil?
        components.split(',').each do |component|
          value = component.strip
          result << { 'value' => value } unless value.empty?
        end

        result.uniq!
      end

      result
    end

    def generate_leanfile
      opts = options
      components = component_list(opts[:components])

      content = Mustache.render(template, {
        'version'          => opts[:sdk_version],
        'base_sdk_version' => opts[:ios_version],
        'xcodeproj'        => opts[:name],
        'target'           => opts[:target],
        'components'       => components
      })

      File.open(@leanfile_path, 'w') do |file|
        file.write(content)
      end
    end

    def prompt(existed)
      puts "#{existed ? 'Reinitialized existing' : 'Initialized'} Leanfile"
    end

    public

    def create
      validate_options
      existed = File.exist?(@leanfile_path)
      generate_leanfile
      prompt(existed)
    end

  end
end
