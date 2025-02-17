# name: Discourse-Mealie
# about: A plugin to integrate Mealie recipes into Discourse posts
# version: 0.1
# authors: Aesgarth
# url: https://github.com/Aesgarth/Discourse-Mealie

enabled_site_setting :discourse_mealie_enabled

after_initialize do
  module ::MealieDiscourse
    class Engine < ::Rails::Engine
      engine_name "mealie_discourse"
      isolate_namespace MealieDiscourse
    end

    class << self
      def fetch_mealie_recipe(recipe_name)
        base_url = SiteSetting.mealie_url
        api_key = SiteSetting.mealie_api_key

        return nil if base_url.blank? || api_key.blank?

        response = nil
        begin
          response = Excon.get(
            "#{base_url}/api/recipes?search=#{CGI.escape(recipe_name)}",
            headers: {
              "Accept" => "application/json",
              "Authorization" => "Bearer #{api_key}"
            }
          )
        rescue Excon::Error => e
          Rails.logger.error("Mealie API request failed: #{e.message}")
          return nil
        end

        Rails.logger.info("Mealie API Response Code: #{response.status}")
        Rails.logger.info("Mealie API Response Body: #{response.body}")

        return nil unless response.status == 200

        begin
          recipes = JSON.parse(response.body)
        rescue JSON::ParserError => e
          Rails.logger.error("Failed to parse Mealie API response: #{e.message}")
          Rails.logger.error("Response body: #{response.body}")
          return nil
        end

        return nil if recipes.empty? || !recipes.is_a?(Array)

        recipes.first
      end
    end
  end

  require_dependency 'topic'

  # Register custom field for storing Mealie recipe IDs
  Topic.register_custom_field_type('mealie_recipe_id', :string)

  # Automatically associate a topic with a Mealie recipe when created
  DiscourseEvent.on(:topic_created) do |topic|
    if SiteSetting.discourse_mealie_enabled && topic.category.name == "Recipes"
      recipe_data = MealieDiscourse.fetch_mealie_recipe(topic.title)

      if recipe_data
        topic.custom_fields["mealie_recipe_id"] = recipe_data["id"]
        topic.save_custom_fields
      end
    end
  end

  # Define routes for webhook listener and test connection
  MealieDiscourse::Engine.routes.draw do
    post "/webhook" => "mealie#webhook"
    post "/test_connection" => "mealie#test_connection"
  end

  Discourse::Application.routes.append do
    mount ::MealieDiscourse::Engine, at: "/mealie"
  end
end
