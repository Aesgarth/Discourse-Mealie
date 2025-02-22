module MealieDiscourse
  class MealieController < ::ApplicationController
    requires_plugin 'discourse_mealie'

    skip_before_action :check_xhr
    before_action :verify_mealie_request, only: [:webhook]

    # Webhook listener for Mealie notifications
    def webhook
      payload = JSON.parse(request.body.read) rescue nil

      if payload && payload["recipe_id"]
        topic = Topic.find_by_custom_field("mealie_recipe_id", payload["recipe_id"])
        if topic
          # Notify users that the recipe has been updated in Mealie
          topic.posts.create!(
            user_id: Discourse.system_user.id,
            raw: "This recipe has been updated in Mealie!"
          )
        end
      end

      render json: { status: "success" }
    end

    # Public test fetch recipe endpoint
    def test_fetch_recipe
      recipe_name = params[:recipe] || "Test Recipe"
      Rails.logger.info("Manual API Test: Fetching #{recipe_name}")

      recipe_data = MealieDiscourse.fetch_mealie_recipe(recipe_name)

      if recipe_data
        render json: { success: true, data: recipe_data }
      else
        render json: { success: false, error: "Recipe not found or API failed" }, status: 400
      end
    end

    private

    # Verify webhook requests using API key
    def verify_mealie_request
      api_key = SiteSetting.mealie_api_key
      halt(403) unless request.headers["Authorization"] == "Bearer #{api_key}"
    end
  end
end
