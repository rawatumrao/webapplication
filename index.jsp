<%@ page import="org.apache.commons.text.StringEscapeUtils"%>
<%@ page import="java.io.*"%>
<%@ page import="java.util.*"%>
<%@ page import="java.text.*"%>
<%@ page import="java.net.*"%>
<%@ page import="tcorej.*"%>
<%@ page import="tcorej.bean.*"%>

<%@ include file="/include/globalinclude.jsp"%>

<%
/* $Id: index.jsp 32051 2024-11-04 08:05:14Z asatapathi $ */

String sFrom = StringTools.n2s(request.getParameter("from"));
if(!Constants.EMPTY.equals(sFrom)){%>
	<jsp:forward page="/admin/support.jsp" />
<%}
String jqueryVersion = Constants.JQUERY_2_2_4;

// configuration
Configurator conf = Configurator.getInstance(Constants.ConfigFile.GLOBAL);

// What's it called this week, Bob?
String sProductName = conf.get("dlitetitle");
String sCodeTag = conf.get("codetag");
String sSpecialAnnouncement = conf.get("special_announcement");

String sAdminbaseurl = conf.get("adminbaseurl");
boolean bRedirect_adminindex  = StringTools.n2b(conf.get("redirect_adminindex"));

String sLoginText = Constants.EMPTY;
String sRequestDomain = StringTools.n2s(request.getServerName()).toLowerCase();
String sURL = request.getRequestURL().toString();
GuestStatus presenter =new GuestStatus();
String username=StringTools.n2s(request.getParameter("guest")).replace("\"","\\\"");
	
String sDeepLink = StringTools.n2s(request.getParameter("deeplink"));

// generate pfo and ufo
PFO pfo = new PFO(request);
UFO ufo = new UFO(request);

// vars
String sMessage = Constants.EMPTY;

// logger
Logger logger = Logger.getInstance();

