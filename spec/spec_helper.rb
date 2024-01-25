$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)
require 'active_support'

def stringify(hash)
  JSON.parse(hash.to_json)
end

class File
  def self.write(name, text)
    File.open(name, 'w') do |f|
      f << text
    end
  end

  def self.write_yaml(name, yaml)
    File.open(name, 'w') do |f|
      f << stringify(yaml).to_yaml
    end
  end

  def self.read_yaml(name)
    YAML.load(File.read(name))
  end
end

class FakeDictionary
  def lookup(term, key: nil)
    ["translated #{term}", []]
  end
end

class FakeSheet
  attr_reader :data

  def initialize(data = [['key', 'en', 'es', 'notes']])
    @data = data
  end

  def num_rows
    @data.length
  end

  def [](row, col)
    @data[row-1][col-1]
  end

  def []=(row, col, value)
    (@data[row-1] ||= [])[col-1] = value
  end

  def synchronize
    # nothin'
  end
end

ENV['CROWD_TRANSLATE_API_TOKEN'] ||= 'test-token'
