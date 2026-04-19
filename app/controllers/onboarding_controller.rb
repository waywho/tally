class OnboardingController < ApplicationController
  skip_before_action :ensure_onboarded
  before_action :require_authentication
  before_action :redirect_if_onboarded

  layout "authentication"

  def step1
    @user = current_user
  end

  def step2
    @user = current_user
  end

  def step3
    @user = current_user
  end

  def update_step1
    current_user.update!(display_name: params[:user][:display_name])
    redirect_to step2_onboarding_path
  end

  def update_step2
    current_user.update!(daily_calorie_target: params[:user][:daily_calorie_target])
    redirect_to step3_onboarding_path
  end

  def finish
    current_user.update!(
      protein_target: params[:user][:protein_target],
      carbs_target: params[:user][:carbs_target],
      fat_target: params[:user][:fat_target],
      fiber_target: params[:user][:fiber_target],
      onboarded_at: Time.current
    )
    redirect_to root_path, notice: t("flash.onboarding_complete")
  end

  def skip
    current_user.update!(onboarded_at: Time.current)
    redirect_to root_path
  end

  private

  def redirect_if_onboarded
    redirect_to root_path if current_user.onboarded_at.present?
  end
end
