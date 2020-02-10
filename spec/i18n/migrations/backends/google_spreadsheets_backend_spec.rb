require 'spec_helper'
require 'i18n/migrations/backends/google_spreadsheets_backend'
require 'i18n/migrations/migration_factory'
require 'i18n/migrations/locale'
require_relative '../simple_migrations'

describe I18n::Migrations::Backends::GoogleSpreadsheetsBackend do
  let(:config) { double('config') }
  let(:backend) { I18n::Migrations::Backends::GoogleSpreadsheetsBackend.new(config) }
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

  describe '#push & #pull' do
    let(:data) {
      [
        ['key', 'en', 'es', 'notes'],
        ['one', 'ONE', 'UNO', 'notes about one'],
        ['two', 'TWO', 'DOS', nil],
      ]
    }

    it 'should pull data from sheet' do
      sheet = FakeSheet.new(data)
      backend.pull_from_sheet(sheet, locale)

      expect(YAML.load_file('/tmp/locale_spec/locales/es.yml')).to eq(stringify(es: { one: 'UNO', two: 'DOS' }))
      expect(YAML.load_file('/tmp/locale_spec/es_notes.yml')).to eq(stringify(es: { one: 'notes about one' }))
    end

    it 'should push data to sheet' do
      File.write_yaml('/tmp/locale_spec/locales/en.yml', en: { one: 'ONE', two: 'TWO' })
      File.write_yaml('/tmp/locale_spec/locales/es.yml', es: { one: 'UNO', two: 'DOS' })
      File.write_yaml('/tmp/locale_spec/es_notes.yml', es: { one: 'notes about one' })

      sheet = FakeSheet.new
      backend.push_to_sheet(sheet, locale)

      expect(sheet.data).to eq(data)
    end
  end
end
