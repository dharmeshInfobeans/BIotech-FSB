import { LightningElement, track } from 'lwc';
import activeLanguages from '@salesforce/site/activeLanguages';

export default class LanguageSelector extends LightningElement {

    @track selectedLanguage = '';
    @track ready = false;
    @track isOpen = false;

    connectedCallback() {
        const urlParams = new URLSearchParams(window.location.search);
        const langFromUrl = urlParams.get('language');

        let resolvedCode = '';

        if (langFromUrl) {
            const normalized = langFromUrl.replace(/_/g, '-').toLowerCase();
            const matched = activeLanguages.find(
                lang => lang.code.replace(/_/g, '-').toLowerCase() === normalized
            );
            if (matched) resolvedCode = matched.code;
        }

        if (!resolvedCode) {
            const def = activeLanguages.find(l => l.code === 'en-US');
            resolvedCode = def ? def.code : (activeLanguages[0]?.code || '');
        }

        this.selectedLanguage = resolvedCode;
        this.ready = true;

        // Close dropdown when clicking outside
        this._handleOutsideClick = this._handleOutsideClick.bind(this);
        document.addEventListener('click', this._handleOutsideClick);
    }

    disconnectedCallback() {
        document.removeEventListener('click', this._handleOutsideClick);
    }

    _handleOutsideClick(event) {
        if (!this.template.querySelector('.lang-selector')?.contains(event.target)) {
            this.isOpen = false;
        }
    }

    get selectorClass() {
        return this.isOpen ? 'lang-selector lang-selector--open' : 'lang-selector';
    }

    get selectedLabel() {
        const found = activeLanguages.find(l => l.code === this.selectedLanguage);
        return found ? found.label : '';
    }

    get languageOptions() {
        return activeLanguages.map(lang => ({
            label: lang.label,
            value: lang.code,
            isSelected: lang.code === this.selectedLanguage,
            itemClass: lang.code === this.selectedLanguage
                ? 'lang-menu-item lang-menu-item--selected'
                : 'lang-menu-item'
        }));
    }

    toggleDropdown(event) {
        event.stopPropagation();
        this.isOpen = !this.isOpen;
    }

    handleSelect(event) {
        const newLang = event.currentTarget.dataset.value;
        this.isOpen = false;

        if (newLang === this.selectedLanguage) return;

        this.selectedLanguage = newLang;
        const url = new URL(window.location.href);
        url.searchParams.set('language', newLang.replace(/-/g, '_'));
        window.location.href = url.toString();
    }
}