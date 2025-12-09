var __defProp = Object.defineProperty;
var __getOwnPropSymbols = Object.getOwnPropertySymbols;
var __hasOwnProp = Object.prototype.hasOwnProperty;
var __propIsEnum = Object.prototype.propertyIsEnumerable;
var __defNormalProp = (obj, key, value) => key in obj ? __defProp(obj, key, { enumerable: true, configurable: true, writable: true, value }) : obj[key] = value;
var __spreadValues = (a, b) => {
  for (var prop in b || (b = {}))
    if (__hasOwnProp.call(b, prop))
      __defNormalProp(a, prop, b[prop]);
  if (__getOwnPropSymbols)
    for (var prop of __getOwnPropSymbols(b)) {
      if (__propIsEnum.call(b, prop))
        __defNormalProp(a, prop, b[prop]);
    }
  return a;
};

// js/hooks/sortable_column.js
var SortableColumn = {
  mounted() {
    this.handleClick = (event) => {
      if (event.shiftKey) {
        event.preventDefault();
        this.pushEvent("sort", {
          sort: this.el.getAttribute("phx-value-sort"),
          shift_key: true
        });
      }
    };
    this.el.addEventListener("click", this.handleClick);
  },
  destroyed() {
    this.el.removeEventListener("click", this.handleClick);
  }
};

// js/hooks/download.js
var Download = {
  mounted() {
    this.handleEvent("download", ({ path }) => {
      const link = document.createElement("a");
      link.href = path;
      link.setAttribute("download", "");
      link.style.display = "none";
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
    });
  }
};

// js/hooks/filter_toggle.js
var FilterToggle = {
  mounted() {
    this.filtersContainer = document.getElementById("filters-container");
    this.toggleText = document.getElementById("filter-toggle-text");
    if (this.toggleText) {
      this.handleEvent("toggle_filters", () => {
        this.toggleFilters();
      });
    }
  },
  // Method to toggle the filters visibility
  toggleFilters() {
    if (!this.filtersContainer || !this.toggleText)
      return;
    const isHidden = this.filtersContainer.classList.contains("hidden");
    if (isHidden) {
      this.filtersContainer.classList.remove("hidden");
      this.toggleText.innerText = "Hide Filters";
    } else {
      this.filtersContainer.classList.add("hidden");
      this.toggleText.innerText = "Show Filters";
    }
  }
};

// ../deps/live_select/priv/static/live_select.min.js
function o(e, t) {
  let i;
  return (...s) => {
    clearTimeout(i), i = setTimeout(() => {
      e.apply(this, s);
    }, t);
  };
}
var live_select_min_default = { LiveSelect: { textInput() {
  return this.el.querySelector("input[type=text]");
}, debounceMsec() {
  return parseInt(this.el.dataset.debounce);
}, updateMinLen() {
  return parseInt(this.el.dataset.updateMinLen);
}, maybeStyleClearButton() {
  const e = this.el.querySelector("button[phx-click=clear]");
  e && (this.textInput().parentElement.style.position = "relative", e.style.position = "absolute", e.style.top = "0px", e.style.bottom = "0px", e.style.right = "5px", e.style.display = "block");
}, pushEventToParent(e, t) {
  const i = this.el.dataset.phxTarget;
  i ? this.pushEventTo(i, e, t) : this.pushEvent(e, t);
}, attachDomEventHandlers() {
  this.textInput().onkeydown = (t) => {
    t.code === "Enter" && t.preventDefault(), this.pushEventTo(this.el, "keydown", { key: t.code });
  }, this.changeEvents = o((t, i, s) => {
    this.pushEventTo(this.el, "change", { text: s }), this.pushEventToParent("live_select_change", { id: this.el.id, field: i, text: s });
  }, this.debounceMsec()), this.textInput().oninput = (t) => {
    const i = t.target.value.trim(), s = this.el.dataset.field;
    i.length >= this.updateMinLen() ? this.changeEvents(this.el.id, s, i) : this.pushEventTo(this.el, "options_clear", {});
  };
  const e = this.el.querySelector("ul");
  e && (e.onmousedown = (t) => {
    const i = t.target.closest("div[data-idx]");
    i && (this.pushEventTo(this.el, "option_click", { idx: i.dataset.idx }), t.preventDefault());
  }), this.el.querySelectorAll("button[data-idx]").forEach((t) => {
    t.onclick = (i) => {
      this.pushEventTo(this.el, "option_remove", { idx: t.dataset.idx });
    };
  });
}, setInputValue(e) {
  this.textInput().value = e;
}, inputEvent(e, t) {
  const i = t === "single" ? "input.single-mode" : e.length === 0 ? "input[data-live-select-empty]" : "input[type=hidden]";
  this.el.querySelector(i).dispatchEvent(new Event("input", { bubbles: true }));
}, mounted() {
  this.maybeStyleClearButton(), this.handleEvent("parent_event", ({ id: e, event: t, payload: i }) => {
    this.el.id === e && this.pushEventToParent(t, i);
  }), this.handleEvent("select", ({ id: e, selection: t, mode: i, current_text: s, input_event: l, parent_event: n }) => {
    if (this.el.id === e) {
      if (this.selection = t, i === "single") {
        const h = t.length > 0 ? t[0].label : s;
        this.setInputValue(h);
      } else
        this.setInputValue(s);
      l && this.inputEvent(t, i), n && this.pushEventToParent(n, { id: e });
    }
  }), this.handleEvent("active", ({ id: e, idx: t }) => {
    if (this.el.id === e) {
      const i = this.el.querySelector(`div[data-idx="${t}"]`);
      i && i.scrollIntoView({ block: "nearest" });
    }
  }), this.attachDomEventHandlers();
}, updated() {
  this.maybeStyleClearButton(), this.attachDomEventHandlers();
}, reconnected() {
  this.selection && this.selection.length > 0 && this.pushEventTo(this.el.id, "selection_recovery", this.selection);
} } };

// js/hooks/hooks.js
var TableHooks = __spreadValues({
  SortableColumn,
  Download,
  FilterToggle
}, live_select_min_default);
var hooks_default = TableHooks;
export {
  TableHooks,
  hooks_default as default
};
