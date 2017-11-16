require 'yaml'

module I18n
  module Migrations
    class Config
      CONFIG_FILE_NAME = '.i18n-migrations.yml'

      def migration_dir
        get_file(:migration_dir)
      end

      def locales_dir
        get_file(:locales_dir)
      end

      def main_locale
        get_value(:main_locale)
      end

      def other_locales
        get_value(:other_locales)
      end

      def google_service_account_key_path
        get_file(:google_service_account_key_path)
      end

      def google_spreadsheets
        get_value(:google_spreadsheets)
      end

      def google_translate_api_key
        get_value(:google_translate_api_key)
      end

      def read!
        yaml_file = find_config_file(CONFIG_FILE_NAME)
        unless yaml_file
          STDERR.puts "Can't find a #{CONFIG_FILE_NAME} file. Try running 'i18n-migrations setup'"
          exit(1)
        end

        @root_dir = File.dirname(yaml_file)

        @config = begin
          YAML::load(File.read(yaml_file))
        rescue Psych::SyntaxError
          STDERR.puts("YAML configuration file contains invalid syntax.")
          STDERR.puts($!.message)
          exit(1)
        end

        # todo check for required keys
        self
      end

      def self.copy_default_config_file(dir)
        File.open(File.join(dir, CONFIG_FILE_NAME), 'w') do |f|
          f << File.read(File.join(File.dirname(__FILE__), '../../../.i18n-migrations.default.yml'))
        end
      end

      private

      def get_value(key)
        if @config.has_key?(key.to_s)
          @config[key.to_s]
        else
          STDERR.puts "You must have defined #{key} in #{@root_dir}/#{CONFIG_FILE_NAME}"
          exit(1)
        end
      end

      def get_file(key)
        file = File.join(@root_dir, get_value(key))
        unless File.exist?(file)
          STDERR.puts "#{File.expand_path(file)} does not exist"
          exit(1)
        end
        file
      end

      def find_config_file(name)
        file = File.expand_path(name)
        loop do
          return file if File.exist?(file)
          next_file = File.join(File.dirname(File.dirname(file)), name)
          return nil if file == next_file
          file = next_file
        end
      end
    end
  end
end
