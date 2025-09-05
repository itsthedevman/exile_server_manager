import $ from "cash-dom";
import * as R from "ramda";
import debounce from "lodash/debounce";

class Validator {
  constructor(form, options = {}) {
    this.form = $(form)[0];
    this.fields = [];
    this.errors = {};
    this.options = {
      errorClass: "is-invalid",
      successClass: "is-valid",
      errorElement: "div",
      errorClass: "invalid-feedback",
      validateOnBlur: true,
      validateOnInput: true,
      ...options,
    };
    this.callbacks = {
      onSuccess: [],
      onFail: [],
    };

    this.init();
  }

  init() {
    if (this.form) {
      // Prevent form submission and validate instead
      $(this.form).on("submit", (e) => {
        e.preventDefault();
        this.validate();
      });
    }
  }

  // Helper to detect if element is using Slim Select
  isSlimSelect(el) {
    // Check if the element has been initialized with Slim Select
    // Slim Select adds a data attribute and hides the original select
    return (
      el &&
      el.tagName === "SELECT" &&
      (el.style.display === "none" || $(el).hasClass("ss-hide")) &&
      $(el).siblings(".ss-main").length > 0
    );
  }

  // Get the Slim Select container for a select element
  getSlimSelectContainer(el) {
    return $(el).siblings(".ss-main")[0];
  }

  addField(selector, rules = []) {
    const field = {
      selector,
      rules,
      validated: false,
      touched: false, // Track if user has interacted with the field
    };

    this.fields.push(field);

    const el = $(field.selector)[0];
    if (el) {
      // Add real-time validation
      if (this.options.validateOnBlur) {
        // For Slim Select, we need to handle blur differently
        if (this.isSlimSelect(el)) {
          const container = this.getSlimSelectContainer(el);

          if (container) {
            $(container).on("blur", () => {
              field.touched = true;
              this.validateField(field);
            });
          }
        } else {
          $(el).on("blur", () => {
            field.touched = true;
            this.validateField(field);
          });
        }
      }

      if (this.options.validateOnInput) {
        $(el).on(
          "input",
          debounce(() => {
            field.touched = true;
            this.validateField(field);
          }, 300)
        );
      }
    }

    return this;
  }

  async validateField(field, forceValidation = false) {
    const el = $(field.selector)[0];
    if (!el) return true;

    // Don't show errors until field has been touched (unless forced during form submission)
    if (!field.touched && !forceValidation) {
      return true;
    }

    const value = el.value;

    // Clear previous errors for this field
    this.clearFieldError(field.selector);

    for (const ruleObj of field.rules) {
      let valid = true;
      let errorMsg = ruleObj.errorMessage || "Invalid value";

      if (ruleObj.rule === "required") {
        valid = R.trim(value) !== "";
        errorMsg = ruleObj.errorMessage || "This field is required";
      } else if (ruleObj.rule === "minLength") {
        valid = value.length >= ruleObj.value;
        errorMsg = ruleObj.errorMessage || `Minimum length is ${ruleObj.value}`;
      } else if (ruleObj.rule === "maxLength") {
        valid = value.length <= ruleObj.value;
        errorMsg = ruleObj.errorMessage || `Maximum length is ${ruleObj.value}`;
      } else if (ruleObj.rule === "customRegexp") {
        valid = ruleObj.value.test(value);
        errorMsg = ruleObj.errorMessage || "Invalid format";
      } else if (typeof ruleObj.validator === "function") {
        try {
          valid = await Promise.resolve(ruleObj.validator(value, el));
        } catch (e) {
          valid = false;
          errorMsg = e.message || errorMsg;
        }
      }

      if (!valid) {
        this.showFieldError(field.selector, errorMsg);
        field.validated = false;
        return false;
      }
    }

    // Field is valid
    this.showFieldSuccess(field.selector);
    field.validated = true;
    return true;
  }

  async validate() {
    this.errors = {};
    let isValid = true;

    // Validate all fields - force validation even for untouched fields
    for (const field of this.fields) {
      const fieldValid = await this.validateField(field, true); // Force validation
      if (!fieldValid) {
        isValid = false;
      }
    }

    // Execute callbacks
    if (isValid) {
      this.callbacks.onSuccess.forEach((cb) => cb());
      // If no onSuccess callbacks and we have a form, use requestSubmit for Turbo
      if (this.callbacks.onSuccess.length === 0 && this.form) {
        this.form.requestSubmit();
      }
    } else {
      this.callbacks.onFail.forEach((cb) => cb());
    }

    return isValid;
  }

