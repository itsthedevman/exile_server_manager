import ApplicationController from "./application_controller";

// Search, online-only filtering, column sorting, and pagination for the server players listing. The whole look-back
// window arrives as one capped read, so every control here works against rows the page already holds and never costs
// another trip to the game server.
//
// Connects to data-controller="players-table"
export default class extends ApplicationController {
  static targets = [
    "row",
    "search",
    "onlineOnly",
    "count",
    "empty",
    "limitWarning",
    "sortHeader",
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
    this.sortKey = null;
    this.sortDirection = 1;
    this.sortNumeric = false;
    this.render();
  }

  // Any change to what's being matched sends the reader back to the first page, since the page they were on may no
  // longer exist under the new filter.
  filter() {
    this.page = 1;
    this.render();
  }

  // Clicking the active column flips its direction; clicking a fresh one adopts its natural first order - A to Z for the
  // name, highest-first for the numeric columns, which is what someone scanning for the top score or richest player
  // wants to see up top.
  sort(event) {
    const header = event.currentTarget;
    const key = header.dataset.sortKey;

    if (this.sortKey === key) {
      this.sortDirection = -this.sortDirection;
    } else {
      this.sortKey = key;
      this.sortNumeric = header.dataset.sortNumeric === "true";
      this.sortDirection = this.sortNumeric ? -1 : 1;
    }

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
    const matches = this.sortRows(this.matchingRows());
    const pageCount = Math.max(1, Math.ceil(matches.length / this.perPageValue));

    this.page = Math.min(this.page, pageCount);

    const start = (this.page - 1) * this.perPageValue;
    const pageRows = matches.slice(start, start + this.perPageValue);
    const visible = new Set(pageRows);

    // Re-seat this page's rows in sorted order, then hide everything not on the page. Appending a node that already
    // lives in the tbody just moves it, so this reorders in place without rebuilding the table.
    if (this.hasRowTarget) {
      const body = this.rowTarget.parentNode;
      pageRows.forEach((row) => body.appendChild(row));
    }

    this.rowTargets.forEach((row) => (row.hidden = !visible.has(row)));

    this.countTarget.textContent = this.countLabel(matches.length);
    this.emptyTarget.hidden = matches.length > 0;

    // The "showing the most recent N" note describes the unfiltered fetch, so it only reads true while the reader is
    // looking at that whole set. Once they search or filter, the count in front of them is the honest one.
    if (this.hasLimitWarningTarget) {
      this.limitWarningTarget.hidden = this.isFiltering();
    }

    this.updateSortIndicators();

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

  // Sorts a copy so the original target order - the query's own online-first, most-recent-first - stays the fallback the
  // rows return to once no column is chosen. Array sort is stable, so that order also breaks ties within equal values.
  sortRows(rows) {
    if (this.sortKey === null) return rows;

    const attribute = this.sortAttribute();

    return [...rows].sort((first, second) => {
      const a = first.dataset[attribute];
      const b = second.dataset[attribute];

      const comparison = this.sortNumeric ? Number(a) - Number(b) : a.localeCompare(b);

      return comparison * this.sortDirection;
    });
  }

  updateSortIndicators() {
    this.sortHeaderTargets.forEach((header) => {
      const indicator = header.querySelector(".sort-indicator");
      if (!indicator) return;

      const active = header.dataset.sortKey === this.sortKey;
      const direction = this.sortDirection === 1 ? "bi-chevron-up" : "bi-chevron-down";

      indicator.className = `bi small ms-1 sort-indicator ${
        active ? direction : "bi-chevron-expand text-muted"
      }`;
    });
  }

  isFiltering() {
    const searching = this.hasSearchTarget && this.searchTarget.value.trim() !== "";
    const onlineOnly = this.hasOnlineOnlyTarget && this.onlineOnlyTarget.checked;

    return searching || onlineOnly;
  }

  // data-sort-key="score" addresses the row's data-sort-score, which reaches the element as dataset.sortScore.
  sortAttribute() {
    return `sort${this.sortKey.charAt(0).toUpperCase()}${this.sortKey.slice(1)}`;
  }

  pageCount() {
    return Math.max(1, Math.ceil(this.matchingRows().length / this.perPageValue));
  }

  countLabel(count) {
    return `${count} ${count === 1 ? "player" : "players"}`;
  }
}
