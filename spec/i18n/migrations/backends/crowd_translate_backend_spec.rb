require 'spec_helper'
require 'i18n/migrations/backends/crowd_translate_backend'
require 'i18n/migrations/migration_factory'
require 'i18n/migrations/locale'
require_relative '../simple_migrations'


describe I18n::Migrations::Backends::CrowdTranslateBackend do
  let(:locales_dir) { '/tmp/crowd_translate_backend_spec/locales' }
  let(:migration_dir) { '/tmp/crowd_translate_backend_spec/migration' }

  let(:client) { I18n::Migrations::Backends::CrowdTranslateClient.new }
  let(:backend) { I18n::Migrations::Backends::CrowdTranslateBackend.new(client: client) }
  let(:migrations) { I18n::Migrations::MigrationFactory.new(migration_dir) }

  before do
    FileUtils.mkdir_p locales_dir
    FileUtils.mkdir_p migration_dir
  end

  after do
    FileUtils.rm_rf locales_dir
    FileUtils.rm_rf migration_dir
  end

  describe '#sync_migrations' do
    it 'should do nothing if migrations are the same' do
      allow(client).to receive(:get).with('migrations.json') {
        ['one', 'two'].to_json
      }

      File.write(File.join(migration_dir, 'one.rb'), 'foo')
      File.write(File.join(migration_dir, 'two.rb'), 'foo')

      backend.sync_migrations(migrations)
    end

    it 'should add missing migrations' do
      allow(client).to receive(:get).with('migrations.json') {
        ['one'].to_json
      }

      contents = <<-CONTENTS
require 'i18n-migrations'

class PaymentsPage201712061057 < I18n::Migrations::Migration
  def change
    add 'payments.show', 'Show'
  end
end
      CONTENTS

      File.write File.join(migration_dir, 'one.rb'), 'foo'
      File.write File.join(migration_dir, 'two.rb'), contents

      expect(client).to receive(:put)
                          .with('migrations/two.json',
                                migration: { ruby_file: contents }) {
                            double(body: "OK")
                          }

      backend.sync_migrations(migrations)
    end

    it "should blow up if the server has migrations we don't know about" do
      allow(client).to receive(:get).with('migrations.json') {
        ['one', 'two', 'four'].to_json
      }

      File.write(File.join(migration_dir, 'one.rb'), 'foo')
      File.write(File.join(migration_dir, 'three.rb'), 'foo')

      expect { backend.sync_migrations(migrations) }
        .to raise_error("You may not upload migrations to the server because it has migrations not found locally: two, four")
    end
  end

  describe '#pull_from_crowd_translate' do
    let(:simple_migrations) {
      m = SimpleMigrations.new
      m.add('one', SimpleMigrations::OneMigration)
      m.add('two', SimpleMigrations::TwoMigration)
      m
    }

    it 'should pull file and save it, updating versions' do
      file_contents = <<-YAML
---
es:
  VERSION: |
    version1
    version2
  actions:
    new: New
      YAML

      allow(client).to receive(:get_locale_file).with('es') {
        file_contents
      }

      locale = I18n::Migrations::Locale.new 'es',
                                            locales_dir: locales_dir,
                                            main_locale_name: 'en',
                                            migrations: simple_migrations,
                                            dictionary: FakeDictionary.new

      backend.pull_from_crowd_translate(locale)

      expect(File.read(File.join(locales_dir, 'es.yml'))).to eq(file_contents)
      expect(YAML::load(File.read(File.join(locales_dir, '../es_remote_version.yml'))))
        .to eq({ 'es' => { 'VERSION' => ['version1', 'version2'] } })
    end
  end

  describe '#push' do
    it 'should ' do

    end
  end
end
