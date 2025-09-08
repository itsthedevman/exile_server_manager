import $ from "cash-dom";
import * as R from "ramda";
import debounce from "lodash/debounce";
import axios from "axios";

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

    // Cache for async validations
    this.validationCache = new Map();

    this.init();
  }

  init() {
    if (this.form) {
      // Prevent form submission and validate instead
      $(this.form).on("submit", async (e) => {
        e.preventDefault();
        await this.validate();
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
      // Add real-time validation with async support
      if (this.options.validateOnBlur) {
        // For Slim Select, we need to handle blur differently
        if (this.isSlimSelect(el)) {
          const container = this.getSlimSelectContainer(el);

          if (container) {
            $(container).on("blur", async () => {
              field.touched = true;
              await this.validateField(field);
            });
          }
        } else {
          $(el).on("blur", async () => {
            field.touched = true;
            await this.validateField(field);
          });
        }
      }

      if (this.options.validateOnInput) {
        $(el).on(
          "input",
          debounce(async () => {
            field.touched = true;
            await this.validateField(field);
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

    // Process rules in order - FAST FAIL on first error
    for (const ruleObj of field.rules) {
      let valid = true;
      let errorMsg = ruleObj.errorMessage || "Invalid value";

      try {
        if (ruleObj.rule === "required") {
          valid = R.trim(value) !== "";
          errorMsg = ruleObj.errorMessage || "This field is required";
        } else if (ruleObj.rule === "minLength") {
          valid = value.length >= ruleObj.value;
          errorMsg =
            ruleObj.errorMessage || `Minimum length is ${ruleObj.value}`;
        } else if (ruleObj.rule === "maxLength") {
          valid = value.length <= ruleObj.value;
          errorMsg =
            ruleObj.errorMessage || `Maximum length is ${ruleObj.value}`;
        } else if (ruleObj.rule === "customRegexp") {
          valid = ruleObj.value.test(value);
          errorMsg = ruleObj.errorMessage || "Invalid format";
        } else if (ruleObj.rule === "ajax") {
          // Check cache first if caching is enabled
          const cacheKey = ruleObj.cache
            ? `${field.selector}-ajax-${value}`
            : null;

          if (cacheKey && this.validationCache.has(cacheKey)) {
            valid = this.validationCache.get(cacheKey);
          } else {
            valid = await this.performAjaxValidation(value, ruleObj);

            // Cache the result if caching is enabled
            if (cacheKey) {
              this.validationCache.set(cacheKey, valid);
            }
          }

          errorMsg = ruleObj.errorMessage || "Validation failed";
        } else if (typeof ruleObj.validator === "function") {
          // Check cache for custom validators if caching is enabled
          const cacheKey = ruleObj.cache
            ? `${field.selector}-custom-${value}`
            : null;

          if (cacheKey && this.validationCache.has(cacheKey)) {
            valid = this.validationCache.get(cacheKey);
          } else {
            // Support both sync and async validators
            const result = ruleObj.validator(value, el);
            valid = await Promise.resolve(result);

            // Cache the result if caching is enabled
            if (cacheKey) {
              this.validationCache.set(cacheKey, valid);
            }
          }
        }
      } catch (e) {
        valid = false;
        errorMsg = e.message || errorMsg;
      }

      // FAST FAIL - stop on first rule error
      if (!valid) {
        this.showFieldError(field.selector, errorMsg);
        field.validated = false;
        return false;
      }
    }

    // All rules passed for this field
    this.showFieldSuccess(field.selector);
    field.validated = true;
    return true;
  }

  async performAjaxValidation(value, rule) {
    try {
      const config = {
        url: rule.url,
        method: rule.method || "GET",
        ...rule.config, // Allow custom axios config
      };

      // Handle params based on method
      if (config.method.toUpperCase() === "GET") {
        config.params = rule.params ? rule.params(value) : { value };
      } else {
        config.data = rule.data ? rule.data(value) : { value };
      }

      const response = await axios(config);

      // Allow custom response handler or default to checking response.data
      if (rule.responseHandler) {
        return rule.responseHandler(response);
      }

      return response.data === true || response.data.valid === true;
    } catch (error) {
      console.error("AJAX validation failed:", error);
      return false;
    }
  }

  async validate() {
    this.errors = {};
    let isValid = true;

    // Validate all fields - STOP on first field with an error
    for (const field of this.fields) {
      const fieldValid = await this.validateField(field, true); // Force validation
      if (!fieldValid) {
        isValid = false;
        break; // STOP HERE - don't validate remaining fields
      }
    }

    // Execute callbacks
    if (isValid) {
      this.callbacks.onSuccess.forEach((cb) => cb());
      // If no onSuccess callbacks and we have a form, submit it
      if (this.callbacks.onSuccess.length === 0 && this.form) {
        // Use submit() instead of requestSubmit() to avoid retriggering validation
        // This works for both Turbo and non-Turbo forms
        this.form.submit();
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

  clearCache(selector = null) {
    if (selector) {
      // Clear cache for specific field
      const keysToDelete = [];
      for (const key of this.validationCache.keys()) {
        if (key.startsWith(selector)) {
          keysToDelete.push(key);
        }
      }
      keysToDelete.forEach((key) => this.validationCache.delete(key));
    } else {
      // Clear entire cache
      this.validationCache.clear();
    }
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

    // Enhanced ajax rule helper with caching
    ajax: (url, options = {}) => ({
      rule: "ajax",
      url,
      method: options.method || "GET",
      params: options.params, // Function that returns params
      data: options.data, // Function that returns data for POST
      config: options.config, // Additional axios config
      responseHandler: options.responseHandler, // Custom response handler
      cache: options.cache !== false, // Cache by default
      errorMessage: options.errorMessage || "Validation failed",
    }),

    custom: (validator, errorMessage = "Invalid value", cache = false) => ({
      validator,
      errorMessage,
      cache, // Allow caching for custom validators too
    }),
  };
}

export default Validator;
