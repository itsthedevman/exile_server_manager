import ApplicationController from "./application_controller";

// Connects to data-controller="cooldown-filters"
//
// Narrows and orders the cooldown table in the browser. The page loads every running cooldown the community has,
// which tops out around a hundred rows, so hiding what does not match and re-seating what does is all filtering and
// sorting have to mean here.
//
// Nothing here navigates, and that is the point. The selects are the same fields the clear form submits, so what is
// on screen and what would be cleared cannot drift apart, and a control that fires a change event on its own can no
// longer start a request.
export default class extends ApplicationController {
  static targets = [
    "row",
    "count",
    "summary",
    "clear",
    "confirm",
    "empty",
    "reset",
    "sortHeader",
  ];

  connect() {
    this.sortKey = null;
    this.sortDirection = 1;
    this.sortNumeric = false;

    this.apply();
  }

  filter() {
    this.apply();
  }

  // First click on a column sorts it, clicking the same one again reverses it. A numeric column opens highest-first,
  // which puts the longest waits at the top rather than the rows that are seconds from clearing themselves.
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

    this.apply();
  }

  apply() {
    const ordered = this.sortRows(this.rowTargets);
    const tbody = ordered[0]?.parentElement;

    // Appending a node that is already in the document moves it, so this re-seats the rows rather than cloning them.
    if (this.sortKey !== null && tbody) ordered.forEach((row) => tbody.appendChild(row));

    const wanted = this.selection();
    let showing = 0;

    ordered.forEach((row) => {
      const matches = Object.entries(wanted).every(
        ([field, value]) => value === "" || row.dataset[field] === value,
      );

      row.hidden = !matches;
      if (matches) showing += 1;
    });

    this.render(showing, Object.values(wanted).every((value) => value === ""));
    this.updateSortIndicators();
  }

  // Sorts a copy so the server's own order stays the fallback the rows sit in until a column is chosen. Array sort is
  // stable, so that order also breaks ties within equal values.
  sortRows(rows) {
    if (this.sortKey === null) return [...rows];

    const attribute = `sort${this.sortKey.charAt(0).toUpperCase()}${this.sortKey.slice(1)}`;

    return [...rows].sort((first, second) => {
      const a = first.dataset[attribute] ?? "";
      const b = second.dataset[attribute] ?? "";
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

  // Narrow to exactly the row this was clicked on, which is the filter combination that identifies it.
  only(event) {
    const { player, command, server } = event.currentTarget.dataset;

    this.select(this.playerField(), player);
    this.select(this.commandField(), command);
    this.select(this.serverField(), server);
  }

  reset() {
    this.select(this.playerField(), "");
    this.select(this.commandField(), "");
    this.select(this.serverField(), "");
  }

  // Setting select.value alone would filter correctly and leave the visible control still reading "Any player":
  // SlimSelect draws its own markup and only redraws when told, so the change has to go through it.
  select(field, value) {
    this.setSlimSelected(field, value || "", false);
  }

  render(showing, unfiltered) {
    this.countTargets.forEach((element) => {
      element.textContent = `${showing} ${showing === 1 ? "cooldown" : "cooldowns"}`;
    });

    if (this.hasSummaryTarget) this.summaryTarget.hidden = showing === 0;
    if (this.hasEmptyTarget) this.emptyTarget.hidden = showing !== 0;
    if (this.hasResetTarget) this.resetTarget.hidden = unfiltered;

    // An unfiltered clear is the one nobody can picture the end of, so it goes through the modal. Any filter at all
    // means the table in front of them is the whole of what changes, which is a better confirmation than a dialog.
    if (this.hasClearTarget) this.clearTarget.hidden = showing === 0 || unfiltered;
    if (this.hasConfirmTarget) this.confirmTarget.hidden = showing === 0 || !unfiltered;
  }

  selection() {
    return {
      player: this.playerField().value,
      command: this.commandField().value,
      server: this.serverField().value,
    };
  }

  playerField() {
    return this.element.querySelector("[name='player']");
  }

  commandField() {
    return this.element.querySelector("[name='command']");
  }

  serverField() {
    return this.element.querySelector("[name='server']");
  }
}
