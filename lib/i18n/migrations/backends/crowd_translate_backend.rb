require_relative './crowd_translate_client'

module I18n
  module Migrations
    module Backends
      class CrowdTranslateBackend
        attr_reader :client

        def initialize(config)
          @client = CrowdTranslateClient.new(api_token: config.crowd_translate_api_token,
                                             server_url: config.crowd_translate_server_url)
        end

        def pull(locale)
          pull_from_crowd_translate(locale)
          locale.migrate!
        end

        def push(locale, force = false)
          raise "CrowdTranslate does not support -f flag yet" if force

          # do this just once
          unless @migrations_synced
            @client.sync_migrations(locale.migrations)
            @migrations_synced = true
          end
          pull(locale)
        end

        def pull_from_crowd_translate(locale)
          data = @client.get_locale_file(locale.name)
          locale.write_raw_data("#{locale.name}.yml", data)
          locale.write_remote_version(YAML::load(data)[locale.name])
        end
      end
    end
  end
end
