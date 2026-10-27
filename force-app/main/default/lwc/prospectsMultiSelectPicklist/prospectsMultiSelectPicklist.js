import { LightningElement, api } from 'lwc';

// Compact "dropdown button that opens a checkbox list" multi-select, styled to sit in the
// same filter row as the rest of prospectsFilterBar. Dispatches the same
// {detail: {value: [...]}} shape lightning-dual-listbox uses, so the parent's change handlers
// don't need to know which widget is behind this.
export default class ProspectsMultiSelectPicklist extends LightningElement {
    @api label;
    @api options = [];
    @api disabled = false;

    _value = [];
    isOpen = false;
    searchTerm = '';
    _searchFocused = false;

    @api
    get value() {
        return this._value;
    }

    set value(val) {
        this._value = val || [];
    }

    // Case-insensitive substring match on label - the same filtering approach used everywhere
    // else in this project (e.g. the export tool's own search box), applied client-side since
    // every dropdown's option list is already loaded in full (at most a few hundred rows, for
    // Owner - no need for a server round trip just to filter what's already in memory.
    get displayOptions() {
        const selected = new Set(this._value || []);
        const term = (this.searchTerm || '').trim().toLowerCase();
        const source = term
            ? (this.options || []).filter((opt) => (opt.label || '').toLowerCase().includes(term))
            : this.options || [];
        // Selected options float to the top instantly, live, as each box is checked/unchecked
        // (Array.sort is stable, so original relative order is preserved within each group) - so
        // the current selection is always visible without scrolling.
        const sorted = [...source].sort((a, b) => {
            const aFirst = selected.has(a.value) ? 0 : 1;
            const bFirst = selected.has(b.value) ? 0 : 1;
            return aFirst - bFirst;
        });
        return sorted.map((opt) => ({
            label: opt.label,
            value: opt.value,
            checked: selected.has(opt.value)
        }));
    }

    get hasNoOptions() {
        return this.displayOptions.length === 0;
    }

    get emptyMessage() {
        return this.searchTerm ? 'No matches' : 'No options';
    }

    get summaryLabel() {
        const count = (this._value || []).length;
        if (count === 0) {
            return 'All';
        }
        if (count === 1) {
            const match = (this.options || []).find((o) => o.value === this._value[0]);
            return match ? match.label : String(this._value[0]);
        }
        return count + ' selected';
    }

    renderedCallback() {
        // Force-close if this picklist becomes disabled while its dropdown happens to be open
        // (e.g. the user clears the Sales/Marketing selection that this one depends on).
        if (this.disabled && this.isOpen) {
            this.isOpen = false;
            this.searchTerm = '';
            return;
        }
        // Autofocus the search box on open, so typing to filter works immediately without an
        // extra click - _searchFocused guards this to once per open (renderedCallback fires on
        // every re-render, e.g. every keystroke, and re-focusing on each of those would steal
        // the cursor position or interrupt typing).
        if (this.isOpen && !this._searchFocused) {
            const input = this.template.querySelector('.ms-search-input');
            if (input) {
                input.focus();
                this._searchFocused = true;
            }
        } else if (!this.isOpen) {
            this._searchFocused = false;
        }
    }

    toggleDropdown(event) {
        event.stopPropagation();
        if (this.disabled) {
            return;
        }
        this.isOpen = !this.isOpen;
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    handleSearchInput(event) {
        this.searchTerm = event.target.value;
    }

    // A full-viewport backdrop rendered only while open, instead of a document-level click
    // listener: this component sits nested several shadow trees deep (picklist ->
    // prospectsFilterBar -> prospectsDashboard), and a document listener's event.target/
    // composedPath gets unreliable to reason about across that many boundaries - one such attempt
    // here previously left the dropdown unable to close after checking a box. A backdrop sidesteps
    // all of that: it sits behind the dropdown panel (lower z-index) and in front of everything
    // else, so a click anywhere outside the panel always lands on the backdrop and closes it,
    // while clicks on the panel itself land on the panel, not the backdrop underneath, and never
    // close it.
    closeDropdown() {
        this.isOpen = false;
    }

    handleOptionChange(event) {
        const clickedValue = event.target.dataset.value;
        const checked = event.target.checked;
        const current = new Set(this._value || []);
        if (checked) {
            current.add(clickedValue);
        } else {
            current.delete(clickedValue);
        }
        this._value = Array.from(current);
        this.dispatchEvent(new CustomEvent('change', { detail: { value: this._value } }));
    }
}