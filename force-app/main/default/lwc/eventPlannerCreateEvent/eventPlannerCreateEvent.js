/**
 * EventPlannerCreateEvent Component
 * Modern refactored version of createEvent component
 * Handles creation of Leave, Holiday, Out of Office, and Customer Visit events
 *
 * @author Salesforce Development Team
 * @date 2026-01-15
 */

import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getPicklistValues,getObjectInfo } from 'lightning/uiObjectInfoApi';
import EVENT_OBJECT from '@salesforce/schema/Event';
import PRODUCT_FAMILY from '@salesforce/schema/Event.Product_Family__c';

// Apex Methods
import createEvent from '@salesforce/apex/calendarPlanningMobileController.createEvent';
import getSubCallTypeOptions from '@salesforce/apex/calendarPlanningMobileController.getSubCallTypeOptions';
import getHolidayRecord from '@salesforce/apex/calendarPlanningMobileController.getHolidayRecord';
import getCallType from '@salesforce/apex/calendarPlanningMobileController.getCallType';
import getLevelTypeOptions from '@salesforce/apex/calendarPlanningMobileController.getLevelTypeOptions';
import getMeetingType from '@salesforce/apex/calendarPlanningMobileController.getMeetingType';
import getLeaveType from '@salesforce/apex/calendarPlanningMobileController.getLeaveType';
import getReviewCallType from '@salesforce/apex/calendarPlanningMobileController.getReviewCallType';
import getUsers from '@salesforce/apex/calendarPlanningMobileController.getUsers';
import updateEventBDPlan from '@salesforce/apex/calendarPlanningMobileController.updateEventBDPlan';
import getAddressData from '@salesforce/apex/CustomLeadCreationController.getAddressData';

// Schema imports
import CALL_TYPE_FIELD from '@salesforce/schema/Event.Account_Visit_Call_Type__c';
import MEETING_TYPE_FIELD from '@salesforce/schema/Event.Meeting_Type__c';

// Custom Labels
import Link_BD_Plan from '@salesforce/label/c.Link_BD_Plan';
import Selected_BD_Plans from '@salesforce/label/c.Selected_BD_Plans';
import Type_of_Planning from '@salesforce/label/c.Type_of_Planning';
import Plan_Week from '@salesforce/label/c.Plan_Week';
import Product from '@salesforce/label/c.Product';
import Contact from '@salesforce/label/c.Contact';
import MileStone_Stage from '@salesforce/label/c.MileStone_Stage';
import Plan_Year from '@salesforce/label/c.Plan_Year';
import CIS_Rating from '@salesforce/label/c.CIS_Rating';
import CE_Rating from '@salesforce/label/c.CE_Rating';
import New_DCR from '@salesforce/label/c.New_DCR';

// Local imports
import { EventFormData } from './EventFormData';
import { ValidationService } from './services/validationService';
import { DateUtils } from './utils/dateUtils';
import { EVENT_TYPES, CALL_TYPES, PLACEHOLDER_VALUES } from './constants/eventTypes';
import { VALIDATION_MESSAGES, RESPONSE_CODES } from './constants/validationMessages';
import { FIELD_NAMES } from './constants/fieldNames';
import USER_ID from '@salesforce/user/Id';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import USER_VERTICAL_FIELD from '@salesforce/schema/User.Vertical__c'; // confirm exact API name

// Holiday datatable columns
const HOLIDAY_COLUMNS = [
    { label: 'Date', fieldName: 'Date', type: 'date' },
    { label: 'Type', fieldName: 'Type', type: 'text' }
];

export default class EventPlannerCreateEvent extends LightningElement {
    // Custom labels
    customLabels = {
        Link_BD_Plan,
        Selected_BD_Plans,
        Type_of_Planning,
        Plan_Week,
        Product,
        Contact,
        MileStone_Stage,
        Plan_Year,
        CE_Rating,
        CIS_Rating,
        New_DCR
    };

    // API properties (inputs from parent)
    @api date;
    @api accountId;
    @api eventType;
    @api labels;
    @api selectedValues;
    @api cisrating;
    @api cerating;
    @api contactoption;
    @api ownerid;
    @api bdplanlist = [];
    @api accountname;
    @api showDataAttribute;
    @api productdata;
    @api productfamily;
    @api productgroup;
    @api contactname;

    // Form data model
    @track formData = new EventFormData();
userVertical;
productFamilyPicklistData; // raw metadata (controllerValues + values), kept so we can re-filter
    // Component state
    isLoading = false;
    saveButtonDisabled = false;
    cardTitle = '';
    dateValueToShow = '';

