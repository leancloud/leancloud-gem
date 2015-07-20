require 'uri'

module LeanCloud

  # LeanCloud HTTP manager
  class LeanHTTP < LeanObject

    DOMAINS = {
      "cn" => 'leancloud.cn',
      "us" => 'avoscloud.us'
    }

    BASE_URL_FMT = 'https://api.%{domain}/1.1/'

    def initialize(opts = {})
      @options = opts
    end

    protected

    def region
      @region ||= valid_region
    end

    def valid_region
      region = @options[:region];

      if region
        exit_with_error('Unsupported server region') unless DOMAINS.has_key?(region)
        region
      else
        'cn'
      end
    end

    def domain
      @domain ||= DOMAINS[region]
    end

    def base_url
      @base_url ||= BASE_URL_FMT % { :domain => domain }
    end

    def api(path)
      URI.join(base_url, path)
    end

  end

end
