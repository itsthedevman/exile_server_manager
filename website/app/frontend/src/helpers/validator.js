import $ from "cash-dom";
import * as R from "ramda";
import { debounce } from "lodash";
import axios from "axios";

export default class Validator {
  constructor(form, options = {}) {
    this.form = $(form)[0];
    this.fields = [];
    this.errors = {};
    this.validationCache = new Map();

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

    this.isSubmitting = false;

    this.#initialize();
  }

  //////////////////////////////////////////////////////////////////////////////
  // Public API
  //////////////////////////////////////////////////////////////////////////////

  addField(selector, rules = []) {
    const field = { selector, rules, validated: false, touched: false };
    this.fields.push(field);

    const el = $(selector)[0];
    if (!el) return this;

    this.#bindFieldEvents(field, el);
    return this;
  }

  async validate() {
    this.errors = {};

    // Use Ramda to process fields until we find an invalid one
    const validateField = async (field) => {
      const isValid = await this.#validateField(field, true);
      if (!isValid) throw field; // Use throw to break early
      return field;
    };

    try {
      await R.pipe(R.map(validateField), (promises) => Promise.all(promises))(
        this.fields
      );

      // All fields valid
      this.#executeCallbacks("onSuccess");
      this.#handleFormSubmission();
      return true;
    } catch (firstErrorField) {
      // First invalid field found
      this.#scrollToError(firstErrorField);
      this.#executeCallbacks("onFail");
      return false;
    }
  }

  clearAllErrors() {
    R.forEach((field) => {
      this.#clearFieldError(field.selector);
      field.validated = false;
      field.touched = false;
    })(this.fields);

    this.errors = {};
  }

  clearCache(selector = null) {
    if (selector) {
      const keysToDelete = R.filter(
        (key) => key.startsWith(selector),
        Array.from(this.validationCache.keys())
      );
      R.forEach((key) => this.validationCache.delete(key))(keysToDelete);
    } else {
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

  //////////////////////////////////////////////////////////////////////////////
  // Private Methods
  //////////////////////////////////////////////////////////////////////////////

  #initialize() {
    if (!this.form) return;

    $(this.form).on("submit", async (e) => {
      if (this.isSubmitting) {
        this.isSubmitting = false;
        return;
      }

      e.preventDefault();
      await this.validate();
    });
  }

  #bindFieldEvents(field, el) {
    const { validateOnBlur, validateOnInput } = this.options;

    if (validateOnBlur) {
      const blurTarget = this.#isSlimSelect(el)
        ? this.#getSlimSelectContainer(el)
        : el;

      if (blurTarget) {
        $(blurTarget).on("blur", async () => {
          field.touched = true;
          await this.#validateField(field);
        });
      }
    }

    if (validateOnInput) {
      $(el).on(
        "input",
        debounce(async () => {
          field.touched = true;
          await this.#validateField(field);
        }, 300)
      );
    }
  }

  async #validateField(field, forceValidation = false) {
    const el = $(field.selector)[0];
    if (!el) return true;

    if (!field.touched && !forceValidation) return true;

    const value = el.value;
    this.#clearFieldError(field.selector);

    // Process rules with early exit on first failure
    for (const rule of field.rules) {
      const { isValid, errorMsg } = await this.#processRule(
        rule,
        value,
        el,
        field
      );

