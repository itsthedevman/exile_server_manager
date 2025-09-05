import ApplicationController from "./application_controller";
import JustValidate from "just-validate";
import { allowTurbo } from "../helpers/just_validate";
import $ from "../helpers/cash_dom";

// Connects to data-controller="community-edit"
export default class extends ApplicationController {
  static targets = [
    "form",
    "welcomeMessageLength",
    "welcomeMessageEnabled",
    "welcomeMessageDisabled",
  ];

  connect() {
    this.validator = new JustValidate(this.formTarget);

    this.#initializeValidator();
    allowTurbo(this.validator);
  }

  onWelcomeMessageToggleClick(event) {
    // Disable the message box element when the toggle is off
    const toggleElem = $(event.currentTarget);
    const messageBoxElem = $("#community_welcome_message");

    const disabled = !toggleElem.is(":checked");
    messageBoxElem.prop("disabled", disabled);

    const enabledCardElem = $(this.welcomeMessageEnabledTarget);
    const disabledCardElem = $(this.welcomeMessageDisabledTarget);

    if (disabled) {
      enabledCardElem.hide();
      disabledCardElem.show();
    } else {
      enabledCardElem.show();
      disabledCardElem.hide();
    }
  }

  onWelcomeMessageInput(event) {
    // Set the message length in the UI
    const messageBoxElem = $(event.currentTarget);
    const lengthElem = $(this.welcomeMessageLengthTarget);

    const textLength = messageBoxElem.val().length;
    lengthElem.html(textLength);
  }

  //////////////////////////////////////////////////////////////////////////////

  #initializeValidator() {
    this.validator
      .addField("#community_community_id", [
        { rule: "required" },
        { rule: "minLength", value: 2 },
      ])
      .addField("#community_welcome_message", [
        { rule: "maxLength", value: 1000 },
      ]);
  }
}
