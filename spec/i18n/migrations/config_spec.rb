require 'spec_helper'
require 'i18n/migrations/config'

describe I18n::Migrations::Config do
  FILE_NAME = 'example/test_config.yml'

  def write_config_file(txt)
    File.open(FILE_NAME, 'w') do |f|
      f << txt
    end
  end

  before do
    write_config_file('')
  end

  after do
    FileUtils.rm(FILE_NAME) if File.exist?(FILE_NAME)
  end

  def load_config
    I18n::Migrations::Config.new(FILE_NAME).read!
  end

  it 'should load a valid file' do
    write_config_file <<-YAML
migration_dir: i18n/migrate
locales_dir: config/locales
main_locale: en
other_locales:
  es:
    name: Spanish
    google_spreadsheet: https://docs.google.com/spreadsheets/d/1111/edit
    do_not_translate:
    - Aula Transparente
    - clase transparente
  de:
    name: German
    google_spreadsheet: https://docs.google.com/spreadsheets/d/333/edit
    do_not_translate:
    - Transparentes Klassenzimmerkonto

  ca:
    name: 'Catalan'
    google_spreadsheet: https://docs.google.com/spreadsheets/d/444/edit

google_service_account_key_path: i18n/google_drive_key.json

google_translate_api_key: 4444
    YAML

    c = load_config

    expect(c.migration_dir).to eq File.expand_path('example/i18n/migrate')
    expect(c.locales_dir).to eq File.expand_path('example/config/locales')

    expect(c.other_locales).to eq(%w(es de ca))
    expect(c.google_spreadsheet(:es)).to eq('https://docs.google.com/spreadsheets/d/1111/edit')
    expect(c.do_not_translate(:es)).to eq(['Aula Transparente', 'clase transparente'])

    expect(c.do_not_translate(:en)).to eq({})
    expect(c.do_not_translate(:ca)).to eq({})
  end
end
