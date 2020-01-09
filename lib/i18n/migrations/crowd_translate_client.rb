require 'faraday'

module I18n
  module Migrations
    class CrowdTranslateClient
      def initialize
        token = ENV['CROWD_TRANSLATE_API_TOKEN']
        raise("You must define CROWD_TRANSLATE_API_TOKEN in order to talk to Crowd Translate") unless token.present?

        server = ENV['CROWD_TRANSLATE_SERVER'] || 'https://crowd-translate.herokuapp.com'
        @faraday = Faraday.new(
          url: "#{server}/api/v1",
          headers: { 'X-CrowdTranslateApiToken' => token },
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

      def play_all_migrations

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
        puts "PUT #{path} #{params}".bold
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
