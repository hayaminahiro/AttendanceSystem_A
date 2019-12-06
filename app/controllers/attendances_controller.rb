class AttendancesController < ApplicationController
  before_action :set_user, only: [:edit, :update, :update_month, :month_approval, :attendance_approval, :update_approval, :update_applicability, :attendance_log]
  before_action :url_confirmation_attendances_edit_page, only: :edit
  
  def create
    # ルーティングを確認すると、/users/:user_id/attendances → paramsでuser_idを受け取る
    @user = User.find(params[:user_id])
    # @userモデルに紐付くattendanceモデルから、find_byで日付カラムがDate.todayを探して@attendanceに代入
    # @attendanceは、つまり今日を表す
    @attendance = @user.attendances.find_by(worked_on: Date.today)
    # もし今日（@attendance）がnilだったら
    if @attendance.started_at.nil?
      # current_time → 現在時刻を表す / attendance_helper.rb参照
      # @attendanceのstarted_atカラムを現在時刻として更新
      @attendance.update_attributes(started_at: current_time)
      flash[:info] = "おはようございます。"
      # started_atに値が存在していて、finished_atがnilだった場合
    elsif @attendance.finished_at.nil?
      # finished_atカラムを現在時刻として@attendanceを更新
      @attendance.update_attributes(finished_at: current_time)
      flash[:info] = "お疲れ様でした。"
    else
      flash[:danger] = "トラブルがあり登録できませんでした。"
    end
    redirect_to @user
  end

  # 勤怠編集画面
  def edit
    @first_day = first_day(params[:date])
    @last_day = @first_day.end_of_month
    @dates = user_attendances_month_date
    # 自分以外の上長
    @users = User.where(admin: false).applied_superior(superior_id: current_user.id)
  end

  # 勤怠情報update
  def update
    if attendances_invalid?
      attendances_params.each do |id, item|
        if attendance_superior_present?(item[:superior_id], item[:change_started], item[:change_finished] )
          attendance = Attendance.find(id)
          attendance.update_attributes(item)
        end
      end
      flash[:success] = "勤怠情報を申請しました。申請できていない場合は申請先上長が選択されているか確認して下さい。"
      redirect_to user_url(@user, params:{first_day: params[:date]})
    else
      flash[:danger] = "不正な時間入力がありました。再入力して下さい。出社時間と退社時間はセットで入力されていますか？"
      redirect_to edit_attendances_path(@user, params[:date])
    end
  end

  # 勤怠変更申請表示モーダル
  def attendance_approval
    # @users = User.attendance_change_superior(superior_id: current_user.id)
    @users = User.applied_superior(superior_id: current_user.id)
    @first_day = first_day(params[:first_day]) # attendance_helper.rb参照
    @last_day = @first_day.end_of_month # end_od_monthは当月の終日を表す
    (@first_day..@last_day).each do |day| # 月の初日から終日までを表す
      unless @user.attendances.any? {|attendance| attendance.worked_on == day}
        record = @user.attendances.build(worked_on: day)
        record.save
      end
    end
    @dates = user_attendances_month_date # 1ヶ月の情報を表す・・・attendances_helper.rb参照
  end

  # 勤怠変更申請の変更送信ボタンのアクション
  def update_applicability
    #「変更を送信する」ボタン：選択肢の確認(承認または否認、かつチェックON ➡︎ true)
    update_applicability_params.each do |id, item|
      if attendance_change_invalid?(item[:attendance_approval], item[:attendance_check]) # 処理がtrueになったら更新
        # eachで回ってきた該当するidのAttendanceオブジェクトをattendanceに代入
        attendance = Attendance.find(id)
        attendance.update_attributes(item)
      end
    end
    flash[:success] = "勤怠変更申請しました。"
    redirect_to user_path(@user)
  end

  # 申請ボタンから送信された情報（上長のidと申請月）を受け取って更新
  def update_month
    if superior_present? # params[:user][:apply_month] = @first_day /申請先上長が選択されているか確認
      update_month_params.each do |id, item| # idはAttendanceモデルオブジェクトのid、itemは各カラムの値が入った更新するための情報
        # 更新するべきAttendanceモデルオブジェクトを探してattendanceに代入
        attendance = Attendance.find(id)
        attendance.update_attributes(item)
      end
      flash[:success] = "所属長申請しました。"
      redirect_to @user
    end
  end

  # 1ヶ月分勤怠申請/モーダル表示
  def month_approval
    @users = User.applied_superior(superior_id: current_user.id)
    @first_day = first_day(params[:first_day]) # attendance_helper.rb参照
    @last_day = @first_day.end_of_month # end_od_monthは当月の終日を表す
    (@first_day..@last_day).each do |day| # 月の初日から終日までを表す
      unless @user.attendances.any? {|attendance| attendance.worked_on == day}
        record = @user.attendances.build(worked_on: day)
        record.save
      end
    end
    @dates = user_attendances_month_date # 1ヶ月の情報を表す・・・attendances_helper.rb参照
    @attendance = User.all.includes(:attendances)
  end

  # 申請の承認可否の更新
  def update_approval
    # update_approval_paramsをeachで回す
    update_approval_params.each do |id, item|
      # もしapply_and_checkbox_invalid? ➡︎ 引数が(item[:month_approval], item[:month_check])の場合
      # each分の中にヘルパーメソッドを記入する事で毎回処理をチェックできる
      if apply_and_checkbox_invalid?(item[:month_approval], item[:month_check]) # 処理がtrueになったら更新
        # eachで回ってきた該当するidのAttendanceオブジェクトをattendanceに代入
        attendance = Attendance.find(id)
        attendance.update_attributes(item)
      end
    end
    flash[:success] = "1ヶ月分の勤怠申請しました。申請できていない場合は必要項目が選択されているか確認して下さい。"
    redirect_to user_path(@user)
  end

  def attendance_log
    @first_day = first_day(params[:date])
    @last_day = @first_day.end_of_month
    @dates = user_attendances_month_date
    # 自分以外の上長
    # @users = User.applied_superior(superior_id: current_user.id)
    @users = User.all
    # 申請上長の名前
    @superior_a = User.find_by(id: 2).name #上長A
    @superior_b = User.find_by(id: 3).name #上長A
    @superior_c = User.find_by(id: 4).name #上長A
  end

  def update_log
    update_log_params.each do |id, item| # idはAttendanceモデルオブジェクトのid、itemは各カラムの値が入った更新するための情報
      # 更新するべきAttendanceモデルオブジェクトを探してattendanceに代入
      attendance = Attendance.find(id)
      attendance.update_attributes(item)
    end
    flash[:success] = "テスト"
    redirect_to @user
  end

  def month_attendances_confirmation
    # 月の情報
    # @user = User.find(params[:id])
    # @attendances = Attendance.all
    # # (params[:day])で受け取ったデータを日付に変換し@dayに格納
    # @day = Date.parse(params[:day])
    # @attendance = @user.attendances.find_by(worked_on: @day)
  end

  def month_attendances_request_path
  end
  
  private
    def attendances_params
      # :attendancesがキーのハッシュの中にネストされたidと各カラムの値があるハッシュ
      # {"1" => {"started_at"=>"10:00", "finished_at"=>"18:00", "note"=>"シフトA"}
      params.permit(attendances: [:change_started, :change_finished, :note, :tomorrow_check, :superior_id,
                                  :attendance_approval, :attendance_check, :apply_month])[:attendances]
    end

    # 勤怠変更申請モーダル内カラム
    def update_applicability_params
      params.permit(attendances: [:attendance_approval, :attendance_check])[:attendances]
    end

    # 申請した上長idと申請月
    def update_month_params
      params.permit(attendances: [:superior_id, :apply_month, :month_approval, :month_check])[:attendances]
    end

    # 申請の承認可否の更新
    def update_approval_params
      params.permit(attendances: [:month_approval, :month_check])[:attendances]
    end

    # beforeアクション

    def set_user
      @user = User.find(params[:id])
    end
    
    def url_confirmation_attendances_edit_page
      @user = User.find(params[:id])
      @attendance = Attendance.find_by(params[:user_id])
      if not current_user.admin?
        unless @user.id == current_user.id
          flash[:danger] = "自分以外のユーザー情報の閲覧・編集はできません。"
          redirect_to root_url
        end
      end
    end
end
