class UsersController < ApplicationController
  before_action :require_authentication

  def edit
    @user = current_user
  end

  def update
    @user = current_user
    if @user.update(user_params)
      redirect_to edit_settings_path, notice: t("flash.settings_saved")
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(
      :display_name,
      :daily_calorie_target, :protein_target, :carbs_target, :fat_target, :fiber_target,
      :timezone, :unit_preference, :country, :language
    )
  end
end
