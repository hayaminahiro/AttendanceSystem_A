class AddSuperiorToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :superior, :boolean, default: false
  end
end
