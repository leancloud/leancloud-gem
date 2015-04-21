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

    def dump_symbol
      dsym_file = @options[:file]

      FileUtils.mkdir_p('/tmp/.leancloud')

      cmd = <<-EOC
      leancloud_dump_syms -a armv7  #{dsym_file} > /tmp/.leancloud/armv7.sym
      leancloud_dump_syms -a armv7s #{dsym_file} > /tmp/.leancloud/armv7s.sym
      leancloud_dump_syms -a arm64  #{dsym_file} > /tmp/.leancloud/arm64.sym
      EOC

      system(cmd)
    end

    def send_symbol
      id  = @options[:id]
      key = @options[:key]
      url = api('stats/breakpad/symbols')

      armv7  = '/tmp/.leancloud/armv7.sym'
      armv7s = '/tmp/.leancloud/armv7s.sym'
      arm64  = '/tmp/.leancloud/arm64.sym'

      cmd = <<-EOC.gsub(/^[ \t]+/, '')
      curl -X POST \\
      -H "X-AVOSCloud-Application-Id: #{id}" \\
      -H "X-AVOSCloud-Application-Key: #{key}" \\
      -F "symbol_file_armv7=@#{armv7}" \\
      -F "symbol_file_armv7s=@#{armv7s}" \\
      -F "symbol_file_arm64=@#{arm64}" \\
      #{url}
      EOC

      msg = <<-EOM.gsub(/^[ \t]+/, '')
      Can not upload symbol files with following command:
      #{cmd}
      EOM

      report_error(msg) unless system(cmd)
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
