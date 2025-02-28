// assets/javascripts/discourse/components/mealie-admin-settings.js.es6
import Component from "@ember/component";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Component.extend({
  importRecipeUrl: "",
  
  actions: {
    triggerImport() {
      if (!this.importRecipeUrl) {
        return;
      }
      
      this.set("importing", true);
      
      ajax("/mealie/import", {
        type: "POST",
        data: { recipe_url: this.importRecipeUrl }
      })
        .then(result => {
          this.set("importRecipeUrl", "");
          this.set("importResult", result.message);
        })
        .catch(popupAjaxError)
        .finally(() => this.set("importing", false));
    }
  }
});