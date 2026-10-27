import { LightningElement, wire, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getLeadRecords from '@salesforce/apex/LeadKycStatusController.getLeadRecords';
import getcustomercreationmodule from '@salesforce/apex/CommonutiltiyClass.getCustomLabelscustomercreation';


export default class LeadKycStatusScreen extends LightningElement {

  @api recordId;
  @track rsmApproved = false;
  @track zsmApproved = false;
  @track rsmRejected = false;
  @track zsmRejected = false;
  @track rsmInfo;
  @track zsmInfo;
  @track rsmInfoRej;
  @track zsmInfoRej;
  @track rsmComments;
  @track zsmComments;
  @track rsmCommentsVisible = false;
  @track zsmCommentsVisible = false;
  // ===============================
@track rsmshow = false;
@track zsmshow = false;
@track gmnsmshow = false;
@track adminshow = true;




  //-------------------------------
  @track gmApproved = false;
  @track adminApproved = false;
  @track gmRejected = false;
  @track adminRejected = false;
  @track gmInfo;
  @track adminInfo;
  @track gmInfoRej;
  @track adminInfoRej;
  @track gmComments;
  @track adminComments;
  @track gmCommentsVisible = false;
  @track adminCommentsVisible = false;
  @track rsmPending=false;
  @track zsmPending=false;
  @track gmPending=false;
  @track adminPending=false;
  @track getcustomermodulelabel={};
  mainData;

  get getRsmMarkerClass() {
    if (this.rsmApproved) {
      return 'timeline-marker success';
    } else if (this.rsmRejected) {
      return 'timeline-marker nosuccess';
    } else if(this.rsmPending){
        return 'timeline-marker pending';
    }else {
      return 'timeline-marker bydefaultSet';
    }
  }

  @wire(getcustomercreationmodule)
getloginlogout(result) {
    if (result.data) {
        this.getcustomermodulelabel = result.data;
        console.log('Translation getloginlogoutlabel', this.getcustomermodulelabel);
        if (this.getcustomermodulelabel != undefined) {
            
        }
    }
    if (result.error) {
        console.log('error', result.error);
    }
}

  get getZsmMarkerClass() {
    if (this.zsmApproved) {
      return 'timeline-marker success';
    } else if (this.zsmRejected) {
      return 'timeline-marker nosuccess';
    } else if(this.zsmPending){
        return 'timeline-marker pending';
    }else {
      return 'timeline-marker bydefaultSet';
    }
  }

  get getGmMarkerClass() {
    if (this.gmApproved) {
      return 'timeline-marker success';
    } else if (this.gmRejected) {
      return 'timeline-marker nosuccess';
    }else if(this.gmPending){
        return 'timeline-marker pending';
    } else {
      return 'timeline-marker bydefaultSet';
    }
  }

  get getAdminMarkerClass() {
    if (this.adminApproved) {
      return 'timeline-marker success';
    } else if (this.adminRejected) {
      return 'timeline-marker nosuccess';
    } else if(this.adminPending){
        return 'timeline-marker pending';
    }else {
      return 'timeline-marker bydefaultSet';
    }
  }

  connectedCallback() {
    this.handleGetData();
  }

  handleGetData() {
    this.rsmPending=false;
    this.zsmPending=false;
    this.gmPending=false;
    this.adminPending=false;
    getLeadRecords({
      recordId: this.recordId
    })
      .then((result) => {
        var showPending=true;
        this.rsmshow = false;
        this.zsmshow = false;
        this.gmnsmshow = false;
        this.adminshow = true;
         var mainData = result;
         console.log('mainData---->',mainData);

       if(mainData.RSM__c!=null && mainData.RSM__c!=undefined && mainData.RSM__c!='') {
        this.rsmshow=true;
       }
       if(mainData.ZSM__c!=null && mainData.ZSM__c!=undefined && mainData.ZSM__c!=''){
        this.zsmshow = true;
       }
       if(mainData.GM_NSM__c!=null && mainData.GM_NSM__c!=undefined && mainData.GM_NSM__c!=''){
        this.gmnsmshow = true;
       }




       
        this.leadRecord = result;
        this.leadRecord = mainData
        this.rsmApproved = mainData.RSM_Approve__c;
        this.zsmApproved = mainData.ZSM_Approve__c;
        this.rsmRejected = mainData.RSM_Not_Approve__c;
        this.zsmRejected = mainData.ZSM_Not_Approve__c;
        console.log('ZSM-->', this.zsmRejected);
        this.rsmInfo = 'Approved';  // You can set this to any data you want to display when RSM is approved
        this.zsmInfo = 'Approved';  // You can set this to any data you want to display when ZSM is approved
        this.rsmInfoRej = 'Rejected';  // You can set this to any data you want to display when RSM is approved
        this.zsmInfoRej = 'Rejected';
        this.rsmComments = mainData.RSM_Comments__c;
        this.zsmComments = mainData.ZSM_Comments__c;
        // ==============
        this.gmApproved = mainData.GM_NSM_Approve__c;
        this.adminApproved = mainData.Admin_Approve__c;
        this.gmRejected = mainData.GM_NSM_Not_Approve__c;
        this.adminRejected = mainData.Admin_Not_Approve__c;
        console.log('ZSM-->', this.zsmRejected);
        this.gmInfo = 'Approved';  // You can set this to any data you want to display when RSM is approved
        this.adminInfo = 'Approved';  // You can set this to any data you want to display when ZSM is approved
        this.gmInfoRej = 'Rejected';  // You can set this to any data you want to display when RSM is approved
        this.adminInfoRej = 'Rejected';
        this.gmComments = mainData.GM_NSM_Comments__c;
        this.adminComments = mainData.Admin_Comments__c;

          console.log('Uploadcount',mainData.Upload_Count__c);
          if(this.rsmRejected || this.zsmRejected || this.gmRejected || this.adminRejected) {
               showPending=false;
          } 

          console.log('Show pending',showPending);

      if(showPending) {
          if(mainData.Upload_Count__c>0 && !this.rsmApproved && !this.rsmRejected) {
            this.rsmPending=true;
        }
        if(mainData.Upload_Count__c>0 && !this.zsmApproved && !this.zsmRejected) {
            this.zsmPending=true;
        }
        if(mainData.Upload_Count__c>0 && !this.gmApproved && !this.gmRejected) {
            if(this.rsmApproved && this.zsmApproved) {
               this.gmPending=false;
            }else {
              this.gmPending=true;
            }
           
        }
        if(mainData.Upload_Count__c>0 && !this.adminApproved && !this.adminRejected) {
            this.adminPending=true;
        }
      }
       
      })
      .catch((error) => {
        this.showToast("FAILED", "Something went wrong!", "error");
      });
  }

  showRsmComments() {
    if (this.rsmApproved || this.rsmRejected) {
      this.rsmCommentsVisible = true;
    }
  }

  hideRsmComments() {
    this.rsmCommentsVisible = false;
  }

  showZsmComments() {
    if (this.zsmApproved || this.zsmRejected) {
      this.zsmCommentsVisible = true;
      console.log('comment-->', this.zsmCommentsVisible);
    }
  }

  hideZsmComments() {
    this.zsmCommentsVisible = false;
  }

  // ================
  showGmComments() {
    if (this.rsmApproved || this.rsmRejected) {
      this.gmCommentsVisible = true;
    }
  }

  hideGmComments() {
    this.gmCommentsVisible = false;
  }

  showAdminComments() {
    if (this.adminApproved || this.adminRejected) {
      this.adminCommentsVisible = true;
      console.log('comment-->', this.zsmCommentsVisible);
    }
  }

  hideAdminComments() {
    this.adminCommentsVisible = false;
  }

  showToast(title, msg, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: msg,
            variant: variant
        });
        this.dispatchEvent(event);
    }

}