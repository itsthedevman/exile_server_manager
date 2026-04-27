import ApplicationController from "./application_controller";
import SlimSelect from "slim-select";

export default class extends ApplicationController {
  static targets = ["select"];
  static values = {
    data: Array,
    placeholder: String,
    searchText: String,
    allowDeselect: Boolean,
    closeOnSelect: Boolean,
    disabled: Boolean,
  };

  connect() {
    const selectElement = this.hasSelectTarget
      ? this.selectTarget
      : this.element;

    const config = {
      select: selectElement,
      data: this.dataValue,
      settings: {
        searchText: this.searchTextValue || "No results",
        searchPlaceholder: this.searchTextValue || "Search",
        closeOnSelect: this.closeOnSelectValue,
        allowDeselect: this.allowDeselectValue,
        placeholderText: this.placeholderValue || "Select value",
        showSearch: true,
        disabled: this.disabledValue || selectElement.disabled,
      },
      events: {
        afterChange: (_) => {
          // Trigger change event for other listeners (including validation)
          this.nextTick(() => {
            selectElement.dispatchEvent(new Event("change", { bubbles: true }));
            selectElement.dispatchEvent(new Event("input", { bubbles: true }));

            // Also trigger blur to force immediate validation if configured
            selectElement.dispatchEvent(new Event("blur", { bubbles: true }));
          });
        },
      },
    };

    this.slimSelect = new SlimSelect(config);
  }

  disconnect() {
    this.slimSelect?.destroy();
  }

  disable() {
    this.slimSelect?.disable();
  }

  enable() {
    this.slimSelect?.enable();
  }

  setData({ detail: { value } }) {
    this.slimSelect?.setData(value);
  }

  clearData() {
    this.slimSelect?.setData([]);
  }

  setSelected({ detail: { value, validate = false } }) {
    this.slimSelect?.setSelected([value], validate);
  }

  clearSelected() {
    this.slimSelect?.setSelected([], false);
  }
}
