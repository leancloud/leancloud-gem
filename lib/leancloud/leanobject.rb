require 'colorize'

module LeanCloud

  # Root class
  class LeanObject

    def show_error(msg)
      puts(msg.colorize(:red))
    end

    def exit_with_error(msg)
      show_error(msg)
      exit
    end

    def show_success(msg)
      puts(msg.colorize(:green))
    end

    def show_message(msg)
      puts("==> #{msg}")
    end

  end

end
