/* eslint-disable eqeqeq */
/* eslint-disable no-console */
/* eslint-disable no-undef */
/* eslint-disable @lwc/lwc/no-async-operation */
import { LightningElement, wire, track, api} from 'lwc';
import findEvent from "@salesforce/apex/calendarPlanningMobileController.findEvent";
import { fireEvent } from 'c/pubsub';
import { CurrentPageReference } from 'lightning/navigation';

const DELAY = 300;
export default class searchEvent extends LightningElement {
    @wire(CurrentPageReference) pageRef;
    @track events;
    @track eventName = '';
    @api labels;

    @wire(findEvent, { eventName: '$eventName' })
    findSearchedEvent(result){ 
    if(result.data){
    this.events =  result.data;
    console.log("Find Event ",this.events);

    }
    else{
         console.log("No Record Found");
    }

  }
  renderedCallback(){
      console.log("Find Event ",this.events);
     
  }

    handleKeyChange(event) {
        // Debouncing this method: Do not update the reactive property as long as this function is
        // being called within a delay of DELAY. This is to avoid a very large number of Apex method calls.
        window.clearTimeout(this.delayTimeout);
        if(event.target.value !='  '){
            const eventNameToFind = event.target.value;
            console.log("Key Change ",eventNameToFind);
            this.delayTimeout = setTimeout(() => {
                this.eventName = eventNameToFind;
            }, DELAY);
        }
       
    }

    clickBack(){
        fireEvent(this.pageRef, 'clickBack', true);
    }
}