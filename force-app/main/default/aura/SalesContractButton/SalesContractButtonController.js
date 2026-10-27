({
	myAction : function(component, event, helper) {
        const recordId = component.get("v.recordId");
		var action = component.get("c.getInstanceUrl");
        
        action.setParams({
            recordId : recordId,
            pdfType : 'Sales Contract'
        });
         action.setCallback(this, function(response){
             console.log('response : ',response.getReturnValue());
             console.log('Record Id : '+recordId);
             const data = response.getReturnValue();
              if(data.Status){
                  //window.open(data.url+'/apex/Proforma_Invoice?Id='+recordId);        
                  component.set('v.URL',data.url+'/apex/Sales_Contracts?Id='+recordId);
             }else{
                 $A.get("e.force:closeQuickAction").fire() ;
                 var toastEvent = $A.get("e.force:showToast");
                    toastEvent.setParams({
                        "title": "Warning",
                        "type":"warning",
                        "message": data.MSG
                    });
                    toastEvent.fire();
             }
            
         });
        
        $A.enqueueAction(action);
	},
    
    ongenerate : function(component,event,helper){
       console.log('function chala');
        console.log('Function is runnign',component.get('v.URL'));
        window.open(component.get('v.URL'));
        /*var action = component.get("c.UpdateFields");
        const recordId = component.get("v.recordId");
        action.setParams({
            recordId : recordId,
            pdfType : 'Sales Contract'
        });
        
        action.setCallback(this, function(response){
            $A.get("e.force:closeQuickAction").fire();
            console.log('response : '+response);
            if(response.getState() == 'SUCCESS'){
               window.open(component.get('v.URL'));
            }
            
        });
       
        
         $A.enqueueAction(action);*/
    }
})