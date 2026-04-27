import { application } from "./application";

const controllerModules = import.meta.glob("./*_controller.js", {
  eager: true,
});

for (const [path, module] of Object.entries(controllerModules)) {
  const controllerName = path
    .match(/\.\/(.+)_controller\.js$/)[1]
    .replace(/_/g, "-");

  application.register(controllerName, module.default);
}