try {
	//logger.log(Logger.INFO, "", sURL, "");
	if (sURL.indexOf("http://") != -1 || bRedirect_adminindex) {
		sURL = sURL.replace("http://","https://");
		if(bRedirect_adminindex){
			sURL = sURL.replace(sRequestDomain,sAdminbaseurl);
		}
		if (request.getQueryString() != null){
			sURL += "?" + request.getQueryString();
		}
		response.sendRedirect(sURL);
		return;
	}

	// set PFO maintab to empty
	pfo.sMainNavType = "empty";

	// page title
	pfo.setTitle("Login");

	// disable user security checks here
	pfo.insecure();

	// supply page revision for debugging
	pfo.sPageRev = "$Id: index.jsp 32051 2024-11-04 08:05:14Z asatapathi $";

	// cache the pfo and ufo
	PageTools.cachePutPageFrag(pfo.sCacheID, pfo);
	PageTools.cachePutUserFrag(ufo.sCacheID, ufo);
	
	// get messages from error redirect
	sMessage = StringTools.n2s((String) request.getAttribute("msg"));

	if (Constants.EMPTY.equals(sMessage)) {
		// nothing from there, try getting something from request
		sMessage = StringTools.n2s((String) request.getParameter("msg"));
	}
	if(!Constants.EMPTY.equals(sMessage)){
		String prettyMsg = StringTools.n2s(Constants.ExceptionTags.getDisplayFromCode(sMessage));
		sMessage = (!Constants.EMPTY.equals(prettyMsg)) ? prettyMsg : Constants.ExceptionTags.getDisplayFromCodeDefault();
	}
		
	// pull login text and app title based on domain
	sLoginText = AdminClientManagement.getClientLoginText(sRequestDomain);
	sProductName = AdminClientManagement.getClientProductName(sRequestDomain);
	
	String sChuckModeKey = StringTools.n2s(request.getParameter("chuckmode"));
	
	MaintenanceSchedManager maintSchedManager = new MaintenanceSchedManager();
	MaintenanceSchedBean maintenanceSchedBean = maintSchedManager.buildLatestMaintenanceSchedBean();
	
	boolean isUnderMaintenance = false;
	boolean isPreviewMaintenance = false;
	boolean isInChuckMode = false;
	if(maintSchedManager.isUnderMaintenance(maintenanceSchedBean,Constants.MAINTENANCE_ADMIN)){
		isUnderMaintenance = true;
		sChuckModeKey = sChuckModeKey.trim();
		if(sChuckModeKey.equalsIgnoreCase(maintenanceSchedBean.getMaintenanceAccessKeyBean().getAccesskey()))	{
			isInChuckMode = true;
		}
	}
	
	if(!isUnderMaintenance){
		isPreviewMaintenance = maintSchedManager.isMaintenancePreview(maintenanceSchedBean,Constants.MAINTENANCE_ADMIN);
	}
%>
	<style>
	#dropDownAnnouncement {
		-webkit-box-shadow: 0 2px 10px 5px rgba(0,0,0,.2); 
		box-shadow: 0 2px 10px 5px rgba(0,0,0,.2); 
		position: fixed; 
		padding:20px 20px 15px 90px; 
		background:#00aeec url('/admin/images/icon_info.png') no-repeat 10px 10px; 
		width:calc(100% - 110px);
		margin:auto;
		display:none;
		z-index:10;
	}
	#closeAnnouncement {
	 	padding:0px 0px 20px 20px;
    	float:right;
    	display:inline-block;
		cursor:pointer
	}
	#dropDownAnnouncement p {
		text-align:left;
		font-size:medium;
		color:white;
		margin-top:0
		}
	#dropDownAnnouncement a:active, #dropDownAnnouncement a:link, #dropDownAnnouncement a:visited {color:#fff; text-decoration:underline}
	#dropDownAnnouncement a:hover {color:#ddd}
	#notifyBtn{
	    display: block;
	    margin-top: 5px;
	    background-color: #006bbd;
	    border: none;
	    padding: 7px 15px;
	    color: #fff;
	    border-radius: 3px;
	    cursor: pointer;
  		font-size: .9em;
	}					}
	#nofityBtn:hover{
	    background-color: #013965;
	}
	
	</style>
	
	<div id="dropDownAnnouncement">
  		<div id="closeAnnouncement">
			<img src="/admin/images/icon_reg-close-white.png">
	 	</div>
		<p id='dropDownMsg'>
			 <%=sSpecialAnnouncement %>
			<div id='mailingList'>
				<button id='notifyBtn' onclick='notifyBtnMsg()'>
					Notify Me About System Updates
				</button>
			</div>
		</p>
	</div>
	<jsp:include page="headertop.jsp">
		<jsp:param name="pfi" value="<%=pfo.sCacheID%>"/>
		<jsp:param name="ufi" value="<%=ufo.sCacheID%>"/>
		<jsp:param name="jqueryVersion" value="<%=jqueryVersion%>" />
	</jsp:include>
	<script type="text/javascript" src="/js/analytics.js"></script>
	<script type="text/javascript">
		if (window != window.top) {
			window.top.location = "/admin/index.jsp?msg=" + encodeURIComponent('<%=sMessage%>');
		}
		//analyticsExclude(["param_eventCostCenter"]);
		analyticsInit();
	</script>

	<jsp:include page="headerbottom.jsp">
		<jsp:param name="pfi" value="<%=pfo.sCacheID%>"/>
		<jsp:param name="ufi" value="<%=ufo.sCacheID%>"/>
	</jsp:include>
		    <div class="messageBar" id="messageBar"><%=sMessage%></div>
		    <div class="graybox" id="adminLoginBox">
				<div class="whitebox" style="float:right; margin:40px 20px; width:180px; padding:20px;" id="adminLoginForm">
				<%if(isUnderMaintenance){%>
						<!--
							<div>
								<h3><%= maintenanceSchedBean.getsMaintenanceMessage()%></h3>
							</div>
						-->
						<div id="mailingList">
							<script type="text/javascript">
							<% if (!isInChuckMode) { %>
								document.getElementById('adminLoginForm').style.display = 'none';
							<% } %>
								setTimeout(function(){
									$('#dropDownAnnouncement').slideToggle(1000);
									$('#specialAnnouncement').remove();
									$('#dropDownMsg')
										.empty()
										.append("<%= maintenanceSchedBean.getsMaintenanceMessage()%>");
								}, 500);
							</script>
						</div>
				<%}
					if((isUnderMaintenance && isInChuckMode ) || !isUnderMaintenance){%>
					<div>
						<h3>Log In to <%=StringEscapeUtils.escapeHtml4(sProductName)%></h3>
						<br />
						<form action="/error_js_disabled.html" method="post" id="frmLogin">
							Username:<br />
							<input id="username" name="username" type="text" value="" />
							<br />
							<br />
							Password:<br />
							<input name="password" id="password" type="password" AUTOCOMPLETE="off" />
							<br />
							<br />
							<input type="submit" class="button" id="login_button" value="Log In" />
							<br />
							<br />
							<span class="small"><a href="/admin/forgotuserpass.jsp">Forgot your Username or Password?</a></span>
							<input type="hidden" id="failCount" name="failCount" value="0"/>
							<input type="hidden" id="eventStatus" name="eventStatus" value="0"/>
							<%if(isUnderMaintenance && isInChuckMode ){%>
								<input type="hidden" id="maintenance_sched_id" name="maintenance_sched_id" value="<%= maintenanceSchedBean.getsMaintenanceScheduleId() %>"/>
								<input type="hidden" id="is_under_maintenance" name="is_under_maintenance" value="true"/>
								<input type="hidden" id="chuckmode" name="chuckmode" value="<%=sChuckModeKey%>"/>
							<%}%>
						</form>
					</div>
					<%}if(isPreviewMaintenance){%>
						<!--
							<div>
								<h3><%= maintenanceSchedBean.getsPreviewWarningMessage()%></h3>
							</div>
						-->	
						<div id="mailingList">
							<script type="text/javascript">
								setTimeout(function(){
									$('#dropDownAnnouncement').slideToggle(1000);
									$('#specialAnnouncement').remove();
									$('#dropDownMsg')
										.empty()
										.append("<%= maintenanceSchedBean.getsPreviewWarningMessage()%>");
								}, 500);
							</script>
						</div>
						<%}%>
				</div>
				<h2>About <%=StringEscapeUtils.escapeHtml4(sProductName)%></h2>
				<br />
				<div class="whitebox" style="width:920px;" id="adminLoginSlideshow">
						<div id="myAlternativeContent">
        				<div id="slideshow" class="pics">
							<div id="nav"></div>
           						 <img src="/admin/banner_asset/image7.jpg" class="slideShowImg first" />
           						 <img src="/admin/banner_asset/image9.jpg" class="slideShowImg" style="display:none" />
           						 <% if(isUnderMaintenance) { %>
           						 <img src="/admin/banner_asset/image-beach.jpg" class="slideShowImg"  style="display:none" />
           						 <% } else { %> 
           						 <img src="/admin/banner_asset/image8.jpg" class="slideShowImg" style="display:none" />
           						 <% } %>
           						 <img src="/admin/banner_asset/image2.jpg" class="slideShowImg" style="display:none" />
           						 <img src="/admin/banner_asset/image10.jpg" class="slideShowImg" style="display:none" />
       					</div>
					</div>
				</div>
						
				<div id="introText">
					<%=sLoginText%>
				</div>
			</div>
			<form method="post" action="/admin/forgotuserpass.jsp" id="forgotPassForm">
			
			</form>
			<form method="post" action="/admin/verify_admin.jsp" id="verifyAdminForm">
			
			</form>
		<form method="post" action="<%=sDeepLink%>" id="passthruForm">
			<input type="hidden" id="<%=Constants.RQUSERID%>" name="<%=Constants.RQUSERID%>"/>
		    <input type="hidden" id="<%=Constants.RQSESSIONID%>" name="<%=Constants.RQSESSIONID%>"/>
		    <input type="hidden" id="<%=Constants.RQFOLDERID%>" name="<%=Constants.RQFOLDERID%>"/>
		    <input type="hidden" id="g_username" name="g_username"/>
		    <input type="hidden" name="from_login" value="1"/>
		</form>
		<form method="post" action="change_password.jsp" id="frmChangePassword">
			<input type="hidden" id="ch_paswd_<%=Constants.RQUSERID%>" name="<%=Constants.RQUSERID%>"/>
		    <input type="hidden" id="ch_paswd_<%=Constants.RQSESSIONID%>" name="<%=Constants.RQSESSIONID%>"/>
		    <input type="hidden" id="ch_paswd_<%=Constants.RQFOLDERID%>" name="<%=Constants.RQFOLDERID%>"/>
		    <input type="hidden" id="ch_paswd_g_username" name="g_username"/>
		    <input type="hidden" id="ch_paswd_guestlink" name="guestlink"/>
		</form>
        
		<jsp:include page="footertop.jsp">
			<jsp:param name="pfi" value="<%=pfo.sCacheID%>"/>
			<jsp:param name="ufi" value="<%=ufo.sCacheID%>"/>
			<jsp:param name="jqueryVersion" value="<%=jqueryVersion%>" />
		</jsp:include>
        <style>
			#myAlternativeContent {z-index: 3; width:920px; height: 300px;}
			#introText {width: 940px; color:#333; margin-top:20px; }
			#introText .callout {font-size:135%; font-weight:300; color:#666;}
			#slideshow {z-index: 4; margin: 5px auto; width: 920px; height: 300px; -webkit-border-radius: 5px; -moz-border-radius: 5px; border-radius: 5px;}
			#slideshow img {display: none;}
			#slideshow img.first {display: block;}
			.slideShowImg {width:100%; max-width:100%}
			#nav {z-index: 8; position: absolute; bottom: 10px; right: 25px }
			#nav a { margin: 0 3px; padding: 0px; border: none; background: transparent url(images/slide_indicator.png) center center no-repeat; text-decoration: none; color:transparent; font-size:12px; line-height:18px }
			#nav a.activeSlide {color:transparent;  background: transparent url(images/slide_indicator-active.png) center center no-repeat; }
			#nav a:focus { outline: none; }
        </style>
		<script type="text/javascript" src="/js/systemtest/detect.js?<%=sCodeTag%>"></script>
		<script type="text/javascript" src="/js/TPAU.js?<%=sCodeTag%>"></script>
		<script type="text/javascript" src="/js/systemtest/compatibilitymode.js?<%=sCodeTag%>"></script>
		<script type="text/javascript" src="/js/systemtest/alertcookie.js?<%=sCodeTag%>"></script>
		<script type="text/javascript" src="/js/systemtest/adminPassFail.js?<%=sCodeTag%>"></script>
		<script type="text/javascript" src="/js/slideshow/jquery.cycle.all.min.js?<%=sCodeTag%>"></script>
		<script type="text/javascript">
			var deepLinkUrl = "<%=sDeepLink%>";
			var varUnderMaintenance = '<%=isUnderMaintenance%>';
			var username = "<%=username%>";

			$(document).ready(function() {
				$.initdialog();
				if (varUnderMaintenance != 'true') {
					$("#username").focus().val(username);
				}
				$("#frmLogin").submit(submitLogin);
				
				function legacyBrowserRedirect() {
					document.body.innerHTML = ("<div style='display:flex; flex-direction: column; justify-content: center; align-items: center; height: 100%;'>" +
					                               "<h1>Internet Explorer is not supported.</h1>" +
					                               "<h2>Please return to this site using Chrome, Firefox, Edge or Safari.</h2>" + 
					                           "<div>");
				}
				try {
					var legacyBrowserTest=(document.addEventListener);
					if (!legacyBrowserTest) {//We are testing for old browsers by checking for event listener support
						legacyBrowserRedirect();
					/*} else if (!window.MediaSource) {//We test the browser to make sure it supports media source extensions. 
						legacyBrowserRedirect();*/
					} else if ((systemDetect.browser=="Internet Explorer")) {
						legacyBrowserRedirect();
					} else {
						///Check the user's browser and display a warning if their system doesn't pass and they don't have a sys_alert cookie set. Relies on adminsysPassFail.js
		        		adminPassFail(1);//Pass the number of days you want the system alert cookie to expire within. Use -1 for immediate.
					}
				} catch (err) {
					adminPassFail(1);
				}

				//Show a special announcement, if it exists. Sets a special_accouncement cookie. Pass through the number of days you want it to live for.
				var checkMessage="<%=sSpecialAnnouncement%>".trim();
				var showMessage=checkMessage.length;
				if ( showMessage > 1 ) {
					showSpecialAnnouncement(1);
				}
				
				//Slideshow options for controlling scrolling images on login page
				$('#slideshow').cycle({
        			fx:'scrollLeft',
        			speed:'300',
					delay: -2000,
        			timeout:7000,
        			pager:'#nav',
					slideExpr:'img'
    			});
			});
			
			var domain = document.domain;
			function getDomain () {
				var string = "";
				var target = "/sc/update_mailinglist.jsp";
				string = domain;
				combined = target + "?site=" + string;
				return combined;
			}
			
			// Nofity Me Btn Function
			function notifyBtnMsg(){ 
				  window.open(getDomain(),
				    ' join our mailing ilst ',
				    ' width= 450,height=450,toolbar=0,menubar=0,location=0,status=1,scrollbars=1,resizable=1,left=100,top=100'
				  );
			}
			
			//Special accouncement functions
			function showAnnouncement() {
				try {
					setTimeout(function() {
						var isThereAMessage="<%=sSpecialAnnouncement%>".trim();
						var messageLength=isThereAMessage.length;
						//Don't show the announcement div unless there is a message to show or showSpecialAnnouncement is true (Set in adminPassFail.js)
						if ((messageLength>1)&&(showSpecialMessage)) {
							$('#dropDownAnnouncement').slideToggle(1000);
						}
					},500);
				} catch (err) {
					console.log("TPQA - Unable to open special announcement. Error: " + err);
				}			
			}
			
			$("#closeAnnouncement").click(function() {
				$('#dropDownAnnouncement').slideToggle(1000);
			});
		
			function submitLogin()
			{	
				var varURL = '/admin/proc_login.jsp';
				if(deepLinkUrl!='') {
					varURL = varURL + '?deeplink='+deepLinkUrl;	
				}
				
				 var data = $('#frmLogin').serializeArray();
				 
				 //never want a situation where tpau makes login process error out
				 try{
					 var tpau = new TPAU();
					 data.push({name: '<%=Constants.JSON_BROWSER_ATTR_KEY%>', value: JSON.stringify(tpau.getKeysArray())});   
				 }catch(e){
				     data.push({name:'<%=Constants.VERI_FINGERPRINT_JS_FAILURE_MSG%>',value:e});
				 }
				 $("#login_button").attr("disabled","true");
				 $.ajax({ type: "POST",
			                url: varURL,
			                data: data,
							traditional:true,
			                dataType: "json",
			                success: getResult,
							error : function(req,text,ex) {
								$("#messageBar").html("Error processing login: " + text);
								$("#login_button").removeAttr("disabled");
							}
			     });			 
	            return false;
			}

			function getResult(jsonResult)
			{
			    $("#login_button").removeAttr("disabled");
				$(".errorText").remove();
                $(".error").removeClass("error");
                jsonResult = jsonResult[0];
                if (!jsonResult.success) {
                	$("#failCount").val(jsonResult.finalCount);
                	
                	var counter=$("#failCount").val();
                	
                	if(counter >=5) {
                		var objButton = {"Ok":function(){passwordReset();showFlashObjects()}};	
						hideFlashObjects();
                		$.confirm("Hmm. Something isn't right. ","Your account has been locked due to too many unsuccessful login attempts.  Please reset your password to unlock your account.",objButton,"");
                    }
                   
					for(var i = 0; i < jsonResult.errors.length; i++) {						
						var curError = jsonResult.errors[i];
						$("#" + curError.element).addClass("error").before("<span class='errorText'>" + curError.message + "<br></span>");
					}
                    return;
                } else {
                	var isExpire = jsonResult.sExpiryAlert;
                	var verificationNeeded = jsonResult.sAdminVerification;
                	if (isExpire == "aboutToExpire") {
                		var objButton = {"Ok":function(){proceedSubmit(jsonResult);showFlashObjects()}};
                		hideFlashObjects();
                		$.alert("Attention, Attention!","Your Webcast account is nearing its expiration. Have questions about your renewal options? Contact support@webcasts.com","icon_alert.png",objButton,"");          	  		
                    } else if (isExpire == "expire") {
                    	var objButton = {"Ok":function(){$(this).dialog('close');showFlashObjects()}};
                    	hideFlashObjects();
                    	$.alert("Attention, Attention!","Your Webcast account has expired. Please contact support@webcasts.com to discuss renewal options.","icon_alert.png",objButton,"");          	  		
                    }else {
	   					proceedSubmit(jsonResult);
	   				}
					
				}
			}
			
		
			function proceedSubmit(jsonResult){
				$("#eventStatus").val(jsonResult.finalMode);        	
            	if(jsonResult.is_password_expired) {
                	$("#frmChangePassword").attr("method", "get"); 
                    $("#ch_paswd_<%=Constants.RQUSERID%>").val(jsonResult.userid); 
    				$("#ch_paswd_<%=Constants.RQSESSIONID%>").val(jsonResult.sessionid);
    				$("#ch_paswd_<%=Constants.RQFOLDERID%>").val(jsonResult.folderid);
    				$("#ch_paswd_guestlink").val(jsonResult.guestlink);
            		$("#ch_paswd_g_username").val(jsonResult.username);                	
                	$("#frmChangePassword").submit();	
            	} else if(jsonResult.sAdminVerification){
            		verifyAdmin(jsonResult);
            	}else {
                	$("#passthruForm").attr("action", jsonResult.guestlink);
                	$("#passthruForm").attr("method", "get"); 
                    $("#<%=Constants.RQUSERID%>").val(jsonResult.userid); 
    				$("#<%=Constants.RQSESSIONID%>").val(jsonResult.sessionid);
    				$("#<%=Constants.RQFOLDERID%>").val(jsonResult.folderid);
            		$("#g_username").val(jsonResult.username);
                	$("#passthruForm").submit();	
            	}

			}
			
			function verifyAdmin(jsonResult){
				var deepLinkUrl = "<%=sDeepLink%>";
				var varURL = '/admin/verify_admin.jsp?<%=Constants.RQUSERID%>='+jsonResult.userid;
				if(deepLinkUrl && deepLinkUrl != '') {
					varURL = varURL + '&deeplink='+deepLinkUrl;	
				}
				window.top.location = varURL;
			}
			
			function passwordReset(){
				$("#forgotPassForm").prop("action","forgotuserpass.jsp?uname=" + $("#username").val());
				$("#forgotPassForm").submit();
			}
			function validateLogin() {
				if($("#username").val()=="") {
					alert("Username is required");
					return false;
				}
				return true;
			}
			function hideFlashObjects() {
				$("#myAlternativeContent").hide();
			}

			function showFlashObjects() {
				$("#myAlternativeContent").show();
			}
		</script>

	<jsp:include page="footerbottom.jsp">
	<jsp:param name="pfi" value="<%=pfo.sCacheID%>"/>
	<jsp:param name="ufi" value="<%=ufo.sCacheID%>"/>
</jsp:include>


<!-- Piwik -->
<script type="text/javascript">
  var _paq = _paq || [];
  _paq.push(["setDoNotTrack", true]);
  _paq.push(['disableCookies']);
  _paq.push(["trackPageView"]);
  _paq.push(["enableLinkTracking"]);

  (function() {
	  try{
		  var u=(("https:" == document.location.protocol) ? "https" : "http") + "://pi.webcasts.com/";
		    _paq.push(["setTrackerUrl", u+"piwik.php"]);
		    _paq.push(["setSiteId", "3"]);
		    var d=document, g=d.createElement("script"), s=d.getElementsByTagName("script")[0]; g.type="text/javascript";
		    g.defer=true; g.async=true; g.src=u+"piwik.js"; s.parentNode.insertBefore(g,s);	  
	  }catch(e){}
  })();
</script>
<!-- End Piwik Code -->

<% } catch (Exception e) {
//
} %>
