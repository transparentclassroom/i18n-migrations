require 'faraday'
require 'active_support/core_ext/object'

module I18n
  module Migrations
    module Backends
      class CrowdTranslateError < StandardError
      end

      class CrowdTranslateClient
        def initialize
          token = ENV['CROWD_TRANSLATE_API_TOKEN']
          raise("You must define CROWD_TRANSLATE_API_TOKEN in order to talk to Crowd Translate") unless token.present?

          @server = ENV['CROWD_TRANSLATE_SERVER'] || 'https://crowd-translate.herokuapp.com'
          @faraday = Faraday.new(url: base_url, headers: { 'X-CrowdTranslateApiToken' => token })
        end

        def get_locale_file(locale_code)
          get("locales/#{locale_code}.yml")
        end

        def get_migration_versions
          JSON.parse(get('migrations.json'))
        end

        def put_migration(version:, ruby_file:)
          put("migrations/#{version}.json", migration: { ruby_file: ruby_file })
        end

        def put_locale(locale_code, name:, yaml_file:, yaml_metadata_file:)
          put("locales/#{locale_code}",
              locale: { name: name, yaml_file: yaml_file, yaml_metadata_file: yaml_metadata_file })
        end

        private

        def get(path)
          puts "GET #{path}".bold
          parse_response 'GET', path, @faraday.get(path)
        end

        def put(path, params = {})
          puts "PUT #{path} #{params.to_s[0..50]}#{'...' if params.to_s.length > 50}".bold
          parse_response 'PUT', path, @faraday.put(path, params)
        end

        def parse_response(method, path, response)
          if response.success?
            response.body
          else
            error = begin
                      JSON.parse(response.body)['error']
                    rescue
                      response.body
                    end
            raise CrowdTranslateError, "... while calling #{method} #{File.join(base_url, path)}\n#{error}"
          end
        end

        def base_url
          "#{@server}/api/v1"
        end
      end
    end
  end
end
