# frozen_string_literal: true

module MealieIntegration
  class MealieController < ::ApplicationController
    requires_plugin 'Discourse-Mealie'
    skip_before_action :verify_authenticity_token, only: [:webhook]
    
    def index
      render json: { status: 'ok' }
    end
    
    def webhook
      # Here we'll handle webhooks from Mealie when new recipes are created
      if SiteSetting.mealie_integration_enabled
        if verify_mealie_webhook(request)
          recipe_id = params[:recipe_id]
          Jobs.enqueue(:import_recipe, recipe_id: recipe_id)
          render json: { success: true, message: "Recipe import job enqueued" }
        else
          render json: { success: false, message: "Invalid webhook signature" }, status: 403
        end
      else
        render json: { success: false, message: "Plugin not enabled" }, status: 404
      end
    end
    
    def import
      # Manual import endpoint for admins
      if current_user&.admin?
        recipe_url = params[:recipe_url]
        recipe_id = extract_recipe_id(recipe_url)
        Jobs.enqueue(:import_recipe, recipe_id: recipe_id)
        render json: { success: true, message: "Recipe import job enqueued" }
      else
        render json: { success: false, message: "Admin access required" }, status: 403
      end
    end
    
    private
    
    def verify_mealie_webhook(request)
      # Implement webhook verification if Mealie supports it
      # For now, we'll just verify the API key
      api_key = request.headers['X-Mealie-Api-Key']
      api_key == SiteSetting.mealie_api_key
    end
    
    def extract_recipe_id(url)
      # Extract recipe ID from a Mealie URL
      # Example implementation, adjust as needed based on Mealie's URL structure
      url.split('/').last
    end
  end
end