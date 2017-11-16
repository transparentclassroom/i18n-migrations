require 'spec_helper'

describe I18n::Migrations do
  it 'has a version number' do
    expect(I18n::Migrations::VERSION).not_to be nil
  end

  it 'does something useful' do
    expect(false).to eq(true)
  end
end
