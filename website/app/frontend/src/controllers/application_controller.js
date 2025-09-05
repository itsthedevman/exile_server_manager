import { Controller } from "@hotwired/stimulus";
import $ from "../helpers/cash_dom";

export default class ApplicationController extends Controller {
  initialize() {
    this.abortController = new AbortController();
  }

  disconnect() {
    this.abortController.abort();
  }

  addEventListener(selector, event, callback) {
    $(selector)[0].addEventListener(event, callback, {
      signal: this.abortController.signal,
    });
  }

  nextTick(callback) {
    setTimeout(callback, 0);
  }

  setSlimSelected(selector, value, validate = true) {
    this.dispatch("setSelected", {
      target: $(selector)[0],
      detail: { value, validate },
    });
  }

  clearSlimSelected(selector) {
    this.dispatch("clearSelected", { target: $(selector)[0] });
  }

  setSlimData(selector, value) {
    this.dispatch("setData", {
      target: $(selector)[0],
      detail: { value },
    });
  }

  clearSlimData(selector) {
    this.dispatch("clearData", { target: $(selector)[0] });
  }

  enableSlim(selector) {
    this.dispatch("enable", { target: $(selector)[0] });
  }

  disableSlim(selector) {
    this.dispatch("disable", { target: $(selector)[0] });
  }
}
