({
    getMpps: function(component, event, helper) {
        var action2 = component.get("c.getAllMppsForAop");
        action2.setParams({
            aopId: component.get("v.aopId"),
            fyear: component.get("v.fiscalYear"),
            prodId: component.get("v.prodId"),
            accId:component.get("v.accId")
        });
        action2.setCallback(this, function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                //                                                                                                           
                var retDatas = response.getReturnValue();
                
                //console.log("In AOPDetailCompInt-->H-->getMpps_M--> ret Acc-->" +JSON.stringify(retDatas) );
                
                if (!$A.util.isEmpty(retDatas)) {
                    /*for(let i = 0; i < retDatas.length; i++){
                        var retData = retDatas[i];
                        if(!$A.util.isEmpty(retData.Monthly_Target__r.Account__r)){
                            console.log("ACC NAME-->"+retData.Monthly_Target__r.Account__r.Name);
                            component.set("v.accName",retData.Monthly_Target__r.Account__r.Name);
                        }
                    }*/
                    component.set("v.accName",retDatas[0].Monthly_Target__r.Account__r.Name);
                    component.set("v.aopQty",retDatas[0].Monthly_Target__r.Target_Quantity__c);
                    component.set("v.remQty",retDatas[0].Monthly_Target__r.Remaining_Qty__c);
                    component.set("v.aopName",retDatas[0].Monthly_Target__r.Name);
                    component.set("v.prodName",retDatas[0].Product__r.Name);
                    component.set("v.mppData", retDatas);
                    
                }else{
                    component.set("v.showInitMessage", true);
                    component.set("v.initMessage", "No MPPs found.");
                }
            }else{
                console.log("Error in apex call......");
            }
        });
        $A.enqueueAction(action2);
    },
})