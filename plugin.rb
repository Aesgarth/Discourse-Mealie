# name: Discourse-Mealie
# about: A plugin to integrate Mealie recipes into Discourse posts
# version: 0.1
# authors: Aesgarth
# url: https://github.com/Aesgarth/Discourse-Mealie

enabled_site_setting :mealie_url
enabled_site_setting :mealie_api_key

after_initialize do
  module ::MealieDiscourse
    class Engine < ::Rails::Engine
      engine_name "mealie_discourse"
      isolate_namespace MealieDiscourse
    end
  end

  require_dependency 'topic'

  Topic.register_custom_field_type('mealie_recipe_id', :string)

  DiscourseEvent.on(:topic_created) do |topic|
    if topic.category.name == "Recipes"
      recipe_data = fetch_mealie_recipe(topic.title)

      if recipe_data
        topic.update(custom_fields: { "mealie_recipe_id" => recipe_data["id"] })
        topic.save_custom_fields
      end
    end
  end

  def fetch_mealie_recipe(recipe_name)
    base_url = SiteSetting.mealie_url
    api_key = SiteSetting.mealie_api_key

    return nil if base_url.blank? || api_key.blank?

    response = Excon.get(
      "#{base_url}/api/recipes?search=#{CGI.escape(recipe_name)}",
      headers: {
        "Accept" => "application/json",
        "Authorization" => "Bearer #{api_key}"
      }
    )

    return nil unless response.status == 200

    recipes = JSON.parse(response.body)
    recipes.first
  end
end