  showFieldError(selector, message) {
    const el = $(selector)[0];
    if (!el) return;

    // Check if this is a Slim Select element
    if (this.isSlimSelect(el)) {
      const container = this.getSlimSelectContainer(el);

      if (container) {
        // Apply error styling to the Slim Select container
        $(container)
          .removeClass(this.options.successClass)
          .addClass("is-invalid");

        // Find or create error element after the Slim Select container
        let errorEl = $(container).siblings(".invalid-feedback")[0];

        if (!errorEl) {
          // Create new error element after the Slim Select container
          errorEl = $(`<div class="invalid-feedback d-block"></div>`)[0];
          $(container).after(errorEl);
        }

        $(errorEl).text(message).show();
      }
    } else {
      // Regular input handling
      $(el).removeClass(this.options.successClass).addClass("is-invalid");

      // Find or create error element
      let errorEl = $(el).siblings(".invalid-feedback")[0];
      if (!errorEl) {
        // Look for existing invalid-feedback in parent (for input groups)
        errorEl = $(el).parent().find(".invalid-feedback")[0];
      }

      if (!errorEl) {
        // Create new error element
        errorEl = $(`<div class="invalid-feedback"></div>`)[0];
        $(el).after(errorEl);
      }

      $(errorEl).text(message).show();
    }
  }

  showFieldSuccess(selector) {
    const el = $(selector)[0];
    if (!el) return;

    // Check if this is a Slim Select element
    if (this.isSlimSelect(el)) {
      const container = this.getSlimSelectContainer(el);

      if (container) {
        // Remove error styling from the Slim Select container
        $(container).removeClass("is-invalid");

        // Make sure to hide ALL error messages (siblings and in parent)
        $(container).siblings(".invalid-feedback").remove();
        $(container).parent().find(".invalid-feedback").remove();
      }
    } else {
      // Regular input handling - just remove error styling
      $(el).removeClass("is-invalid");

      // Hide error message
      $(el).siblings(".invalid-feedback").hide();
      $(el).parent().find(".invalid-feedback").hide();
    }
  }

  clearFieldError(selector) {
    const el = $(selector)[0];
    if (!el) return;

    // Check if this is a Slim Select element
    if (this.isSlimSelect(el)) {
      const container = this.getSlimSelectContainer(el);
      if (container) {
        $(container).removeClass("is-invalid");
        // Remove all error feedback elements
        $(container).siblings(".invalid-feedback").remove();
        $(container).parent().find(".invalid-feedback").remove();
      }
    } else {
      // Regular input handling
      $(el).removeClass("is-invalid");
      $(el).siblings(".invalid-feedback").hide();
      $(el).parent().find(".invalid-feedback").hide();
    }
  }

  clearAllErrors() {
    // Clear all field errors and reset validation state
    this.fields.forEach((field) => {
      this.clearFieldError(field.selector);
      field.validated = false;
      field.touched = false; // Also reset touched state
    });

    // Clear the errors object
    this.errors = {};
  }

  onSuccess(callback) {
    this.callbacks.onSuccess.push(callback);
    return this;
  }

  onFail(callback) {
    this.callbacks.onFail.push(callback);
    return this;
  }

  // Add some common validation rules as static methods
  static rules = {
    required: (errorMessage = "This field is required") => ({
      rule: "required",
      errorMessage,
    }),

    minLength: (length, errorMessage) => ({
      rule: "minLength",
      value: length,
      errorMessage: errorMessage || `Minimum length is ${length}`,
    }),

    maxLength: (length, errorMessage) => ({
      rule: "maxLength",
      value: length,
      errorMessage: errorMessage || `Maximum length is ${length}`,
    }),

    email: (errorMessage = "Please enter a valid email") => ({
      rule: "customRegexp",
      value: /^[^\s@]+@[^\s@]+\.[^\s@]+$/,
      errorMessage,
    }),

    custom: (validator, errorMessage = "Invalid value") => ({
      validator,
      errorMessage,
    }),
  };
}

export default Validator;
