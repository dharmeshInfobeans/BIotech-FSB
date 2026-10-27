import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import searchAccountsContacts from '@salesforce/apex/LeadFormController.searchAccountsContacts';
import getAccountWithContacts from '@salesforce/apex/LeadFormController.getAccountWithContacts';
import getContactWithAccount from '@salesforce/apex/LeadFormController.getContactWithAccount';
import createLead from '@salesforce/apex/LeadFormController.createLead';
import getLeadPicklistValues from '@salesforce/apex/LeadFormController.getLeadPicklistValues';

export default class LeadForm extends LightningElement {
    @track leadData = {
        FirstName: '',      // Maps to FirstName__c
        LastName: '',       // Maps to LastName__c
        Email: '',          // Maps to Email__c
        Phone: '',          // Maps to Phone__c (if exists)
        MobilePhone: '',    // Maps to Mobile__c
        Company: '',        // Maps to Company__c
        Title: '',          // Maps to Title__c (if exists)
        Website: '',        // Maps to Website__c (if exists)
        Street: '',         // Maps to Street__c
        City: '',           // Maps to City__c
        State: '',          // Maps to State__c (if exists)
        PostalCode: '',     // Maps to PostalCode__c
        Country: '',        // Maps to Country__c
        Region: '',         // Maps to Region__c
        LeadSource: '',     // Maps to LeadSource__c (if exists)
        Status: '',  // Maps to Status__c (if exists)
        Industry: '',       // Maps to Industry__c (if exists)
        AnnualRevenue: null,  // Maps to AnnualRevenue__c (if exists)
        NumberOfEmployees: null,  // Maps to NumberOfEmployees__c (if exists)
        Description: ''     // Maps to Description__c (if exists)
    };
    
    @track searchTerm = '';
    @track searchResults = [];
    @track selectedAccount = null;
    @track selectedContact = null;
    @track relatedContacts = [];
    @track isLoading = false;
    @track isSearching = false;
    @track leadSourceOptions = [];
    @track statusOptions = [];
    @track industryOptions = [];
    @track regionOptions = [];
    @track showConfirmModal = false;
    @track showErrorModal = false;
    @track errorMessage = '';
    @track errorRegion = '';
    @track validationErrors = [];
    leadCountryOptions = [];
    
    connectedCallback() {
        this.loadPicklistValues();
    }
    
    loadPicklistValues() {
        getLeadPicklistValues()
            .then(result => {
                this.leadSourceOptions = result.leadSourceOptions || [];
                this.statusOptions = result.statusOptions || [];
                this.industryOptions = result.industryOptions || [];
                this.regionOptions = result.regionOptions || [];
                this.leadCountryOptions = result.leadCountryOptions || [];
                console.log('Picklist values loaded successfully',this.leadCountryOptions);
            })
            .catch(error => {
                console.error('Error loading picklist values:', error);
                this.showToast('Error', 'Failed to load form options', 'error');
            });
    }
    
    handleSearchChange(event) {
        this.searchTerm = event.target.value;
        if (this.searchTerm.length >= 2) {
            this.searchAccounts();
        } else {
            this.searchResults = [];
        }
    }
    
    searchAccounts() {
        this.isSearching = true;
        searchAccountsContacts({ searchTerm: this.searchTerm })
            .then(result => {
                this.searchResults = result || [];
                this.isSearching = false;
            })
            .catch(error => {
                console.error('Search error:', error);
                this.showToast('Error', 'Search failed: ' + (error.body?.message || error.message), 'error');
                this.isSearching = false;
            });
    }
    
    handleSelectCustomer(event) {
        const customerId = event.currentTarget.dataset.id;
        const customerType = event.currentTarget.dataset.type;
        
        this.isLoading = true;
        
        if (customerType === 'Account') {
            // Fetch Account with related Contacts
            getAccountWithContacts({ accountId: customerId })
                .then(result => {
                    this.selectedAccount = result.account;
                    this.relatedContacts = (result.contacts || []).map((contact, index) => ({
                        ...contact,
                        isSelected: index === 0,
                        itemClass: index === 0 ? 'related-contact-item selected' : 'related-contact-item'
                    }));
                    this.selectedContact = null;
                    
                    // Populate Account fields
                    this.populateFromAccount(result.account);
                    
                    // If there are related contacts, populate with the first contact's details
                    if (this.relatedContacts && this.relatedContacts.length > 0) {
                        this.populateFromContact(this.relatedContacts[0]);
                        this.selectedContact = this.relatedContacts[0];
                    }
                    
                    this.isLoading = false;
                })
                .catch(error => {
                    console.error('Error fetching account:', error);
                    this.showToast('Error', 'Failed to load account details', 'error');
                    this.isLoading = false;
                });
        } else if (customerType === 'Contact') {
            // Fetch Contact with related Account
            getContactWithAccount({ contactId: customerId })
                .then(result => {
                    this.selectedContact = result.contact;
                    this.selectedAccount = result.account;
                    this.relatedContacts = [];
                    
                    // Populate Contact fields
                    this.populateFromContact(result.contact);
                    
                    // Populate Account fields if account exists
                    if (result.account) {
                        this.populateFromAccount(result.account);
                    }
                    
                    this.isLoading = false;
                })
                .catch(error => {
                    console.error('Error fetching contact:', error);
                    this.showToast('Error', 'Failed to load contact details', 'error');
                    this.isLoading = false;
                });
        }
        
        this.searchResults = [];
        this.searchTerm = '';
    }
    
