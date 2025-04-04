/*
 * Copyright (C) 2011 - present Instructure, Inc.
 *
 * This file is part of Canvas.
 *
 * Canvas is free software: you can redistribute it and/or modify it under
 * the terms of the GNU Affero General Public License as published by the Free
 * Software Foundation, version 3 of the License.
 *
 * Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
 * details.
 *
 * You should have received a copy of the GNU Affero General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

import $ from 'jquery'
import './jquery.google-analytics'
import 'compiled/jquery/ModuleSequenceFooter'
import ToolLaunchResizer from './lti/tool_launch_resizer'

var $toolForm = $("#tool_form")

var launchToolManually = function(){
  var $button = $toolForm.find('button');

  $toolForm.show();

  // Firefox remembers disabled state after page reloads
  $button.attr('disabled', false);
  setTimeout(function() {
    // LTI links have a time component in the signature and will
    // expire after a few minutes.
    $button.attr('disabled', true).text($button.data('expired_message'));
  }, 60 * 2.5 * 1000);


  $toolForm.submit(function() {
    $(this).find(".load_tab,.tab_loaded").toggle();
  });
}

var launchToolInNewTab = function(){
  $toolForm.attr('target', '_blank');
  launchToolManually();
}

switch($toolForm.data('tool-launch-type')){
  case 'window':
    $toolForm.show();
    launchToolInNewTab();
    break;
  case 'self':
    $toolForm.removeAttr('target')
    try {
      $toolForm.submit();
    } catch(e){}
    break;
  default:
    //Firefox throws an error when submitting insecure content
    try {
      $toolForm.submit();
    } catch(e){}

    $("#tool_content").bind("load", function(){
      if(document.location.protocol !== "https:" || $("#tool_form")[0].action.indexOf("https:") > -1) {
        $('#insecure_content_msg').hide();
        $toolForm.hide();
      }
    });
    setTimeout(function(){
      if($('#insecure_content_msg').is(":visible")){
        $('#load_failure').show()
        launchToolInNewTab();
      }
    }, 3 * 1000);
    break;
}

//Google analytics tracking code
var toolName = $toolForm.data('tool-id') || "unknown";
var toolPath = $toolForm.data('tool-path');
var messageType = $toolForm.data('message-type') || 'tool_launch';
$.trackEvent(messageType, toolName, toolPath);

//Iframe resize handler
var $tool_content_wrapper;
var min_tool_height;

$(function() {
  var $window = $(window);
  $tool_content_wrapper = $('.tool_content_wrapper');
  const toolResizer = new ToolLaunchResizer(min_tool_height);
  const $tool_content = $('iframe#tool_content')

  const $external_content_info_alerts = $tool_content_wrapper
    .find('.before_external_content_info_alert, .after_external_content_info_alert');

  $external_content_info_alerts.on('focus', function(e) {
    $tool_content_wrapper.find('iframe').css('border', '2px solid #008EE2');
    $(this).removeClass('screenreader-only');
  })

  $external_content_info_alerts.on('blur', function(e) {
    $tool_content_wrapper.find('iframe').css('border', 'none');
    $(this).addClass('screenreader-only');
  })

  if (ENV.LTI != null && ENV.LTI.SEQUENCE != null) {
    $('#module_sequence_footer').moduleSequenceFooter({
      assetType: 'Lti',
      assetID: ENV.LTI.SEQUENCE.ASSET_ID,
      courseID: ENV.LTI.SEQUENCE.COURSE_ID
    });
  }
});

window.addEventListener('message', function(e) {
  try {
    var message = JSON.parse(e.data);
    switch (message.subject) {
      case 'lti.frameResize':
        const toolResizer = new ToolLaunchResizer();
        var height = message.height;
        if (height <= 0) height = 1;

        const container = toolResizer.tool_content_wrapper(message.token || e.origin).data('height_overridden', true);
        break;

      case 'lti.showModuleNavigation':
        if(message.show === true || message.show === false){
          $('.module-sequence-footer').toggle(message.show);
        }
        break;

      case 'lti.scrollToTop':
        $('html,body').animate({
           scrollTop: $('.tool_content_wrapper').offset().top
         }, 'fast');
        break;

      case 'lti.setUnloadMessage':
        setUnloadMessage(message.message);
        break;

      case 'lti.removeUnloadMessage':
        removeUnloadMessage();
        break;

      case 'lti.screenReaderAlert':
        $.screenReaderFlashMessageExclusive(message.body)
        break;
    }
  } catch(err) {
    (console.error || console.log).call(console, 'invalid message received from');
  }
});

var beforeUnloadHandler;
function setUnloadMessage(msg) {
  removeUnloadMessage();

  beforeUnloadHandler = function(e) {
    return (e.returnValue = msg || "");
  }
  window.addEventListener('beforeunload', beforeUnloadHandler);
}

function removeUnloadMessage() {
  if (beforeUnloadHandler) {
    window.removeEventListener('beforeunload', beforeUnloadHandler);
    beforeUnloadHandler = null;
  }
}
