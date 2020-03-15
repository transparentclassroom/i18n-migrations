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
        ['VERSION', "version1\nversion2", "version1\nversion2", ''],
        ['one', 'ONE', 'UNO', 'notes about one'],
        ['two', 'TWO', 'DOS', ''],
        ['more.complex.key', 'more stuff', 'mas stuff', "[autotranslated]\n[error: foo]"],
      ]
    }

    it 'should pull data from sheet' do
      sheet = FakeSheet.new(data)
      backend.pull_from_sheet(sheet, locale)

      data, metadata = locale.read_data_and_metadata

      expect(data).to eq('VERSION' => "version1\nversion2",
                         'one' => 'UNO',
                         'two' => 'DOS',
                         'more.complex.key' => 'mas stuff')
      expect(metadata.to_h).to eq('one' => { 'notes' => 'notes about one' },
                                  'more.complex.key' => { 'autotranslated' => true,
                                                          'errors' => ['foo'] })

      expect(File.read_yaml(File.join(locales_dir, '../es_remote_version.yml')))
        .to eq('VERSION' => ['version1', 'version2'])
    end

    it 'should push data to sheet' do
      File.write_yaml('/tmp/locale_spec/locales/en.yml',
                      en: { VERSION: "version1\nversion2",
                            one: 'ONE',
                            two: 'TWO',
                            'more.complex.key': 'more stuff' })
      File.write_yaml('/tmp/locale_spec/locales/es.yml',
                      es: { VERSION: "version1\nversion2",
                            one: 'UNO',
                            two: 'DOS',
                            'more.complex.key': 'mas stuff' })
      File.write_yaml('/tmp/locale_spec/es_metadata.yml',
                      one: { notes: 'notes about one' },
                      'more.complex.key': { autotranslated: true, errors: ['foo'] })

      sheet = FakeSheet.new
      backend.push_to_sheet(sheet, locale)

      expect(sheet.data).to eq(data)

      expect(File.read_yaml(File.join(locales_dir, '../es_remote_version.yml')))
        .to eq('VERSION' => ['version1', 'version2'])
    end
  end

  describe 'parsing metadatum' do
    def parse(string)
      backend.parse_metadatum(string).to_h
    end

    def unparse(hash)
      backend.unparse_metadatum(Metadata::Metadatum.new(hash))
    end

    it "should parse" do
      expect(parse("")).to eq({})
      expect(parse("foo")).to eq('notes' => 'foo')
      expect(parse("[autotranslated] foo")).to eq('autotranslated' => true, 'notes' => 'foo')
      expect(parse("[error: bob]")).to eq('errors' => ['bob'])
      expect(parse("[autotranslated][error: something] like cheese [error: bob] [and crackers]"))
        .to eq('autotranslated' => true,
               'notes' => 'like cheese  [and crackers]',
               'errors' => ['something', 'bob'])
    end

    it "should unparse" do
      expect(unparse({})).to eq('')
      expect(unparse('notes' => 'foo')).to eq("foo")
      expect(unparse('autotranslated' => true, 'notes' => 'foo')).to eq("[autotranslated]\nfoo")
      expect(unparse('errors' => ['bob'])).to eq("[error: bob]")
      expect(unparse('autotranslated' => true,
                     'notes' => 'like cheese  [and crackers]',
                     'errors' => ['something', 'bob']))
        .to eq("[autotranslated]\n[error: something]\n[error: bob]\nlike cheese  [and crackers]")
    end
  end
end