    // Event type flags
    isLeave = false;
    isHoliday = false;
    isOutOfOffice = false;
    isCustomerVisit = false;

    // UI state for conditional rendering
    @track showJointAssignee = false;
    isInClinicBranding = false;
    enableproductoption = false;

    // Sub call type options
    @track subCallTypeOptions = [];

    // Picklist options
    levelTypeOptions = [];
    callTypeOptions = [];
    meetingTypeOptions = [];
    leaveOptions = [];
    reviewCallOptions = [];
    usersOptions = [];
    addressList = [];

    // Picklist metadata
    callTypeData;
    callTypeDisable = true;

    // Product and user selection
    selectedProduct = '';
    usersSelected = '';
    currentCallType = '';

    // Address data
    currentAddress = '';
    addressData = PLACEHOLDER_VALUES.NONE;

    // BD Plan modal
    showBdPlanModal = false;
    updateEventMap = new Map();
    selectedIdToUpdateBDPlan = [];

    // Compensation off
    @track holidayList = [];
    holidayColumns = HOLIDAY_COLUMNS;
    selectedHolidayRows = [];
    @track showCompensationOffTable = false;  // Explicit reactive property for table visibility

    // Contact display
    customerCheck = false;

    // eventRecordTypeId
    eventRecordTypeId;
    eventProductFamily =[];

    //check if account is selected
    isAccountSelected = false;


    targetFilter = {
    criteria: [
        {
            fieldPath: 'Target_Completed__c',   // replace with your actual checkbox field API name
            operator: 'eq',
            value: false
        }
    ]
};
    /**
     * Computed property - Check if current call type is Phakic Training
     */
    get isPhakicTraining() {
        return this.formData.callType === CALL_TYPES.PHAKIC_TRAINING;
    }

    /**
     * Computed property - Check if contact field should be shown
     * Contact field should only be shown for Accounts (not Leads) and when contactoption exists
     */
    get shouldShowContactField() {
        return this.showDataAttribute !== 'Lead';
    }

    /**
     * Computed property - Check if there are holiday dates available
     */
    get hasHolidayDates() {
        return this.holidayList && this.holidayList.length > 0;
    }

 get showTarget() {
    const showTargetValue = ['MKTG/Conf/In Clinic Planning', 'MKTG/Conf/In Clinic / PD Planning', 'CTP', 'Focus', 'Testimonial', 'Poster and Brandings' , 'Welcome Kit', 'Counseling Kit', 'Decode Program'];
    return showTargetValue.includes(this.formData?.callType);
}

    /**
     * Wire: Get Level Type picklist options for Phakic Training
     */
    @wire(getLevelTypeOptions)
    wiredLevelTypeOptions({ error, data }) {
        if (data) {
            this.levelTypeOptions = Object.keys(data).map(label => ({
                label: label,
                value: data[label]
            }));
        } else if (error) {
            this.handleError('Error fetching level type options', error);
        }
    }

    @wire(getRecord, { recordId: USER_ID, fields: [USER_VERTICAL_FIELD] })
wiredCurrentUser({ data, error }) {
    if (data) {
        this.userVertical = getFieldValue(data, USER_VERTICAL_FIELD);
        this.filterProductFamilyOptions();
    } else if (error) {
        this.handleError('Error fetching user vertical', error);
    }
}
    // event product family picklist valuie
    @wire(getObjectInfo, { objectApiName: EVENT_OBJECT })
objectInfo({ data, error }) {
    if (data) {
        this.eventRecordTypeId = data.defaultRecordTypeId;
        //console.log('OUTPUT :   this.eventRecordTypeId',  this.eventRecordTypeId);
    } else if (error) {
        console.error(error);
    }
}
@wire(getPicklistValues, {
    recordTypeId: '$eventRecordTypeId',
    fieldApiName: PRODUCT_FAMILY
})
wiredPicklist({ data, error }) {
    if (data) {
        // this.eventProductFamily = data.values.map(item => ({
        //     label: item.label,
        //     value: item.value
        // }));
        this.productFamilyPicklistData = data; // keep controllerValues + values
     //   console.log('OUTPUT : data',data);
        this.filterProductFamilyOptions();
        console.log('event product family on loading',this.eventProductFamily);
    } else if (error) {
        console.error(error);
    }
}
filterProductFamilyOptions() {
   // console.log('userVertical:', JSON.stringify(this.userVertical));
  //  console.log('controllerValues:', JSON.stringify(this.productFamilyPicklistData?.controllerValues));

    if (!this.productFamilyPicklistData || !this.userVertical) {
        this.eventProductFamily = [];
        return;
    }

    const controllerValues = this.productFamilyPicklistData.controllerValues;
    const controllerIndex = controllerValues[this.userVertical];
  //  console.log('controllerIndex:', controllerIndex);

    if (controllerIndex === undefined) {
        console.warn('No controller index found for vertical:', this.userVertical);
        this.eventProductFamily = [];
        return;
    }

    this.eventProductFamily = this.productFamilyPicklistData.values
        .filter(opt => opt.validFor.includes(controllerIndex))
        .map(opt => ({ label: opt.label, value: opt.value }));

    //console.log('filtered eventProductFamily:', JSON.stringify(this.eventProductFamily));
}

