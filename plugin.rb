# name: Discourse-Mealie
# about: A plugin to integrate Mealie recipes into Discourse posts
# version: 0.1
# authors: Aesgarth
# url: https://github.com/Aesgarth/Discourse-Mealie

enabled_site_setting :discourse_mealie_enabled
require_relative "app/controllers/mealie_controller"


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

        if base_url.blank?
          Rails.logger.error("Mealie API: base_url is missing!")
          return nil
        end

        if api_key.blank?
          Rails.logger.error("Mealie API: API key is missing!")
          return nil
        end

        unless base_url.start_with?("http://", "https://")
          base_url = "https://#{base_url}"
        end

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
        Rails.logger.info("Mealie API Response Headers: #{response.headers}")
        Rails.logger.info("Mealie API Response Body: #{response.body}")

        if response.status == 401
          Rails.logger.error("Mealie API: Unauthorized! Check API key.")
          return nil
        end

        if response.status == 302
          Rails.logger.error("Mealie API: Redirect detected! Are we hitting a login page?")
          return nil
        end

        return nil unless response.status == 200

        begin
          response_json = JSON.parse(response.body)
        rescue JSON::ParserError => e
          Rails.logger.error("Failed to parse Mealie API response: #{e.message}")
          Rails.logger.error("Response body: #{response.body}")
          return nil
        end

        unless response_json["items"].is_a?(Array) && !response_json["items"].empty?
          Rails.logger.error("Mealie API: No valid items returned in response.")
          return nil
        end

        first_recipe = response_json["items"].first
        recipe_slug = first_recipe["slug"]

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

  Topic.register_custom_field_type('mealie_recipe_id', :string)

  DiscourseEvent.on(:topic_created) do |topic|
    Rails.logger.info("Topic Created Event Triggered for: #{topic.title}")
    if SiteSetting.discourse_mealie_enabled && topic.category.name == "Recipes"
      Rails.logger.info("Fetching recipe for topic: #{topic.title}")
      recipe_data = MealieDiscourse.fetch_mealie_recipe(topic.title)

      if recipe_data
        Rails.logger.info("Recipe found: #{recipe_data["id"]}")
        topic.custom_fields["mealie_recipe_id"] = recipe_data["id"]
        topic.save_custom_fields
      else
        Rails.logger.error("No recipe found for topic: #{topic.title}")
      end
    end
  end

  MealieDiscourse::Engine.routes.draw do
    post "/webhook" => "mealie#webhook"
    post "/test_connection" => "mealie#test_connection"
    get "/test_fetch_recipe" => "mealie#test_fetch_recipe"
  end

  Discourse::Application.routes.append do
    mount ::MealieDiscourse::Engine, at: "/mealie"
  end
end
