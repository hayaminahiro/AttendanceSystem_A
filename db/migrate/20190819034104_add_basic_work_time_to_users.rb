class AddBasicWorkTimeToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :basic_work_time, :datetime, default: Time.zone.parse('2019-07-01 07:30:00')
  end
end
