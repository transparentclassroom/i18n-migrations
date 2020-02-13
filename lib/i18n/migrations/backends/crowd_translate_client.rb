require 'faraday'
require 'active_support/core_ext/object'

module I18n
  module Migrations
    module Backends
      class CrowdTranslateClient
        def initialize(api_token:, server_url:)
          @faraday = Faraday.new(
            url: File.join(server_url, '/api/v1'),
            headers: { 'X-CrowdTranslateApiToken' => api_token },
          )
        end

        def sync_migrations(migrations)
          local_versions = migrations.all_versions
          remote_versions = JSON.parse(get('migrations.json'))

          if (extra_versions = remote_versions - local_versions).present?
            raise("You may not upload migrations to the server because it has migrations not found locally: " +
                    "#{extra_versions.join(', ')}")
          end

          if (versions_to_add = local_versions - remote_versions).present?
            versions_to_add.each do |version|
              begin
                put("migrations/#{version}.json",
                    migration: { ruby_file: migrations.get_migration(version: version) })
              rescue
                puts "There was an error updating migration:".red
                puts "  #{migrations.migration_file(version: version)}".bold
                raise
              end
            end
          end
        end

        def get_locale_file(locale_code)
          get("locales/#{locale_code}.yml")
        end

        private

        def get(path)
          puts "GET #{path}".bold
          parse_response @faraday.get path
        end

        def put(path, params = {})
          puts "PUT #{path} #{params.to_s[0..50]}#{'...' if params.to_s.length > 50}".bold
          parse_response @faraday.put path, params
        end

        def parse_response(response)
          if response.success?
            response.body
          else
            error = begin
                      JSON.parse(response.body)['error']
                    rescue
                      response.body
                    end
            raise error
          end
        end
      end
    end
  end
end
