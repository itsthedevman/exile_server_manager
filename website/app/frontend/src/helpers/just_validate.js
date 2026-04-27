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

  let validationPassed = false;

  validator.formSubmitHandler = function (event) {
    // If validation already passed, let the submission through to Turbo
    if (validationPassed) {
      validationPassed = false;
      return;
    }

    validator.isSubmitted = true;
    const form = event.currentTarget;

    event.preventDefault();

    validator.validateHandler(event).then(() => {
      if (!validator.isValid) {
        return;
      }

      // Set flag before submitting so we bypass validation on next pass
      // Use setTimeout to defer to next event loop tick - fixes timing issues
      // when requestSubmit is called from within an async handler
      validationPassed = true;
      setTimeout(() => form.requestSubmit(), 0);
    });
  };

  validator.addListener("submit", validator.form, validator.formSubmitHandler);
}