    handleSelectRelatedContact(event) {
        const contactId = event.currentTarget.dataset.id;
        const contact = this.relatedContacts.find(con => con.Id === contactId);
        
        if (contact) {
            // Update selected state and class for all contacts
            this.relatedContacts = this.relatedContacts.map(con => ({
                ...con,
                isSelected: con.Id === contactId,
                itemClass: con.Id === contactId ? 'related-contact-item selected' : 'related-contact-item'
            }));
            
            this.selectedContact = contact;
            // Update only contact-specific fields, keep account fields
            this.leadData = {
                ...this.leadData,
                FirstName: contact.FirstName || '',
                LastName: contact.LastName || '',
                Email: contact.Email || '',
                Phone: contact.Phone || this.leadData.Phone,
                MobilePhone: contact.MobilePhone || '',
                Title: contact.Title || '',
                Street: contact.MailingStreet || this.leadData.Street,
                City: contact.MailingCity || this.leadData.City,
                State: contact.MailingState || this.leadData.State,
                PostalCode: contact.MailingPostalCode || this.leadData.PostalCode,
                Country: contact.MailingCountry || this.leadData.Country
            };
        }
    }
    
    populateFromAccount(account) {
        // Account data is already an SObject
        // Only populate if account has value, otherwise keep existing
        if (account.Name) this.leadData.Company = account.Name;
        if (account.Website) this.leadData.Website = account.Website;
        if (account.BillingStreet) this.leadData.Street = account.BillingStreet;
        if (account.BillingCity) this.leadData.City = account.BillingCity;
        if (account.BillingState) this.leadData.State = account.BillingState;
        if (account.BillingPostalCode) this.leadData.PostalCode = account.BillingPostalCode;
        if (account.BillingCountry) this.leadData.Country = account.BillingCountry;
        if (account.Phone) this.leadData.Phone = account.Phone;
        if (account.Industry) this.leadData.Industry = account.Industry;
        if (account.AnnualRevenue != null) this.leadData.AnnualRevenue = account.AnnualRevenue;
        if (account.NumberOfEmployees != null) this.leadData.NumberOfEmployees = account.NumberOfEmployees;
    }
    
    populateFromContact(contact) {
        // Contact data is already an SObject
        // Prioritize contact data, but don't overwrite if contact field is empty
        if (contact.FirstName) this.leadData.FirstName = contact.FirstName;
        if (contact.LastName) this.leadData.LastName = contact.LastName;
        if (contact.Email) this.leadData.Email = contact.Email;
        if (contact.Phone) this.leadData.Phone = contact.Phone;
        if (contact.MobilePhone) this.leadData.MobilePhone = contact.MobilePhone;
        if (contact.Title) this.leadData.Title = contact.Title;
        // Use Account name from contact if available, otherwise keep existing Company
        if (contact.Account?.Name) {
            this.leadData.Company = contact.Account.Name;
        } else if (contact.AccountName) {
            this.leadData.Company = contact.AccountName;
        }
        // Contact address fields take priority over Account address
        if (contact.MailingStreet) this.leadData.Street = contact.MailingStreet;
        if (contact.MailingCity) this.leadData.City = contact.MailingCity;
        if (contact.MailingState) this.leadData.State = contact.MailingState;
        if (contact.MailingPostalCode) this.leadData.PostalCode = contact.MailingPostalCode;
        if (contact.MailingCountry) this.leadData.Country = contact.MailingCountry;
    }
    
    handleFieldChange(event) {
        const fieldName = event.target.dataset.field || event.target.name;
        let value = event.target.value;
        
        // Handle number fields
        if (fieldName === 'AnnualRevenue' || fieldName === 'NumberOfEmployees') {
            value = value ? parseFloat(value) : null;
        }
        
        this.leadData = {
            ...this.leadData,
            [fieldName]: value
        };
        
        // Clear validation error for this field
        this.clearValidationError(fieldName);
    }
    
    handleClearCustomer() {
        this.selectedAccount = null;
        this.selectedContact = null;
        this.relatedContacts = [];
        this.searchTerm = '';
        this.searchResults = [];
    }
    
