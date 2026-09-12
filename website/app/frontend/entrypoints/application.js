// Entry point for the build script in your package.json
import "@hotwired/turbo-rails";
import "../src/controllers";
import * as bootstrap from "bootstrap";
import $ from "cash-dom";
import * as R from "ramda";

$(document).on("turbo:load", function () {
  bindToolTips();
  bindTurboModal();
  bindDataTriggers();
});

$(document).on("turbo:frame-load", function () {
  bindToolTips();
  bindDataTriggers();
});

$(document).on("turbo:before-stream-render", function (event) {
  const originalRender = event.detail.render;

  event.detail.render = function (streamElement) {
    originalRender(streamElement);
    bindToolTips();
    bindDataTriggers();
  };
});

// Runs again after every frame load and stream render, so markup they bring in gets its tooltips too. getOrCreateInstance
// keeps an element that already has one from being given a second.
function bindToolTips() {
  $('[data-bs-toggle="tooltip"]').each(function (i, el) {
    bootstrap.Tooltip.getOrCreateInstance(el);
  });
}

function bindTurboModal() {
  let elem = $("#turbo-modal");
  if (elem.length === 0) return;

  // Remove the content once it is hidden
  elem.on("hidden.bs.modal", (_event) => {
    $("#turbo_modal").html("");
  });
}

function bindDataTriggers() {
  $("[data-trigger]").each((_i, e) => {
    const elem = $(e);
    const trigger = elem.data("trigger");

    console.log("Received trigger: ", trigger);

    // Trigger: "modal:show:selector", "modal:hide:selector"
    if (R.test(/^modal:(show|hide)/, trigger)) {
      const [action, selector] = R.pipe(R.split(":"), R.slice(1, 3))(trigger);

      const modal = bootstrap.Modal.getOrCreateInstance($(selector)[0]);
      if (R.isNil(modal)) return;

      if (action === "show") {
        modal.show();
      } else if (action === "hide") {
        modal.hide();
      }

      elem.remove();
      return;
    }
  });
}
