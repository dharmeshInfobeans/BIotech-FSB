({
    doInit: function (component, helper) {
        let orderId = component.get('v.recordId');

        var statusAction = component.get("c.fetchStatus_Requests");
        statusAction.setParams({ 'orderId': orderId });
        statusAction.setCallback(this, function (response) {
            $A.get("e.force:closeQuickAction").fire();
            console.log(response);
            var isValidStatus = response.getReturnValue().isValidStatus;
            var frPresentStatus = response.getReturnValue().frPresent;
            var statusupdate = response.getReturnValue().updatesSucces;
            var consigneeStatus = response.getReturnValue().consigneePresent;
            var inCartProductPresent = response.getReturnValue().inCartProductPresent;
            if (!isValidStatus) {
                var toastEvent = $A.get("e.force:showToast");

                toastEvent.setParams({
                    title: 'Error',
                    message: $A.get("$Label.c.RequestFreightForDraftOrder"),
                    duration: ' 5000',
                    key: 'info_alt',
                    type: 'error',
                    mode: 'pester'
                });
                toastEvent.fire();
            } else if (!consigneeStatus) {
                var toastEvent4 = $A.get("e.force:showToast");

                toastEvent4.setParams({
                    title: 'Error',
                    message: 'To request for Freight Consignee must be selected!',
                    duration: ' 5000',
                    key: 'info_alt',
                    type: 'error',
                    mode: 'pester'
                });
                toastEvent4.fire();
            } else if (!frPresentStatus) {
                var toastEvent2 = $A.get("e.force:showToast");
                toastEvent2.setParams({
                    title: 'Error',
                    message: $A.get("$Label.c.NoFreightRequestPresent"),
                    duration: '5000',
                    key: 'info_alt',
                    type: 'error',
                    mode: 'pester'
                });
                toastEvent2.fire();
            } else if (inCartProductPresent) {
                var toastEvent2 = $A.get("e.force:showToast");
                toastEvent2.setParams({
                    title: 'Error',
                    message: $A.get("$Label.c.InCartProductsPresent"),
                    duration: '5000',
                    key: 'info_alt',
                    type: 'error',
                    mode: 'pester'
                });
                toastEvent2.fire();
            } else {
                var toastEvent3 = $A.get("e.force:showToast");
                toastEvent3.setParams({
                    title: 'Success',
                    message: $A.get("$Label.c.FreightRequesteSuccessfully"),
                    type: 'success',
                    mode: 'pester'
                });
                toastEvent3.fire();
            }



        });

        $A.enqueueAction(statusAction);

    }
})