    validateForm() {
        const missingFields = [];
        
        // Required fields validation
        if (!this.leadData.LastName || this.leadData.LastName.trim() === '') {
            missingFields.push('Last Name');
        }
         if (!this.leadData.FirstName || this.leadData.FirstName.trim() === '') {
            missingFields.push('First Name');
        }
         if (!this.leadData.Email || this.leadData.Email.trim() === '') {
            missingFields.push('Email');
        }
         if (!this.leadData.MobilePhone || this.leadData.MobilePhone.trim() === '') {
            missingFields.push('Mobile Phone');
        }           
        if (!this.leadData.Street || this.leadData.Street.trim() === '') {
            missingFields.push('Street');
        }
        if (!this.leadData.City || this.leadData.City.trim() === '') {
            missingFields.push('City');
        }
        if (!this.leadData.State || this.leadData.State.trim() === '') {
            missingFields.push('State/Province');
        }
        if (!this.leadData.PostalCode || this.leadData.PostalCode.trim() === '') {
            missingFields.push('Postal Code');
        }   
        if (!this.leadData.Country || this.leadData.Country.trim() === '') {
            missingFields.push('Country');
        }

        if (!this.leadData.Company || this.leadData.Company.trim() === '') {
            missingFields.push('Company');
        }
         const statusValue = this.leadData.Status || '';
         if (statusValue.trim() === '') {
            missingFields.push('Status');
        }
        
        // Region is required
        if (!this.leadData.Region || this.leadData.Region.trim() === '') {
            missingFields.push('Region');
        }
        
        // Email validation
        if (this.leadData.Email && !this.isValidEmail(this.leadData.Email)) {
            this.showToast('Validation Error', 'Please enter a valid email address', 'error');
            return false;
        }
        
        // Show toast for missing required fields
        if (missingFields.length > 0) {
            this.showToast('Validation Error', 'Please fill in required fields: ' + missingFields.join(', '), 'error');
            return false;
        }
        
        return true;
    }
    
    isValidEmail(email) {
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        return emailRegex.test(email);
    }
    
    handleSubmit() {
        if (!this.validateForm()) {
            return;
        }
        this.showConfirmModal = true;
    }
    
    handleConfirmSubmit() {
        this.showConfirmModal = false;
        this.isLoading = true;
        
        createLead({ leadData: this.leadData })
            .then(result => {
                this.showToast('Success', 'Scorecard Lead created successfully with ID: ' + result, 'success');
                this.resetForm();
            })
            .catch(error => {
                console.error('Create lead error:', error);
                // Extract error message - handle different error formats
                let errorMsg = 'Failed to create lead';
                if (error.body) {
                    // AuraHandledException format
                    errorMsg = error.body.message || error.body.exceptionType || error.body.output?.errors?.[0]?.message || error.message;
                } else if (error.message) {
                    errorMsg = error.message;
                }
                
                // Check if this is a region validation error
                const isRegionError = errorMsg && errorMsg.toLowerCase().includes('scorecard is not configured for the selected region');
                
                if (isRegionError) {
                    // Show custom region error modal
                    this.errorRegion = this.leadData.Region || '';
                    this.errorMessage = errorMsg;
                    this.showErrorModal = true;
                } else {
                    // Show generic error toast for other errors
                    this.showToast('Error', errorMsg, 'error');
                }
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
    
    handleCloseErrorModal() {
        this.showErrorModal = false;
        this.errorMessage = '';
        this.errorRegion = '';
    }
    
    handleCancelSubmit() {
        this.showConfirmModal = false;
    }
    
    handleModalClick(event) {
        event.stopPropagation();
    }
    
    resetForm() {
        this.leadData = {
            FirstName: '',
            LastName: '',
            Email: '',
            Phone: '',
            MobilePhone: '',
            Company: '',
            Title: '',
            Website: '',
            Street: '',
            City: '',
            State: '',
            PostalCode: '',
            Country: '',
            Region: '',
            LeadSource: '',
            Status: 'Open - Not Contacted',
            Industry: '',
            AnnualRevenue: null,
            NumberOfEmployees: null,
            Description: ''
        };
        this.selectedAccount = null;
        this.selectedContact = null;
        this.relatedContacts = [];
        this.searchTerm = '';
        this.searchResults = [];
        this.validationErrors = [];
    }
    
    hasValidationError(fieldName) {
        return this.validationErrors.some(err => err.field === fieldName);
    }
    
    get firstNameRowClass() {
        return this.hasValidationError('FirstName') ? 'form-field-row field-error-wrapper' : 'form-field-row';
    }
    
    get lastNameRowClass() {
        return this.hasValidationError('LastName') ? 'form-field-row field-error-wrapper' : 'form-field-row';
    }
    
    get emailRowClass() {
        return this.hasValidationError('Email') ? 'form-field-row field-error-wrapper' : 'form-field-row';
    }
    
    get companyRowClass() {
        return this.hasValidationError('Company') ? 'form-field-row field-error-wrapper' : 'form-field-row';
    }
    
    get regionRowClass() {
        return this.hasValidationError('Region') ? 'form-field-row field-error-wrapper' : 'form-field-row';
    }
    
    get selectedContactName() {
        if (!this.selectedContact) return '';
        const firstName = this.selectedContact.FirstName || '';
        const lastName = this.selectedContact.LastName || '';
        return `${firstName} ${lastName}`.trim();
    }
    
    clearValidationError(fieldName) {
        this.validationErrors = this.validationErrors.filter(err => err.field !== fieldName);
    }
    
    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(evt);
    }
}