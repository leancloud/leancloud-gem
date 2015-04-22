require 'tmpdir'
require 'fileutils'
require 'leancloud/http/lean_http'

module LeanCloud

  # LeanCloud symbol uploader
  class SymbolUploader < LeanHTTP

    def initialize(opts)
      @options = opts
    end

    private

    def dsym_path
      path = @options[:file]
      @dsym_file ||= path if !path.nil? and File.readable?(path)
    end

    def validate_options
      report_error('LeanCloud App ID not found') unless @options[:id]
      report_error('LeanCloud App Key not found') unless @options[:key]
      report_error('DSYM file not found') unless dsym_path
    end

    def tmp_dir
      @tmp_dir ||= File.join(Dir.tmpdir(), '.leancloud')
    end

    def dump_symbol
      dsym_file = @options[:file]

      FileUtils.mkdir_p(tmp_dir)

      cmd = <<-EOC
      leancloud_dump_syms -a armv7  #{dsym_file} > #{tmp_dir}/armv7.sym
      leancloud_dump_syms -a armv7s #{dsym_file} > #{tmp_dir}/armv7s.sym
      leancloud_dump_syms -a arm64  #{dsym_file} > #{tmp_dir}/arm64.sym
      EOC

      system(cmd)
    end

    def symbol_fields
      fields = []

      { 'armv7'  => "#{tmp_dir}/armv7.sym",
        'armv7s' => "#{tmp_dir}/armv7s.sym",
        'arm64'  => "#{tmp_dir}/arm64.sym"
      }.each do |arch, path|
        next if !File.readable?(path) or File.zero?(path)
        fields << "-F \"symbol_file_#{arch}=@#{path}\""
      end

      fields
    end

    def send_symbol
      fields = symbol_fields

      return if fields.empty?

      form_fields = fields.join(' ')
      url = api('stats/breakpad/symbols')

      cmd = <<-EOC.gsub(/^[ \t]+/, '')
      curl -X POST \\
      -H "X-AVOSCloud-Application-Id: #{@options[:id]}" \\
      -H "X-AVOSCloud-Application-Key: #{@options[:key]}" \\
      #{form_fields} \\
      #{url}
      EOC

      unless system(cmd)
        msg = "Can not upload symbol files with following command:\n#{cmd}"
        report_error(msg)
      end
    end

    def report_error(msg)
      raise msg
    end

    public

    def upload
      validate_options
      dump_symbol
      send_symbol
    end

  end

end
