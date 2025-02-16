# name: Discourse-Mealie
# about: A plugin to integrate Mealie recipes into Discourse posts
# version: 0.1
# authors: Aesgarth
# url: https://github.com/Aesgarth/Discourse-Mealie

enabled_site_setting :mealie_url
enabled_site_setting :mealie_api_key

after_initialize do
  Rails.logger.info "Discourse-Mealie: Plugin initializing..."

  module ::MealieDiscourse
    class Engine < ::Rails::Engine
      engine_name "mealie_discourse"
      isolate_namespace MealieDiscourse
    end
  end

  require_dependency 'topic'

  Topic.register_custom_field_type('mealie_recipe_id', :string)

  DiscourseEvent.on(:topic_created) do |topic|
    begin
      category_name = topic.category&.name || "Unknown"
      Rails.logger.info "Discourse-Mealie: Topic created in category '#{category_name}'"

      if category_name == "Recipes"
        recipe_data = fetch_mealie_recipe(topic.title)

        if recipe_data
          topic.custom_fields["mealie_recipe_id"] = recipe_data["id"]
          topic.save_custom_fields
          Rails.logger.info "Discourse-Mealie: Recipe ID #{recipe_data['id']} saved to topic #{topic.id}"
        else
          Rails.logger.warn "Discourse-Mealie: No recipe found for '#{topic.title}'"
        end
      end
    rescue => e
      Rails.logger.error "Discourse-Mealie: Error processing topic - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end
end

def fetch_mealie_recipe(recipe_name)
  base_url = SiteSetting.mealie_url
  api_key = SiteSetting.mealie_api_key

  if base_url.blank? || api_key.blank?
    Rails.logger.warn "Discourse-Mealie: Mealie URL or API key is missing!"
    return nil
  end

  begin
    response = Excon.get(
      "#{base_url}/api/recipes?search=#{CGI.escape(recipe_name)}",
      headers: {
        "Accept" => "application/json",
        "Authorization" => "Bearer #{api_key}"
      }
    )

    unless response.status == 200
      Rails.logger.warn "Discourse-Mealie: API request failed with status #{response.status}"
      return nil
    end

    recipes = JSON.parse(response.body)
    Rails.logger.info "Discourse-Mealie: Found #{recipes.length} recipes for '#{recipe_name}'"
    recipes.first
  rescue => e
    Rails.logger.error "Discourse-Mealie: Error fetching recipe - #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    nil
  end
end
