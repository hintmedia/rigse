function get_edit_resource_popup(external_activity_id, popup_options){
  var lightboxConfig = {
        content:"<div style='padding:10px'>Loading...Please Wait.</div>",
        title:"Edit External Activity"
    };
    list_lightbox=new Lightbox(lightboxConfig);
    jQuery(".n.move_handle").css({"width":"400px"});
    jQuery(".buttons")[0].innerHTML = jQuery(".buttons")[0].innerHTML + "<a href='javascript:void(0)' style='float:right;margin-top: 5px;margin-right: 10px' class='button' onclick='close_popup()'>Cancel</a>"
    var target_url = "/eresources/999/edit";
    if (popup_options && popup_options.use_short_form) {
      target_url = "/eresources/999/edit_basic"
    }
    target_url = target_url.replace('999',external_activity_id);
    var options = {
        method: 'get',
        onSuccess: function(transport) {
            var text = transport.responseText;
            text = "<div id='oErrMsgDiv' style='color:Red;font-weight:bold'></div>"+ text;
            list_lightbox.handle.setContent("<div id='windowcontent' style='padding:10px'>" + text + "</div>");
            //var contentheight=$('windowcontent').getHeight();
            var contentheight = popup_options && popup_options.content_height ? popup_options.content_height : 500;
            var contentoffset = popup_options && popup_options.content_offset ? popup_options.content_offset : 40;
            list_lightbox.handle.setSize(500,contentheight+contentoffset+20);
            list_lightbox.handle.center();
        }
    };
    new Ajax.Request(target_url, options);
}