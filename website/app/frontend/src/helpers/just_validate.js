export function allowTurbo(validator) {
  // In order for Turbo to work, "preventDefault" cannot be called. Period.
  // JustValidate calls "preventDefault" in their formSubmitHandler function
  validator.removeListener(
    "submit",
    validator.form,
    validator.formSubmitHandler
  );

  // This is JustValidate code, modified to conditionally call "preventDefault"
  // https://github.com/horprogs/Just-validate/blob/master/src/main.ts#L1000
  validator.formSubmitHandler = function (event) {
    validator.isSubmitted = true;
    validator.validateHandler(event).finally(() => {
      if (!validator.isValid) event.preventDefault();
    });
  };

  validator.addListener("submit", validator.form, validator.formSubmitHandler);

  // requestSubmit will trigger a submit with Turbo
  validator.onSuccess((event) => {
    event.currentTarget.requestSubmit();
  });
}
