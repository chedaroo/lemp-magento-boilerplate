<?php
/**
* This mainly to overide the links on the my account page in the My Orders section
* so that the invoices tab doesnt appear as the client has a separate inviocing sytem
* and doesn't want to confuse customers
*/
class EmsInt_Custom_Block_Order_Info extends Mage_Sales_Block_Order_Info
{

  public function getLinks()
  {
    $this->checkLinks();
    return $this->_links;
  }

  private function checkLinks()
  {
    $order = $this->getOrder();
    // Don't show invoices link
    unset($this->_links['invoice']);

    if (!$order->hasShipments()) {
        unset($this->_links['shipment']);
    }
    if (!$order->hasCreditmemos()) {
        unset($this->_links['creditmemo']);
    }
  }
}