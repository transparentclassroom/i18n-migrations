# this class stores metadata about terms in a locale
# specifically things like errors, notes, autotranslated
# it acts kind of like a hash where you give it a key and it returns a metadatum object
class Metadata
  def initialize(hash = {})
    @hash = hash
  end

  def [](key)
    if @hash[key].is_a?(Metadatum)
      @hash[key]
    else
      @hash[key] = Metadatum.new(@hash[key])
    end
  end

  def []=(key, value)
    raise("you may only assign a metadatum") unless value.is_a?(Metadatum)
    @hash[key] = value.dup
  end

  def delete(key)
    metadatum = self[key]
    @hash.delete(key)
    metadatum
  end

  def to_h
    compacted_hash = {}
    @hash.keys.sort.each do |key|
      value = @hash[key].to_h
      compacted_hash[key] = value if value.present?
    end
    compacted_hash
  end

  def to_yaml
    to_h.to_yaml
  end

  class Metadatum
    attr_accessor :errors, :notes, :autotranslated

    def initialize(hash)
      safe_hash = hash || {}
      @errors = safe_hash['errors'] || []
      @notes = safe_hash['notes']
      @autotranslated = !!safe_hash['autotranslated']
    end

    def to_h
      hash = {}
      hash['errors'] = @errors unless @errors.empty?
      hash['notes'] = @notes unless @notes.blank?
      hash['autotranslated'] = @autotranslated if autotranslated
      hash
    end
  end
end
