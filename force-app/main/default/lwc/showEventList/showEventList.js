import { api, LightningElement, track, wire} from 'lwc';
import updateEventData from "@salesforce/apex/calendarPlanningMobileController.updateEventData";
import deleteEventData from "@salesforce/apex/calendarPlanningMobileController.deleteEventData";
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CurrentPageReference } from 'lightning/navigation';
import { registerListener, unregisterAllListeners, fireEvent } from "c/pubsub";
import getEventsForBDPlan from "@salesforce/apex/calendarPlanningMobileController.getEventsForBDPlan"; 
import updateEventBDPlan from "@salesforce/apex/calendarPlanningMobileController.updateEventBDPlan"; 
import Update_BD_Plan from '@salesforce/label/c.Update_BD_Plan';
import Selected_BD_Plans from '@salesforce/label/c.Selected_BD_Plans';
import Type_of_Planning from '@salesforce/label/c.Type_of_Planning';
import Plan_Week from '@salesforce/label/c.Plan_Week';
import Product from '@salesforce/label/c.Product';
import Contact from '@salesforce/label/c.Contact';
import MileStone_Stage from '@salesforce/label/c.MileStone_Stage';
import Plan_Year from '@salesforce/label/c.Plan_Year';
import getLeadData from '@salesforce/apex/calendarPlanningMobileController.getLeadData';


export default class ShowEventList extends LightningElement {
    @wire(CurrentPageReference) pageRef;
    customLabels = {
        Update_BD_Plan,Selected_BD_Plans,Type_of_Planning,Plan_Week,Product,Contact,MileStone_Stage,Plan_Year
    }
    @api evelists;
    @api labels;
    @track eventRecordId;
    @track showEditEventModal = false;
    @track eventObj;
    @track meetingOptions;
    @track options;
    @track spinner = false;
    selectedProduct='';
    @track otherType = false;
    @track bdplanlist;
    updateEventMap = {};
    @track accountId;
    @track leadData=[];
    @track eventstage = true;
      
   
    @api ownerid;
    updateBDPlanEventMap = new Map();
    selectedIdToUpdateBDPlan;


    connectedCallback(){
        console.log('evelists ',JSON.stringify(this.evelists));
        console.log('labels ',this.labels);
    }

    renderedCallback(){
        // registerListener("reloadComponent", this.reloadComponent, this);
    }

    // reloadComponent(){
    //     console.log('reloadComponent');
    //     this.spinner = true;
    //     //setTimeout(function(){ this.spinner = false; }, 1000);
    //     this.spinner = false;
    // }

    editEventDetail(event){
        console.log('eventId ',event.currentTarget.dataset.id);
        this.eventRecordId = event.currentTarget.dataset.id;
        for(var event of this.evelists){
            if(event.Id==this.eventRecordId){
                console.log('editEventDetail event ',event);
                this.eventObj = JSON.parse(JSON.stringify(event));
                this.eventObj.Product=event.Product;
                this.accountId = this.eventObj.AccountId;
                if(this.eventObj.OtherType){
                    this.otherType = true;
                }else{
                    this.otherType = false;
                }
                if(this.eventObj.stage =='Planned'){
                    this.eventstage = false;
                }
                this.updateEventMap['Id']=this.eventRecordId;
                this.updateEventMap['Subject']=event.Subject;
                this.updateEventMap['Call_Type__c'] = event.CallType;  //********************Gyadeen ahirwar********************* */
                this.updateEventMap['ActivityDate']=event.ActivityDate;
                this.updateEventMap['Follow_Up_Date__c']=event.FollowUpDate;
                this.updateEventMap['Product__c']=event.Product;
                this.updateEventMap['DCR_Description__c']=event.Description!=undefined?event.Description:null;
                this.updateEventMap['StartDateTime']=event.ActivityDate;
                this.updateEventMap['EndDateTime']=event.ActivityDate;
                break;
            }
        }
        console.log('After Click Edit eventObj ',this.eventObj);
        console.log('After Click Edit updateEventMap ',this.updateEventMap);
        this.showEditEventModal = true;
    }
    handleCancel(){
        this.showEditEventModal = false;
    }
    
