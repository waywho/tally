class OnboardingController < ApplicationController
  skip_before_action :ensure_onboarded
  before_action :require_authentication
  before_action :redirect_if_onboarded

  STEPS = %w[step1 step2 step3].freeze
  NEXT_STEP = { "step1" => "step2", "step2" => "step3" }.freeze
  PREV_STEP = { "step2" => "step1", "step3" => "step2" }.freeze

  layout "authentication"

  def show
    @user = current_user
    @step = STEPS.include?(params[:step]) ? params[:step] : STEPS.first
    render @step
  end

  def update
    @step = params[:step]

    case @step
    when "step1"
      current_user.update!(display_name: params[:user][:display_name])
      redirect_to onboarding_step_path(NEXT_STEP[@step])
    when "step2"
      current_user.update!(daily_calorie_target: params[:user][:daily_calorie_target])
      redirect_to onboarding_step_path(NEXT_STEP[@step])
    when "step3"
      current_user.update!(
        protein_target: params[:user][:protein_target],
        carbs_target: params[:user][:carbs_target],
        fat_target: params[:user][:fat_target],
        fiber_target: params[:user][:fiber_target],
        onboarded_at: Time.current
      )
      redirect_to root_path, notice: t("flash.onboarding_complete")
    end
  end

  def skip
    current_user.update!(onboarded_at: Time.current)
    redirect_to root_path
  end

  private

  def redirect_if_onboarded
    redirect_to root_path if current_user&.onboarded_at.present?
  end
end
