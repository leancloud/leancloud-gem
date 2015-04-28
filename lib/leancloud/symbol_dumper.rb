require 'mustache'

module LeanCloud

  # Mach-O symbol dumper
  class SymbolDumper < LeanObject

    def initialize(opts)
      @opts = opts
    end

    private

    attr_reader :dsym_path
    attr_reader :dest_path

    def dsym_path
      @opts[:file]
    end

    def dest_path
      @opts[:dest]
    end

    def verbose?
      @opts[:verbose]
    end

    def make_validation
      exit_with_error('DSYM path not found') unless File.readable?(dsym_path.to_s)
      exit_with_error('Destination path not found') unless File.directory?(dest_path.to_s)
    end

    def list_macho_files
      files = []

      if File.directory?(dsym_path)
        files += Dir.glob(File.join(dsym_path, '**/*'))
      else
        files << dsym_path
      end

      files.each do |file|
        info = %x(lipo -info #{file} 2>/dev/null)
        yield file unless info.empty?
      end
    end

    def macho_entries
      entries = []

      list_macho_files do |file|
        uuids = %x(dwarfdump --uuid #{file})
        uuids.split("\n").each do |line|
          next unless line =~ /^UUID/
          components = line.split(' ')
          uuid = components[1]
          entries << {
            uuid: uuid,
            arch: components[2][1...-1],
            dest: File.join(dest_path, "#{uuid}.sym"),
            file: file
          }
        end
      end

      entries
    end

    def dump_cmd_template
      <<-EOT.gsub(/^[ \t]+/, '')
      {{#entries}}
      leancloud_dump_syms -a {{arch}} {{file}} > {{dest}} 2>/dev/null
      {{/entries}}
      EOT
    end

    def dump_symbols
      cmd = Mustache.render(dump_cmd_template, { entries: macho_entries })
      puts cmd if verbose?
      system(cmd)
    end

    public

    def dump
      make_validation
      dump_symbols
    end

  end

end
