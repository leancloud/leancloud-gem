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

    def verbose
      @options[:verbose]
    end

    def dsym_path
      path = @options[:file]
      @dsym_path ||= path if !path.nil? and File.readable?(path)
    end

    def dsym_macho
      @dsym_macho ||= Dir.glob(File.join(dsym_path, 'Contents/Resources/DWARF/*')).first
    end

    def validate_options
      report_error('LeanCloud App ID not found') unless @options[:id]
      report_error('LeanCloud App Key not found') unless @options[:key]
      report_error('DSYM file not found') unless dsym_path
    end

    def tmp_dir
      @tmp_dir ||= File.join(Dir.tmpdir(), 'cn.leancloud/symbols')
    end

    def dsym_archs
      info = `lipo -info #{dsym_macho}`
      arch_list = info[/(?<=:)([^:]*)$/].strip
      arch_list.split(' ')
    end

    def dump_cmd_template
      <<-EOT.gsub(/^[ \t]+/, '')
      {{#archs}}
      leancloud_dump_syms -a {{name}} #{dsym_path} > #{tmp_dir}/{{name}}.sym
      {{/archs}}
      EOT
    end

    def dump_symbol
      FileUtils.mkdir_p(tmp_dir)

      cmd = Mustache.render(dump_cmd_template, {
        archs: dsym_archs.map { |arch| { 'name' => arch } }
      })

      puts "Command for dump symbol file:\n#{cmd}" if verbose

      system(cmd)
    end

    def symbol_fields
      fields = []

      dsym_archs.each do |arch|
        path = "#{tmp_dir}/#{arch}.sym"
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
      #{url} >/dev/null 2>&1
      EOC

      puts 'Uploading symbol files...'
      puts "Command for uploading:\n#{cmd}" if verbose

      unless system(cmd)
        report_error('Failed to upload symbol files.')
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
