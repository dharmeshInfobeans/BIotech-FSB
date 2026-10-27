import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getLedgers from '@salesforce/apex/SAPLedgerService.getLedgers';
import getDownloadUrl from '@salesforce/apex/SAPLedgerService.getDownloadUrl';

import getContentVersionId from '@salesforce/apex/SAPLedgerService.getContentVersionId';

import BIOTECH_LOGO from '@salesforce/resourceUrl/CompanyLogo';
import { FIELD_LABEL_TRANSLATIONS } from './distributorLedgeri18n';
import LANG from '@salesforce/i18n/lang';

const STATUS_LIST = ['Sent', 'Completed', 'Declined', 'Expired'];

const STATUS_BADGE_MAP = {
    Sent:      { badge: 'dp-status-badge badge-draft',     dot: 'status-dot dot-amber' },
    Completed: { badge: 'dp-status-badge badge-signed',    dot: 'status-dot dot-green' },
    Declined:  { badge: 'dp-status-badge badge-declined',  dot: 'status-dot dot-red'   },
    Expired:   { badge: 'dp-status-badge badge-abandoned', dot: 'status-dot dot-grey'  }
};

const DEFAULT_BADGE = { badge: 'dp-status-badge badge-abandoned', dot: 'status-dot dot-grey' };

const PILL_DOT_MAP = {
    Sent:      'pill-dot dot-amber',
    Completed: 'pill-dot dot-green',
    Declined:  'pill-dot dot-red',
    Expired:   'pill-dot dot-grey'
};

const STATUS_LABEL_MAP = {
    Sent:      'Sign Request',
    Completed: 'Signed',
    Declined:  'Declined',
    Expired:   'Expired'
};

export default class DistributorPortal extends NavigationMixin(LightningElement) {

    // ─── navigation ───────────────────────────────────────────
    @track activeNav = 'ledgers';
    logoUrl = BIOTECH_LOGO;

    get navItems() {
        return [{
            id: 'ledgers',
            label: this.t('Customer Ledgers'),
            icon: 'utility:file',
            cls: 'dp-nav-item dp-nav-active'
        }];
    }

    get isLedgers() { return this.activeNav === 'ledgers'; }

    handleNavClick() {
        this.activeNav = 'ledgers';
    }

    @track allLedgers     = [];
    @track selectedStatus = 'Sent';
    @track isLoading      = false;

    @track counts = { Sent: 0, Completed: 0, Declined: 0, Expired: 0 };

    // ─── preview modal state ─────────────────────────────────
    @track showPreviewModal  = false;
    @track previewUrl        = '';
    @track previewVersionId  = '';
    @track previewLedgerName = '';
    @track isModalLoading    = false;

    get sentCount()      { return this.counts.Sent; }
    get completedCount() { return this.counts.Completed; }
    get declinedCount()  { return this.counts.Declined; }
    get expiredCount()   { return this.counts.Expired; }

    // Filtered view shown in the card grid
    get ledgers() {
        return this.allLedgers
            .filter(r => r.Status__c === this.selectedStatus)
            .map(row => ({
                ...row,
                accountId:      row.Account__r?.Name,
                accountUrl:     '/' + row.Account__c,
                accountName:    row.Account__r?.Name,
                statusBadgeCls: (STATUS_BADGE_MAP[row.Status__c] || DEFAULT_BADGE).badge,
                statusDotCls:   (STATUS_BADGE_MAP[row.Status__c] || DEFAULT_BADGE).dot,
                statusLabel:    this.t(STATUS_LABEL_MAP[row.Status__c] || row.Status__c),
                quarterYear:    this.getQuarterYear(row.Statement_Date__c)
            }));
    }

    getQuarterYear(dateStr) {
        if (!dateStr) return '';
        const [year, month] = dateStr.split('-').map(Number);
        const quarter = Math.ceil(month / 3);
        return `Q${quarter} ${year}`;
    }

