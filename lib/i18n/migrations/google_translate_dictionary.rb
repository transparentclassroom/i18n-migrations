require 'rest-client'

module I18n
  module Migrations
    class GoogleTranslateDictionary
      def initialize(from_locale:, to_locale:, key:, do_not_translate:)
        @from_locale, @to_locale, @key, @do_not_translate = from_locale, to_locale, key, do_not_translate
      end

      # key is provided so we can figure out if this is text or html
      # returns [translated term, notes]
      def lookup(term, key: nil)
        return [term, ''] if @from_locale == @to_locale

        response = RestClient.get 'https://www.googleapis.com/language/translate/v2', {
            accept: :json,
            params: { key: @key,
                      source: @from_locale,
                      target: @to_locale,
                      format: format(key),
                      q: term }
        }
        translated_term = JSON.parse(response.body)['data']['translations'].first['translatedText']
        translated_term, errors = fix(term, translated_term, key: key)
        unless errors.empty?
          STDERR.puts "'#{term}' => '#{translated_term}'\n#{errors.join(', ').red}"
        end
        [translated_term, (errors.map { |e| "[error: #{e}]" } + ['[autotranslated]']).join("\n")]
      end

      VARIABLE_STRING_REGEX = /%\{[^\}]+\}/
      HTML_ESCAPE_REGEX = /&[A-Za-z#0-9]+;/
      HTML_ESCAPES = {
          '&#39;' => "'",
          '&amp;' => '&',
          '&lt;' => '<',
          '&gt;' => '>',
          '&quot;' => '"',
          '&nbsp;' => ' ',
          '&#8594;' => '→',
          '&#8592;' => '←',
          '&hellip;' => '…',
      }
      # returns updated after term, errors
      def fix(before, after, key: nil)
        is_html = format(key) == :html
        errors = []

        # do not translate
        @do_not_translate.each do |term, bad_translations|
          if before.include?(term) && !after.include?(term)
            if (translation = find_included_translation(after, bad_translations))
              after = after.gsub(translation, term)
            else
              errors << "missing #{term}"
            end
          end
        end

        # common mistakes
        after = after
                    .gsub('% {', '%{')
                    .gsub('％{', '%{')

        # match up variables, should have same variable in before and after
        before_variables = before.scan(VARIABLE_STRING_REGEX)
        after_variables = after.scan(VARIABLE_STRING_REGEX)

        if before_variables.sort == after_variables.sort
          # we have all of our variables, let's make sure spacing before them is correct

          unless no_spaces?
            before_variables.each do |variable|
              before_index = before =~ /(.?)#{variable}/
              before_leading = $1
              after_index = after =~ /(.?)#{variable}/
              after_leading = $1

              if before_index && after_index &&
                  before_leading == ' ' && after_leading != ' ' &&
                  after_index != 0
                after = after.sub(variable, " #{variable}")
              end
            end
          end

        else
          # we don't have all the variables we should have
          missing = before_variables - after_variables
          extra = after_variables - before_variables

          # we'll try to fix if it looks easy
          if missing.length == 1 && extra.length == 1
            after = after.sub(extra.first, missing.first)
          else
            errors << "missing #{missing.join(', ')}" if missing.length > 0
            errors << "extra #{extra.join(', ')}" if extra.length > 0
          end
        end

        # fix html escapes
        escapes = after.scan(HTML_ESCAPE_REGEX)
        if escapes.present?
          before_escapes = before.scan(HTML_ESCAPE_REGEX)
          escapes.each do |escape|
            if is_html && before_escapes.include?(escape)
              # leave it
            else
              if (replace_with = HTML_ESCAPES[escape])
                after = after.sub(escape, replace_with)
              else
                errors << "Don't know how to clean up #{escape}"
              end
            end
          end
        end


        [after, errors]
      end

      private

      def no_spaces?
        @to_locale == 'zh'
      end

      def format(key)
        key&.index('_html') ? :html : :text
      end

      def find_included_translation(after, bad_translations)
        bad_translations.each do |translation|
          return translation if after.include?(translation)
        end
        nil
      end
    end
  end
end
