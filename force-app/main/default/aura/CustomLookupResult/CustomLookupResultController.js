({
    selectRecord : function(component, event, helper){      
        // get the selected record from list  
        console.log("--------------event called ");
     //   debugger;
        var iNameVal =component.get("v.IconName");
        var ind = component.get("v.indexValue");
        var conId = component.get('v.contId');
        var getSelectRecord = component.get("v.oRecord");
        console.log("@@@@@@@@@@@@@@@@@account id "+getSelectRecord.Id);
        // call the event   
        var compEvent = component.getEvent("oSelectedRecordEvent");
        
        // set the Selected sObject Record to the event attribute.  
        compEvent.setParams({"recordByEvent" : getSelectRecord,
                             "accountId" : getSelectRecord.Id,
                             "iName" : iNameVal,
                             "contactId":conId,
                             "indexValue":ind});  
        // fire the event  
        compEvent.fire();
    },
})