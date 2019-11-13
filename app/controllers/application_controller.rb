class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
  include SessionsHelper
  include AttendancesHelper
  
  # 曜日を格納 $はグローバル変数（どこでも壁を乗り越え使用可）
  # 下記の%w{日 月 火 水 木 金 土}はRubyのリテラル表記と呼ばれるもの
  # ["日", "月", "火", "水", "木", "金", "土"]の配列と同じように使用可
  $days_of_the_week = %w{日 月 火 水 木 金 土}
  
  # ページ出力前に1ヵ月分のデータの存在を確認・セット
  def set_one_month
    @first_day = params[:date].nil? ?
                     Date.current.beginning_of_month : params[:date].to_date
    @last_day = @first_day.end_of_month
    one_month = [*@first_day..@last_day]

    @attendances = @user.attendances.where(worked_on: @first_day..@last_day).order(:worked_on)

    unless one_month.count == @attendances.count
      ActiveRecord::Base.transaction do
        one_month.each { |day| @user.attendances.create!(worked_on: day) }
      end
      @attendances = @user.attendances.where(worked_on: @first_day..@last_day).order(:worked_on)
    end

  rescue ActiveRecord::RecordInvalid
    flash[:danger] = "ページ情報の取得に失敗しました、再アクセスしてください。"
    redirect_to root_url
  end


end
