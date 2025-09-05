import $ from "cash-dom";

export function onModalHidden(selector, callbackFunction) {
  $(selector)[0].addEventListener("hidden.bs.modal", callbackFunction);
}