    /**
     * Wire: Get Call Type picklist with dependency metadata
     */
    @wire(getPicklistValues, {
        recordTypeId: '0126F0000013zvNQAQ',
        fieldApiName: CALL_TYPE_FIELD
    })
    wiredCallTypePicklist({ data, error }) {
        if (data) {
            this.callTypeData = data;
        } else if (error) {
            this.handleError('Error fetching call type picklist', error);
        }
    }

    /**
     * Wire: Get Meeting Type picklist
     */
    @wire(getPicklistValues, {
        recordTypeId: '0126F0000013zvNQAQ',
        fieldApiName: MEETING_TYPE_FIELD
    })
    wiredMeetingTypePicklist({ data, error }) {
        if (data) {
            this.meetingTypeOptions = data.values;
        } else if (error) {
            this.handleError('Error fetching meeting type picklist', error);
        }
    }

    /**
     * Wire: Get users for joint assignee
     */
    @wire(getUsers)
    wiredUsers({ error, data }) {
        if (data) {
            this.usersOptions = data.map(val => ({
                label: val.Name,
                value: val.Id
            }));
        } else if (error) {
            this.handleError('Error fetching users', error);
        }
    }

    /**
     * Wire: Get meeting type options (from Apex - for backward compatibility)
     */
    @wire(getMeetingType)
    wiredMeetingType({ data }) {
        if (data) {
            // Using picklist metadata instead, but keeping for compatibility
        }
    }

    /**
     * Wire: Get leave type options
     */
    @wire(getLeaveType)
    wiredLeaveType({ error, data }) {
        if (data) {
            this.leaveOptions = Object.keys(data).map(label => ({
                label: label,
                value: data[label]
            }));
        } else if (error) {
            this.handleError('Error fetching leave types', error);
        }
    }

    /**
     * Wire: Get review call type options
     */
    @wire(getReviewCallType)
    wiredReviewCallType({ error, data }) {
        if (data) {
            this.reviewCallOptions = Object.keys(data).map(label => ({
                label: label,
                value: data[label]
            }));
        } else if (error) {
            this.handleError('Error fetching review call types', error);
        }
    }

    /**
     * Wire: Get call type options (from Apex - for backward compatibility)
     */
    @wire(getCallType)
    wiredCallType({ data }) {
        if (data) {
            // Using picklist metadata instead, but keeping for compatibility
        }
    }

    /**
     * Lifecycle hook - Component connected to DOM
     */
    connectedCallback() {
        this.initializeComponent();
    }

    /**
     * Initialize component state and data
     */
    async initializeComponent() {
        this.isLoading = true;

        try {
            if(this.accountId.substring(0,3) == '001'){
                this.isAccountSelected = true;
               
            }
             console.log(' this.isAccountSelected = true;', this.isAccountSelected);
            // Initialize form data
            this.formData.ownerId = this.ownerid;
            this.formData.product = this.productgroup || '';
            this.formData.relatedTo = this.accountId;

            // Initialize date
            this.formData.date = this.date || DateUtils.getCurrentDate();
            this.dateValueToShow = DateUtils.formatDateForDisplay(this.formData.date);

            // Check if contact is pre-selected
            this.customerCheck = !!this.contactname;

            // Fetch address data
            await this.loadAddressData();

            // Set event type flags
            this.setEventTypeFlags();

            // Warn if Customer Visit has no product on the lead
            if (this.isCustomerVisit && !this.productgroup && !this.isAccountSelected) {
                this.showToast('Warning', 'Please select a product on the prospect record before creating this event.', 'warning');
            }

        } catch (error) {
            this.handleError('Error initializing component', error);
        } finally {
            this.isLoading = false;
        }
    }

