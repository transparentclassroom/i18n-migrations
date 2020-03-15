require 'spec_helper'
require 'i18n/migrations/metadata'

describe Metadata do
  let(:metadata) { Metadata.new }
  it 'should set data for a thing whether or not it exists' do
    metadata['foo.bar'].errors = ['sam']
    metadata['foo.bar'].notes = 'something'
    metadata['foo.bar'].autotranslated = true

    expect(metadata['foo.bar'].errors).to eq ['sam']
    expect(metadata['foo.bar'].notes).to eq 'something'
    expect(metadata['foo.bar'].autotranslated).to eq true

    expect(metadata.to_h).to eq('foo.bar' => { 'errors' => ['sam'],
                                               'notes' => 'something',
                                               'autotranslated' => true })

    metadata['foo.bar'].notes = 'something else'
    expect(metadata['foo.bar'].notes).to eq 'something else'

    expect(metadata.to_h).to eq('foo.bar' => { 'errors' => ['sam'],
                                               'notes' => 'something else',
                                               'autotranslated' => true })
  end

  it 'should delete data when given empty data' do
    hash = { 'foo.bar' => { 'errors' => ['sam'],
                            'notes' => 'something',
                            'autotranslated' => true } }
    metadata = Metadata.new(hash)
    expect(metadata.to_h).to eq(hash)

    metadata['foo.bar'].errors = []

    expect(metadata.to_h).to eq('foo.bar' => { 'notes' => 'something',
                                               'autotranslated' => true })
    expect(metadata['foo.bar'].errors).to eq []

    metadata['foo.bar'].notes = '  '
    expect(metadata.to_h).to eq('foo.bar' => { 'autotranslated' => true })
    expect(metadata['foo.bar'].notes).to eq '  '

    metadata['foo.bar'].autotranslated = false
    expect(metadata.to_h).to eq({})
    expect(metadata['foo.bar'].autotranslated).to eq(false)

    metadata = Metadata.new(metadata.to_h)
    expect(metadata['foo.bar'].errors).to eq []
    expect(metadata['foo.bar'].notes).to eq nil
    expect(metadata['foo.bar'].autotranslated).to eq(false)
  end

  it 'should be possible to delete data' do
    hash = { 'foo.bar' => { 'notes' => 'something' },
             'foo' => { 'autotranslated' => true } }
    metadata = Metadata.new(hash)
    metadata.delete('foo.bar')

    expect(metadata.to_h).to eq('foo' => { 'autotranslated' => true })
  end

  it 'should be possible to move data' do
    hash = { 'foo.bar' => { 'notes' => 'something' },
             'foo' => { 'autotranslated' => true } }
    metadata = Metadata.new(hash)
    metadata['bar'] = metadata['foo']

    # they should not be connected
    metadata['foo'].notes = 'wham'

    expect(metadata.to_h).to eq({ 'foo.bar' => { 'notes' => 'something' },
                                  'bar' => { 'autotranslated' => true },
                                  'foo' => { 'notes' => 'wham', 'autotranslated' => true } })

    # complete the move
    metadata.delete('foo')
    expect(metadata.to_h).to eq({ 'foo.bar' => { 'notes' => 'something' },
                                  'bar' => { 'autotranslated' => true } })
  end
end
