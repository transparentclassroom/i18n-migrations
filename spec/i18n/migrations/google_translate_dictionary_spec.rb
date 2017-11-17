require 'spec_helper'
require 'i18n/migrations/google_translate_dictionary'

describe I18n::Migrations::GoogleTranslateDictionary do
  let(:do_not_translate) { {
      'Transparent Classroom' => ['Aula Transparente', 'Invisible Cuarto']
  } }
  let(:dict) { I18n::Migrations::GoogleTranslateDictionary.new('en', 'es', nil, do_not_translate) }

  describe '#fix' do
    it 'should let most strings pass through' do
      expect(dict.fix('hello mom', 'hola mama')).to eq(['hola mama', []])
      expect(dict.fix('hello, mom!', '¡hola, mama!')).to eq(['¡hola, mama!', []])
    end

    xit 'should fix errors around %{}s' do
      expect(dict.fix('hello, %{mom}!', '¡hola, %{mama}!')).to eq(['¡hola, %{mom}!', []])
      expect(dict.fix('hello, %{mom}!', '¡hola, % {mom}!')).to eq(['¡hola, %{mom}!', []])
      expect(dict.fix('hello, %{mom}!', '¡hola,% {mom}!')).to eq(['¡hola, %{mom}!', []])
      expect(dict.fix('hello, %{mom}!', '¡hola,%{mom}!')).to eq(['¡hola, %{mom}!', []])

      # leave this one alone
      expect(dict.fix('<a href="%{link}">%{text}</a>', '<a href="%{link}">%{text}</a>'))
          .to eq(['<a href="%{link}">%{text}</a>', []])
    end

    it 'should raise errors around mismatched %{}s' do
      expect(dict.fix('hello, %{mom} and %{dad}!', '¡hola, mom!')).to eq(['¡hola, mom!', ['missing %{mom}, %{dad}']])
    end

    it 'should fix DO_NOT_TRANSLATE strings if possible' do
      expect(dict.fix('Welcome to Transparent Classroom', 'Bienvenidos al Transparent Classroom'))
          .to eq(['Bienvenidos al Transparent Classroom', []])
      expect(dict.fix('Welcome to Transparent Classroom', 'Bienvenidos al Aula Transparente'))
          .to eq(['Bienvenidos al Transparent Classroom', []])
    end

    it 'should raise errors around mistranslating DO_NOT_TRANSLATE strings' do
      expect(dict.fix('Welcome to Transparent Classroom', 'Bienvenidos al Transparente'))
          .to eq(['Bienvenidos al Transparente', ['missing Transparent Classroom']])
    end
  end
end