    /**
     * Load address data for the account/lead
     */
    async loadAddressData() {
        try {
            const result = await getAddressData({ accounId: this.accountId });
            this.addressList = result || [];

            if (this.addressList.length > 0) {
                this.addressData = this.addressList[0].label;
            }
        } catch (error) {
            this.handleError('Error loading address data', error);
        }
    }

    /**
     * Set event type flags and card title based on eventType prop
     */
    setEventTypeFlags() {
        this.formData.eventType = this.eventType;

        // Reset compensation off table when switching event types
        this.showCompensationOffTable = false;

        switch (this.eventType) {
            case EVENT_TYPES.LEAVE:
                this.cardTitle = `${this.labels.Leave__c} ${this.labels.Details__c}`;
                this.isLeave = true;
                this.isHoliday = false;
                this.isOutOfOffice = false;
                this.isCustomerVisit = false;
                break;
            case EVENT_TYPES.HOLIDAY:
                this.cardTitle = `${this.labels.Holiday__c} ${this.labels.Details__c}`;
                this.isLeave = false;
                this.isHoliday = true;
                this.isOutOfOffice = false;
                this.isCustomerVisit = false;
                break;
            case EVENT_TYPES.OUT_OF_OFFICE:
                this.cardTitle = `${this.labels.Out_Of_Office__c} ${this.labels.Details__c}`;
                this.isLeave = false;
                this.isHoliday = false;
                this.isOutOfOffice = true;
                this.isCustomerVisit = false;
                break;
            case EVENT_TYPES.CUSTOMER_VISIT:
                this.cardTitle = this.customLabels.New_DCR;
                this.isLeave = false;
                this.isHoliday = false;
                this.isOutOfOffice = false;
                this.isCustomerVisit = true;
                break;
            default:
                this.cardTitle = 'Event Details';
        }
    }

    /**
     * Handle field value changes
     * @param {Event} event - Change event from input field
     */
    // handleFieldChange(event) {
    //     const { name, value, checked, type } = event.target;

    //     // Update form data based on field type
    //     if (type === 'checkbox' || type === 'toggle') {
    //         this.formData[name] = checked;

    //         // Handle joint assignee checkbox/toggle
    //         if (name === 'jointAssignee') {
    //             this.showJointAssignee = checked;
    //         }
    //     } else {
    //         this.formData[name] = value;
    //     }
    //     console.log('form change check',this.formData);

    //     // Handle special field logic
    //     this.handleDependentFieldLogic(name, value || checked);
    // }

handleFieldChange(event) {
    const { name, value, checked, type } = event.target;

    const fieldValue = (type === 'checkbox' || type === 'toggle')
        ? checked
        : value;

    const updatedFormData = new EventFormData();
    Object.assign(updatedFormData, this.formData);

    updatedFormData[name] = fieldValue;

    this.formData = updatedFormData;

    if (name === 'jointAssignee') {
        this.showJointAssignee = checked;
    }

    this.handleDependentFieldLogic(name, fieldValue);
}
handleTargetChange( event ) {
     const updatedFormData = new EventFormData();
       Object.assign(updatedFormData, this.formData);
        updatedFormData['targetId'] =  event.detail.recordId;
          this.formData = updatedFormData;
}
    //   this.formData = {   ...this.formData,   ['targetId']: event.detail.recordId };}

    /**
     * Handle dependent field logic and conditional rendering
     * @param {string} fieldName - Name of the field that changed
     * @param {*} value - New value of the field
     */
    handleDependentFieldLogic(fieldName, value) {
        switch (fieldName) {
            case FIELD_NAMES.MEETING_TYPE:
                this.handleMeetingTypeChange(value);
                break;

            case FIELD_NAMES.CALL_TYPE:
                this.currentCallType = value;
                this.handleCallTypeChange(value);
                break;

            case FIELD_NAMES.SUB_CALL_TYPE:
                this.enableproductoption = true;
                break;

            case FIELD_NAMES.LEAVE_TYPE:
                // Check if value contains "Compensation" (handles both label and value variations)
                if (value && value.toLowerCase().includes('compensation')) {
                    this.showCompensationOffTable = true;
                    this.loadHolidayData();
                } else {
                    this.showCompensationOffTable = false;
                    this.holidayList = [];
                    this.selectedHolidayRows = [];
                }
                break;

            case FIELD_NAMES.ADDRESS:
                this.currentAddress = value;
                break;

            default:
                break;
        }
    }

