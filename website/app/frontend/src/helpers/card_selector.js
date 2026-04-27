import $ from "../helpers/cash_dom";
import * as R from "ramda";

export default class CardSelector {
  constructor(cards) {
    this.cards = cards;

    // Cache the original button text on init
    this.originalButtonText = R.map(
      (card) => $(card).find("button").text(),
      cards
    );
  }

  select(key, selectedText = "SELECTED") {
    this.reset();

    const selectedCard = this.cards[key];
    if (!selectedCard) return;

    $(selectedCard).addClass("selected");

    const button = $(selectedCard).find("button");
    button.addClass("selected");
    button.html(selectedText);
  }

  reset() {
    R.forEachObjIndexed((card, key) => {
      const cardElem = $(card);
      cardElem.removeClass("selected");

      const button = cardElem.find("button");
      button.removeClass("selected");

      // Restore the original text we cached
      button.html(this.originalButtonText[key]);
    }, this.cards);
  }
}
