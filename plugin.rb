# name: discourse-mealie
# about: A plugin to integrate Mealie recipes into Discourse posts
# version: 0.1
# authors: Aesgarth
# url: https://github.com/Aesgarth/Discourse-Mealie

enabled_site_setting :mealie_api_url

after_initialize do
  module ::MealieDiscourse
    class Engine < ::Rails::Engine
      engine_name "mealie_discourse"
      isolate_namespace MealieDiscourse
    end
  end

  require_dependency 'topic'
  
  # When a new topic is created in a specific category, fetch Mealie data
  Topic.register_custom_field_type('mealie_recipe_id', :string)

  DiscourseEvent.on(:topic_created) do |topic|
    if topic.category.name == "Recipes" # Change this to your category
      recipe_data = fetch_mealie_recipe(topic.title)
      
      if recipe_data
        topic.update(custom_fields: { "mealie_recipe_id" => recipe_data["id"] })
        topic.save_custom_fields
      end
    end
  end

  def fetch_mealie_recipe(recipe_name)
    api_url = SiteSetting.mealie_api_url
    return nil if api_url.blank?

    response = Excon.get("#{api_url}/api/recipes?search=#{CGI.escape(recipe_name)}",
                         headers: { "Accept" => "application/json" })

    return nil unless response.status == 200

    recipes = JSON.parse(response.body)
    recipes.first # Return the first matching recipe
  end
end