    /**
     * Handle Meeting Type change - update dependent Call Type options
     * @param {string} value - Selected meeting type value
     */
    handleMeetingTypeChange(value) {
        if (value === PLACEHOLDER_VALUES.SELECT) {
            this.callTypeDisable = true;
            this.callTypeOptions = [{
                label: PLACEHOLDER_VALUES.SELECT,
                value: PLACEHOLDER_VALUES.SELECT
            }];
        } else if (this.callTypeData) {
            const key = this.callTypeData.controllerValues[value];
            this.callTypeOptions = this.callTypeData.values.filter(
                opt => opt.validFor.includes(key)
            );
            this.callTypeDisable = false;
        }
    }

    /**
     * Handle Call Type change - show/hide Sub Call Type for In Clinic Branding
     * @param {string} value - Selected call type value
     */
    handleCallTypeChange(value) {
        if (value === CALL_TYPES.IN_CLINIC_BRANDING) {
            this.isInClinicBranding = true;
            this.loadSubCallTypeOptions();
        } else {
            this.isInClinicBranding = false;
            this.enableproductoption = false;
            this.formData.subCallType = '';
            this.subCallTypeOptions = [];
        }
    }

    /**
     * Load sub call type picklist options from Apex
     */
    async loadSubCallTypeOptions() {
        try {
            this.subCallTypeOptions = await getSubCallTypeOptions();
        } catch (error) {
            this.handleError('Error fetching Sub Call Type options', error);
        }
    }

    /**
     * Handle product selection from child component
     * @param {CustomEvent} event - Event from c-multi-select-picklist-with-search
     */
    handleSelectProduct(event) {
        this.selectedProduct = event.detail;
        this.formData.product = event.detail;
    }

    /**
     * Handle user selection from child component
     * @param {CustomEvent} event - Event from c-multi-select-user-picklist-with-search
     */
    handleSelectUser(event) {
        const selectedUsers = event.detail;
        this.usersSelected = selectedUsers;
        // Ensure users is always an array (Apex expects List<Object>)
        this.formData.users = Array.isArray(selectedUsers) ? selectedUsers : [];
    }

    /**
     * Load holiday data for compensation off selection
     */
    async loadHolidayData() {
        try {
            const result = await getHolidayRecord({});
            this.holidayList = result.holidays || [];
        } catch (error) {
            this.handleError('Error loading holiday data', error);
        }
    }

    /**
     * Handle row selection in compensation off datatable
     * @param {Event} event - Row selection event
     */
    handleRowSelection(event) {
        const selectionValue = event.detail.selectedRows;

        if (selectionValue.length > 1) {
            this.showToast('Error', VALIDATION_MESSAGES.COMPENSATION_OFF_SELECT_ONE, 'error');
            this.saveButtonDisabled = true;
            return;
        }

        this.selectedHolidayRows = selectionValue;
        this.saveButtonDisabled = selectionValue.length !== 1;
    }

    /**
     * Handle save button click
     */
    async handleSave() {
        try {
            this.isLoading = true;
            this.saveButtonDisabled = true;

            // Update form data with latest values
            this.formData.relatedTo = this.accountId;
            this.formData.product = this.productgroup || '';
            // Ensure users is always an array (Apex expects List<Object>)
            this.formData.users = Array.isArray(this.usersSelected) ? this.usersSelected : [];
            // Date is already in MM/DD/YYYY format from parent component
            this.formData.date = this.date;
            this.formData.ownerId = this.ownerid;

            // Validate form
            const errors = ValidationService.validateForm(this.formData);
              if (this.formData.relatedTo.substring(0,3) == '001' && (this.formData?.eventProductFamily ==null || this.formData?.eventProductFamily ==undefined || this.formData?.eventProductFamily =='')) {
            errors.push('Product Family is required');
        }
            if (errors.length > 0) {
                this.showToast('Validation Error', errors.join(', '), 'warning');
                return;
            }
            console.log('this.formData',this.formData);
            // Convert form data to Apex format
            const dataMap = this.formData.toApexMap();
            dataMap['eventProductFamily']=this.formData?.eventProductFamily || null;
            dataMap['targetId']=this.formData?.targetId || null;
            console.log('data map',dataMap);
            // Call Apex to create event
            const result = await createEvent({
                dataMap: dataMap,
                eventAdress: this.currentAddress
            });

            // Handle result
            this.handleSaveResult(result);

        } catch (error) {
            this.handleError('Error saving event', error);
        } finally {
            this.isLoading = false;
            this.saveButtonDisabled = false;
        }
    }

