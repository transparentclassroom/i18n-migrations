require 'spec_helper'
require 'i18n/migrations/crowd_translate_client'
require 'i18n/migrations/migration_factory'

describe I18n::Migrations::CrowdTranslateClient do
  let(:client) { I18n::Migrations::CrowdTranslateClient.new }
  let(:migration_dir) { '/tmp/migration_factory_spec/migration' }
  let(:migrations) { I18n::Migrations::MigrationFactory.new(migration_dir) }

  before do
    FileUtils.mkdir_p migration_dir
  end

  after do
    FileUtils.rm_rf migration_dir
  end

  describe '#sync_migrations' do
    it 'should do nothing if migrations are the same' do
      allow(RestClient).to receive(:get).with('https://crowd-translate.herokuapp.com/migrations.json') {
        double(body: ['one', 'two'].to_json)
      }

      File.write(File.join(migration_dir, 'one.rb'), 'foo')
      File.write(File.join(migration_dir, 'two.rb'), 'foo')

      client.sync_migrations(migrations)
    end

    it 'should add missing migrations' do
      allow(RestClient).to receive(:get).with('https://crowd-translate.herokuapp.com/migrations.json') {
        double(body: ['one'].to_json)
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

      expect(RestClient).to receive(:put)
                                .with('https://crowd-translate.herokuapp.com/migrations/two.json',
                                      params: { ruby: contents }) {
                                  double(body: "OK")
                                }

      client.sync_migrations(migrations)
    end

    it "should blow up if the server has migrations we don't know about" do
      allow(RestClient).to receive(:get).with('https://crowd-translate.herokuapp.com/migrations.json') {
        double(body: ['one', 'two', 'four'].to_json)
      }

      File.write(File.join(migration_dir, 'one.rb'), 'foo')
      File.write(File.join(migration_dir, 'three.rb'), 'foo')

      expect { client.sync_migrations(migrations) }
          .to raise_error("You may not upload migrations to the server because it has migrations not found locally: two, four")
    end
  end
end
