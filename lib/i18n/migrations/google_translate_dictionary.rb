require 'rest-client'

module I18n
  module Migrations
    class GoogleTranslateDictionary
      def initialize(key, from_locale, to_locale)
        @key, @from_locale, @to_locale = key, from_locale, to_locale
      end

      def lookup(term)
        return term if @from_locale == @to_locale

        response = RestClient.get 'https://www.googleapis.com/language/translate/v2', {
            accept: :json,
            params: { key: @key, source: @from_locale, target: @to_locale, q: term }
        }
        JSON.parse(response.body)['data']['translations'].first['translatedText']
      end

      # we should validate translations based on reasonable rules
    end
  end
end
