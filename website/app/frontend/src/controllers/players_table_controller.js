import ApplicationController from "./application_controller";

// Search, online-only filtering, and pagination for the server players listing. The whole look-back window arrives
// as one capped read, so every control here works against rows the page already holds and never costs another trip
// to the game server.
//
// Connects to data-controller="players-table"
export default class extends ApplicationController {
  static targets = [
    "row",
    "search",
    "onlineOnly",
    "count",
    "empty",
    "pagination",
    "pageInfo",
    "previous",
    "next",
  ];

  static values = {
    perPage: { type: Number, default: 50 },
  };

  connect() {
    this.page = 1;
    this.render();
  }

  // Any change to what's being matched sends the reader back to the first page, since the page they were on may no
  // longer exist under the new filter.
  filter() {
    this.page = 1;
    this.render();
  }

  previous() {
    this.page = Math.max(1, this.page - 1);
    this.render();
  }

  next() {
    this.page = Math.min(this.pageCount(), this.page + 1);
    this.render();
  }

  render() {
    const matches = this.matchingRows();
    const pageCount = Math.max(1, Math.ceil(matches.length / this.perPageValue));

    this.page = Math.min(this.page, pageCount);

    const start = (this.page - 1) * this.perPageValue;
    const visible = new Set(matches.slice(start, start + this.perPageValue));

    this.rowTargets.forEach((row) => (row.hidden = !visible.has(row)));

    this.countTarget.textContent = this.countLabel(matches.length);
    this.emptyTarget.hidden = matches.length > 0;
    this.paginationTarget.hidden = pageCount === 1;
    this.pageInfoTarget.textContent = `Page ${this.page} of ${pageCount}`;
    this.previousTarget.disabled = this.page === 1;
    this.nextTarget.disabled = this.page === pageCount;
  }

  matchingRows() {
    const query = this.hasSearchTarget
      ? this.searchTarget.value.trim().toLowerCase()
      : "";

    const onlineOnly = this.hasOnlineOnlyTarget && this.onlineOnlyTarget.checked;

    return this.rowTargets.filter((row) => {
      if (onlineOnly && row.dataset.online !== "true") return false;

      return query === "" || row.dataset.search.includes(query);
    });
  }

  pageCount() {
    return Math.max(1, Math.ceil(this.matchingRows().length / this.perPageValue));
  }

  countLabel(count) {
    return `${count} ${count === 1 ? "player" : "players"}`;
  }
}
