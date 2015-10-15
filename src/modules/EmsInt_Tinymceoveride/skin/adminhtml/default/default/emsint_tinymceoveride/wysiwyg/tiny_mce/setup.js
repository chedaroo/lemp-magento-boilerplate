(function (getSettings) {
    tinyMceWysiwygSetup.prototype.getSettings = function (mode) {
        var oSettings = getSettings.call(this, mode);
        oSettings.extended_valid_elements = "+i[*]";
        return oSettings;
    };
}(tinyMceWysiwygSetup.prototype.getSettings));