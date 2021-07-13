class PagesController < ApplicationController
  def home
    authenticate_user!
    @user = current_user
  end
end
