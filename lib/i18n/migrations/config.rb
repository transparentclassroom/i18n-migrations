require 'yaml'

module I18n
  module Migrations
    class Config
      CONFIG_FILE_NAME = '.i18n-migrations.yml'
      DEFAULT_CONCURRENCY = 4
      DEFAULT_WAIT_SECONDS = 0
      CROWD_TRANSLATE_BACKEND = 'crowd_translate'
      GOOGLE_SPREADSHEET_BACKEND = 'google_spreadsheets'
      VALID_BACKENDS = [CROWD_TRANSLATE_BACKEND, GOOGLE_SPREADSHEET_BACKEND]

      def initialize(config_file_name = CONFIG_FILE_NAME)
        @config_file_name = config_file_name
      end

      def migration_dir
        get_file(:migration_dir)
      end

      def locales_dir
        get_file(:locales_dir)
      end

      def main_locale
        get_value(:main_locale)
      end

      def backend
        value = get_value(:backend)
        raise ArgumentError, "Backend must be one of #{VALID_BACKENDS}" unless VALID_BACKENDS.include?(value)
        value
      end

      def crowd_translate?
        backend == CROWD_TRANSLATE_BACKEND
      end

      def google_spreadsheet?
        backend == GOOGLE_SPREADSHEET_BACKEND
      end

      def other_locales
        get_value(:other_locales).keys
      end

      def google_service_account_key_path
        get_file(:google_service_account_key_path)
      end

      def google_spreadsheet(locale)
        get_value([:other_locales, locale, :google_spreadsheet])
      end

      def crowd_translate_api_token
        get_value(:crowd_translate_api_token)
      end

      def crowd_translate_server_url
        get_value(:crowd_translate_server_url)
      end

      def do_not_translate(locale)
        return {} if locale.to_s == main_locale

        get_value([:other_locales, locale])['do_not_translate'] || {}
      end

      def google_translate_api_key
        get_value(:google_translate_api_key)
      end

      def concurrency
        get_value(:concurrency, DEFAULT_CONCURRENCY)
      end

      def push_concurrency
        get_value(:push_concurrency, concurrency)
      end

      def wait_seconds
        get_value(:wait_seconds, DEFAULT_WAIT_SECONDS)
      end

      def read!
        yaml_file = find_config_file(@config_file_name)
        unless yaml_file
          STDERR.puts "Can't find a #{@config_file_name} file. Try running 'i18n-migrations setup'"
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

      def get_value(key, default = nil)
        if key.is_a?(Array)
          value = @config
          key.each do |key_part|
            if value&.has_key?(key_part.to_s)
              value = value[key_part.to_s]
            else
              raise ArgumentError, "You must have defined #{key.join('/')} in #{@root_dir}/#{@config_file_name}"
            end
          end
          value
        elsif @config.has_key?(key.to_s)
          @config[key.to_s]
        elsif default.present?
          default
        else
          raise ArgumentError, "You must have defined #{key} in #{@root_dir}/#{@config_file_name}"
        end
      end

      def get_file(key)
        file = File.join(@root_dir, get_value(key))
        unless File.exist?(file)
          raise ArgumentError, "#{File.expand_path(file)} does not exist, please create it."
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
