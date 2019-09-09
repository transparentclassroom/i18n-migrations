require 'rest_client'

module I18n
  module Migrations
    class CrowdTranslateClient
      def sync_migrations(migrations)
        local_versions = migrations.all_versions
        remote_versions = JSON.parse(get('/migrations.json'))

        if (extra_versions = remote_versions - local_versions).present?
          raise("You may not upload migrations to the server because it has migrations not found locally: " +
                    "#{extra_versions.join(', ')}")
        end

        if (versions_to_add = local_versions - remote_versions).present?
          versions_to_add.each do |version|
            put("/migrations/#{version}.json",
                ruby: migrations.get_migration(version: version))
          end
        end
      end

      def play_all_migrations

      end

      def get_locale_file(locale_code)
        get("/locales/#{locale_code}.yml")
      end

      private

      def get(url)
        response = RestClient.get "https://crowd-translate.herokuapp.com#{url}"
        response.body
      end

      def put(url, params = {})
        response = RestClient.put "https://crowd-translate.herokuapp.com#{url}",
                                  params: params
        response.body
      end
    end
  end
end
