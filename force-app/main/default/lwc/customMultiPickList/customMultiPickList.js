import { LightningElement, api, wire, track } from 'lwc';

export default class CustomMultiPickList extends LightningElement {

    @api title;
    @api placeholder;
    showDD = false;
    init = false;
    isExpanded = false;
    isSelectAll = false;
    @track placeHolderToShow;

    _options = [];
    @api get options() { return this._options; }
    set options(value) {
        const previouslyChecked = new Set(
            (this._options || []).filter(o => o.checked).map(o => o.value)
        );
        this._options = (value || []).map(opt => ({
            label: opt.label,
            value: opt.value,
            show: opt.show !== undefined ? opt.show : true,
            checked: previouslyChecked.has(opt.value)
        }));
        this.dispatchSelectionChange();
    }

    @api label;
    @api required;
    @api showpills;
    @api currentrole;
    @api selectedValues = '';
    @track selectedValuesList = [];

        get computedTitle() {
        return this.selectedValues || this.title || this.placeholder;
    }

    @api
    closeDropdown() {
        this.showDD = false;
    }

    connectedCallback() {
        this.addEventListener('callMethod', this.handleCallMethod.bind(this));
        this.addEventListener('detailChanged', this.handleFilters.bind(this));
        this._handleOutsideClick = this.handleOutsideClick.bind(this);
        document.addEventListener('click', this._handleOutsideClick);
        this.placeHolderToShow = this.placeholder;
    }

    handleOutsideClick(event) {
        if (!this.template.contains(event.target)) {
            this.template.querySelector('[data-id="remove-Input"]').value = '';
            this.showAllOption();
        }
    }

    handleFilters(event) {
        this._options.forEach(option => {
            if (option.value === event.detail) {
                option.checked = true;
            } else {
                option.checked = false;
            }
        });
        this.getSelectedList();
        this.postSelect();
    }

    handleClick() {
        if (this.showDD) {
            this.showDD = !this.showDD;
        } else {
            let opts = this._options ? this._options.filter((element) => element.show).length : 0;
            this.showDD = opts > 0;
            const selectEvent = new CustomEvent('picklistclose', { detail: this.currentrole });
            this.dispatchEvent(selectEvent);
        }
        this.template.addEventListener('click', (event) => {
            event.stopPropagation();
        });
        document.addEventListener('click', () => {
            this.showDD = false;
        });
        this.template.querySelector('[data-id="remove-Input"]').value = '';
        this.showAllOption();
    }

    handleCallMethod(event) {
        this._options = this._options.map(item => ({ ...item, checked: false }));
        this.getSelectedList();
        this.postSelect();
    }

    showAllOption() {
        this._options = this._options.map(option => ({ ...option, show: true }));
    }

    dispatchSelectionChange() {
        const selected = this._options
            .filter(o => o.checked)
            .map(o => o.value);
        this.dispatchEvent(
            new CustomEvent('selectedlistchange', {
                detail: selected
            })
        );
    }

    onSearch(event) {
        this._options = this._options.map(option => ({
            ...option,
            show: option.label.toLowerCase().startsWith(event.detail.value.toLowerCase())
        }));
        let filteredopts = this._options.filter((element) => element.show);
        this.showDD = filteredopts.length > 0;
    }

    onSelect(event) {
        if (event.target.value == 'SelectAll') {
            this._options = this._options.map(option => ({ ...option, checked: event.target.checked }));
        } else {
            this._options = this._options.map(option => {
                if (option.label === event.target.value) {
                    return { ...option, checked: event.target.checked };
                }
                return option;
            });
        }

        let tempVar1 = [];
        this._options.forEach(ele => {
            if (ele.checked) { tempVar1.push(ele.label); }
        });
        if (tempVar1.length > 0) {
            this.selectedValues = tempVar1.join(',');
            this.placeHolderToShow = tempVar1.join(',');
        } else {
            this.selectedValues = '';
            this.placeHolderToShow = this.placeholder;
        }

        this.postSelect();
        this.dispatchSelectionChange();
    }

    onRemove(event) {
        const name = event.detail.name;
        this._options = this._options.map(option => {
            if (option.label === name) {
                return { ...option, checked: false };
            }
            return option;
        });
        this.postSelect();
        this.getSelectedList();
        this.dispatchSelectionChange();
    }

    postSelect() {
        let count = this._options.filter((element) => element.checked).length;
        this.isSelectAll = (count == this._options.length);
        if (this.showpills) {
            let evnt = setInterval(() => {
                if (count > 1) {
                    if (this.template.querySelector('[role="listbox"]').getBoundingClientRect().height >
                        (this.template.querySelectorAll('[role="pill"]')[0].getBoundingClientRect().height + 10)) {
                        this.template.querySelector('[role="more"]').classList.remove('slds-hide');
                    } else {
                        this.template.querySelector('[role="more"]').classList.add('slds-hide');
                    }
                }
                clearInterval(evnt);
            }, 200);
        }
        try {
            if (this.required) {
                if (count > 0) {
                    this.template.querySelector('.cmpl-input').setCustomValidity('');
                }
                this.template.querySelector('.cmpl-input').reportValidity();
            }
        } catch (error) {}
    }

    get showPillView() {
        if (this.showpills) {
            let count = this._options ? this._options.filter((element) => element.checked).length : 0;
            return this.showpills && count > 0;
        }
        return false;
    }

    showMore() {
        this.template.querySelector('.slds-listbox_selection-group').classList.add('slds-listbox_expanded');
        this.template.querySelector('[role="more"]').classList.add('slds-hide');
        this.template.querySelector('[role="less"]').classList.remove('slds-hide');
    }

    showLess() {
        this.template.querySelector('.slds-listbox_selection-group').classList.remove('slds-listbox_expanded');
        this.template.querySelector('[role="less"]').classList.add('slds-hide');
        this.template.querySelector('[role="more"]').classList.remove('slds-hide');
    }

    @api
    getSelectedList() {
        return this._options.filter((element) => element.checked).map((element) => element.label).join(';');
    }

    @api
    setSelectedList(selected) {
        selected?.split(';').forEach(name => {
            const opt = this._options.find(option => option.label === name);
            if (opt) opt.checked = true;
        });
        this.postSelect();
    }

    @api
    setOptions(opts) {
        this._options = opts.map(opt => ({ label: opt.label, value: opt.value, show: true, checked: false }));
    }

    @api
    isValid() {
        if (this.required) {
            let count = this._options ? this._options.filter((element) => element.checked).length : 0;
            if (count == 0) {
                this.template.querySelector('.cmpl-input').setCustomValidity('Please select item(s)');
                this.template.querySelector('.cmpl-input').reportValidity();
                return false;
            }
        }
        return true;
    }

    @api clearTitle() {
        this.selectedValues = '';
        this.placeHolderToShow = this.placeholder;
    }

    disconnectedCallback() {
        document.removeEventListener('click', this._handleOutsideClick);
    }

    @api callFromParent() {
        this.template.querySelector('[data-id="remove-Input"]').value = '';
        this.showAllOption();
    }
}