    /**
     * Handle save result from Apex
     * @param {string} result - Response code from Apex
     */
    handleSaveResult(result) {
        switch (result) {
            case RESPONSE_CODES.SUCCESS:
                this.showToast('Success', VALIDATION_MESSAGES.EVENT_CREATED, 'success');
                this.dispatchSaveEvent();
                break;

            case RESPONSE_CODES.ERROR:
                this.showToast('Error', VALIDATION_MESSAGES.CE_CIS_NOT_APPROVED, 'error');
                break;

            case RESPONSE_CODES.ADDRESS:
                this.showToast('Error', VALIDATION_MESSAGES.ADDRESS_NOT_APPROVED, 'error');
                break;

            case RESPONSE_CODES.CECIS:
                this.showToast('Error', VALIDATION_MESSAGES.CE_CIS_PHAKIC_NOT_APPROVED, 'error');
                break;

            case RESPONSE_CODES.REJECT:
                this.showToast('Error', VALIDATION_MESSAGES.ALL_NOT_APPROVED, 'error');
                break;

            default:
                this.showToast('Error', 'Unknown error occurred', 'error');
        }
    }

    /**
     * Dispatch event to parent indicating successful save
     */
    dispatchSaveEvent() {
        // Dispatch custom event with save detail
        this.dispatchEvent(new CustomEvent('cancel', {
            detail: 'save',
            bubbles: true,
            composed: true
        }));

        // Dispatch eventsaved event for parent to reload
        this.dispatchEvent(new CustomEvent('eventsaved', {
            detail: { date: this.date },
            bubbles: true,
            composed: true
        }));
    }

    /**
     * Handle cancel button click
     */
    handleCancel() {
        this.dispatchEvent(new CustomEvent('cancel', {
            bubbles: true,
            composed: true
        }));
    }

    /**
     * Handle BD Plan linking modal open
     */
    handleAddBdr() {
        console.log('🔗 [BD Tracker Modal] Opening BD Plan modal...');
        console.log('🔗 [BD Tracker Modal] Account ID:', this.accountId);
        console.log('🔗 [BD Tracker Modal] Account Name:', this.accountname);
        console.log('🔗 [BD Tracker Modal] BD Plan List Length:', this.bdplanlist?.length || 0);
        console.log('🔗 [BD Tracker Modal] BD Plan List Data:', JSON.stringify(this.bdplanlist, null, 2));

        if (!this.bdplanlist || this.bdplanlist.length === 0) {
            console.warn('⚠️ [BD Tracker Modal] No BD Plans available to display');
        }

        this.showBdPlanModal = true;
    }

    /**
     * Handle BD Plan checkbox selection
     * @param {Event} event - Checkbox change event
     */
    handleClickCheckbox(event) {
        const selectedVal = event.currentTarget.dataset.id;

        // Clone bdplanlist for reactivity
        this.bdplanlist = [...this.bdplanlist].map(item => {
            if (item.Id === selectedVal) {
                return { ...item, isCheck: event.target.checked };
            }
            return item;
        });

        // Update map
        if (this.updateEventMap.has(selectedVal)) {
            this.updateEventMap.delete(selectedVal);
        } else {
            this.updateEventMap.set(selectedVal, selectedVal);
        }

        this.selectedIdToUpdateBDPlan = Array.from(this.updateEventMap.values());
    }

    /**
     * Save BD Plan selections
     */
    async handleSaveUpdateBDPlan() {
        try {
            await updateEventBDPlan({
                selectedIdToUpdateBDPlan: this.selectedIdToUpdateBDPlan,
                action: 'Link'
            });

            this.showToast('Success', VALIDATION_MESSAGES.BD_PLAN_LINKED, 'success');

            // Dispatch event to reload BD plans
            this.dispatchEvent(new CustomEvent('bdplanlinked', {
                bubbles: true,
                composed: true
            }));

            this.closeModal();

        } catch (error) {
            this.handleError('Error linking BD Plan', error);
        }
    }

    /**
     * Close BD Plan modal
     */
    closeModal() {
        this.showBdPlanModal = false;
    }

    /**
     * Show toast message
     * @param {string} title - Toast title
     * @param {string} message - Toast message
     * @param {string} variant - Toast variant (success, error, warning, info)
     */
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }

    /**
     * Handle errors consistently
     * @param {string} title - Error title
     * @param {Error} error - Error object
     */
    handleError(title, error) {
        const message = error.body?.message || error.message || 'An unknown error occurred';
        this.showToast(title, message, 'error');
    }
}