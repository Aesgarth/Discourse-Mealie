// assets/javascripts/discourse/mealie-route-map.js.es6
export default {
    resource: "admin.adminPlugins",
    path: "/plugins",
    map() {
      this.route("mealie", function() {
        this.route("index", { path: "/" });
      });
    }
  };