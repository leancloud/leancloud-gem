require 'mustache'
require 'fileutils'

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

    def temp_symbol_file
      @temp_symbol_file ||= File.join(dest_path, '~.sym')
    end

    def move_temp_symbol_file
      head = File.open(temp_symbol_file).first

      components = head.split(' ')
      arch = components[2]
      uuid = components[3]
      name = components[4]

      file = File.join(dest_path, name, uuid, "#{name}.sym")

      FileUtils.mkdir_p(File.dirname(file))
      FileUtils.cp(temp_symbol_file, file)
    end

    def dump_symbol_file(file)
      uuids = %x(dwarfdump --uuid #{file})
      uuids.split("\n").each do |line|
        next unless line =~ /^UUID/
        arch = line.split(' ')[2][1...-1]
        system("leancloud_dump_syms -a #{arch} #{file} > #{temp_symbol_file} 2>/dev/null")
        move_temp_symbol_file
      end
    end

    def dump_symbols
      list_macho_files do |file|
        dump_symbol_file(file)
      end
    end

    public

    def destroy
      FileUtils.rm_rf(temp_symbol_file)
    end

    def dump
      make_validation
      dump_symbols
    end

  end

end
