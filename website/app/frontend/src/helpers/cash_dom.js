import $ from "cash-dom";

$.fn.show = function () {
  return this.each(function () {
    const el = $(this);

    // Remove d-none class
    el.removeClass("d-none");

    // If element had inline display: none, remove it
    if (el.css("display") === "none") {
      el.css("display", "");
    }
  });
};

$.fn.hide = function () {
  return this.each(function () {
    const el = $(this);

    // Add d-none class
    el.addClass("d-none");

    // Clean up any inline display styles
    el.css("display", "");
  });
};

export default $;
