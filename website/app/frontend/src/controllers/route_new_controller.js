import ApplicationController from "./application_controller";
import $ from "../helpers/cash_dom";
import * as R from "ramda";
import CardSelector from "../helpers/card_selector";
import { onModalHidden } from "../helpers/modals";
import axios from "axios";
import throttle from "lodash/throttle";
import Validate from "../helpers/validator";
import { disableSubmitOnEnter, Serializer } from "../helpers/forms";

// Connects to data-controller="route-new"
export default class extends ApplicationController {
  static targets = [
    "form",

    "sourceAny",
    "sourceCustom",
    "sourceSelect",

    "presetEverything",
    "presetRaid",
    "presetMoney",
    "presetCustom",
    "typeSelect",

    "selectedServers",
    "selectedTypes",
    "selectedCommunity",
    "selectedChannel",

    "previewSelectedServers",
    "previewSelectedTypes",
    "previewTo",
  ];

  static presets = {
    everything: [
      "base-raid",
      "charge-plant-started",
      "custom",
      "flag-restored",
      "flag-steal-started",
      "flag-stolen",
      "grind-started",
      "hack-started",
      "marxet-item-sold",
      "protection-money-due",
      "protection-money-paid",
    ],
    raid: [
      "base-raid",
      "charge-plant-started",
      "flag-restored",
      "flag-steal-started",
      "flag-stolen",
      "grind-started",
      "hack-started",
    ],
    money: [
      "marxet-item-sold",
      "protection-money-due",
      "protection-money-paid",
    ],
  };

  loadChannels = throttle(() => this.#loadChannels(), 1000);

  connect() {
    this.modal = this.element;
    this.presets = R.clone(this.constructor.presets);
    this.channels = {};

    this.validator = new Validate();
    this.#initializeValidator();

    this.serializer = new Serializer("span[data-routes-new-storage]", "routes");

    this.sourceCards = new CardSelector({
      any: $(this.sourceAnyTarget),
      custom: $(this.sourceCustomTarget),
    });

    this.presetCards = new CardSelector({
      everything: $(this.presetEverythingTarget),
      raid: $(this.presetRaidTarget),
      money: $(this.presetMoneyTarget),
      custom: $(this.presetCustomTarget),
    });

    this.#selectSource("any");
    this.#selectPreset("everything");

    this.#renderPreview();

    // Prepare the modal
    onModalHidden(this.modal, () => this.#clearModal());

    this.nextTick(() => {
      this.disableSlim(this.selectedChannelTarget);
    });
  }

  onSelectedServerChanged(_event) {
    this.#renderPreview();
  }

  onSourceCardChanged(event) {
    const id = $(event.currentTarget).data("id");

    this.#selectSource(id);

    const selectElem = $(this.sourceSelectTarget);

    if (this.selectedSource === "custom") {
      selectElem.show();
    } else {
      selectElem.hide();
    }

    this.#renderPreview();
  }

  onPresetCardChanged(event) {
    const id = $(event.currentTarget).data("id");

    this.#selectPreset(id);

    const selectElem = $(this.typeSelectTarget);

    if (this.selectedPreset === "custom") {
      selectElem.show();
    } else {
      selectElem.hide();
    }

    this.#renderPreview();
  }

  onCommunityChanged(_event) {
    this.loadChannels();
    this.#renderPreview();
  }

  onChannelChanged(_event) {
    this.#renderPreview();
  }

  onTypesChanged(_event) {
    this.#renderPreview();
  }

  onCreateClicked(_event) {
    this.validator.validate().then((isValid) => {
      if (!isValid) return;

      const types =
        this.presets[this.selectedPreset] || $(this.selectedTypesTarget).val();

      const extractID = R.compose(R.head, R.split(":"));
      const server_ids =
        this.selectedSource === "any"
          ? "any"
          : R.map(extractID, $(this.selectedServersTarget).val());

      const community_id = extractID($(this.selectedCommunityTarget).val());
      const channel_id = extractID($(this.selectedChannelTarget).val());

      this.serializer.serialize({
        types,
        server_ids,
        community_id,
        channel_id,
      });

      this.formTarget.submit();
    });
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////

  #initializeValidator() {
    this.validator
      .addField(this.selectedServersTarget, [
        {
          validator: (value, _context) => {
            if (this.selectedSource === "any") return true;

            return !R.isEmpty(value);
          },
          errorMessage: "Please select one or more servers",
        },
      ])
      .addField(this.selectedTypesTarget, [
        {
          validator: (value, _context) => {
            if (this.selectedPreset !== "custom") return true;

            return !R.isEmpty(value);
          },
          errorMessage: "Please select one or more types",
        },
      ])
      .addField(this.selectedCommunityTarget, [{ rule: "required" }])
      .addField(this.selectedChannelTarget, [{ rule: "required" }]);

    disableSubmitOnEnter();
  }

  #selectSource(source) {
    this.selectedSource = source;
    this.sourceCards.select(source);
  }

  #selectPreset(preset) {
    this.selectedPreset = preset;
    this.presetCards.select(preset);
  }

