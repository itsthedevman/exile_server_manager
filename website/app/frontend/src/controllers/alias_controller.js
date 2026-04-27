import ApplicationController from "./application_controller";
import $ from "../helpers/cash_dom";
import * as R from "ramda";
import Validate from "../helpers/validator";
import { onModalHidden } from "../helpers/modals";
import CardSelector from "../helpers/card_selector";

// Base controller - see alias_new_controller/alias_edit_controller
export default class extends ApplicationController {
  static outlets = ["aliases"];

  static targets = [
    "communityButton",
    "communitySection",
    "communityID",

    "serverButton",
    "serverSection",
    "serverID",

    "value",
    "valueCount",

    "communityPreviewSection",
    "communityPreviewBefore",
    "communityPreviewAfter",

    "serverPreviewSection",
    "serverPreviewBefore",
    "serverPreviewAfter",
  ];

  connect() {
    this.modal = this.element;

    this.validator = new Validate();
    this.#initializeValidator();

    // Prepare the new alias cards
    this.cards = new CardSelector({
      community: $(this.communityButtonTarget),
      server: $(this.serverButtonTarget),
    });

    // Prepare the previews
    this.previews = {
      community: {
        before: $(this.communityPreviewBeforeTarget),
        after: $(this.communityPreviewAfterTarget),
      },
      server: {
        before: $(this.serverPreviewBeforeTarget),
        after: $(this.serverPreviewAfterTarget),
      },
    };

    this._showSection("community");
    this.#renderPreview();

    // Prepare the modal
    onModalHidden(this.modal, () => this.#clearModal());
  }

  onSectionChanged(event) {
    const targetElem = $(event.currentTarget);
    const type = targetElem.data("type");
    this._showSection(type);
  }

  onValueInput(_event) {
    this.#updateCounter();
    this.#renderPreview();
  }

  onIDChanged(_event) {
    this.#renderPreview();
  }

  // protected

  _showSection(type) {
    this.selectedType = type;
    this.cards.select(this.selectedType);

    const communitySectionElem = $(this.communitySectionTarget);
    const serverSectionElem = $(this.serverSectionTarget);
    const communityPreviewElem = $(this.communityPreviewSectionTarget);
    const serverPreviewElem = $(this.serverPreviewSectionTarget);

    this.#renderPreview();

    if (this.selectedType === "server") {
      // Change the preview
      communityPreviewElem.hide();
      serverPreviewElem.show();

      // Toggle the sections
      communitySectionElem.hide();
      serverSectionElem.show();
    } else {
      // Change the preview
      communityPreviewElem.show();
      serverPreviewElem.hide();

      // Toggle the sections
      communitySectionElem.show();
      serverSectionElem.hide();
    }
  }

  // private

  #initializeValidator() {
    this.validator
      .addField(this.communityIDTarget, [
        {
          validator: (value, _context) => {
            if (this.selectedType !== "community") return true;

            return !R.isEmpty(value);
          },
          errorMessage: "Please select a community",
        },
      ])
      .addField(this.serverIDTarget, [
        {
          validator: (value, _context) => {
            if (this.selectedType !== "server") return true;

            return !R.isEmpty(value);
          },
          errorMessage: "Please select a server",
        },
      ]);
  }

  #updateCounter() {
    $(this.valueCountTarget).html($(this.valueTarget).val().length);
  }

  #clearModal() {
    $(this.valueTarget).val("");

    this.clearSlimSelected(this.communityIDTarget);
    this.clearSlimSelected(this.serverIDTarget);

    this.validator.clearAllErrors();

    this._showSection("community");

    this.#renderPreview();
    this.#updateCounter();
  }

  #renderPreview() {
    const previews = this.previews[this.selectedType];

    // Preview the selected server
    const beforeElem = previews.before;

    if (this.selectedType === "server") {
      const [server_id, _] = $(this.serverIDTarget).val().split(":", 2);

      beforeElem.html(server_id?.trim() || "&lt;server&gt;");
    } else {
      const [community_id, _] = $(this.communityIDTarget).val().split(":", 2);

      beforeElem.html(community_id?.trim() || "&lt;community&gt;");
    }

    // Preview the alias value
    const afterElem = previews.after;
    const value = $(this.valueTarget).val();

    if (R.isEmpty(value)) {
      afterElem.hide();
    } else {
      afterElem.show();
    }

    afterElem.html(value);
  }
}
