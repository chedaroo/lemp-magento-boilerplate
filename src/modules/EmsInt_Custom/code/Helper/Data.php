<?php
class EmsInt_Custom_Helper_Data extends Mage_Core_Helper_Abstract
{
  /**
   * Gets the locale code for a store based on store ID
   * @param  string $storeId Optional, defaults to current
   * @return string          Locale Code
   */
  protected function _getLocaleCode($storeId = '')
  {
    // Use current storeId if empty
    $storeId = empty($storeId) ? Mage::app()->getStore()->getStoreId() : $storeId;
    // Return local code
    return Mage::getStoreConfig('general/locale/code', $storeId);
  }

  /**
   * Gets an array of website codes
   * @return Array Keys are Id's, values are codes
   */
  protected function _getWebsiteCodes()
  {
    $websiteCodes = array();
    // Get list of website Id's
    $websites = Mage::app()->getWebsites();
    // Loop over websites
    foreach($websites as $website){
      // Get store from ID
      $websiteId = $website->getId();
      $websiteCodes[$websiteId] = $website->getCode();
    }
    return $websiteCodes;
  }

  /**
   * Returns a website model base on website code
   * @param  string $websiteCode
   * @return Object              Mage_Core_Model_Website
   */
  protected function _getWebsiteByCode($websiteCode)
  {
    $websiteId = array_search($websiteCode, $this->_getWebsiteCodes());
    return Mage::getModel('core/website')->load($websiteId);
  }

  /**
   * Returns a store from a website which matches a given Locale Code
   * @param  Object $websiteCode Mage_Core_Model_Website
   * @param  String $localeCode  Locale code to match
   * @return Object              Mage_Core_Model_Store
   */
  protected function _getStoreWithMatchingLocal($website, $localeCode)
  {
    $storeIds = $website->getStoreIds();

    foreach($storeIds as $storeId) {
      $storeLocalCode = $this->_getLocaleCode($storeId);
      if($storeLocalCode === $localeCode) {
        return Mage::getModel('core/store')->load($storeId);
      }
    }
    return false;
  }

  /**
   * Returns the base url for a website, including Locale
   * @param  string $websiteCode
   * @return string
   */
  protected function _getWebsiteUrlByCode($websiteCode)
  {
    // Get Curent local code
    $localeCode = $this->_getLocaleCode();
    // Get website
    $website = $this->_getWebsiteByCode($websiteCode);
    // Store to load
    $store = $this->_getStoreWithMatchingLocal($website, $localeCode);

    if(!$store) {
      return $website->getDefaultStore()->getBaseUrl();
    }

    // Language query
    $languageQuery = '?__store=' . $store->getCode() . '&__from_store=' . Mage::app()->getStore()->getCode();

    return $store->getBaseUrl(Mage_Core_Model_Store::URL_TYPE_LINK);
  }

  /**
   * Public function to allow call from layout xml
   */
  public function getWebsiteUrlByCode($websiteCode)
  {
    return $this->_getWebsiteUrlByCode($websiteCode);
  }

  public function getCurrentUrl()
  {
    return Mage::app()->getStore()->getBaseUrl();
  }

}