({
    getPendingEvents : function(component, event, helper) {
        //console.log('In helper');
        var action = component.get("c.getEvents");
        action.setCallback(this,function(response) {
            var state = response.getState();
            //console.log('In helper STATE->'+state);
            this.hideSpinner(component);
            //console.log('After hiding spinner!!->');
            if (state === "SUCCESS") {
                this.hideSpinner(component);
                //console.log("FROM APEX-->RCVD EVENTS-->"+JSON.stringify(response.getReturnValue()));
                let retDatas = response.getReturnValue();
                console.log('retDatas LENGTH->'+ retDatas.length);
                for (var i = 0; i < retDatas.length; i++) {
                    var retData = retDatas[i];
                    if (retData.What){
                        retData.AccountName = retData.What.Name;    
                    }
                    
                    if (retData.Owner){
                        retData.OwnerName = retData.Owner.Name;    
                    }
                }
               // console.log("RetVal-->Added Parent Prop-->"+JSON.stringify(retDatas));
                component.set("v.data", retDatas);
            }else{
                this.hideSpinner(component);
                console.log("ERROR in getting Events from Apex!!");
            }
        });
        $A.enqueueAction(action);
    },
    
    /*
     * This function get called when user clicks on Save button
     * user can get all modified records
     * and pass them back to server side controller
     * */
    saveDataTable : function(component, event, helper,statBool,status) {
        let editedRecords;
        let totalRecordEdited;
        if(statBool === true && (status == component.get("v.approvedStatusVal")) ){
            console.log('Approve-->Boolean true....from button');
            var selectedRowList = component.find("eventDataTable").getSelectedRows();
            console.log("OG DATA-->"+JSON.stringify(selectedRowList));
            for(var j = 0; j < selectedRowList.length; j++){
                var eachRowData = selectedRowList[j];
                eachRowData.Status__c = component.get("v.approvedStatusVal");
                eachRowData.Locked__c = false;
            }
            editedRecords = selectedRowList;
            totalRecordEdited = editedRecords.length;
            
            console.log("MODIFIED DATA-->"+JSON.stringify(editedRecords));
        }else if(statBool === true && (status == component.get("v.rejectedStatusVal")) ){
            console.log('Rejected-->Boolean true....from button');
            var selectedRowList = component.find("eventDataTable").getSelectedRows();
            console.log("OG DATA-->"+JSON.stringify(selectedRowList));
            for(var j = 0; j < selectedRowList.length; j++){
                var eachRowData = selectedRowList[j];
                eachRowData.Status__c = component.get("v.rejectedStatusVal");
                eachRowData.Locked__c = false;
            }
            editedRecords = selectedRowList;
            totalRecordEdited = editedRecords.length;
            
            console.log("MODIFIED DATA-->"+JSON.stringify(editedRecords));
        }else{
            editedRecords =  component.find("eventDataTable").get("v.draftValues");
            console.log('DRAFT VALUES-->'+JSON.stringify(editedRecords));
            totalRecordEdited = editedRecords.length;   
        }
        
        
        var action = component.get("c.updateEvents");
        action.setParams({
            'editedAccountList' : editedRecords
        });
        action.setCallback(this,function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                this.hideSpinner(component);
                //if update is successful
                if(response.getReturnValue() === true){
                    helper.showToast({
                        "title": "Record Update",
                        "type": "success",
                        "message": totalRecordEdited+" Account Records Updated"
                    });
                    helper.reloadDataTable();
                } else{ //if update got failed
                    this.hideSpinner(component);
                    helper.showToast({
                        "title": "Error!!",
                        "type": "error",
                        "message": "Error updating events..."
                    });
                }
            }
        });
        $A.enqueueAction(action);
    },
    
    UpdateBeatPlan : function(component, event, helper){
    	var action = component.get("c.getBeatPlan");
        action.setParams({
            'eventId' : component.get("v.eveId")
        });
        action.setCallback(this,function(response) {
            var state = response.getState();
            
        });
        $A.enqueueAction(action);    
    }, 
    
    /*
     * Show toast with provided params
     * */
    showToast : function(params){
        var toastEvent = $A.get("e.force:showToast");
        if(toastEvent){
            toastEvent.setParams(params);
            toastEvent.fire();
        } else{
            alert(params.message);
        }
    },
    
    /*
     * reload data table
     * */
    reloadDataTable : function(){
        var refreshEvent = $A.get("e.force:refreshView");
        if(refreshEvent){
            refreshEvent.fire();
        }
    },
    
    showSpinner : function(component){
        component.set("v.showSpinner",true);
    },
    hideSpinner : function(component){
        component.set("v.showSpinner",false);
    }
})