    get isEmpty()    { return !this.isLoading && this.ledgers.length === 0; }
    get hasLedgers() { return !this.isLoading && this.ledgers.length > 0;  }

    // ─── status pills ─────────────────────────────────────────
    get statusPills() {
        return STATUS_LIST.map(s => ({
            value:  s,
            label:  this.t(STATUS_LABEL_MAP[s] || s),
            dotCls: PILL_DOT_MAP[s],
            count:  this.counts[s] || 0,
            cls:    `dp-pill${this.selectedStatus === s ? ' dp-pill-active' : ''}`
        }));
    }

    // ─── language ────────────────────────────────────────────
    userLang = 'en';
    @track langDropdownOpen = false;

    languageOptions = [
        { code: 'en', label: 'English',   badge: 'EN' },
        { code: 'zh', label: '中文',       badge: 'ZH' },
        { code: 'it', label: 'Italiano',   badge: 'IT' },
        { code: 'es', label: 'Español',    badge: 'ES' },
        { code: 'fr', label: 'Français',   badge: 'FR' },
        { code: 'ar', label: 'العربية',    badge: 'AR' },
        { code: 'pl', label: 'Polski',     badge: 'PL' },
        { code: 'pt', label: 'Português',  badge: 'PT' },
        { code: 'ru', label: 'Русский',    badge: 'RU' },
        { code: 'ur', label: 'اردو',       badge: 'UR' },
        { code: 'id', label: 'Bahasa',     badge: 'ID' },
        { code: 'de', label: 'Deutsch',    badge: 'DE' },
        { code: 'ja', label: '日本語',      badge: 'JA' },
    ];

    get currentLanguageLabel() {
        const opt = this.languageOptions.find(o => o.code === this.userLang);
        return opt ? opt.label : 'English';
    }

    get currentLanguageBadge() {
        const opt = this.languageOptions.find(o => o.code === this.userLang);
        return opt ? opt.badge : 'EN';
    }

    get languageDropdownItems() {
        return this.languageOptions.map(o => ({
            ...o,
            isSelected: o.code === this.userLang,
            itemClass: 'lang-dropdown-item' + (o.code === this.userLang ? ' lang-selected' : '')
        }));
    }

    toggleLangDropdown() {
        this.langDropdownOpen = !this.langDropdownOpen;
    }

    handleLangSelect(event) {
        const li = event.target.closest('[data-code]');
        if (!li) return;
        const code = li.dataset.code;
        if (code && code !== this.userLang) {
            this.userLang = code;
        }
        this.langDropdownOpen = false;
    }

    closeLangDropdown() {
        this.langDropdownOpen = false;
    }

    _getUserLanguage() {
        const htmlLang = document.documentElement.lang;
        if (htmlLang) {
            const hl = htmlLang.substring(0, 2).toLowerCase();
            if (hl && hl !== 'en') return hl;
        }
        if (LANG) {
            const sfLang = LANG.substring(0, 2);
            if (sfLang && sfLang !== 'en') return sfLang;
        }
        const parts = window.location.pathname.split('/');
        const langFull = parts[2];
        if (!langFull) return 'en';
        return langFull.substring(0, 2);
    }

    t(key) {
        if (this.userLang === 'en') return key;
        const entry = FIELD_LABEL_TRANSLATIONS[key];
        if (entry && entry[this.userLang]) return entry[this.userLang];
        return key;
    }

