import ApplicationController from "./application_controller";
import Validator from "../helpers/validator";
import { disableSubmitOnEnter } from "../helpers/forms";

// Connects to data-controller="server-edit"
export default class extends ApplicationController {
  static targets = ["form"];

  static values = { serverIdCheckPath: String };

  connect() {
    this.validator = new Validator(this.formTarget);

    this.#initializeValidator();
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////

  #initializeValidator() {
    this.validator
      .addField("#server_server_id", [
        { rule: "required" },
        {
          rule: "customRegexp",
          value: /^\S+$/i,
          errorMessage: "Server ID cannot contain whitespace",
        },
        {
          rule: "customRegexp",
          value: /^\w+$/i,
          errorMessage: "Server ID cannot contain any symbols",
        },
        {
          rule: "ajax",
          url: this.serverIdCheckPathValue,
          params: (value) => ({ id: value }),
          responseHandler: (response) => response.data.available,
          cache: true,
          errorMessage: "Server ID already exists",
        },
      ])
      .addField("#server_server_ip", [
        { rule: "required" },
        {
          rule: "customRegexp",
          value: /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/i,
          errorMessage: "Provide a valid public facing IPv4 address",
        },
      ])
      .addField("#server_server_port", [
        { rule: "required" },
        {
          rule: "customRegexp",
          value: /\d+/,
          errorMessage: "Provide a valid port",
        },
      ]);

    disableSubmitOnEnter();
  }
}
