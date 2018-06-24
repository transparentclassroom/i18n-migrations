$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)

class File
  def self.write(name, text)
    File.open(name, 'w') do |f|
      f << text
    end
  end
end

class FakeDictionary
  def lookup(term)
    ["translated #{term}", '[autotranslated]']
  end
end
