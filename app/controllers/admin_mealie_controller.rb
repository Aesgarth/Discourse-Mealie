require_dependency "application_controller"

module MealieDiscourse
  class AdminMealieController < ::Admin::AdminController
    requires_plugin 'discourse_mealie'

    before_action :ensure_logged_in

    # Test connection to Mealie API (Admin Only)
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
  end
end
