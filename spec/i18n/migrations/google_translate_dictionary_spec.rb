require 'spec_helper'
require 'i18n/migrations/google_translate_dictionary'

describe I18n::Migrations::GoogleTranslateDictionary do
  let(:do_not_translate) { {
      'Transparent Classroom' => ['Aula Transparente', 'Invisible Cuarto']
  } }
  let(:dict) {
    I18n::Migrations::GoogleTranslateDictionary.new(from_locale: 'en',
                                                    to_locale: 'es',
                                                    key: nil,
                                                    do_not_translate: do_not_translate)
  }

  describe '#fix' do
    it 'should let most strings pass through' do
      expect(dict.fix('hello mom', 'hola mama')).to eq(['hola mama', []])
      expect(dict.fix('hello, mom!', '¡hola, mama!')).to eq(['¡hola, mama!', []])
    end

    it 'should fix errors around %{}s' do
      expect(dict.fix('hello, %{mom}!', '¡hola, %{mama}!')).to eq(['¡hola, %{mom}!', []])
      expect(dict.fix('hello, %{mom}!', '¡hola, % {mom}!')).to eq(['¡hola, %{mom}!', []])
      expect(dict.fix('hello, %{mom}!', '¡hola,% {mom}!')).to eq(['¡hola, %{mom}!', []])
      expect(dict.fix('hello, %{mom}!', '¡hola,%{mom}!')).to eq(['¡hola, %{mom}!', []])

      # leave alone
      expect(dict.fix('%{person}s %{thing}', '%{thing} de %{person}')).to eq(['%{thing} de %{person}', []])
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

    describe 'escaped html' do
      it 'should be fine with escaped stuff in html' do
        expect(dict.fix('say &#39;observe&#39;', 'di &#39;observar&#39;', key: 'foo_html'))
            .to eq(['di &#39;observar&#39;', []])
      end

      it 'should complain if there are html escaped stuff that was not in original' do
        expect(dict.fix('say \'observe\'', 'di &#39;observar&#39;', key: 'foo_html'))
            .to eq(["di 'observar'", []])
      end

      it 'should complain if there are html escaped stuff in not html' do
        expect(dict.fix('say &#39;observe&#39;', 'di &#39;observar&#39;', key: 'foo'))
            .to eq(["di 'observar'", []])
      end

      it 'should know how to replace all sorts of char escapes' do
        expect(dict.fix('foo', 'foo &amp; &quot; &lt; &gt; &nbsp; &#39;', key: 'foo'))
            .to eq(["foo & \" < >   '", []])
      end

      it 'should have error if it does not know an escape' do
        expect(dict.fix('foo', 'foo &what;', key: 'foo'))
            .to eq(['foo &what;', ["Don't know how to clean up &what;"]])
      end
    end
  end
end
