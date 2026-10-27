({
    
    doInit : function(component,event, helper){
        var orderProduct = component.get('v.orderProduct')
        //console.log('In Do init function : ',orderProduct.subOrderProducts);
        component.set('v.MinOrderQuant', orderProduct.Quantity);
        //   component.set('v.actualOrderQuantity', orderProduct.Quantity);
        
        var action = component.get("c.getModels");
        action.setParams({ "productId": orderProduct.Product});
        action.setCallback(this, function(response){
            var state = response.getState();
            console.log('Model response : ',response.getReturnValue());
            if (component.isValid() && state === "SUCCESS"){
                var result = response.getReturnValue();
                if(result.length > 0) {
                    if(!$A.util.isUndefinedOrNull(orderProduct.subOrderProducts)){
                        if(orderProduct.subOrderProducts.length == 0){
                            helper.addSubProductRow(component, event, helper);
                        }else{
                            helper.calculateTotals(component, event, helper);
                        }
                    }
                    
                    var modelsWithPowerRange = result;
                    
                    for(var i =0; i < modelsWithPowerRange.length; i++) {
                                          
                        let powerRange = [];
                        if(!$A.util.isUndefinedOrNull(modelsWithPowerRange[i].Spherical_Power_Minimum__c) && !$A.util.isUndefinedOrNull(modelsWithPowerRange[i].Spherical_Power_Maximum__c) && !$A.util.isUndefinedOrNull(modelsWithPowerRange[i].Steps__c)){
                             let minPower = modelsWithPowerRange[i].Spherical_Power_Minimum__c;
                             let maxPower = modelsWithPowerRange[i].Spherical_Power_Maximum__c;
                             let step = modelsWithPowerRange[i].Steps__c;
                               
                               while(minPower <= maxPower){
                                powerRange.push(minPower.toString());
                                minPower =minPower + step;
                            	}                            
                        }
                        if(!$A.util.isUndefinedOrNull(modelsWithPowerRange[i].Spherical_Power_Minimum1__c) && !$A.util.isUndefinedOrNull(modelsWithPowerRange[i].Spherical_Power_Maximum1__c) && !$A.util.isUndefinedOrNull(modelsWithPowerRange[i].Steps1__c)){
                             let minPower = modelsWithPowerRange[i].Spherical_Power_Minimum1__c;
                             let maxPower = modelsWithPowerRange[i].Spherical_Power_Maximum1__c;
                             let step = modelsWithPowerRange[i].Steps1__c;
                               
                               while(minPower <= maxPower){
                                powerRange.push(minPower);
                                minPower =minPower + step;
                            	}                            
                        }
                         
                        
                            if(!$A.util.isUndefinedOrNull(modelsWithPowerRange[i].Minimum_Power_2__c) && !$A.util.isUndefinedOrNull(modelsWithPowerRange[i].Maximum_Power2__c) && !$A.util.isUndefinedOrNull(modelsWithPowerRange[i].Steps2__c)){
                             let minPower = modelsWithPowerRange[i].Minimum_Power_2__c;
                             let maxPower = modelsWithPowerRange[i].Maximum_Power2__c;
                             let step = modelsWithPowerRange[i].Steps2__c;
                               
                               while(minPower <= maxPower){
                                powerRange.push(minPower);
                                minPower =minPower + step;
                            	}
                                
                            }
                         let axisAngle = [];
                         let cylindricalPower = [];
                        if(!$A.util.isUndefinedOrNull(modelsWithPowerRange[i].Axis_Angle__c) && !$A.util.isUndefinedOrNull(modelsWithPowerRange[i].Axis_Angle__c)){
                            axisAngle = modelsWithPowerRange[i].Axis_Angle__c.split(';');
                        }
                        
                        if(!$A.util.isUndefinedOrNull(modelsWithPowerRange[i].Cylindrical_Power__c) && !$A.util.isUndefinedOrNull(modelsWithPowerRange[i].Cylindrical_Power__c)){
                            cylindricalPower = modelsWithPowerRange[i].Cylindrical_Power__c.split(';');
                        }

                        modelsWithPowerRange[i].powerRange = powerRange;
                        modelsWithPowerRange[i].axisAngle = axisAngle;
                        modelsWithPowerRange[i].cylindricalPower = cylindricalPower;
                    }
                    component.set('v.modelsWithPowerRange', modelsWithPowerRange);
                    
                }
            }
        });
        $A.enqueueAction(action);         
    },
    
    
    modelCancleHandle : function(component, event, helper) {
        var orderProductRecordProviderEvnt = component.getEvent("orderProductRecordProviderEvent");
        orderProductRecordProviderEvnt.setParams({
            "showSelectModalPopup" : false
        });
        orderProductRecordProviderEvnt.fire();   
    },
    
    saveSubProducts : function(component, event, helper) {
        var MinOrderQuant = component.get('v.MinOrderQuant');        
        var orderProduct = component.get('v.orderProduct');
        var actualOrderQuantity = component.get('v.actualOrderQuantity');
        
        // if(orderProduct.Quantity < MinOrderQuant){
        //var errMsg = 'Actual Order quantity ('+actualOrderQuantity+') is less than Minimum order quantity ('+MinOrderQuant+') to be placed. Do you want to still proceed?';
        
        var errMsg =  $A.get("$Label.c.QActualOrderQuantity")+'('+actualOrderQuantity+')'+ $A.get("$Label.c.QisLessThanMinimumOrderQuantity")+'('+MinOrderQuant+')' +$A.get("$Label.c.QtobePlaced");
        
        
        if(actualOrderQuantity < MinOrderQuant){
            var r = confirm(errMsg);
            if(r == false){
                return;
            }
            
        }
        
        var totalQuantity = component.get('v.totalQuantity');
        var confirmResult = false;
        
        var toastEvent = $A.get("e.force:showToast");
        var actualOrderQuantity = component.get('v.actualOrderQuantity');
        
        if(totalQuantity < actualOrderQuantity){
            toastEvent.setParams({
                type:'error',
                title:$A.get("$Label.c.Error"),
                message: $A.get("$Label.c.Order_product_quantity_should_be_higher_than_sub_product_quantity"),
                mode:'sticky'
            });
            toastEvent.fire();
        }else if(totalQuantity > actualOrderQuantity){
            toastEvent.setParams({
                type:'error',
                title:$A.get("$Label.c.Error"),
                message: $A.get("$Label.c.Total_sub_product_quantity_is_equal_to_the_order_product_quantity"),
                mode:'sticky'
            });      
            toastEvent.fire();
        }else if(totalQuantity == actualOrderQuantity){
            var orderProduct = component.get('v.orderProduct');
            var addSubProductEvt = component.getEvent("addSubProductEvt");
            addSubProductEvt.setParams({
                "orderProduct" : orderProduct,
                "showSelectModalPopup" : false
            });
            addSubProductEvt.fire();
        }
        
    },
    
    handleAddProduct : function(component, event, helper) {
        var productRecordRecord = component.get('v.orderProduct');
        var wrapperList =  component.get('v.ListSubProductWrapper');
        wrapperList.push(productRecordRecord);
        component.set('v.ListSubProductWrapper', wrapperList);         
        var action = component.get("c.getSubProdcts");
        action.setParams({ "productRecord": productRecord});
        action.setCallback(this, function(response){
            var state = response.getState();
            if (component.isValid() && state === "SUCCESS"){
                var result = response.getReturnValue();
                var wrapperList =  component.get('v.ListSubProductWrapper');
                wrapperList.push(result);
                component.set('v.ListSubProductWrapper', wrapperList); 
            }
        });
        $A.enqueueAction(action); 
        
    },
    
    addNewRow : function(component, event, helper) {
        helper.addSubProductRow(component,event,helper);
    },
    
    handleQPChange : function(component, event, helper) {
        helper.calculateTotals(component, event, helper);
    },
    
    calculateParentTotal : function(component, event, helper) {
        var changedQuantity = event.getSource().get("v.value")
        var orderProduct = component.get('v.orderProduct');
        orderProduct.TotalPrice =   orderProduct.SalesPrice * changedQuantity;
        component.set('v.orderProduct', orderProduct);
    calculateFOCquantity(component, orderProduct);
    },

    calculateFOCquantity : function(component, orderProduct) {
        console.log('BG >>> orderProduct : ',orderProduct.FocQuantity);
        console.log('BG >>> orderProduct Data:',orderProduct.totalQuantity);
        console.log('BG>> orderProduct quantity',orderProduct.FOCText);
        var foctext = orderProduct.FOCText;
        var result;
        if(foctext.includes('orderProduct FOC')) {
            console.log('In if');
            result = this.findApplicableDiscount(orderProduct.FOCText, orderProduct.Quantity);

        }
        else {
            console.log('orderProduct In else');
           result = orderProduct.FOCText;
        }
        var FOCquantity = (Math.round((result*orderProduct.Quantity)/100));
        //const result = findApplicable Discount(qliRec.FOCText, qliRec.totalQuantity);

        // Do something with the result, such as displaying it in the component
        //component.set("v.resultMessage", result);
        console.log('orderProduct result :',result);
        console.log('orderProduct.Quantity :',orderProduct.Quantity);
        console.log('result*orderProduct.Quantity)/100 :',(result*orderProduct.Quantity)/100);
        console.log('math.raound : ',Math.round((result*orderProduct.Quantity)/100));
        console.log('33netquantity : ',FOCquantity);
        orderProduct.FocQuantity = FOCquantity; //
        orderProduct.totalQuantity=(orderProduct.FocQuantity==undefined || orderProduct.FocQuantity==0 || orderProduct.FocQuantity==null || orderProduct.FocQuantity=='' || orderProduct.FocQuantity==NaN) && (orderProduct.Quantity==undefined || orderProduct.Quantity==0 || orderProduct.Quantity==null || orderProduct.Quantity=='' || orderProduct.Quantity==NaN) ? 0 : (parseInt(orderProduct.Quantity) + parseInt(orderProduct.FocQuantity)); //code add
        
        component.set('v.orderProductRecord', orderProduct);

    },
    
    handleDeleteSubProd : function(component, event, helper) {
        var subProductTodelete = event.getParam("orderProduct");
        var isSubProductDelete = event.getParam("isDelete");
        var subOrderProducts = component.get('v.orderProduct.subOrderProducts');
        var i=0;
        var removedSubProd;
        for(i=0; i<subOrderProducts.length; i++){
            if(isSubProductDelete && subOrderProducts[i].UniqueKey == subProductTodelete.UniqueKey){
                removedSubProd = subOrderProducts.splice(i,1);
                component.set('v.orderProduct.subOrderProducts',subOrderProducts);
                var msg = 'Subproduct '+removedSubProd+' Deleted Successfully';
                var toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams({
                    type:'error',   
                    title:$A.get("$Label.c.Success"),
                    message: $A.get("")
                });      
                toastEvent.fire();  
            }
        }
        if(subOrderProducts.length ==1){
            var toastEvent = $A.get("e.force:showToast");
            toastEvent.setParams({
                type:'error',   
                title:$A.get("$Label.c.Error"),
                message: $A.get("$Label.c.Atleast_one_sub_product_is_required"),
                mode:'sticky'
            });      
            toastEvent.fire();            
            return;
        }
        
        
        var action = component.get("c.deleteSubProduct");
        action.setParams({ "RecordId" : subProductTodelete.SubProdId });
        action.setCallback(this, function(response){
            var state = response.getState();
            if (component.isValid() && state === "SUCCESS"){
                for(var i =0; i<subOrderProducts.length;i++){
                    if(subOrderProducts[i].UniqueKey == subProductTodelete.UniqueKey){
                        subOrderProducts.splice(i, 1);
                        break;
                    }
                }
                
                
                
                component.set('v.orderProduct.subOrderProducts', subOrderProducts);
                helper.calculateTotals(component, event, helper);
                
                
                var toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams({
                    type : 'success',
                    title: $A.get("$Label.c.Success"),
                    message: $A.get("$Label.c.The_record_has_been_deleted_successfully"),
                    mode:'sticky'
                    
                });
                toastEvent.fire();
            }
        });
        $A.enqueueAction(action);
        
        
        
        
        
        
        
        /*
        var action = component.get("c.deleteSubProduct");
        action.setParams({ "RecordId" : subProductTodelete.RecordId });
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {  
                for(var i =0; i<subOrderProducts.length;i++){
                    if(subOrderProducts[i].UniqueKey == subProductTodelete.UniqueKey){
                        subOrderProducts.splice(i, 1);
                        break;
                    }
                }
                         var toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams({
                    type : 'success',
                    title: $A.get("$Label.c.Success"),
                    message: $A.get("The record has been deleted successfully.")
                    
                });
                toastEvent.fire();
            }     
        });
        $A.enqueueAction(action);
        */
        
        
        
        
    }
})