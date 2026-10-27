({
    /*
     * This finction defined column header
     * and calls getPendingEvents helper method for column data
     * editable:'true' will make the column editable
     * */
    doInit : function(component, event, helper) {   
        console.log("apprvdVAl-->",component.get("v.approvedStatusVal"));
        var actions = [
            { label: 'Show details', name: 'show_details' }
        ];
        component.set('v.columns', [
            {label: 'Subject', fieldName: 'Subject', iconName:'utility:travel_and_places',type: 'text'},
            {type: 'button', initialWidth:80,typeAttributes: {label: 'View', name: 'View',title: 'View',value: 'view',iconPosition: 'left'}},
            {label: 'Status', fieldName: 'Status__c',iconName:'action:update_status', type: 'text'},
            {label: 'Start', fieldName: 'StartDateTime',iconName:'utility:date_time', initialWidth:190,editable:'true', type: 'date', typeAttributes:{year: "numeric",month: "short",day: "2-digit",hour: "2-digit",minute: "2-digit"}},
            {label: 'End', fieldName: 'EndDateTime', iconName:'utility:date_time', initialWidth:190,editable:'true', type: 'date', typeAttributes:{year: "numeric",month: "short",day: "2-digit",hour: "2-digit",minute: "2-digit"}},
            {label: '?', fieldName: 'Locked__c', iconName:'utility:lock',initialWidth: 60, editable:'true', type: 'boolean'},
            {label: 'Account', fieldName: 'AccountName', iconName:'standard:account', type: 'text'},
            {label: 'Assigned To', fieldName: 'OwnerName',  iconName:'standard:people',type: 'text'}
        ]); 
        helper.showSpinner(component);
        helper.getPendingEvents(component, helper);
    },
    onReject : function (component, event, helper) {
        var editedRecords =  component.find("eventDataTable").get("v.selectedRows");
        console.log("Selected Rec-->"+JSON.stringify(editedRecords));
        
        if(!$A.util.isEmpty(editedRecords)){
            var changeStatus = true;
            var rejectstatus = component.get("v.rejectedStatusVal");
            helper.showSpinner(component);
            helper.saveDataTable(component, event, helper,changeStatus,rejectstatus);   
        }else{
            helper.showToast({
                "title": "Oops, Nothing Selected!",
                "type": "info",
                "message": "Please select atleast one event to change status."
            });
        }
        
        
    },
    onApprove : function (component, event, helper) {
        var editedRecords =  component.find("eventDataTable").get("v.selectedRows");
        console.log("Selected Rec-->"+JSON.stringify(editedRecords));
        
        if(!$A.util.isEmpty(editedRecords)){
            var changeStatus = true;
            var approvestatus = component.get("v.approvedStatusVal");
            helper.showSpinner(component);
            helper.saveDataTable(component, event, helper,changeStatus,approvestatus); 
            helper.UpdateBeatPlan(component, event, helper); 
        }else{
            helper.showToast({
                "title": "Oops, Nothing Selected!",
                "type": "info",
                "message": "Please select atleast one event to change status."
            });
        }
        
        
    },
    onRefresh : function (component, event, helper) {
        $A.get("e.force:refreshView").fire();
    },
    
    /* It is used when Inline Editing of Cell is performed
     * This function is calling saveDataTable helper function
     * to save modified records
     * */
    onSave : function (component, event, helper) {
        var changeStatus = false;
        helper.showSpinner(component);
        helper.saveDataTable(component, event, helper,changeStatus);
    },
    
    rowSelectionHandler : function (component, event, helper) {
        
        var selectedRows = event.getParam('selectedRows');
        console.log(selectedRows);
        var setRows = [];
        for(var i = 0;i<selectedRows.length; i++){
            setRows.push(selectedRows[i].Id);
        }
        console.log('--setRows-'+setRows);
        component.set("v.eveId",setRows);
        console.log('eveId==>'+component.get("v.eveId"));
        /*var action = component.get("c.getBeatPlan");
        action.setParams({
            'eventId' : setRows
        });
        action.setCallback(this,function(response) {
            var state = response.getState();
            
        });
        $A.enqueueAction(action);*/
        
        
    },
    handleRowAction : function (component, event, helper) {
        var evtRecId = event.getParam('row').Id;
        var actionName = event.getParam('action').name;
        if ( actionName == 'View') {
            /*var viewRecordEvent = $A.get("e.force:navigateToURL");
            viewRecordEvent.setParams({
                "url": "/" + recId
            });
            viewRecordEvent.fire();*/
            window.open('/'+evtRecId,'_blank');
        } 
    },
    viewRecord : function(component, event, helper) {

    }
})