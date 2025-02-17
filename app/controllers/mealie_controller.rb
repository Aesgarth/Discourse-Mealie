module MealieDiscourse
  class MealieController < ::Admin::AdminController
    requires_plugin 'discourse_mealie'

    skip_before_action :check_xhr
    before_action :ensure_logged_in, except: [:webhook]
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

    # Test connection to Mealie API
    def test_connection
      base_url = SiteSetting.mealie_url
      api_key = SiteSetting.mealie_api_key

      if base_url.blank? || api_key.blank?
        render_json_error("Mealie URL or API key is missing.")
        return
      end

      response = Excon.get(
        "#{base_url}/api/recipes",
        headers: { "Authorization" => "Bearer #{api_key}" }
      )

      if response.status == 200
        render json: success_json.merge(message: "Connection successful!")
      else
        render_json_error("Failed to connect: HTTP #{response.status}")
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
