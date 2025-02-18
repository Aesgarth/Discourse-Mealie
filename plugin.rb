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

        # Correct search query format
        search_url = "#{base_url}/api/recipes?queryFilter=#{CGI.escape(recipe_name)}"

        Rails.logger.info("Mealie API Request URL: #{search_url}")

        response = nil
        begin
          response = Excon.get(
            search_url,
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
          response_json = JSON.parse(response.body)
        rescue JSON::ParserError => e
          Rails.logger.error("Failed to parse Mealie API response: #{e.message}")
          Rails.logger.error("Response body: #{response.body}")
          return nil
        end

        return nil unless response_json["items"].is_a?(Array) && !response_json["items"].empty?

        first_recipe = response_json["items"].first
        recipe_slug = first_recipe["slug"]

        # If we got a valid slug, fetch the full recipe details
        return nil if recipe_slug.blank?

        recipe_url = "#{base_url}/api/recipes/#{recipe_slug}"
        Rails.logger.info("Fetching full recipe details from: #{recipe_url}")

        begin
          recipe_response = Excon.get(
            recipe_url,
            headers: {
              "Accept" => "application/json",
              "Authorization" => "Bearer #{api_key}"
            }
          )
        rescue Excon::Error => e
          Rails.logger.error("Failed to fetch full recipe details: #{e.message}")
          return nil
        end

        return nil unless recipe_response.status == 200

        begin
          full_recipe = JSON.parse(recipe_response.body)
        rescue JSON::ParserError => e
          Rails.logger.error("Failed to parse full recipe response: #{e.message}")
          Rails.logger.error("Response body: #{recipe_response.body}")
          return nil
        end

        full_recipe
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
