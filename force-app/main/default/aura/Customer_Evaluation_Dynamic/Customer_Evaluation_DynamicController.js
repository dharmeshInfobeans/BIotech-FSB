({
	doInit : function(component, event, helper) {
		var action = component.get("c.getCEFormData");
        action.setParams({
            "accountId" : component.get("v.recordId")
        });
        action.setCallback(this, function(response) {
            console.log('response : ',response.getReturnValue());
            var result = response.getReturnValue();
            if(response.getState()=="SUCCESS") {
                var arrayMapKeys = [];
                var recordObject = {Account__c:component.get("v.recordId"),Year__c:result.currentYear};
                
                if(result.recordType){
                    recordObject['recordTypeId'] = result.recordType;
                }
                if(result.oldEecordId){
                    recordObject['Id'] = result.oldEecordId;
                }
                for(var key in result.form){
                    if(result.data){
                        result.form[key].forEach(element=>{
                            var tempValue = result.data[element.name] != undefined ? result.data[element.name] : '';
                            element.value = element.name == 'Account__c' ? result.data.Account__r.Name : tempValue;
                        });
                        console.log('result.form[key] :',result.form[key]);
                    }  else{
                         result.form[key].forEach(element=>{
                            if(element.name == 'Status__c'){
                            	element.value = 'Draft';
                             	recordObject['Status__c'] = 'Draft';
                         	}
                         });
                    } 
                    arrayMapKeys.push({key:result.sectionPosition[key], value: result.form[key]});
                }
                console.log('arrayMapKeys : ',arrayMapKeys);
                component.set('v.formData',arrayMapKeys);
                component.set('v.isDisabled',result.disableForm);
                component.set('v.recordObject',recordObject);
            }
        });
        
        $A.enqueueAction(action);
	},
    
    handleChange : function(component, event, helper){
        console.log('event.getSource().get("v.value") : ',event.getSource().get("v.name"));
        console.log('event checkbox : ',event.getSource().get("v.type"));
        var recordObject = component.get('v.recordObject');
        if(event.getSource().get("v.type") == 'Checkbox'){
            recordObject[event.getSource().get("v.name")] = event.getSource().get("v.checked");
        }else{
			recordObject[event.getSource().get("v.name")] = event.getSource().get("v.value");
        }
     	component.set('v.recordObject',recordObject);   
    },
    saveCE: function(component, event, helper){
        console.log('Save : ',JSON.stringify(component.get("v.recordObject")));
        helper.saveCE(component);
    },
    closeModel: function(component, event, helper){
    	$A.get("e.force:closeQuickAction").fire()
    },
    hideToast : function(component, event, helper) {
        component.set("v.isError",false);
    }
})