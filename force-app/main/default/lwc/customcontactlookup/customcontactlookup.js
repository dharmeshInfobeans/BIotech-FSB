import { LightningElement, api, wire, track } from 'lwc';
// import apex method from salesforce module 
import fetchContactLookupData from '@salesforce/apex/CustomLeadCreationController.fetchContactLookupData';
const DELAY = 300; // dealy apex callout timing in miliseconds  
import {
    registerListener,
    unregisterAllListeners,
    fireEvent
} from "c/pubsub";
import { refreshApex } from '@salesforce/apex';
import {
NavigationMixin
} from 'lightning/navigation';
import {
ShowToastEvent
} from 'lightning/platformShowToastEvent';
import {
CurrentPageReference
} from 'lightning/navigation';

export default class customcontactlookup  extends NavigationMixin(LightningElement) {
    // public properties with initial default values 
    @api label = 'custom lookup label';
    @api placeholder = 'search...';
    @api iconName = 'standard:Contact';
    @api sObjectApiName = 'Contact';
    @api contactid;
    @api selectedRecord;

    @track conId = '';
    @track accountId = '';
    @wire(CurrentPageReference) pageRef;
    // private properties 
    lstResult = []; // to store list of returned records   
    hasRecords = true;
    searchKey = ''; // to store input field value    
    isSearchLoading = false; // to control loading spinner  
    delayTimeout;
    selectedRecord = {}; // to store selected lookup record in object formate 
    // initial function to populate default selected lookup record if defaultRecordId provided  
    connectedCallback() {

    }
    renderedCallback() {
        registerListener('accountIdData', this.accountIdData, this);
        registerListener('contId', this.contId, this);
    }
    contId(conId) {
        this.conId=
        this.conId = conId;
          
        fetchContactLookupData({ searchKey: this.searchKey, AccountId: this.accountId, contId: this.conId }).then(result => {
            console.log('45--------------------------------');
            const { data, error } = result; // destructure the provisioned value
            this.isSearchLoading = false;
            console.log('result Contact', result);
            this.hasRecords = result.length == 0 ? false : true;
            this.lstResult = JSON.parse(JSON.stringify(result));
            console.log('Result contact',this.lstResult);
            if(this.lstResult.length>0) {
            this.selectedRecord = this.lstResult.find(data => data.Id === this.lstResult[0].Id); // find selected record from list 
            console.log('Selected record-----', this.selectedRecord);
            this.selectedRecord['contact'] = 'contact';
            this.selectedRecord['Name'] = this.selectedRecord.FirstName + ' ' + this.selectedRecord.LastName;
             console.log('this.selectedRecord',this.selectedRecord['Name']);
             if(this.selectedRecord.MobilePhone ==undefined || this.selectedRecord.MobilePhone ==''){
                this.showErrorMessage('Please add mobile number on selected contact before create lead');
                this.selectedRecord={};
                return;
              
            }
            this.handelSelectRecordHelper();
             
            this.lookupUpdatehandler(this.selectedRecord);
              // update value on parent component as well from helper function 
            // helper function to show/hide lookup result container on UI
            }
        }).catch(error => {
            console.log('error', error);
        })

    }
    accountIdData(accId) {
        if (accId != '' && accId != undefined) {
            console.log('AccountId----121', accId);
            this.accountId = accId;
            fetchContactLookupData({ searchKey: this.searchKey, AccountId: accId, contId: ''}).then(result => {
                const { data, error } = result; // destructure the provisioned value
                this.isSearchLoading = false;
                console.log('result', result);
                this.hasRecords = result.length == 0 ? false : true;
                this.lstResult = JSON.parse(JSON.stringify(result));
                refreshApex(this.lstResult);
                console.log('On selected the accounts',this.lstResult);
            }).catch(error => {
                console.log('error', error);
            })
        } else {
            this.hasRecords = false;
            this.lstResult = null;
            this.searchKey = '';
            this.selectedRecord = {};
            this.lookupUpdatehandler("contact"); 
            const searchBoxWrapper = this.template.querySelector('.searchBoxWrapper');
            searchBoxWrapper.classList.remove('slds-hide');
            searchBoxWrapper.classList.add('slds-show');
            const pillDiv = this.template.querySelector('.pillDiv');
            pillDiv.classList.remove('slds-show');
            pillDiv.classList.add('slds-hide');
        }

    }