  #clearModal() {
    this.#selectSource("any");
    this.#selectPreset("everything");

    this.clearSlimSelected(this.selectedServersTarget);
    this.clearSlimSelected(this.selectedCommunityTarget);
    this.clearSlimSelected(this.selectedTypesTarget);

    // this.validator.clearAllErrors();
    this.#renderPreview();
  }

  #renderPreview() {
    this.#renderPreviewServers();
    this.#renderPreviewCommunity();
    this.#renderPreviewTypes();
  }

  #renderPreviewServers() {
    const serversElem = $(this.previewSelectedServersTarget);

    if (this.selectedSource === "any") {
      serversElem.html(`<span class="badge bg-secondary">Any Server</span>`);
      return;
    }

    let html = $(this.selectedServersTarget)
      .val()
      .map((id) => id.split(":", 2)[0]) // Take only the server ID
      .map((label) => `<span class="badge bg-secondary">${label}</span>`)
      .join("");

    if (R.isEmpty(html)) {
      html = `<small class="text-muted">Waiting for selection...</small>`;
    }

    serversElem.html(html);
  }

  #renderPreviewCommunity() {
    const toElem = $(this.previewToTarget);

    const communityName = $(this.selectedCommunityTarget)
      .val()
      .split(":", 2)[1];

    if (R.isNil(communityName)) {
      toElem.html(`<small class="text-muted">Waiting for selection...</small>`);
      return;
    }

    let html = `
      <span class="badge bg-primary">${communityName}</span>
      <span class="text-muted mx-1">→</span>
    `;

    const channelName = $(this.selectedChannelTarget).val().split(":", 2)[1];

    if (channelName) {
      html += `<span class="badge bg-info">#${channelName}</span>`;
    } else {
      html += `<small class="text-muted">Waiting for selection...</small>`;
    }

    toElem.html(html);
  }

  #renderPreviewTypes() {
    const typesElem = $(this.previewSelectedTypesTarget);
    const preset = this.presets[this.selectedPreset];

    let values = preset;
    if (R.isNil(values)) {
      values = $(this.selectedTypesTarget).val();
    }

    let html = "";
    if (R.isEmpty(values)) {
      html = `<small class="text-muted">Waiting for selection...</small>`;
    } else {
      html = values
        .map((type) => this.#titleize(type))
        .map((label) => `<small>${label}</small>`)
        .join(`<span class="opacity-50">•</span>`);
    }

    typesElem.html(html);
  }

  #titleize(string) {
    return string
      .replace(/[-_]/g, " ")
      .split(" ")
      .map((word) => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
      .join(" ");
  }

  #loadChannels() {
    const communityID = $(this.selectedCommunityTarget).val().split(":", 2)[0];
    const channelElem = $(this.selectedChannelTarget);

    this.disableSlim(channelElem);
    this.clearSlimData(channelElem);

    if (R.isNil(communityID) || R.isEmpty(communityID)) return;

    const channels = this.channels[communityID] || [];

    // Use the cache if there is one
    if (R.isNotEmpty(channels)) {
      this.setSlimData(channelElem, this.channels[communityID]);
      this.enableSlim(channelElem);
      return;
    }

    axios
      .get(`/communities/${communityID}/channels`, {
        params: { user: true, slim_select: true },
      })
      .then((response) => {
        this.channels[communityID] = response.data.content.channels;
        this.setSlimData(channelElem, this.channels[communityID]);
        this.enableSlim(channelElem);
      })
      .catch((error) => {
        console.error(error);
      });
  }
}
