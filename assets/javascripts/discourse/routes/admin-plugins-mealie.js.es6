// assets/javascripts/discourse/routes/admin-plugins-mealie.js.es6
import Route from "@ember/routing/route";

export default Route.extend({
  controllerName: "admin-plugins-mealie",
  renderTemplate() {
    this.render("admin/plugins/mealie");
  }
});