    handleKeyChange(event) {
        // Debouncing this method: Do not update the reactive property as long as this function is
        // being called within a delay of DELAY. This is to avoid a very large number of Apex method calls.
        this.isSearchLoading = true;
        window.clearTimeout(this.delayTimeout);
        const searchKey = event.target.value;
          fetchContactLookupData({ searchKey: searchKey, AccountId: this.accountId, contId:'' }).then(result => {
            const { data, error } = result; // destructure the provisioned value
            this.isSearchLoading = false;
            console.log('result', result);
            this.hasRecords = result.length == 0 ? false : true;
            this.lstResult = JSON.parse(JSON.stringify(result));
           
         // update value on parent component as well from helper function 
            // helper function to show/hide lookup result container on UI

        }).catch(error => {
            console.log('error', error);
        })
        this.delayTimeout = setTimeout(() => {
            this.searchKey = searchKey;
        }, DELAY);
    }
    // method to toggle lookup result section on UI 
    toggleResult(event) {
        const lookupInputContainer = this.template.querySelector('.lookupInputContainer');
        const clsList = lookupInputContainer.classList;
        const whichEvent = event.target.getAttribute('data-source');
        switch (whichEvent) {
            case 'searchInputField':
                clsList.add('slds-is-open');
                break;
            case 'lookupContainer':
                clsList.remove('slds-is-open');
                break;
        }
    }
    // method to clear selected lookup record  
    handleRemove() {
        this.searchKey = '';
            fetchContactLookupData({ searchKey: this.searchKey, AccountId: this.accountId, contId: this.conId }).then(result => {
            const { data, error } = result; // destructure the provisioned value
            this.isSearchLoading = false;
            console.log('result', result);
            this.hasRecords = result.length == 0 ? false : true;
            this.lstResult = JSON.parse(JSON.stringify(result));
            console.log('Result contact',this.lstResult);
            console.log('Selected record', this.selectedRecord);

          // update value on parent component as well from helper function 
            // helper function to show/hide lookup result container on UI

        }).catch(error => {
            console.log('error', error);
        })
        this.selectedRecord = {};
        this.lookupUpdatehandler("contact"); // update value on parent component as well from helper function 
        // remove selected pill and display input field again 
        const searchBoxWrapper = this.template.querySelector('.searchBoxWrapper');
        searchBoxWrapper.classList.remove('slds-hide');
        searchBoxWrapper.classList.add('slds-show');
        const pillDiv = this.template.querySelector('.pillDiv');
        pillDiv.classList.remove('slds-show');
        pillDiv.classList.add('slds-hide');
        
    }
    // method to update selected record from search result 
    handelSelectedRecord(event) {
        var objId = event.target.getAttribute('data-recid'); // get selected record Id 
        
        this.selectedRecord = this.lstResult.find(data => data.Id === objId); // find selected record from list 
        this.selectedRecord['contact'] = 'contact';
        console.log('Selected',this.selectedRecord);
        this.selectedRecord['Name'] = this.selectedRecord.FirstName + ' ' + this.selectedRecord.LastName;
          if(this.selectedRecord.MobilePhone ==undefined || this.selectedRecord.MobilePhone ==''){
                this.showErrorMessage('Please add mobile number on selected contact before create lead');
                this.selectedRecord={};
                return;
              
            }
        this.lookupUpdatehandler(this.selectedRecord); // update value on parent component as well from helper function 
        this.handelSelectRecordHelper(); // helper function to show/hide lookup result container on UI
    }

    get combinedValue() {
        const name = this.selectedRecord?.Name || ''; // Safe check for null or undefined
        const mobile = this.selectedRecord?.MobilePhone || ''; // Mobile number if needed
        return `${name} -- ${mobile}`; // Concatenate name and mobile
    }
    /*COMMON HELPER METHOD STARTED*/
    handelSelectRecordHelper() {
        console.log('in selected');
        this.template.querySelector('.lookupInputContainer').classList.remove('slds-is-open');
        const searchBoxWrapper = this.template.querySelector('.searchBoxWrapper');
        searchBoxWrapper.classList.remove('slds-show');
        searchBoxWrapper.classList.add('slds-hide');
        const pillDiv = this.template.querySelector('.pillDiv');
        pillDiv.classList.remove('slds-hide');
        pillDiv.classList.add('slds-show');
    }
    // send selected lookup record to parent component using custom event
    lookupUpdatehandler(value) {
        console.log('value',value);
        const oEvent = new CustomEvent('lookupupdate',
            {
                'detail': { selectedRecord: value }
            }
        );
        this.dispatchEvent(oEvent);
    }


@api handleSubmit() {
    console.log('2nd testtt11111');

    // Get input field
    const field1 = this.template.querySelector('lightning-input[name="field1"]');
    
    console.log('fields', field1);


    // Check if field is available and not empty
    if (field1 && field1.value) {
        isnull = true
        // Your form submission logic here
        console.log('Form submitted successfully');
    } else {
        // Set custom validity and report validity
        if (field1) {
            field1.setCustomValidity('Contact is required');
            field1.reportValidity();
        }
    }
}
showErrorMessage(meesage) {
    const evt = new ShowToastEvent({
        title: 'Error',
        message: meesage,
        variant: 'error',
        mode: 'dismissable'
    });
    this.dispatchEvent(evt);
}

}