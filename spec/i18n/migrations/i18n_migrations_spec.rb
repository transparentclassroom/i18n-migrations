require 'spec_helper'
require 'i18n/migrations/version'

describe I18n::Migrations do
  it 'has a version number' do
    expect(I18n::Migrations::VERSION).not_to be nil
  end
end
