({
    onCloseIconClick : function(component, event, helper) {
        component.set("v.showInitMessage", true);
        component.set("v.initMessage", "Please hover over AOP quantity to view details"); 
    },
    onMppMonthClick : function(component, event, helper) {
        var mppId = event.currentTarget.dataset.mppid;
        if(mppId){
            window.open('/'+mppId,'_blank');
        }
    },
    onAOPQtyClick : function(component, event, helper) {
        var aopRecId = component.get("v.aopId");	
         if(aopRecId){
            window.open('/'+aopRecId,'_blank');
        }
    },
    handleApplicationEvent : function(component, event, helper) {
        
        var showDetail = event.getParam("showDetails");
        var accId = event.getParam("accountId");
        var aopId = event.getParam("aopId");
        var prodId = event.getParam("prodId");
        var mpId = event.getParam("mpId");
        var fYear = event.getParam("fiscalYear");
        var month = event.getParam("month");
        
        if(showDetail){
            
            component.set("v.showInitMessage", false);	
            /* console.log("In AppEvtHandler-->acc DATA-->"+JSON.stringify(accId));
            console.log("In AppEvtHandler-->aop DATA-->"+JSON.stringify(aopId));
            console.log("In AppEvtHandler-->prod DATA-->"+JSON.stringify(prodId));
            console.log("In AppEvtHandler-->mp DATA-->"+JSON.stringify(mpId));
            console.log("In AppEvtHandler-->fyear DATA-->"+JSON.stringify(fYear));
            console.log("In AppEvtHandler-->Month-->"+JSON.stringify(month));*/
            
            // set the handler attributes based on event data
            component.set("v.accId", accId);	
            component.set("v.prodId", prodId);
            component.set("v.mpId", mpId);	
            component.set("v.aopId", aopId);
            component.set("v.fiscalYear", fYear);	
            component.set("v.month", month);
            
            helper.getMpps(component,event);  
        }else{
            component.set("v.showInitMessage", true);
            component.set("v.initMessage", "Please hover over AOP quantity to view details");
        }
        
        
    },
    
})