      if (!isValid) {
        this.#showFieldError(field.selector, errorMsg);
        field.validated = false;
        return false;
      }
    }

    this.#showFieldSuccess(field.selector);
    field.validated = true;
    return true;
  }

  async #processRule(rule, value, el, field) {
    const { rule: ruleName, errorMessage: customErrorMsg } = rule;
    let isValid = true;
    let errorMsg = customErrorMsg || "Invalid value";

    try {
      switch (ruleName) {
        case "required":
          isValid = R.trim(value) !== "";
          errorMsg = customErrorMsg || "This field is required";
          break;

        case "minLength":
          isValid = value.length >= rule.value;
          errorMsg = customErrorMsg || `Minimum length is ${rule.value}`;
          break;

        case "maxLength":
          isValid = value.length <= rule.value;
          errorMsg = customErrorMsg || `Maximum length is ${rule.value}`;
          break;

        case "customRegexp":
          isValid = rule.value.test(value);
          errorMsg = customErrorMsg || "Invalid format";
          break;

        case "ajax":
          isValid = await this.#handleAjaxRule(rule, value, field);
          errorMsg = customErrorMsg || "Validation failed";
          break;

        default:
          if (typeof rule.validator === "function") {
            isValid = await this.#handleCustomValidator(rule, value, el, field);
          }
      }
    } catch (error) {
      isValid = false;
      errorMsg = error.message || errorMsg;
    }

    return { isValid, errorMsg };
  }

  async #handleAjaxRule(rule, value, field) {
    const cacheKey = rule.cache ? `${field.selector}-ajax-${value}` : null;

    if (cacheKey && this.validationCache.has(cacheKey)) {
      return this.validationCache.get(cacheKey);
    }

    const isValid = await this.#performAjaxValidation(value, rule);

    if (cacheKey) {
      this.validationCache.set(cacheKey, isValid);
    }

    return isValid;
  }

  async #handleCustomValidator(rule, value, el, field) {
    const cacheKey = rule.cache ? `${field.selector}-custom-${value}` : null;

    if (cacheKey && this.validationCache.has(cacheKey)) {
      return this.validationCache.get(cacheKey);
    }

    const result = await Promise.resolve(rule.validator(value, el));

    if (cacheKey) {
      this.validationCache.set(cacheKey, result);
    }

    return result;
  }

  async #performAjaxValidation(value, rule) {
    try {
      const config = {
        url: rule.url,
        method: rule.method || "GET",
        ...rule.config,
      };

      const isGet = config.method.toUpperCase() === "GET";
      const paramData = rule.params ? rule.params(value) : { value };

      if (isGet) {
        config.params = paramData;
      } else {
        config.data = rule.data ? rule.data(value) : paramData;
      }

      const response = await axios(config);

      return rule.responseHandler
        ? rule.responseHandler(response)
        : response.data === true || response.data.valid === true;
    } catch (error) {
      console.error("AJAX validation failed:", error);
      return false;
    }
  }

  #executeCallbacks(type) {
    R.forEach((callback) => callback())(this.callbacks[type]);
  }

  #handleFormSubmission() {
    if (this.callbacks.onSuccess.length > 0 || !this.form) return;

    const turboDisabled = R.any(
      (value) => value === "false" || value === false,
      [this.form.dataset.turbo, this.form.getAttribute("data-turbo")]
    );

    if (turboDisabled) {
      this.form.submit();
    } else {
      this.isSubmitting = true;

      setTimeout(() => {
        this.form.requestSubmit();
      }, 0);
    }
  }

  #scrollToError(errorField) {
    const el = $(errorField.selector)[0];
    if (!el) return;

    const scrollTarget = this.#isSlimSelect(el)
      ? this.#getSlimSelectContainer(el) || el
      : el;

    const offset = 400;
    const elementPosition =
      scrollTarget.getBoundingClientRect().top + window.pageYOffset;
    const offsetPosition = elementPosition - offset;

    window.scrollTo({
      top: offsetPosition,
      behavior: "smooth",
    });

    setTimeout(() => {
      if (!this.#isSlimSelect(el) && el.focus) {
        el.focus();
      }
    }, 500);
  }

  //////////////////////////////////////////////////////////////////////////////
  // SlimSelect Helpers
  //////////////////////////////////////////////////////////////////////////////

  #isSlimSelect(el) {
    return (
      el?.tagName === "SELECT" &&
      (el.style.display === "none" || $(el).hasClass("ss-hide")) &&
      $(el).siblings(".ss-main").length > 0
    );
  }

  #getSlimSelectContainer(el) {
    return $(el).siblings(".ss-main")[0];
  }

  //////////////////////////////////////////////////////////////////////////////
  // Error Display Methods
  //////////////////////////////////////////////////////////////////////////////

  #showFieldError(selector, message) {
    const el = $(selector)[0];
    if (!el) return;

    if (this.#isSlimSelect(el)) {
      this.#showSlimSelectError(el, message);
    } else {
      this.#showRegularError(el, message);
    }
  }

  #showSlimSelectError(el, message) {
    const container = this.#getSlimSelectContainer(el);
    if (!container) return;

    $(container).removeClass(this.options.successClass).addClass("is-invalid");

    let errorEl = $(container).siblings(".invalid-feedback")[0];

    if (!errorEl) {
      errorEl = $(`<div class="invalid-feedback d-block"></div>`)[0];
      $(container).after(errorEl);
    }

    $(errorEl).text(message).show();
  }

  #showRegularError(el, message) {
    $(el).removeClass(this.options.successClass).addClass("is-invalid");

    let errorEl =
      $(el).siblings(".invalid-feedback")[0] ||
      $(el).parent().find(".invalid-feedback")[0];

    if (!errorEl) {
      errorEl = $(`<div class="invalid-feedback"></div>`)[0];
      $(el).after(errorEl);
    }

    $(errorEl).text(message).show();
  }

  #showFieldSuccess(selector) {
    const el = $(selector)[0];
    if (!el) return;

    if (this.#isSlimSelect(el)) {
      this.#showSlimSelectSuccess(el);
    } else {
      this.#showRegularSuccess(el);
    }
  }

  #showSlimSelectSuccess(el) {
    const container = this.#getSlimSelectContainer(el);
    if (!container) return;

    $(container).removeClass("is-invalid");
    $(container).siblings(".invalid-feedback").remove();
    $(container).parent().find(".invalid-feedback").remove();
  }

  #showRegularSuccess(el) {
    $(el).removeClass("is-invalid");
    $(el).siblings(".invalid-feedback").hide();
    $(el).parent().find(".invalid-feedback").hide();
  }

  #clearFieldError(selector) {
    const el = $(selector)[0];
    if (!el) return;

    if (this.#isSlimSelect(el)) {
      this.#showSlimSelectSuccess(el); // Same as success for clearing
    } else {
      this.#showRegularSuccess(el); // Same as success for clearing
    }
  }

  //////////////////////////////////////////////////////////////////////////////
  // Static Rule Helpers
  //////////////////////////////////////////////////////////////////////////////

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

    ajax: (url, options = {}) => ({
      rule: "ajax",
      url,
      method: options.method || "GET",
      params: options.params,
      data: options.data,
      config: options.config,
      responseHandler: options.responseHandler,
      cache: options.cache !== false,
      errorMessage: options.errorMessage || "Validation failed",
    }),

    custom: (validator, errorMessage = "Invalid value", cache = false) => ({
      validator,
      errorMessage,
      cache,
    }),
  };
}
