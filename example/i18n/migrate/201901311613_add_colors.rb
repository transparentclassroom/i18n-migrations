require 'i18n-migrations'

class AddColors201901311613 < I18n::Migrations::Migration
  def change
    add'colors.red', 'red'
    add'colors.blue', 'blue'
    add'colors.green', 'green'
  end
end
