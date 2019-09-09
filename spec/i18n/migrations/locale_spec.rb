require 'spec_helper'

require 'i18n/migrations/locale'
require 'i18n/migrations/migration'
require 'i18n/migrations/migration_factory'
require 'i18n/migrations/crowd_translate_client'

class OneMigration < I18n::Migrations::Migration
	def change
		add 'one', 'ONE'
	end
end

class TwoMigration < I18n::Migrations::Migration
	def change
		add 'two', 'TWO'
	end
end

class SimpleMigrations
	def initialize
		@migrations = {}
	end

	def all_versions
		@migrations.keys
	end

	def play_migration(version:, locale:, data:, notes:, dictionary:, direction:)
		translations = I18n::Migrations::MigrationFactory::Translations.new(data: data, notes: notes)
		migration = @migrations[version].new(locale_code: locale,
																				 translations: translations,
																				 dictionary: dictionary,
																				 direction: direction)
		migration.change
	end

	def add(version, migration_class)
		@migrations[version] = migration_class
	end
end

describe I18n::Migrations::Locale do
	let(:locales_dir) { '/tmp/locale_spec/locales' }
	let(:migrations) {
		m = SimpleMigrations.new
		m.add('one', OneMigration)
		m.add('two', TwoMigration)
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
			locale.pull(sheet)

			expect(YAML.load_file('/tmp/locale_spec/locales/es.yml')).to eq(stringify(es: { one: 'UNO', two: 'DOS' }))
			expect(YAML.load_file('/tmp/locale_spec/es_notes.yml')).to eq(stringify(es: { one: 'notes about one' }))
		end

		it 'should push data to sheet' do
			File.write_yaml('/tmp/locale_spec/locales/en.yml', en: { one: 'ONE', two: 'TWO' })
			File.write_yaml('/tmp/locale_spec/locales/es.yml', es: { one: 'UNO', two: 'DOS' })
			File.write_yaml('/tmp/locale_spec/es_notes.yml', es: { one: 'notes about one' })

			sheet = FakeSheet.new
			locale.push(sheet)

			expect(sheet.data).to eq(data)
		end
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

			allow(RestClient).to receive(:get).with('https://crowd-translate.herokuapp.com/locales/es.yml') {
				double(body: file_contents)
			}

			locale.pull_from_crowd_translate(I18n::Migrations::CrowdTranslateClient.new)

			expect(File.read('/tmp/locale_spec/locales/es.yml')).to eq(file_contents)
			expect(YAML::load(File.read('/tmp/locale_spec/es_remote_version.yml')))
				.to eq({ 'es' => { 'VERSION' => ['version1', 'version2'] } })
		end
	end
end
