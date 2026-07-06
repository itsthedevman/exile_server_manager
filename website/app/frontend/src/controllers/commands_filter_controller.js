import ApplicationController from "./application_controller";

// Live-filters the command cards on commands#index by usage name as the user
// types. Matching is a substring test against each card's usage with the leading
// slash dropped, so "/server gamble" matches "server gamble" or "gamble". Cards
// that don't match are hidden, sections left with no visible cards are hidden,
// and an empty-state message shows when nothing matches.
//
// Connects to data-controller="commands-filter"
export default class extends ApplicationController {
  static targets = ["input", "card", "section", "empty"];

  filter() {
    const query = this.inputTarget.value.trim().toLowerCase();

    this.cardTargets.forEach((card) => {
      const usage = card.dataset.usage.replace(/^\//, "").toLowerCase();
      card.classList.toggle("d-none", query !== "" && !usage.includes(query));
    });

    let anyVisible = false;
    this.sectionTargets.forEach((section) => {
      const hasVisibleCard = section.querySelector(
        '[data-commands-filter-target="card"]:not(.d-none)',
      );
      section.classList.toggle("d-none", !hasVisibleCard);
      if (hasVisibleCard) anyVisible = true;
    });

    if (this.hasEmptyTarget) {
      this.emptyTarget.classList.toggle("d-none", anyVisible);
    }
  }
}
