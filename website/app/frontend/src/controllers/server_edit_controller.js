import ApplicationController from "./application_controller";
import JustValidate from "just-validate";
import { allowTurbo } from "../helpers/just_validate";
import { disableSubmitOnEnter } from "../helpers/forms";
import axios from "axios";
import $ from "../helpers/cash_dom";

// Connects to data-controller="server-edit"
export default class extends ApplicationController {
  static targets = ["form"];

  static values = { serverIdCheckPath: String };

  connect() {
    this.validator = new JustValidate(this.formTarget);

    this.#initializeValidator();
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////

  #initializeValidator() {
    this.validator
      .addField("#server_server_id", [
        { rule: "required" },
        {
          rule: "customRegexp",
          value: /\S+/gi,
          errorMessage: "Server ID cannot contain whitespace",
        },
        {
          rule: "customRegexp",
          value: /\w+/gi,
          errorMessage: "Server ID cannot contain any symbols",
        },
        {
          validator: (value, _context) => () =>
            new Promise(async (resolve) => {
              try {
                const response = await axios.get(this.serverIdCheckPathValue, {
                  params: { id: value },
                });

                resolve(response.data.available);
              } catch (error) {
                console.error("Server ID check failed:", error);
                resolve(false);
              }
            }),
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
    allowTurbo(this.validator);
  }
}
