import ApplicationController from "./application_controller";

// Live-filters command cards as the user types. Each card carries its own searchable text in
// data-search; matching is a case-insensitive substring test. Cards that don't match are hidden,
// sections left with no visible cards are hidden along with their count badge, and an empty-state
// message shows when nothing matches.
//
// Connects to data-controller="commands-filter"
export default class extends ApplicationController {
  static targets = ["input", "card", "section", "empty"];

  filter() {
    const query = this.inputTarget.value.trim().toLowerCase();

    this.cardTargets.forEach((card) => {
      const haystack = card.dataset.search.toLowerCase();
      card.classList.toggle("d-none", query !== "" && !haystack.includes(query));
    });

    let anyVisible = false;
    this.sectionTargets.forEach((section) => {
      const visibleCards = section.querySelectorAll(
        '[data-commands-filter-target="card"]:not(.d-none)',
      );

      section.classList.toggle("d-none", visibleCards.length === 0);
      this.#updateCount(section, visibleCards.length);

      if (visibleCards.length > 0) anyVisible = true;
    });

    if (this.hasEmptyTarget) {
      this.emptyTarget.classList.toggle("d-none", anyVisible);
    }
  }

  #updateCount(section, visibleCount) {
    const badge = section.querySelector(
      '[data-commands-filter-target="count"]',
    );

    if (!badge) return;

    const noun = badge.dataset.countNoun;
    badge.textContent = noun
      ? `${visibleCount} ${visibleCount === 1 ? noun : `${noun}s`}`
      : visibleCount;
  }
}
