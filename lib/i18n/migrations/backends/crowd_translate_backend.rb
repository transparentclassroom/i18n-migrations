require_relative './crowd_translate_client'

module I18n
  module Migrations
    module Backends
      class CrowdTranslateBackend
        attr_reader :client

        def initialize(client: CrowdTranslateClient.new)
          @client = client
        end

        def pull(locale)
          pull_from_crowd_translate(locale)
        end

        def push(locale, force: false)
          if force
            force_push(locale)
          end

          pull(locale)
        end

        # this will replace everything about a locale, it will create a locale that does not yet exist
        def force_push(locale)
          data, metadata = locale.read_data_and_metadata(parse: false)
          client.put_locale(locale.name,
                            name: locale.name,
                            yaml_file: data,
                            yaml_metadata_file: metadata)

        end

        def pull_from_crowd_translate(locale)
          data = client.get_locale_file(locale.name)
          locale.data_file.write(data)
          locale.write_remote_version(YAML::load(data)[locale.name])
        end

        def sync_migrations(migrations)
          local_versions = migrations.all_versions
          remote_versions = client.get_migration_versions

          if (extra_versions = remote_versions - local_versions).present?
            raise("You may not upload migrations to the server because it has migrations not found locally: " +
                    "#{extra_versions.join(', ')}")
          end

          if (versions_to_add = local_versions - remote_versions).present?
            versions_to_add.each do |version|
              begin
                client.put_migration(version: version, ruby_file: migrations.get_migration(version: version))
              rescue
                raise CrowdTranslateError, "... while updating migration: #{migrations.migration_file(version: version)}\n#{$!.message}"
              end
            end
          end
        end
      end
    end
  end
end
