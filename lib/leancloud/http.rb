require 'uri'

module LeanCloud

  # LeanCloud HTTP manager
  class HTTP < LeanObject

    BASE_URL = 'https://cn-stg1.avoscloud.com/1/'

    attr_accessor :app_id, :app_key

    private

    def api(path)
      URI.join(BASE_URL, path)
    end

    def validate_symbol_options(opts)
      exit_with_error('LeanCloud App ID not found') unless opts[:id]
      exit_with_error('LeanCloud App Key not found') unless opts[:key]
    end

    public

    def upload_symbol(opts)
      validate_symbol_options(opts)

      path = File.join(opts[:path], 'Contents/Resources/DWARF')
      file = Dir.glob("#{path}/*").first

      exit_with_error('Symbol file not found') unless File.readable?(file)

      url = api('stats/breakpad/symbols')
      cmd = <<-EOC.gsub(/^[ \t]+/, '')
      curl -X POST \
      -H "X-AVOSCloud-Application-Id: #{opts[:id]}" \
      -H "X-AVOSCloud-Application-Key: #{opts[:key]}" \
      -F "symbol_file=@#{file}" \
      '#{url}' >/dev/null 2>&1
      EOC

      raise "Can not upload symbol file to LeanCloud" unless system(cmd)
    end

  end

end
