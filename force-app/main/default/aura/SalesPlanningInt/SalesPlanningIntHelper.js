({
    handleDestroy : function(component,event,auraIdToDestroy){
        //console.log("In SalesPLanningINt-->H-->handleDestroy_M !!!");
        if(!$A.util.isUndefinedOrNull(component.find(auraIdToDestroy)) || !$A.util.isEmpty(component.find(auraIdToDestroy))){
            //if( component.find(auraIdToDestroy) !=null || component.find(auraIdToDestroy)!='undefined'){
            //console.log("In SalesPLanningINt-->H-->handleDestroy_M--> Inside Destroy!!");   
            window.setTimeout(
                    $A.getCallback(function() {
                        if(auraIdToDestroy && !$A.util.isEmpty(component.find(auraIdToDestroy))){
                        	console.log('In SalesPLanningINt-->H-->handleDestroy_M-->IF-->In TimeOut Function!!');    
                            component.find(auraIdToDestroy).destroy();
                        }
                        
           }), 5);
           // console.log("In SalesPLanningINt-->H-->handleDestroy_M-->Comp Destroyed!!");   
        }else{
            console.log("In SalesPLanningINt-->H-->handleDestroy_M-->Component is already Destroyed.");
        }
        
    },
    handleActive: function (component, event) {
        let lastDayForPlanning =  component.get("v.endDayOfMonth");
        //console.log("In SalesPLanningINt-->H-->handleActive_M-->endDay-->"+lastDayForPlanning);
        //console.log("In SalesPLanningINt-->H-->handleActive_M-->typeof endDay-->"+typeof lastDayForPlanning);
        var tabToLockOrUnlockMap = component.get("v.passValueMap");
        var tab = event.getSource();
        switch (tab.get('v.id')) {
            case 'Apr' :
                var tabToLock = tabToLockOrUnlockMap['Apr'];
                this.injectComponent('c:TargetAndPlanningInt', tab, 'Apr', lastDayForPlanning, tabToLock);
                break;
            case 'May' :
                var tabToLock = tabToLockOrUnlockMap['May'];
                this.injectComponent('c:TargetAndPlanningInt', tab, 'May', lastDayForPlanning, tabToLock);
                break;
            case 'Jun' :
                var tabToLock = tabToLockOrUnlockMap['Jun'];
                this.injectComponent('c:TargetAndPlanningInt', tab, 'Jun', lastDayForPlanning, tabToLock);
                break;
            case 'Jul' :
                var tabToLock = tabToLockOrUnlockMap['Jul'];
                this.injectComponent('c:TargetAndPlanningInt', tab, 'Jul', lastDayForPlanning, tabToLock);
                break;
            case 'Aug' :
                var tabToLock = tabToLockOrUnlockMap['Aug'];
                this.injectComponent('c:TargetAndPlanningInt', tab, 'Aug', lastDayForPlanning, tabToLock);
                break;
            case 'Sep' :
                var tabToLock = tabToLockOrUnlockMap['Sep'];
                this.injectComponent('c:TargetAndPlanningInt', tab, 'Sep', lastDayForPlanning, tabToLock);
                break;
            case 'Oct' :
                var tabToLock = tabToLockOrUnlockMap['Oct'];
                this.injectComponent('c:TargetAndPlanningInt', tab, 'Oct', lastDayForPlanning, tabToLock);
                break;  
            case 'Nov' :
                var tabToLock = tabToLockOrUnlockMap['Nov'];
                this.injectComponent('c:TargetAndPlanningInt', tab, 'Nov', lastDayForPlanning, tabToLock);
                break;  
            case 'Dec' :
                var tabToLock = tabToLockOrUnlockMap['Dec'];
                this.injectComponent('c:TargetAndPlanningInt', tab, 'Dec', lastDayForPlanning, tabToLock);
                break;  
            case 'Jan' :
                var tabToLock = tabToLockOrUnlockMap['Jan'];
                this.injectComponent('c:TargetAndPlanningInt', tab, 'Jan', lastDayForPlanning, tabToLock);
                break; 
            case 'Feb' :
                var tabToLock = tabToLockOrUnlockMap['Feb'];
                this.injectComponent('c:TargetAndPlanningInt', tab, 'Feb', lastDayForPlanning, tabToLock);
                break;  
            case 'Mar' :
                var tabToLock = tabToLockOrUnlockMap['Mar'];
                //console.log("In SalesPLanningINt-->H-->handleActive_M-->tabToLock???-->"+tabToLock);
                this.injectComponent('c:TargetAndPlanningInt', tab, 'Mar', lastDayForPlanning, tabToLock);
                break;  
                
        }
    },
    injectComponent: function (compName, parentComp,currSelectedTab,lastPlanningDay,lockthisTab) {
        var lastPlnDay = parseInt(lastPlanningDay);
         //console.log("In SalesPLanningINt-->H-->injectComponent_M-->parsed Day String-->"+lastPlnDay);
         //console.log("In SalesPLanningINt-->H-->injectComponent_M-->typeof Day String-->"+typeof lastPlnDay);
        //console.log("In SalesPLanningINt-->H-->injectComponent_M-->lockDisTab???-->"+lockthisTab);
        $A.createComponent(compName, {
            "aura:id": currSelectedTab,
            "targetMonth": currSelectedTab,
            "endDay":lastPlnDay,
            "lockOrUnlockThisTab": lockthisTab
        }, function (contentComponent, status, error) {
            if(status === "SUCCESS"){
                
                parentComp.set('v.body', contentComponent);
                
            }else if (status === "INCOMPLETE") {
                console.log("In SalesPLanningINt-->H-->handleDestroy_M-->No response from server or client is offline.");
                this.showToast({
                    "title": "Oops!, Something went wrong...",
                    "type": "error",
                    "message": "Either you are offline or No response from server."
                }); 
            }else if (status === "ERROR") {
                console.log("In SalesPLanningINt-->H-->handleDestroy_M-->Error: " + JSON.stringify(error));
                this.showToast({
                    "title": "Oops!!",
                    "type": "error",
                    "message": "Error occurred while creating dynamic component."
                }); 
            }
        });
    },
    showToast : function(params){
        var toastEvent = $A.get("e.force:showToast");
        if(toastEvent){
            toastEvent.setParams(params);
            toastEvent.fire();
        } else{
            alert(params.message);
        }
    }
})