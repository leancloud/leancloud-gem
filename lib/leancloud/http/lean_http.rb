require 'uri'

module LeanCloud

  # LeanCloud HTTP manager
  class LeanHTTP < LeanObject
    BASE_URL = 'https://cn-stg1.avoscloud.com/1/'

    protected

    def api(path)
      URI.join(BASE_URL, path)
    end

  end

end
