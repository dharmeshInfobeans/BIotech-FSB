/**
 * @file eventPlannerCustomerCard.js
 * @description Refactored customer card component for displaying account/lead information
 * with modern LWC patterns, SLDS 2.0 design, and improved validation logic
 * @author Refactored for modern LWC patterns
 * @version 2.0
 */

import { LightningElement, api, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { fireEvent } from 'c/pubsub';

// Apex Imports
import getCurrentUser from '@salesforce/apex/calendarPlanningMobileController.getCurrentUser';
import getCustomlabel from '@salesforce/apex/calendarPlanningMobileController.getLabels';

// Custom Labels
import Domestic from '@salesforce/label/c.Domestic';

// Constants
const CE_DATE_EXPIRY_DAYS = 364;
const RECORD_TYPE_DOMESTIC_DOCTOR = 'Domestic-Doctor/Hospital';
const RECORD_TYPE_DOMESTIC_ORTHO = 'Domestic - Ortho';
const RECORD_TYPE_DOMESTIC_DISTRIBUTOR = 'Domestic-Distributor';
const USER_TYPE_DOMESTIC_ORTHO = 'Domestic Ortho';
const ACCOUNT_STATUS_ACTIVATED = 'Activated';

export default class EventPlannerCustomerCard extends LightningElement {
    // ========== Public API Properties ==========

    /**
     * Account or Lead object containing customer data
     * @type {Object}
     */
    @api account;

    /**
     * Custom labels for internationalization
     * @type {Object}
     */
    @api labels = {};

    /**
     * Current region filter (Domestic, International, Turkey)
     * @type {String}
     */
    @api region = '';

    // ========== Private Properties ==========

    /**
     * Page reference for pubsub events
     * @type {Object}
     */
    @wire(CurrentPageReference) pageRef;

    /**
     * Current user information
     * @type {Object}
     */
    currentUser;

    /**
     * User's region name/type
     * @type {String}
     */
    userRegionName;

    /**
     * Translated confirmation messages
     * @type {Object}
     */
    confirmationmessage = {};

    /**
     * Controls visibility of Ce-Cis confirmation modal
     * @type {Boolean}
     */
    showCeCisConfirmationModal = false;

    /**
     * CE rating extracted from card click
     * @type {String}
     */
    ceRating;

    /**
     * CIS rating extracted from card click
     * @type {String}
     */
    cisRating;

    /**
     * Show data attribute (Account/Lead indicator)
     * @type {String}
     */
    showDataAttribute;

    /**
     * Custom labels reference
     * @type {Object}
     */
    customLabels = {
        Domestic
    };

    // ========== Wire Adapters ==========

    /**
     * Wire adapter to fetch current user information
     * @param {Object} result - Wired result containing data or error
     */
    @wire(getCurrentUser)
    wiredUser({ error, data }) {
        if (data) {
            this.currentUser = data;
            this.userRegionName = data.User_Type__c;
        } else if (error) {
            console.error('Error fetching current user:', error);
        }
    }

    /**
     * Wire adapter to fetch translated custom labels
     * @param {Object} result - Wired result containing data or error
     */
    @wire(getCustomlabel)
    wiredLabels({ error, data }) {
        if (data) {
            this.confirmationmessage = data;
        } else if (error) {
            console.error('Error fetching labels:', error);
        }
    }

    // ========== Computed Properties ==========

    /**
     * Checks if location information is available
     * @returns {Boolean} True if billing city or country exists
     */
    get hasLocation() {
        return !!(this.account?.BillingCity || this.account?.BillingCountry);
    }

    /**
     * Checks if CE-CIS rating information is available
     * @returns {Boolean} True if CERating or CISRating exists
     */
    get hasRatings() {
        return !!(this.account?.CERating || this.account?.CISRating);
    }

    /**
     * Formats location display string
     * @returns {String} Formatted location string (City, Country)
     */
    get locationDisplay() {
        const city = this.account?.BillingCity || '';
        const country = this.account?.BillingCountry || '';
        return [city, country].filter(Boolean).join(', ');
    }

    /**
     * Checks if the record is a Lead
     * @returns {Boolean} True if record type is Lead
     */
    get isLead() {
        return this.account?.show === 'Lead';
    }

    /**
     * Checks if the record is an Opportunity
     * @returns {Boolean} True if record type is Opportunity
     */
    get isOpportunity() {
        return this.account?.show === 'Opportunity';
    }

    /**
     * Checks if the record is a Lead or Opportunity
     * @returns {Boolean} True if record type is Lead or Opportunity
     */
    get isLeadOrOpportunity() {
        return this.isLead || this.isOpportunity;
    }

    /**
     * Checks if Account name should be displayed (Opportunities only)
     * @returns {Boolean} True if record is an Opportunity and has AccountName
     */
    get showAccountName() {
        return this.isOpportunity && this.account?.AccountName;
    }

    /**
     * Returns the display title with account name in parentheses for opportunities
     * @returns {String} Formatted title string
     */
    get displayTitle() {
        //console.log('OUTPUT : account',JSON.stringify(this.account));
        if (this.isOpportunity && this.account?.AccountName) {
            return `${this.account.Name} (${this.account.AccountName})`;
        }
        return this.account?.Name || '';
    }

    /**
     * Extracts and formats contact list from account
     * @returns {Array} Array of contact objects with label and value
     */
    get contactList() {
        if (!this.account?.Contacts) {
            return [];
        }

        try {
            const contacts = JSON.parse(JSON.stringify(this.account.Contacts));
            return contacts.map(contact => ({
                label: contact.Name,
                value: contact.Id
            }));
        } catch (error) {
            console.error('Error parsing contacts:', error);
            return [];
        }
    }

    /**
     * Calculates days since last CE date
     * @returns {Number} Number of days since last CE date
     */
    get daysSinceLastCE() {
        if (!this.account?.last_CE_date__c) {
            return Infinity;
        }

        const lastCEDate = new Date(this.account.last_CE_date__c);
        const today = new Date();
        const diffInTime = today.getTime() - lastCEDate.getTime();
        return Math.floor(diffInTime / (1000 * 3600 * 24));
    }

    // ========== Event Handlers ==========

    /**
     * Handles card click event - main entry point for validation logic
     * @param {Event} event - Click event
     */
    handleCardClick(event) {
        console.log('event on card',event.currentTarget.dataset);
        // Extract data attributes
        // Note: HTML data attributes convert undefined/null to string "undefined" or empty string
        // We need to convert them back to actual undefined for proper comparison
        const cisRatingRaw = event.currentTarget.dataset.cisrating;
        const ceRatingRaw = event.currentTarget.dataset.cerating;

        this.cisRating = (cisRatingRaw === 'undefined' || cisRatingRaw === '' || cisRatingRaw === null) ? undefined : cisRatingRaw;
        this.ceRating = (ceRatingRaw === 'undefined' || ceRatingRaw === '' || ceRatingRaw === null) ? undefined : ceRatingRaw;
        this.showDataAttribute = event.currentTarget.dataset.show;

        console.log('Card clicked - CIS Rating:', this.cisRating, 'CE Rating:', this.ceRating, 'Lead:', this.account?.Lead, 'Existing:', this.account?.Existing);

        // Publish product data event (legacy support)
        if (this.account?.Product) {
            fireEvent(this.pageRef, 'ProductshowData', this.account.Product);
        }

        // Run validation logic
        if (this.shouldBlockDomesticValidation()) {
            this.handleDomesticValidationBlock();
        } else {
            this.handleStandardValidation();
        }
    }

    /**
     * Handles Ce-Cis confirmation modal cancel action
     */
    handleCeCisCancel() {
        this.showCeCisConfirmationModal = false;
    }

    /**
     * Handles Ce-Cis confirmation modal continue action
     */
    handleCeCisContinue() {
        this.showCeCisConfirmationModal = false;
        this.fireCalendarEvent();
    }

    // ========== Validation Methods ==========

    /**
     * Determines if domestic-specific validation should block standard flow
     * @returns {Boolean} True if domestic validation rules apply
     */
    shouldBlockDomesticValidation() {
        // Skip domestic validation for Opportunities
        if (this.account?.show === 'Opportunity') {
            return false;
        }

        const isDomesticRegion = this.customLabels.Domestic === this.region;
        const hasMissingOrExpiredRatings = this.hasMissingRatings() || this.isCEDateExpired();
        const isNotDistributor = this.account?.RecordTypeName !== RECORD_TYPE_DOMESTIC_DISTRIBUTOR;
        const hasRecordType = !!this.account?.RecordType;

        // Domestic region check
        if (isDomesticRegion && hasMissingOrExpiredRatings && isNotDistributor && hasRecordType) {
            const isNotDistributorType = this.labels?.Distributor__c !== this.account?.RecordType?.DeveloperName;
            if (isNotDistributorType) {
                return true;
            }
        }

        // India-specific lead/account check
        if (this.hasMissingRatings()) {
            const isDomesticAccount = this.isDomesticDoctorOrOrtho() &&
                                     this.account?.RecordTypeName !== RECORD_TYPE_DOMESTIC_DISTRIBUTOR &&
                                     this.account?.show === 'Account';

            const isIndiaLead = this.account?.show === 'Lead' &&
                               (this.account?.BillingCountry === 'INDIA' ||
                                this.account?.BillingCountry === 'India');

            if (isDomesticAccount || isIndiaLead) {
                return true;
            }
        }

        return false;
    }
    connectedCallback() {
       if(this.account?.ProductFamily ) console.log('OUTPUT : account Opp',JSON.stringify(this.account));
    }
    /**
     * Handles validation logic when domestic rules block standard flow
     */
    handleDomesticValidationBlock() {
        // Skip validation for Domestic Ortho users
        if (this.userRegionName === USER_TYPE_DOMESTIC_ORTHO) {
            this.fireCalendarEvent();
            return;
        }

        // Check for address approval
        if (this.isLeadWithoutAddressApproval()) {
            this.showToast(
                'Address Approval',
                this.confirmationmessage.Address_approval__c,
                'warning'
            );
            return;
        }

        // Show Ce-Cis confirmation modal for leads without ratings
        if (this.shouldShowCeCisConfirmationModal()) {
            console.log('Setting showCeCisConfirmationModal to true');
            console.log('Custom labels:', this.confirmationmessage);
            this.showCeCisConfirmationModal = true;
            console.log('Modal state after setting:', this.showCeCisConfirmationModal);
            return;
        }

        this.fireCalendarEvent();
    }

    /**
     * Handles standard validation logic
     */
    handleStandardValidation() {
        // Check for address approval
        if (this.isLeadWithoutAddressApproval()) {
            this.showToast(
                'Address Approval',
                this.confirmationmessage.Address_approval__c,
                'warning'
            );
            return;
        }

        // Check for SAP code validation
        if (this.requiresSAPCodeValidation()) {
            this.showToast(
                'SAP code',
                this.confirmationmessage.SAP_code_not_configure_Or_Active_account__c,
                'error'
            );
            return;
        }

        this.fireCalendarEvent();
    }

    /**
     * Checks if both CE and CIS ratings are missing
     * @returns {Boolean} True if either rating is undefined
     */
    hasMissingRatings() {
        return this.cisRating === undefined || this.ceRating === undefined;
    }

    /**
     * Checks if CE date has expired (> 364 days)
     * @returns {Boolean} True if CE date is expired
     */
    isCEDateExpired() {
        return this.daysSinceLastCE > CE_DATE_EXPIRY_DAYS;
    }

    /**
     * Checks if account is Domestic Doctor/Hospital or Domestic Ortho
     * @returns {Boolean} True if matching record type
     */
    isDomesticDoctorOrOrtho() {
        return this.account?.RecordTypeName === RECORD_TYPE_DOMESTIC_DOCTOR ||
               this.account?.RecordTypeName === RECORD_TYPE_DOMESTIC_ORTHO;
    }

    /**
     * Checks if this is a lead without address approval
     * @returns {Boolean} True if lead exists without approval
     */
    isLeadWithoutAddressApproval() {
        return this.account?.Lead === 'Lead' &&
               this.account?.Existing === false &&
               this.account?.status__c === false;
    }

    /**
     * Determines if Ce-Cis confirmation modal should be shown
     * Based on the exact logic from the old customerCard component
     * @returns {Boolean} True if modal should display
     */
    shouldShowCeCisConfirmationModal() {
        // This matches the exact condition from customerCard.js line 144-146
        // Show modal when:
        // - Both CIS and CE ratings are undefined
        // - Customer is a Lead (not Account)
        // - Lead is new (not existing customer)
        const shouldShow = this.cisRating === undefined &&
                          this.ceRating === undefined &&
                          this.account?.Lead === 'Lead' &&
                          this.account?.Existing === false;

        console.log('shouldShowCeCisConfirmationModal check:', {
            cisRating: this.cisRating,
            ceRating: this.ceRating,
            Lead: this.account?.Lead,
            Existing: this.account?.Existing,
            shouldShow: shouldShow
        });

        return shouldShow;
    }

    /**
     * Checks if SAP code validation is required
     * @returns {Boolean} True if SAP validation fails
     */
    requiresSAPCodeValidation() {
        // Opportunities don't require SAP validation
        if (this.account?.show === 'Opportunity') {
            return false;
        }

        const isAccount = this.account?.Account === 'Account';
        const isNotBranch = this.account?.branchaccount === 'false';
        const isDomesticType = this.account?.RecordTypeName === RECORD_TYPE_DOMESTIC_DOCTOR ||
                              this.account?.RecordTypeName === RECORD_TYPE_DOMESTIC_DISTRIBUTOR;
        const invalidStatus = this.account?.status !== ACCOUNT_STATUS_ACTIVATED ||
                             this.account?.sapcode === undefined;

        return isAccount && isNotBranch && isDomesticType && invalidStatus;
    }

    // ========== Helper Methods ==========

    /**
     * Fires the handleShowCalendar event with account data
     */
    fireCalendarEvent() {
        const payload = {
            accountdata: this.account?.Id,
            accountname: this.account?.Name,
            cerating: this.ceRating,
            cisrating: this.cisRating,
            contactList: this.contactList,
            showDataAttribute: this.showDataAttribute,
            product: this.account?.Product,
            productFamily: this.account?.ProductFamily,
            productGroup: this.account?.ProductGroup,
            contact: this.account?.ContactName,
            customerCheck: this.account?.Existing
        };

        fireEvent(this.pageRef, 'handleShowCalendar', payload);
    }

    /**
     * Displays a toast notification
     * @param {String} title - Toast title
     * @param {String} message - Toast message
     * @param {String} variant - Toast variant (success, error, warning, info)
     */
    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}