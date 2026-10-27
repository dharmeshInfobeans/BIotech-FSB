import { LightningElement,track,api, wire } from 'lwc';
import findRecords from '@salesforce/apex/calendarPlanningMobileController.findRecords';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import { registerListener, unregisterAllListeners, fireEvent } from 'c/pubsub';

export default class CustomLookupComponent extends LightningElement {
    @wire(CurrentPageReference) pageRef;
    @track records;
    @track error;
    @track selectedRecord;
    @api index;
    @api relationshipfield;
    @api iconname = "standard:account";
    @api objectName = 'Account';
    @api searchfield = 'Name';
    @api label;
    @api keyval='';
    handleOnchange(event){
        //event.preventDefault();
        const searchKey = event.detail.value;
        //this.records = null;
        /* eslint-disable no-console */
         console.log(searchKey);

        /* Call the Salesforce Apex class method to find the Records */
        if(searchKey){
        findRecords({
            searchKey : searchKey, 
            objectName : this.objectName, 
            searchField : this.searchfield
        })
        .then(result => {
            this.records = result;
            console.log('search records',this.records);
            for(let i=0; i < this.records.length; i++){
                const rec = this.records[i];
                this.records[i].Name = rec[this.searchfield];
            }
            this.error = undefined;
            //console.log(' records ', this.records);
        })
        .catch(error => {
            this.error = error;
            this.records = undefined;
        });
    }else{
        this.records = null;
        console.log(this.records);
    }
    }
    
    handleSelect(event){
        const selectedRecordId = event.detail;
        console.log('event',event.detail);
        /* eslint-disable no-console*/
        this.selectedRecord = this.records.find( record => record.Id === selectedRecordId);
        console.log('selectedRecord',  this.selectedRecord);
        /* fire the event with the value of RecordId for the Selected RecordId */
        const selectedRecordEvent = new CustomEvent(
            "selectedrec",
            {
                //detail : selectedRecordId
                detail : { recordId : selectedRecordId, index : this.index, relationshipfield : this.relationshipfield,object :this.objectName}
            }
        );
        this.dispatchEvent(selectedRecordEvent);
    }

    handleRemove(event){
        event.preventDefault();
        this.selectedRecord = undefined;
        this.records = undefined;
        this.error = undefined;
        /* fire the event with the value of undefined for the Selected RecordId */
        const selectedRecordEvent = new CustomEvent(
            "selectedrec",
            {
                detail : { recordId : undefined, index : this.index, relationshipfield : this.relationshipfield,object :this.objectName}
            }
        );
        this.dispatchEvent(selectedRecordEvent);
    }
}