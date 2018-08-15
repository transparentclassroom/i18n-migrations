require 'spec_helper'
require 'i18n/migrations/migration_factory'

describe I18n::Migrations::MigrationFactory do
  let(:migration_dir) { '/tmp/migration_factory_spec/migration' }
  let(:migrations) { I18n::Migrations::MigrationFactory.new(migration_dir) }

  before do
    FileUtils.mkdir_p migration_dir
  end

  after do
    FileUtils.rm_rf migration_dir
  end

  describe '#all_versions' do
    it 'should list all ruby files in migration dir' do
      File.write(File.join(migration_dir, '201712061055_payments_page.rb'), 'foo')
      File.write(File.join(migration_dir, '201712061057_payments_page.rb'), 'foo')
      File.write(File.join(migration_dir, 'ignore.txt'), 'foo')

      expect(migrations.all_versions).to match_array(["201712061055_payments_page", "201712061057_payments_page"])
    end
  end

  describe '#play_migration' do
    let(:data) { {} }
    let(:notes) { {} }
    before do
      File.write File.join(migration_dir, '201712061057_payments_page.rb'), <<-RUBY
require 'i18n-migrations'

class PaymentsPage201712061057 < I18n::Migrations::Migration
  def change
    add 'payments.show.title', 'Transparent Classroom Receipt', es: 'Recibo para Transparent Classroom'
    add 'payments.show.hint.credit', 'This is a credit'
  end
end
      RUBY
    end

    def play_migration(direction)
      migrations.play_migration(version: '201712061057_payments_page',
                                locale: 'es',
                                data: data,
                                notes: notes,
                                dictionary: FakeDictionary.new,
                                direction: direction)
    end

    it 'should create migration and run it' do
      play_migration(:up)

      expect(data)
          .to eq({
                     'payments.show.hint.credit' => 'translated This is a credit',
                     'payments.show.title' => 'Recibo para Transparent Classroom',
                 })
      expect(notes)
          .to eq({
                     'payments.show.hint.credit' => '[autotranslated]',
                 })
    end

    it 'should create migration and roll it back' do
      play_migration(:up)
      play_migration(:down)

      expect(data).to eq({})
      expect(notes).to eq({})
    end
  end
end
