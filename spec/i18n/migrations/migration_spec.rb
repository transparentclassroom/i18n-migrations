require 'spec_helper'
require 'i18n/migrations/migration'
require 'i18n/migrations/migration_factory'

describe I18n::Migrations::Migration do
  let(:translations) { I18n::Migrations::MigrationFactory::Translations.new(data: @data, notes: @notes) }

  before do
    @data, @notes = {}, {}
  end

  def play_migration(type, direction)
    migration = type.new(translations: translations,
                         locale_code: 'es',
                         dictionary: FakeDictionary.new,
                         direction: direction)
    migration.change
  end

  describe '#add' do
    class TestMigrationAdd < I18n::Migrations::Migration
      def change
        add 'actions.new', 'New'
        add 'names.bob', 'Bob'
      end
    end

    it 'should work' do
      play_migration TestMigrationAdd, :up

      expect(@data).to eq('actions.new' => 'translated New',
                          'names.bob' => 'translated Bob')
      expect(@notes).to eq('actions.new' => '[autotranslated]',
                           'names.bob' => '[autotranslated]')

      play_migration TestMigrationAdd, :down

      expect(@data).to eq({})
      expect(@notes).to eq({})
    end
  end

  describe '#mv' do
    class TestMigrationMv < I18n::Migrations::Migration
      def change
        mv 'actions.new', 'actions.start'
      end
    end

    it 'should work' do
      @data = { 'actions.new' => 'New' }
      @notes = { 'actions.new' => 'something' }

      play_migration TestMigrationMv, :up

      expect(@data).to eq('actions.start' => 'New')
      expect(@notes).to eq('actions.start' => 'something')

      play_migration TestMigrationMv, :down

      expect(@data).to eq('actions.new' => 'New')
      expect(@notes).to eq('actions.new' => 'something')
    end
  end

  describe '#update' do
    class TestMigrationUpdate < I18n::Migrations::Migration
      def change
        update 'names.bob', 'Robert', 'Bob'
      end
    end

    it 'should work' do
      @data = { 'names.bob' => 'Bob' }
      @notes = { 'names.bob' => 'something' }

      play_migration TestMigrationUpdate, :up

      expect(@data).to eq('names.bob' => 'translated Robert')
      expect(@notes).to eq('names.bob' => '[autotranslated]')

      play_migration TestMigrationUpdate, :down

      expect(@data).to eq('names.bob' => 'translated Bob')
      expect(@notes).to eq('names.bob' => '[autotranslated]')
    end
  end

  describe '#rm' do
    class TestMigrationRm < I18n::Migrations::Migration
      def change
        rm 'actions.new', 'New'
      end
    end

    it 'should work' do
      @data = { 'actions.new' => 'New' }
      @notes = { 'actions.new' => 'something' }

      play_migration TestMigrationRm, :up

      expect(@data).to eq({})
      expect(@notes).to eq({})

      play_migration TestMigrationRm, :down

      expect(@data).to eq('actions.new' => 'translated New')
      expect(@notes).to eq('actions.new' => '[autotranslated]')
    end
  end
end