    handleUpdateBDPlan(){
        console.log('accountId ',this.eventRecordId);
        console.log('skey ',this.ownerid);
        getEventsForBDPlan({accountid:this.accountId,  userid:this.ownerid,  action:'Update'})
            .then(result =>{
                this.bdplanlist = JSON.parse(JSON.stringify(result));
                console.log('getEventsForBDPlan bdplanlist ',this.bdplanlist);
                this.spinner = true;
                this.showEditEventModal = false;
                this.updateBdPlan = true;
                this.spinner = false;
            })
            .catch(error => {
                console.log('error ', error);
            });

   //Adding by gyadeen Below
    getLeadData({leadId:this.eventRecordId}).then(result=>{
          console.log('Lead result',result);  
          this.leadData=result;
           this.spinner = true;
                this.showEditEventModal = false;
                this.updateBdPlan = true;
                this.spinner = false;
        }).catch(error=>{
            console.log('error',error);
        })
// adding by Gyadeen 
    }

    handleClickCheckbox(event){
        console.log('Clicked ',event.target.checked);
        console.log('Id ',event.currentTarget.dataset.id);  
        var selectedVal = event.currentTarget.dataset.id;
        this.bdplanlist = JSON.parse(JSON.stringify(this.bdplanlist));     
         for(var item of this.bdplanlist){
            if(event.currentTarget.dataset.id == item.Id){
                item.isCheck = event.target.checked;
            }
        }
        console.log('this.bdplanlist ',this.bdplanlist);
        if(event.target.checked){
            this.updateBDPlanEventMap.set(selectedVal, selectedVal);
        }else{
            if(this.updateBDPlanEventMap.has(selectedVal)){
                this.updateBDPlanEventMap.delete(selectedVal);
            }
        }
        console.log('this.updateBDPlanEventMap ',this.updateBDPlanEventMap);
        this.selectedIdToUpdateBDPlan = Array.from(this.updateBDPlanEventMap.values());
        console.log('selectedIdToUpdateBDPlan ',this.selectedIdToUpdateBDPlan);
    }

    handleChangeField(event){
        this.updateEventMap[event.target.name] = event.target.value;
        console.log('updateEventMap ',this.updateEventMap);
        if(event.target.name == 'ActivityDate'){
            this.updateEventMap[event.target.name]=event.target.value;
            this.updateEventMap['StartDateTime']=event.target.value;
            this.updateEventMap['EndDateTime']=event.target.value;
        }
    }
    handleSelectProduct(data){
        console.log('Selected Product Data ',data.detail);
        this.selectedProduct = data.detail;
        this.eventObj.Product = this.selectedProduct;
        console.log('this.eventObj ',this.eventObj);
        this.updateEventMap['Product__c']=this.eventObj.Product;
    }

    closeBdrModal(){
        this.showEditEventModal = true;
        this.updateBdPlan = false;
    }

    updateEvent(){
        console.log('this.updateEventMap ',this.updateEventMap);
        updateEventData({dataMap:this.updateEventMap})
        .then(result =>{
            console.log('Update opp ',result);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Event Updated',
                    message: 'Event Updated Successfully',
                    variant: 'success'
                })
            );
            // const cancelEvent = new CustomEvent(
            //     "cancel",
            //    {detail:"save"}
            // );
            // this.dispatchEvent(cancelEvent);
            // fireEvent(this.pageRef, "cancelEvent", true); 
            fireEvent(this.pageRef, "reloadEvents", this.updateEventMap['ActivityDate']);
            this.showEditEventModal = false;
        })
        .catch(error => {
            console.log('error ', error);
            this.dispatchEvent(
                new ShowToastEvent({
                    message: error.body.message,
                    variant: 'error'
                })
            );
        });
    }
    handleDelete(){
        deleteEventData({dataMap:this.updateEventMap})
        .then(result =>{
            console.log('Deleted opp ',result);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Event Deleted',
                    message: 'Event Deleted Successfully',
                    variant: 'success'
                })
            );
            fireEvent(this.pageRef, "reloadEvents", this.eventObj.ActivityDate);
            this.spinner = true;
            this.showEditEventModal = false;
            // this.reloadComponent();
            this.spinner = false;
        })
        .catch(error => {
            console.log('error ', error);
            this.dispatchEvent(
                new ShowToastEvent({
                    message: error.body.message,
                    variant: 'error'
                })
            );
        });
    }

    handleSaveUpdateBDPlan(){
        updateEventBDPlan({selectedIdToUpdateBDPlan:this.selectedIdToUpdateBDPlan, action:'Update'})
        .then(result =>{
            console.log('updateEventBDPlan ',result);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'BD Plan Updated',
                    message: 'BD Plan Updated Successfully',
                    variant: 'success'
                })
            );
            fireEvent(this.pageRef, "reloadBDPlanEvent", true);
            this.updateBdPlan = false;
            this.showEditEventModal = true;
        })
        .catch(error => {
            console.log('error ', error);
            this.dispatchEvent(
                new ShowToastEvent({
                    message: error.body.message,
                    variant: 'error'
                })
            );
        });
    }
}