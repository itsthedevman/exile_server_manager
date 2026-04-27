import $ from "cash-dom";
import * as R from "ramda";

export function disableSubmitOnEnter() {
  $(document).on("keydown", "form", function (event) {
    return event.key != "Enter";
  });
}

export class Serializer {
  constructor(form, namespace) {
    this.form = $(form);
    this.namespace = namespace;
    this.fieldClass = `dynamic-${namespace.replace(/[[\]]/g, "-")}-field`;
  }

  serialize(data) {
    this.#clearExistingFields();
    this.#buildFields("", data);
  }

  #clearExistingFields() {
    this.form.find(`.${this.fieldClass}`).remove();
  }

  #buildFields(path, value) {
    if (R.isNil(value) || value === "") {
      this.#createHiddenField(path, "");
    } else if (R.is(Array, value)) {
      value.forEach((item) => {
        this.#buildFields(`${path}[]`, item);
      });
    } else if (R.is(Object, value)) {
      R.forEachObjIndexed((val, key) => {
        const newPath = path ? `${path}[${key}]` : `[${key}]`;
        this.#buildFields(newPath, val);
      }, value);
    } else {
      this.#createHiddenField(path, value);
    }
  }

  #createHiddenField(path, value) {
    $("<input>")
      .attr("type", "hidden")
      .attr("name", `${this.namespace}${path}`)
      .val(value)
      .addClass(this.fieldClass)
      .appendTo(this.form);
  }
}

export function isChecked(elem) {
  return $(elem).is(":checked");
}
