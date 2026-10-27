import { LightningElement, api, track } from 'lwc';

export default class ProductMultiSelect extends LightningElement {
    @api label = 'Products';

    @api
    get options() {
        return this._options;
    }
    set options(val) {
        this._options = val || [];
    }

    @api
    get value() {
        return this._selectedValues;
    }
    set value(val) {
        this._selectedValues = [...new Set(Array.isArray(val) ? val : [])];
    }

    _options = [];
    @track _selectedValues = [];
    @track isOpen = false;

    get processedOptions() {
        return this._options.map(opt => ({
            value: opt.value,
            label: opt.label,
            selected: this._selectedValues.includes(opt.value),
            optionClass: `slds-media slds-listbox__option slds-listbox__option_plain slds-media_small${
                this._selectedValues.includes(opt.value) ? ' slds-is-selected' : ''
            }`
        }));
    }

    get selectedOptions() {
        const seen = new Set();
        return this._options.filter(opt => {
            if (this._selectedValues.includes(opt.value) && !seen.has(opt.value)) {
                seen.add(opt.value);
                return true;
            }
            return false;
        });
    }

    get hasSelected() {
        return this._selectedValues.length > 0;
    }

    get isEmpty() {
        return !this._options || this._options.length === 0;
    }

    get displayText() {
        const count = new Set(this._selectedValues).size;
        return count === 0 ? '0 Option(s) Selected' : `${count} Option(s) Selected`;
    }

    get comboboxClass() {
        return `slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click${this.isOpen ? ' slds-is-open' : ''}`;
    }

    handleToggle(event) {
        event.stopPropagation();
        this.isOpen = !this.isOpen;
    }

    handleOptionSelect(event) {
        event.stopPropagation();
        const val = event.currentTarget.dataset.value;
        if (this._selectedValues.includes(val)) {
            this._selectedValues = this._selectedValues.filter(v => v !== val);
        } else {
            this._selectedValues = [...this._selectedValues, val];
        }
        this.fireChange();
    }

    handleRemove(event) {
        event.stopPropagation();
        const val = event.currentTarget.dataset.value;
        this._selectedValues = this._selectedValues.filter(v => v !== val);
        this.fireChange();
    }

    fireChange() {
        this.dispatchEvent(new CustomEvent('change', {
            detail: { value: this._selectedValues }
        }));
    }
}