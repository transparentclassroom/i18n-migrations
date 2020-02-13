require 'spec_helper'
require 'i18n/migrations/backends/crowd_translate_backend'
require 'i18n/migrations/migration_factory'
require 'i18n/migrations/locale'
require_relative '../simple_migrations'

describe I18n::Migrations::Backends::CrowdTranslateBackend do
  let(:backend) { I18n::Migrations::Backends::CrowdTranslateBackend.new }
  let(:locales_dir) { '/tmp/locale_spec/locales' }
  let(:migrations) {
    m = SimpleMigrations.new
    m.add('one', SimpleMigrations::OneMigration)
    m.add('two', SimpleMigrations::TwoMigration)
    m
  }

  def locale(name = 'es')
    I18n::Migrations::Locale.new name,
                                 locales_dir: locales_dir,
                                 main_locale_name: 'en',
                                 migrations: migrations,
                                 dictionary: FakeDictionary.new
  end

  before do
    FileUtils.mkdir_p locales_dir
  end

  after do
    FileUtils.rm_rf locales_dir
  end

  describe '#pull_from_crowd_translate' do
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

      allow(backend.client).to receive(:get).with('locales/es.yml') {
        file_contents
      }

      backend.pull_from_crowd_translate(locale)

      expect(File.read('/tmp/locale_spec/locales/es.yml')).to eq(file_contents)
      expect(YAML::load(File.read('/tmp/locale_spec/es_remote_version.yml')))
        .to eq({ 'es' => { 'VERSION' => ['version1', 'version2'] } })
    end
  end
end