    // ─── translated label getters ─────────────────────────────
    get labelSelectLanguage()  { return this.t('Select Language'); }
    get labelBrandSub()        { return this.t('All Your Statements in One Place'); }
    get labelDistributor()     { return this.t('Distributor'); }
    get labelNavigation()      { return this.t('NAVIGATION'); }
    get labelQuickStats()      { return this.t('QUICK STATS'); }
    get labelStatSignRequest() { return this.t('Sign Request'); }
    get labelStatSigned()      { return this.t('Signed'); }
    get labelStatDeclined()    { return this.t('Declined'); }
    get labelStatExpired()     { return this.t('Expired'); }
    get labelPageTitle()       { return this.t('Customer Ledgers'); }
    get labelPageDesc()        { return this.t('View and download ledger statements filtered by status.'); }
    get labelRefresh()         { return this.t('Refresh'); }
    get labelFilterByStatus()  { return this.t('Filter by status:'); }
    get labelNoLedgersFound()  { return this.t('No Ledgers Found'); }
    get labelNoLedgersText()   { return this.t('There are no ledgers matching the selected status. Try a different filter.'); }
    get labelStatementDate()   { return this.t('Statement Date'); }
    get labelQuarter()         { return this.t('Quarter'); }
    get labelView()            { return this.t('View'); }
    get labelDownload()        { return this.t('Download'); }
    get labelClose()           { return this.t('Close'); }
    get labelLoadingDocument() { return this.t('Loading document…'); }

    // ─── lifecycle ────────────────────────────────────────────
    connectedCallback() {
        this.userLang = this._getUserLanguage();
        this.loadAllLedgers();
    }

    // ─── data loading ─────────────────────────────────────────
    loadAllLedgers() {
        this.isLoading = true;

        const promises = STATUS_LIST.map(status =>
            getLedgers({ status })
                .then(rows => ({ status, rows: rows || [] }))
                .catch(error => {
                    console.error('Apex Error for status:', status);
                    console.error(JSON.stringify(error));
                    return { status, rows: [] };
                })
        );

        Promise.all(promises)
            .then(results => {
                const newCounts = { Sent: 0, Completed: 0, Declined: 0, Expired: 0 };
                const combined = [];

                results.forEach(({ status, rows }) => {
                    newCounts[status] = rows.length;
                    combined.push(...rows);
                });

                this.counts = newCounts;
                this.allLedgers = combined;
                this.isLoading = false;
            })
            .catch(error => {
                console.error('Promise Error:', error);
                this.isLoading = false;
            });
    }

    // ─── handlers ─────────────────────────────────────────────
    handleStatusPillClick(event) {
        this.selectedStatus = event.currentTarget.dataset.value;
    }

    handleRefresh() {
        this.allLedgers = [];
        this.loadAllLedgers();
    }

    // ─── preview modal handlers (same pattern as admin) ───────
    handleView(event) {
        const recordId = event.currentTarget.dataset.id;
        const row = this.ledgers.find(r => r.Id === recordId);

        this.previewLedgerName = row ? row.Contact_Name__c : 'Document';
        this.showPreviewModal  = true;
        this.isModalLoading    = true;
        this.previewUrl        = '';
        this.previewVersionId  = '';

        getContentVersionId({ ledgerId: recordId })
            .then(versionId => {
                if (!versionId) {
                    console.error('No ContentVersion found for ledger:', recordId);
                    this.isModalLoading = false;
                    return;
                }
                this.previewVersionId = versionId;
                this.previewUrl       = '/sfc/servlet.shepherd/version/renditionDownload'
                                      + '?rendition=THUMB720BY480'
                                      + '&versionId=' + versionId;
                this.isModalLoading   = false;
            })
            .catch(error => {
                console.error('Preview error', error);
                this.isModalLoading = false;
            });
    }

    handleClosePreview() {
        this.showPreviewModal  = false;
        this.previewUrl        = '';
        this.previewVersionId  = '';
        this.previewLedgerName = '';
    }

    handleDownloadFromPreview() {
        if (this.previewVersionId) {
            window.open('/sfc/servlet.shepherd/version/download/' + this.previewVersionId, '_blank');
        }
    }

    handleDownload(event) {
        const recordId = event.currentTarget.dataset.id;
        getDownloadUrl({ ledgerId: recordId })
            .then(url => window.open(url, '_blank'))
            .catch(err => console.error(err));
    }
}