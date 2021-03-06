# frozen_string_literal: true

# Open the I18n module to add our functions and overrides.
module I18n
  @translations = {}

  class << self
    attr_reader :translations

    # Clears the @translations variable. If not cleared the variable would continue to grow with new
    # translations on each request.
    def translations_reset
      @translations = {}
    end

    # Adds every lookup of a translation to a separate Hash.
    # This Hash will contain all translations used in the current session.
    # Watch out for gems like SimpleForm for they will look for a translation in multiple places
    # resulting in more translations being requested then are actually used.
    #
    # 'super' will abort itself if no translation was found. Therefore the key is added to the Hash
    # before the lookup takes place. This ensures we can translate untranslated keys.
    def translate(key, options = {})
      # Do not pass 'raise' or 'throw' since it will abort in super if no translation was found.
      # Do not pass 'object' since it will cause Redis to throw an error 'Cannot dump File'.
      # TODO: find out why this is. Maybe it tries to cache the object as part of the cache key.
      options.except!(:raise, :throw, :object)

      value = super

      current_locale = options[:locale] || locale
      @translations[current_locale] = {} unless @translations[current_locale]
      path = lookup_key(value, key, options)

      if value.is_a?(Hash)
        value.each do |sub_key, sub_value|
          lookup_key = [path, sub_key].join('.')
          @translations[current_locale][lookup_key] = {
            options: interpolations(options), value: sub_value
          }
        end
      elsif value.is_a?(Array)
        @translations[current_locale][path] = {
          options: interpolations(options), value: value.to_yaml
        }
      else
        @translations[current_locale][path] = {
          options: interpolations(options), value: return_value(value)
        }
      end

      value
    end
    alias t translate

    private

    # @param options [Hash] with the options as passed to the translate function.
    # @return [Hash] with the options that are relevant for the translator.
    def interpolations(options)
      options.except(*I18n::RESERVED_KEYS, :locale)
    end

    # @params translations [Array] that holds all of the translatable items.
    # @return [Array] with all unique translatable keys.
    def lookup_keys(translations)
      translations.map { |_locale, translation| translation.keys }.flatten.uniq
    end

    # @return [String] that is the full path to a translation.
    def lookup_key(value, key, options = {})
      scope(options).push(key).compact.join('.')
    end

    # @return [Array] with the scope of the translation.
    def scope(options)
      case options[:scope]
      when nil
        []
      when Array
        options[:scope]
      when String, Symbol
        [options[:scope].to_s]
      end
    end

    def return_value(value)
      return if value.is_a?(String) && value[/\Atranslation missing: /]
      value
    end
  end
end
