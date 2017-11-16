module I18n
  module Migrations
    class Migration
      # locale = en | es | ...
      # data = all keys -> all translations in this locale
      # notes = some keys -> notes about the translation in this locale
      # dictionary = call dictionary.lookup(term) to get localized version of a term
      # direction = :up | :down (up when migrating, down when rolling back)
      def initialize(locale, data, notes, dictionary, direction = :up, verbose = false)
        @locale, @data, @notes, @dictionary, @direction, @verbose = locale, data, notes, dictionary, direction, verbose
      end

      # Overrides can be provided, e.g. { es: 'El foo de la barro' }
      def add(key, term, overrides = {})
        if @direction == :up
          info "adding #{key}"
          _add key, term, overrides
        else
          info "unadding #{key}"
          _rm key
        end
      end

      def mv(old_key, new_key)
        if @direction == :up
          info "moving #{old_key} => #{new_key}"
          _mv old_key, new_key
        else
          info "moving back #{new_key} => #{old_key}"
          _mv new_key, old_key
        end
      end

      # Overrides can be provided, e.g. { es: 'El foo de la barro' }
      def rm(key, old_term, overrides = {})
        if @direction == :up
          info "removing #{key}"
          _rm key
        else
          info "unremoving #{key}"
          _add key, old_term, overrides
        end
      end

      # Overrides can be provided, e.g. { es: 'El foo de la barro' }
      def update(key, new_term, old_term, overrides = {})
        if @direction == :up
          info "updating #{key}"
          _update key, new_term, overrides
        else
          info "unupdating #{key}"
          _update key, old_term, {}
        end
      end

      private

      def _add(key, term, overrides)
        assert_does_not_exist! key
        @data[key] = overrides[@locale.to_sym] || @dictionary.lookup(term)
        @notes[key] = "[autotranslated]"
      end

      def _mv(from, to)
        assert_exists! from
        assert_does_not_exist! to
        @data[to] = @data.delete(from)
      end

      def _update(key, term, overrides)
        assert_exists! key
        @data[key] = overrides[@locale.to_sym] || @dictionary.lookup(term)
        @notes[key] = "[autotranslated]"
      end

      def _rm(key)
        assert_exists! key
        @data.delete(key)
        @notes.delete(key)
      end

      def info(message)
        puts message if @verbose
      end

      def assert_exists!(key)
        raise "#{key} doesn't exist in #{@locale}" unless @data.has_key?(key)
      end

      def assert_does_not_exist!(key)
        raise "#{key} already exists in #{@locale}" if @data.has_key?(key)
      end
    end
  end
end
