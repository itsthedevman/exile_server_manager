/**
 * Fix for JustValidate + Turbo + Async Validators infinite loop issue
 *
 * Problem: When using async validators with Turbo, we need to:
 * 1. Prevent the initial form submission so async validation can run
 * 2. Manually submit the form after validation passes
 * 3. BUT avoid triggering our own validation handler again when we submit
 *
 * Without this fix, form.requestSubmit() triggers the same submit handler,
 * which runs validation again, which calls requestSubmit() again...
 * creating an infinite validation loop that never actually submits the form.
 *
 * Solution: Mark our programmatic submissions with a special flag so we can
 * detect them and let them bypass validation on the second pass.
 */
export function allowTurbo(validator) {
  validator.removeListener(
    "submit",
    validator.form,
    validator.formSubmitHandler
  );

  validator.formSubmitHandler = function (event) {
    // Check if this is a "real" submission (after validation passed)
    if (event.isTrusted === false || event.detail?.skipValidation) {
      // This is our programmatic submit, let it through
      return;
    }

    validator.isSubmitted = true;
    const form = event.currentTarget;

    event.preventDefault();

    validator.validateHandler(event).then(() => {
      if (!validator.isValid) {
        return;
      } else {
        // Create a custom event that bypasses validation
        const submitEvent = new Event("submit", {
          bubbles: true,
          cancelable: true,
        });
        submitEvent.detail = { skipValidation: true };
        form.dispatchEvent(submitEvent);
      }
    });
  };

  validator.addListener("submit", validator.form, validator.formSubmitHandler);
}
