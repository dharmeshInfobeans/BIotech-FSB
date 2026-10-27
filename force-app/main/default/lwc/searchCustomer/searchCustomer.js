/* eslint-disable @lwc/lwc/no-async-operation */
/* eslint-disable no-console */
import { LightningElement, track, api, wire} from 'lwc';
import findAccount from '@salesforce/apex/calendarPlanningMobileController.findAccount';
import { refreshApex } from '@salesforce/apex';
import { CurrentPageReference, NavigationMixin} from 'lightning/navigation';
import { registerListener, unregisterAllListeners, fireEvent } from 'c/pubsub';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import Region from '@salesforce/label/c.Select_Region';

const DELAY = 100;
export default class SearchCustomer extends NavigationMixin(LightningElement){
    @wire(CurrentPageReference) pageRef;
    customlabels = {Region}
    @track searchKey = '';
    @api selectedval = '';
    @track accounts;
    @track noResult = false;
    url;
    @track sKey;
    @track showTabs=false;
    @track showAccount = true;
    @track accId;
    @track newCustomer = false;
    @track showDistributor = true;
    wiredData;
    @track accountType = 'All';
    regionValueToSearch;
    @track regionValue;
		@track zoneValue;
    @track zoneValue=null;
    @api userRegionSelectList;
    @api userZoneSelectList;
    @track showZone = false;
    isFind = true;
    @api labels = {};
    value = '';
    @track ObjectName='All';
    @track showAccountData=false;
    @track contactName='';

    get options() {
        return [
            { label: 'Sales', value: 'option1' },
           
        ];
    }
    @wire(findAccount, {searchKey: '$searchKey', region:'$regionValueToSearch', selectedZone:'$zoneValue',ObjectName:'$ObjectName'})
    findAccount(result){ 
        this.contactName='';
        console.log('test');
        this.wiredData = result;
        if(result.data){
            console.log('result.data ',result.data);
            this.accounts =  this.wiredData.data;
            if(this.wiredData.ContactName!=undefined) {
               this.contactName=this.wiredData.ContactName;
               console.log('Contact name',this.contactName);
            }
            console.log("Find Account ",result.data.length);
            if(result.data.length == 0){
                this.noResult = true;
            }
            else{
                this.noResult = false;
            }
        }
    }

  handleChange(event){
    console.log('Name : ',event.target.id);
    this.accountType = event.target.id.split('-')[0];
    console.log('Value : ',this.accountType);
    delete this.options[0]['checked'];
    console.log('options : ',this.options);
  }

    renderedCallback() {
      
        registerListener('refreshMachine', this.refMachine, this);
        registerListener("showPackage", this.selectedAccountValue, this);
        registerListener("resetSearchBar", this.handleResetSearchBar, this);
        registerListener("handleShowTabs", this.handleShowTabs, this);
        registerListener("handleBackFromTabScreen", this.handleHideTabs, this); 
        registerListener("refreshSearch", this.handleRefreshSearch, this);
    }

    connectedCallback(){
        console.log('connected call in search account : ',this.customlabels);
        console.log('userRegionSelectList ',this.userRegionSelectList);
        if(this.userRegionSelectList.length>0){
            this.regionValueToSearch = this.userRegionSelectList[0].label;
            this.regionValue = this.userRegionSelectList[0].label;
						this.zoneValue = this.userZoneSelectList.length > 0 ? this.userZoneSelectList[0].label : '';
            if(this.regionValue==='Domestic'){
                this.showZone = true;
            }else{
                this.showZone = false;
            }
        }
        this.searchKey = '';
        refreshApex(this.wiredData);

        if(this.ObjectName=='All') {
           this.showAccountData=true;
        }
    }

