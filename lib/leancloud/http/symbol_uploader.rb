require 'tmpdir'
require 'fileutils'
require 'mustache'
require 'leancloud/http/lean_http'

module LeanCloud

  # LeanCloud symbol uploader
  class SymbolUploader < LeanHTTP

    def initialize(opts)
      @options = opts
    end

    private

    attr_reader :dsym_path
    attr_reader :dsym_macho
    attr_reader :dsym_archs
    attr_reader :tmp_dir

    def verbose?
      @verbose ||= !@options[:verbose].nil?
    end

    def dsym_path
      @dsym_path ||= (
        path = @options[:file]
        path if !path.nil? and File.readable?(path)
      )
    end

    def dsym_macho
      @dsym_macho ||= Dir.glob(File.join(dsym_path, 'Contents/Resources/DWARF/*')).first
    end

    def lipo_dsym_archs
      info = %x(lipo -info #{dsym_macho} 2>/dev/null)
      arch_list = info[/[^:]+$/].strip
      arch_list.split(' ')
    end

    def dsym_archs
      @dsym_archs ||= lipo_dsym_archs
    end

    def tmp_dir
      @tmp_dir ||= File.join(Dir.tmpdir(), 'cn.leancloud/symbols')
    end

    def validate_options
      report_error('LeanCloud App ID not found') unless @options[:id]
      report_error('LeanCloud App Key not found') unless @options[:key]
      report_error('DSYM file not found') unless dsym_path
    end

    def symbol_path(arch)
      File.join(tmp_dir, "#{arch}.sym")
    end

    def dump_cmd_template
      <<-EOT.gsub(/^[ \t]+/, '')
      {{#archs}}
      leancloud_dump_syms -a {{name}} #{dsym_path} > {{path}} 2>/dev/null
      {{/archs}}
      EOT
    end

    def dump_symbol
      FileUtils.mkdir_p(tmp_dir)

      archs = dsym_archs.map { |arch| { name: arch, path: symbol_path(arch) } }

      cmd = Mustache.render(dump_cmd_template, archs: archs)

      puts "Command for dump symbol files:\n#{cmd}" if verbose?

      system(cmd)
    end

    def symbol_fields
      fields = []

      dsym_archs.each do |arch|
        path = symbol_path(arch)
        next if !File.readable?(path) or File.zero?(path)
        fields << "-F \"symbol_file_#{arch}=@#{path}\""
      end

      fields
    end

    def send_symbol
      fields = symbol_fields

      return if fields.empty?

      form_fields = fields.join(" \\\n")
      url = api('stats/breakpad/symbols')

      cmd = <<-EOC.gsub(/^[ \t]+/, '')
      curl -X POST \\
      -H "X-AVOSCloud-Application-Id: #{@options[:id]}" \\
      -H "X-AVOSCloud-Application-Key: #{@options[:key]}" \\
      #{form_fields} \\
      #{url} 2>/dev/null
      EOC

      puts "Command for uploading symbol files:\n#{cmd}" if verbose?
      puts 'Uploading symbol files...'

      response = %x(#{cmd})

      unless '{}' == response
        report_error("Failed to upload symbol files:\n#{response}")
      else
        puts 'Uploaded symbol files.'
      end
    end

    def report_error(msg)
      fail msg
    end

    public

    def upload
      validate_options
      dump_symbol
      send_symbol
    end

  end

end
