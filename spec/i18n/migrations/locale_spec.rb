require 'spec_helper'

require 'i18n/migrations/locale'
require 'i18n/migrations/migration'
require 'i18n/migrations/migration_factory'
require 'i18n/migrations/backends/crowd_translate_client'
require_relative './simple_migrations'

describe I18n::Migrations::Locale do
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

  describe '#validate' do
  end

  describe '#update_info' do
    it 'should read date & notes and write them back' do
      File.write_yaml '/tmp/locale_spec/locales/es.yml', es: { something: 'this is data' }
      File.write_yaml '/tmp/locale_spec/es_notes.yml', es: { something_else: 'this is notes' }

      locale.update_info do |data, notes|
        expect(data).to eq({ 'something' => 'this is data' })
        expect(notes).to eq({ 'something_else' => 'this is notes' })

        data['foo'] = 'blue'
        data['bar.baz.boo'] = 'cow'
        notes['foo'] = 'red'
        notes['bar.baz.boo'] = 'bull'
      end

      expect(File.read('/tmp/locale_spec/locales/es.yml')).to eq <<-YML
---
es:
  bar:
    baz:
      boo: cow
  foo: blue
  something: this is data
      YML
      expect(File.read('/tmp/locale_spec/es_notes.yml')).to eq <<-YML
---
es:
  bar:
    baz:
      boo: bull
  foo: red
  something_else: this is notes
      YML
    end
  end

  describe '#migrate & #rollback' do
    it 'should play migrations not yet played' do
      data = {}
      notes = {}
      locale.migrate(data, notes)
      expect(data).to eq('VERSION' => "one\ntwo",
                         'one' => 'translated ONE',
                         'two' => 'translated TWO')
      expect(notes).to eq('one' => '[autotranslated]',
                          'two' => '[autotranslated]')

      # rollback one migration
      locale.rollback(data, notes)
      expect(data).to eq('VERSION' => 'one',
                         'one' => 'translated ONE')

      # play just the one migration
      locale.migrate(data, notes)
      expect(data).to eq('VERSION' => "one\ntwo",
                         'one' => 'translated ONE',
                         'two' => 'translated TWO')

      # rollback both migrations
      locale.rollback(data, notes)
      locale.rollback(data, notes)
      expect(data).to eq('VERSION' => '')
    end
  end
end
