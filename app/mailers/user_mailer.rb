class UserMailer < ApplicationMailer
  def shot_uploaded
    @user = params[:user]
    @shot = params[:shot]

    mail to: @user.email, subject: "See your new #{@shot.profile_title} shot 👀"
  end

  def cancelled_premium
    @user = params[:user]
    mail to: @user.email, subject: "#{Instance.name}: subscription feedback"
  end

  def airtable_base_full
    @user = params[:user]
    mail to: @user.email, subject: "#{Instance.name}: your Airtable base is full"
  end

  def oidc_link
    @user = params[:user]
    @token = params[:token]
    mail to: @user.email, subject: "Finish connecting OpenID Connect to #{Instance.name}"
  end
end