    handleChangeRegionAndZone(event){
        console.log('handleChangeRegion Name ',event.target.name);
        console.log('handleChangeRegion Value ',event.target.value);
        if(event.target.name == 'Region'){
            this.regionValue = event.target.value;
            if(event.target.value=='Domestic'){
                this.showZone = true;
                this.regionValueToSearch = null;
            }else{
                this.regionValueToSearch = this.regionValue;
                this.showZone = false;
                this.zoneValue = null;
            }
        }else{
            this.zoneValue = event.target.value;
        }
        if(this.regionValue=='Domestic' && this.zoneValue==null){
            this.isFind = false;
        }else{
            this.isFind = true;
            this.regionValueToSearch = this.regionValue;
        }
        console.log('this.isFind ',this.isFind);
        console.log('this.regionValue ',this.regionValue);
        console.log('this.zoneValue ',this.zoneValue);
        // if(this.isFind){
        //     findAccount({region:this.regionValueToSearch, selectedZone:this.zoneValue})
        //     .then(result =>{
        //         console.log('Filtered Accounts ',result);
        //         this.accounts = result;
        //     })
        //     .catch(error => {
        //         console.log('error ', error);
        //     });
        // }
    }

    clickBack(){
        fireEvent(this.pageRef, 'homeScreen', true);
    }
    disconnectedCallback() {
        // unsubscribe from searchKeyChange event
        unregisterAllListeners(this);
        this.searchKey = '';
    }
    handleRefreshSearch(){
        this.handleKeyChange('');
     return refreshApex(this.wiredData);
    }
    handleShowTabs(accId){
        console.log('accId ', accId);
        this.accId = accId;
        this.showTabs = true;
        this.showAccount = false;
        this.handleKeyChange('');
        return refreshApex(this.wiredData);
    }
    handleHideTabs(accId) {
        console.log('accId ', accId);
        this.accId = accId;
        this.showTabs = false;
        this.showAccount = true;
        this.searchKey = '';
        if (accId == 'homeFromTab'){
            fireEvent(this.pageRef, 'homeScreen', true);
        }
        return refreshApex(this.wiredData);
    }
    handleResetSearchBar(){
        console.log('handleResetSearchBar ');
        this.template.querySelector("form").reset();
    }

    selectedAccountValue(val){
        this.selectedval = val;
        console.log('this.selectedval ',this.selectedval);
    }

    refMachine(){
        //return refreshApex(this.accounts);
    }
    handleKeyChange(event) {
        this.sKey = event.target.value;
				this.searchKey = this.sKey;
        console.log('this.sKey in Search Customer', this.sKey);
        // Debouncing this method: Do not update the reactive property as long as this function is
        // being called within a delay of DELAY. This is to avoid a very large number of Apex method calls.
        // window.clearTimeout(this.delayTimeout);
        // this.delayTimeout = setTimeout(() => {
        //     this.searchKey = this.sKey;
        // }, DELAY);
    }

    // handleNewClick(){
    //     console.log('this.template.querySelector("form") ', this.template.querySelector("form"));
    //     // this.template.querySelector("form").reset();
    //     fireEvent(this.pageRef, 'handleNewCustomer', true);
    //     console.log('SKEY When Click New ',this.sKey);
    //     fireEvent (this.pageRef, 'searchKeyVal', this.sKey);
    //     // this.hideShowCust = false;
    //     console.log("New Button Clicked");
    //     this.newCustomer = true;
    // }
    // closepopup(){
    //     this.hideCustomer = true;
    //}

    cardClick(event){
        console.log('Clicked ',event.currentTarget.dataset.card);
        fireEvent(this.pageRef, 'handleShowCalendar', {'accountdata':event.currentTarget.dataset.card,'ContactName':this.contactName ,'cerating':'', 'cisrating':'', 'contactList':false});
        // fireEvent(this.pageRef, 'handleShowCalendar', {'accountdata':this.account.Id, 'cerating':this.cerating, 'cisrating':this.cisrating, 'contactList':contactList});

    }
    handleGetdata(event) {
     //   console.log('value',event.target.value);
        this.ObjectName=event.target.value;
        console.log('Object Name:',this.ObjectName);
        if(this.ObjectName=='Account' || this.ObjectName=='All') {
            this.showAccountData=true;
            console.log('test1');
        } else {
            this.showAccountData=false; 
            console.log('test2');
        }
    }
}