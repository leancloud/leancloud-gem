require 'uri'

module LeanCloud

  # LeanCloud HTTP manager
  class LeanHTTP < LeanObject
    BASE_URL = 'https://api.leancloud.cn/1/'

    protected

    def api(path)
      URI.join(BASE_URL, path)
    end

  end

end
