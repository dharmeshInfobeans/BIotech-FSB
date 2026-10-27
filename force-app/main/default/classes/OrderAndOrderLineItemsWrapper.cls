public class OrderAndOrderLineItemsWrapper {
    public class OrderWrapper {
        public String orderId;
        public String additionalField1;
        public String additionalField2;
        public String additionalField3;
        public List<OrderAndOrderLineItemsWrapper.OrderLineItemsWrapper> orderLineItems;
    }

    public class OrderLineItemsWrapper {
        public String orderNumSF;
        public String orderNumSAP;
        public String status;
        public String plant;
        public String additionalField1;
        public String additionalField2;
        public String additionalField3;
        public String additionalField4;
        public String additionalField5;
        public List<ShipmentWrapper> shipments;
    }

    public class ShipmentWrapper {
        public String shippingPartner;
        public String partnerName;
        public String trackingNumber;
        public String deliveryNumber;
        public String invoiceNumber;
        public String externalInvoiceNumber;
        public String SAPorderNumber;
        public String shipingStatus;
        public String assignedDate;
        public String assignedTime;
        public String deliveredDate;
        public String deliveredTime;
        //public String invoiceBodyString;


    }
}