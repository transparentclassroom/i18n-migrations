module I18n
  module Migrations
    class Migration
      class Logger
        def initialize(verbose: false)
          @verbose = verbose
        end

        def info(message)
          puts message if @verbose
        end
      end

      # translations = facade over translations
      # locale = en | es | ...
      # dictionary = call dictionary.lookup(term) to get localized version of a term
      # direction = :up | :down (up when migrating, down when rolling back)
      def initialize(translations:, locale_code:, dictionary:, direction: :up, logger: Logger.new)
        @translations, @locale_code, @dictionary, @direction, @logger =
            translations, locale_code, dictionary, direction, logger
      end

      # Overrides can be provided, e.g. { es: 'El foo de la barro' }
      def add(key, term, overrides = {})
        if @direction == :up
          @logger.info "adding #{key}"
          _add key, term, overrides
        else
          @logger.info "unadding #{key}"
          _rm key
        end
      end

      def mv(old_key, new_key)
        if @direction == :up
          @logger.info "moving #{old_key} => #{new_key}"
          _mv old_key, new_key
        else
          @logger.info "moving back #{new_key} => #{old_key}"
          _mv new_key, old_key
        end
      end

      # Overrides can be provided, e.g. { es: 'El foo de la barro' }
      def rm(key, old_term, overrides = {})
        if @direction == :up
          @logger.info "removing #{key}"
          _rm key
        else
          @logger.info "unremoving #{key}"
          _add key, old_term, overrides
        end
      end

      # Overrides can be provided, e.g. { es: 'El foo de la barro' }
      def update(key, new_term, old_term, overrides = {})
        if @direction == :up
          @logger.info "updating #{key}"
          _update key, new_term, overrides
        else
          @logger.info "unupdating #{key}"
          _update key, old_term, {}
        end
      end

      private

      def _add(key, term, overrides)
        assert_does_not_exist! key
        assign_translation(key, term, overrides)
      end

      def _mv(from, to)
        assert_exists! from
        assert_does_not_exist! to
        @translations.move_term(from, to)
      end

      def _update(key, term, overrides)
        assert_exists! key
        assign_translation(key, term, overrides)
      end

      def _rm(key)
        assert_exists! key
        delete_translation key
      end

      def assert_exists!(key)
        raise "#{key} doesn't exist in #{@locale_code}" unless @translations.get_term(key)
      end

      def assert_does_not_exist!(key)
        raise "#{key} already exists in #{@locale_code}" if @translations.get_term(key)
      end

      # should delete key & return translation
      def delete_translation(key)
        @translations.delete_term(key)
      end

      def assign_translation(key, term, overrides)
        if overrides[@locale_code.to_sym]
          @translations.set_term(key, value: overrides[@locale_code.to_sym])
        else
          value, notes = @dictionary.lookup(term, key: key)
          @translations.set_term(key, value: value, notes: notes)
        end
      end
    end
  end
end
