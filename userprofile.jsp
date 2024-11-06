<%@ page import="org.apache.commons.text.*"%>
<%@ page import="org.json.*"%>
<%@ page import="java.util.*"%>
<%@ page import="java.net.*"%>
<%@ page import="tcorej.*"%>
<%@ page import="tcorej.adminlicense.*"%>
<%@ page import="tcorej.AdminUser.AdminSSOLogin"%>
<%@ page import="tcorej.email.clientnotification.ClientMailingListManager"%>
<%@ page import="tcorej.saml.*"%>
<%@ page import="tcorej.security.*"%>
<%@ include file="/include/globalinclude.jsp"%>


<%
//configuration
Configurator conf = Configurator.getInstance(Constants.ConfigFile.GLOBAL);

// generate pfo and ufo
PFO pfo = new PFO(request);
UFO ufo = new UFO(request);

// logging
Logger logger = Logger.getInstance();

// admin
AdminUser admin = null;

// edited user
AdminUser account = null;


// Profile page header title
String sPageTitle = "My Profile";
String sSubHeaderTitle = Constants.EMPTY;
String sQueryString = Constants.EMPTY;
String sFolderName = Constants.EMPTY;
boolean isSelfManageAccount = false;
String sUsername=Constants.EMPTY;
String expiryDate=Constants.EMPTY;
String LastLogin = Constants.EMPTY;
List<HashMap<String,String>> alVerifiedDevices = new ArrayList<HashMap<String,String>>();
//date formatter
SDFManager sdf = SDFManager.getInstance(Constants.PRETTYDATE_PATTERN_2);
boolean canOptOutOfTwoFactor = false;
String sAdminCreateDate = Constants.EMPTY;
try {
	boolean isLicenseTeamManagerEditingLicenseAccount = false;
	
	// check permissions
	if (!StringTools.isNullOrEmpty(ufo.sUserID) && !StringTools.isNullOrEmpty(ufo.sAccountID)) {
		admin = AdminUser.getInstance(ufo.sUserID);
		account = AdminUser.getInstance(ufo.sAccountID);

		if (admin == null || account == null) {
			throw new Exception(Constants.ExceptionTags.EGENERALEXCEPTION.display_code());
		}
		
		isLicenseTeamManagerEditingLicenseAccount = account.hasLicense() && account.getLicense().getTeamManagerAdminId().equals(admin.sUserID);
				
		if (!ufo.sUserID.equals(ufo.sAccountID)) {
			sPageTitle = "Manage Admin";
			sSubHeaderTitle = "Managing " + account.sUsername + "'s Account";
			pfo.sSubNavType = "manageusers";
			
			sFolderName = AdminFolder.getFolderName(account.sHomeFolder);
			
			if (!(admin.can(Perms.User.MODIFYEXISTINGUSERACCOUNTS) && AdminUserManagement.hasControlUser(admin.sUserID, account.sUserID)) && !isLicenseTeamManagerEditingLicenseAccount) {
				//Need modify accounts and control of the account being edited or be a license team manager editing an account on their license.
				throw new Exception(Constants.ExceptionTags.ENOUSERAUTH.display_code());
			}
			
		} else {		
			pfo.sSubNavType = "";
			isSelfManageAccount = true;
		}
		
		String slastlogin = AdminUserManagement.getLastLogin(account.sUserID);
		sQueryString = pfo.toQueryString() + "&" + ufo.toQueryString();
		
		if (account.hasLicense()) {
			expiryDate = sdf.format(account.getLicense().getExpirationDate(), "GMT");
		} else {
			expiryDate = account.getProperty(AdminProps.adminaccountexpiration);
			if (!StringTools.isNullOrEmpty(expiryDate)) {
				expiryDate = sdf.format(DateTools.getDateFromString(StringTools.n2s(expiryDate), Constants.MYSQLTIMESTAMP_PATTERN), "GMT");
			}
		}
		
		sAdminCreateDate = DateTools.mysqlTimestamp(account.userCreateDate);
		sAdminCreateDate = sdf.format(DateTools.getDateFromString(sAdminCreateDate, Constants.MYSQLTIMESTAMP_PATTERN), "GMT");
		
		if (!StringTools.isNullOrEmpty(slastlogin)) {
			LastLogin = sdf.format(DateTools.getDateFromString(StringTools.n2s(slastlogin), Constants.MYSQLTIMESTAMP_PATTERN), "GMT");
		} 
	} else {
		throw new Exception(Constants.ExceptionTags.EGENERALEXCEPTION.display_code());
	}

	pfo.sMainNavType = "nohighlight";
	pfo.useAdminNavi();
	pfo.setTitle(sPageTitle);

	PageTools.cachePutPageFrag(pfo.sCacheID, pfo);
	PageTools.cachePutUserFrag(ufo.sCacheID, ufo);
	alVerifiedDevices = AdminVerificationTools.getActiveVerifiedDevices(account);
	canOptOutOfTwoFactor =  !(account.sRootFolder.equals(Constants.TALKPOINT_ROOT_FOLDERID) || account.can(Perms.User.SUPERUSER) || (admin.hasLicense() && admin.getLicense().is2StepRequired()));

	String sReturnPage = StringTools.n2s(request.getParameter("returnpage"));
	String sForwardURL;
	String sCancelButtonText;
	if ("editlicense".equals(sReturnPage)) {
		sForwardURL = "/admin/management/editlicense.jsp?" + sQueryString + "&" + Constants.RQLICENSEID + "=" + account.getLicenseId();
		sCancelButtonText = "« Return to License";
		pfo.sSubNavType = "managelicenses";
	} else {
		sForwardURL = "/admin/management/manageusers.jsp?" + sQueryString;
		sCancelButtonText = "« Return to Admin List";
	}
	
	String sLicenseId = account.getLicenseId();
	AdminLicense license = StringTools.isNullOrEmpty(sLicenseId) ? null : AdminLicense.get(sLicenseId);
		
	JSONObject licenseIdToLicenseInfoJSON = new JSONObject();
	JSONObject licenseInfoJSON = new JSONObject();
	licenseInfoJSON.put("folderid", Constants.EMPTY);
	licenseInfoJSON.put("foldername", "NONE");
	licenseInfoJSON.put("pgiclientid", "");
	licenseIdToLicenseInfoJSON.put(Constants.EMPTY, licenseInfoJSON);
	
	if (license != null) {
		licenseInfoJSON = new JSONObject();
		licenseInfoJSON.put("folderid", license.getFolderId());
		licenseInfoJSON.put("foldername", FolderPathCache.getFolderName(license.getFolderId()));
		licenseInfoJSON.put("pgiclientid", license.getPgiClientId());
		licenseIdToLicenseInfoJSON.put(license.getLicenseId(), licenseInfoJSON);
	}
	
	ClientMailingListManager listManager = ClientMailingListManager.getInstance(null);
	boolean isSAMLEnabledForLicense = SAMLSettings.getSAMLSettingsByLicense(sLicenseId).size() > 0;
	String userId = admin.sUserID;
%>

<jsp:include page="/admin/headertop.jsp">
	<jsp:param name="pfi" value="<%=pfo.sCacheID%>"/>
	<jsp:param name="ufi" value="<%=ufo.sCacheID%>"/>
</jsp:include>


<jsp:include page="/admin/headerbottom.jsp">
		<jsp:param name="pfi" value="<%=pfo.sCacheID%>"/>
		<jsp:param name="ufi" value="<%=ufo.sCacheID%>"/>
</jsp:include>
<style>
	.flexbox{
		display: flex;
		margin: 0;
	}
	
	.flexboxColumn{
		display: flex;
		flex-direction: column;
	}
	
	.adminInputTxt{
		width: 200px;
		margin: 0;
	}
	
	.adminFieldNameDiv{
		width: 200px;
	}
	
	.adminText{
		margin: 10px 0 0 0;
	}
	
	.marginRight10px{
	    margin-right: 10px !important;
	}
	
	.marginBottom5px{
		margin-bottom: 5px;
	}
	
	#licenseSlct{
	    width: 150px;
	}
	
	.subscribe_system_updates{
		margin-bottom: 10px !important;
	}
	
	.hideMe{
		display: none;
	}
	
	.enabledTwoStep, .disabledTwoStep{
	    margin: 0 5px;
	}
	
	.enabledTwoStep{
		color: #10de10;
	}
	
	.disabledTwoStep{
		color: #ff0000;
	}
</style>
<div class="pageContent">
<h1><%=sPageTitle%> "<%=account.sUsername%>"</h1>
	<div id="myprofile_container" class="graybox">
	<div style="width:400px; float:right;">
	<%if(admin.can(Perms.User.SUPERUSER) || admin.can(Perms.User.MODIFYEXISTINGUSERACCOUNTS) || ufo.sUserID.equals(ufo.sAccountID)){%>
    <div class="whitebox" >
    	
		<h2>Change Password</h2>

		<form action="/admin/management/proc_changepassword.jsp" method="post" id="frm_changepassword">
			<div class="divRow">
				<div class="divCell">
					<div>
						<span class="adminFieldName">New Password</span>
					</div>
					<div class="textInput" name="newPassword">
						<input id="<%=Constants.RQNEWPASSWORD%>" name="<%=Constants.RQNEWPASSWORD%>" type="password" value="" autocomplete="off" >
					</div>
				</div>
			</div>

			<div class="divRow">
				<div class="divCell">
					<div>
						<span class="adminFieldName">Verify New Password</span>
					</div>
					<div class="textInput" name="verifyPassword">
						<input id="<%=Constants.RQNEWPASSWORDVERIFY%>" name="<%=Constants.RQNEWPASSWORDVERIFY%>" type="password" value="" autocomplete="off" >
					</div>
				</div>
			</div>

			<div class="divRow">
				<input  class="button" id= "savePassword" name="savePassword" type="button" value="Save Password"/><br><br>
				<input type="hidden" id="<%=Constants.RQCURRENTPASSWORD%>" name="<%=Constants.RQCURRENTPASSWORD%>" value=""/>
				<input type="hidden" name="<%=Constants.RQUSERID%>" value="<%=admin.sUserID%>"/>
				<input type="hidden" name="<%=Constants.RQACCOUNTID%>" value="<%=account.sUserID%>"/>
			</div>
			
		</form>
		<%if(account.lastLoginDate!=null || !sAdminCreateDate.isEmpty()){%>
		<h2>Account Information</h2>
		<%} %>
		
		<div>
			<span id="createdSpan"><span class="adminFieldName">Date Created: </span> <%=sAdminCreateDate%></span>
		</div>
		
		<%if(account.lastLoginDate!=null){%>
		<br>
		<div>
			<span id="loginSpan"><span class="adminFieldName">Last Login: </span> <%=LastLogin%></span>
		</div>
		<%} %>
		<%if(Constants.EMPTY.equals(expiryDate)){%>
	<div>
		<span id="expirySpan"><span class="adminFieldName">Expires on: </span> <%=expiryDate%></span>
  </div>	
		<%}%>
		<br/>
		<input class="button subscribe_system_updates" id="subscribe_system_updates" type="button" style="display:none;"/>
		<br>
		<span>2-Step Verification:</span>
		<span id="twoFactorStatusSpn"></span>
		<a class="button" href="/admin/management/managetwofactorauthentication.jsp?<%=sQueryString%>&ai=<%=account.sUserID%>">Manage Settings</a>
		<br/><br/>

		<div id="two_factor_mgmt"<%=account.requiresDeviceVerification()?"":"style='display:none'"%>>
			<div <%=alVerifiedDevices.size()>0?"":"style='display:none'"%>>
				<span class="adminFieldName">Verified Devices:</span><br/>
				<table class="contentTableList" id="adminIPWhitelistTable" cellpadding="0" cellspacing="0" >
				<%	
						for(HashMap<String,String> hmDeviceFingerprint : alVerifiedDevices){
				%>
						<tr id="<%=hmDeviceFingerprint.get("deviceid")%>">
 							<td width="120" style="padding:5px 0 5px 0;">
						    	<span class="" style="width:100%;font-size:12px;"><%=hmDeviceFingerprint.get("VERIFICATION_DATE")%></span>
							</td> 
 							<td width="150">
						    	<span class="veri_device" style="font-size:12px;"><%=hmDeviceFingerprint.get("user_agent")%></span>
							</td>
							<td width="120" style="padding:5px 0 5px 0;">
						    	<span class="" style="width:100%;font-size:12px;"><%=hmDeviceFingerprint.get("ip_address")%></span>
							</td> 
							<td width="120" style="padding:5px 0 5px 0;">
						    	<input class="button deleteDevice" name="deleteDevice" type="button" value="Delete Device" autocomplete="off">
							</td> 
						</tr> 
					<%} %>
				</table>
			</div>
		</div>
	</div>
	<br/>
<%}%>
		</div>


<div style="width:600px;">
    <% if (!isSelfManageAccount) { %>
			<div class="divRow">
				<a class="button" href="/admin/management/managepermissions.jsp?<%=sQueryString%>&ai=<%=account.sUserID%>&returnpage=<%=sReturnPage%>">Manage <%=account.sUsername%>'s Permissions</a><br /><br /><br />
			</div>
		<% } %>


		<h2>Contact Information</h2>

		<form id="frm_userinfo">

			<div class="flexboxColumn">
				<div class="divRow flexbox adminText">
					<div class='adminFieldNameDiv'>
						<span class="adminFieldName">Username</span>
					</div>
					<div class="adminFieldNameDiv">
						<span class="adminFieldName">License</span>
					</div>
					<div class="adminFieldNameDiv" style="display:none;">
						<span class="adminFieldName">Client ID</span>
					</div>
				</div>
				<div class="divRow flexbox marginBottom5px">
					<div class="textInput adminInputTxt">
						<input id="username" name="username" type="text" value="<%=StringEscapeUtils.escapeHtml4(account.sUsername)%>" >
					</div>
					
<%			
					if (!admin.can(Perms.User.MANAGELICENSES)) {
%>
						<div class="textInput adminInputTxt">
							<span><%=license == null ? "none" : StringEscapeUtils.escapeHtml4(license.getDescription())%></span>
						</div>
<%					} else { %>
						<div class="textInput adminInputTxt">
							<select id="licenseSlct" name="licenseSlct">
								<option value="" <%=license == null ? "selected" : Constants.EMPTY%>>none</option>
<%
							if (license != null) {
								licenseInfoJSON = new JSONObject();
								licenseInfoJSON.put("folderid", license.getFolderId());
								licenseInfoJSON.put("foldername", FolderPathCache.getFolderName(license.getFolderId()));
				    			licenseInfoJSON.put("pgiclientid", license.getPgiClientId());
				    			licenseIdToLicenseInfoJSON.put(license.getLicenseId(), licenseInfoJSON);
				    		
								%><option value="<%=StringEscapeUtils.escapeHtml4(license.getLicenseId())%>" selected><%=StringEscapeUtils.escapeHtml4(license.getDescription())%></option><%
							}
			
							AdminLicenseTools.AdminLicenseList licenseList = AdminLicenseTools.getLicenseList(admin.sUserID);
						
							while (licenseList.hasNext()) {
								licenseList.nextItem();
								
								if (licenseList.getCurrentLicenseId().equals(sLicenseId)) {
									continue;
								}
							
								licenseInfoJSON = new JSONObject();
								licenseInfoJSON.put("folderid", licenseList.getCurrentLicenseFolderId());
					    		licenseInfoJSON.put("foldername", FolderPathCache.getFolderName(licenseList.getCurrentLicenseFolderId()));
					    		licenseInfoJSON.put("pgiclientid", licenseList.getCurrentLicensePgiClientId());
					    		licenseIdToLicenseInfoJSON.put(licenseList.getCurrentLicenseId(), licenseInfoJSON);
				    			
								%><option value="<%=StringEscapeUtils.escapeHtml4(licenseList.getCurrentLicenseId())%>"><%=StringEscapeUtils.escapeHtml4(licenseList.getCurrentLicenseName())%></option><%
							}
%>
							</select>
						</div>
<%					} %>
					<div class="textInput adminInputTxt" style="display:none;"><span id="pgiClientIdSpn"><%=license == null ? "" : StringEscapeUtils.escapeHtml4(license.getPgiClientId())%></span></div>
				</div>
			</div>
            <div class="divRow">
				<div class="divCell">
					<div>
						<span class="adminFieldName">First Name</span>
					</div>
					<div class="textInput" name="fnameField">
						<input id="fname" name="fname" type="text" value="<%=account.sFirstName.replaceAll("\"","&quot;")%>" >
					</div>
				</div>
				<div class="divCell">
					<div>
						<span class="adminFieldName">Last Name</span>
					</div>
					<div class="textInput" name="lnameField">
						<input id="lname" name="lname" type="text" value="<%=account.sLastName.replaceAll("\"","&quot;")%>" >
					</div>
				</div>
			</div>

			<div class="divRow">
				<div class="divCell">
					<div>
						<span class="adminFieldName">Email Address</span>
					</div>
					<div class="textInput" name="emailField">
						<input id="email" name="email" type="text" value="<%=account.sEmailAddress%>" >
					</div>
				</div>
			</div>

			<div class="divRow">
				<div class="divCell">
					<div>
						<span class="adminFieldName">Address Line 1</span>
					</div>
					<div class="textInput" name="address1Field">
						<input id="address1" name="address1" type="text" value="<%=account.sAddress1.replaceAll("\"","&quot;")%>" >
					</div>
				</div>

				<div class="divCell">
					<div>
						<span class="adminFieldName">Address Line 2</span>
					</div>
						
					<div class="textInput" name="address2Field">
						<input id="address2" name="address2" type="text" value="<%=account.sAddress2.replaceAll("\"","&quot;")%>" >
					</div>
				</div>
				
			</div>

			<div class="divRow">
				<div class="divCell">
					<div>
						<span class="adminFieldName">City</span>
					</div>
					<div class="textInput" name="cityField">
						<input id="city" name="city" type="text" value="<%=account.sCity.replaceAll("\"","&quot;")%>" >
					</div>
				</div>

				<div class="divCell">
					<div>
						<span class="adminFieldName">State</span>
					</div>
					<div class="textInput" name="stateField">
						<jsp:include page="/include/df_htmlstateselect.jsp">
							<jsp:param name="id" value="state"/>
							<jsp:param name="name" value="state"/>
							<jsp:param name="default" value="<%=account.sState%>"/>
						</jsp:include>
					</div>
				</div>

				<div class="divCell">
					<div>
						<span class="adminFieldName">ZIP/Postal Code</span>
					</div>
					<div class="textInput" name="zipField">
						<input id="zip" name="zip" type="text" value="<%=account.sZIP.replaceAll("\"","&quot;")%>" >
					</div>
				</div>
			</div>

			<div class="divRow">
				<div class="divCell">
					<div>
						<span class="adminFieldName">Country</span>
					</div>
					<div class="textInput" name="countryField">
						<jsp:include page="/include/df_htmlcountryselect.jsp">
							<jsp:param name="id" value="countryid"/>
							<jsp:param name="name" value="countryid"/>
							<jsp:param name="default" value="<%=account.iCountryID%>"/>
						</jsp:include>
					</div>
				</div>
			</div>

			<div class="divRow">
				<span class="adminFieldName">Time Zone</span><br>
				<select id="timezoneid" name="timezoneid">
					<%
					    List<Map<String,String>> zoneList = DateTools.getTimeZones();
						String tmptzname = Constants.EMPTY;
						String tmptzid = Constants.EMPTY;

					    for(Map<String,String> currentTz : zoneList) {
							tmptzname = currentTz.get("name");
							tmptzid = currentTz.get("timezoneid");
							if (account.sTimeZoneName.equals(tmptzname)) { %>
								<option value="<%=tmptzid%>" selected="selected"><%=currentTz.get("extended_name")%></option>
						<%	} else { %>
								<option value="<%=tmptzid%>"><%=currentTz.get("extended_name")%></option>
					<%		}
					    }
					%>
				</select>
			</div>

			<div class="divRow">
				<div class="divCell">
					<div>
						<span class="adminFieldName">Telephone Number</span>
					</div>
					<div class="textInput" name="telephoneField">
						<input id="telephone" name="telephone" type="text" value="<%=account.sPhoneNumber%>" >
					</div>
				</div>

			</div>
            <div class="divRow"></div>
			<div class="clear"></div>
			</div>
	
        <% if (!isSelfManageAccount) { %>
		 <div style="padding-top:20px;">
			<h2>Home Folder</h2>
			<div class="divRow">
				<div class="divCell">
	                <span id="folderSpan"><span class="adminFieldName">Current folder:&nbsp;</span><span id="folderNameSpn"><%=sFolderName%></span></span>
	                <% if (admin.can(Perms.User.MODIFYEXISTINGUSERACCOUNTS) || isLicenseTeamManagerEditingLicenseAccount) { %>
	                <a class="button" id="folderChooser" href="#">Change folder &raquo;</a>
	                <% } %>
				</div>
            </div>
            	<div class="clear"></div>
            </div>
		<% } %>
		
		
		<% if (isSAMLEnabledForLicense) { %>
		 <div style="padding-top:20px;">
			<h2>Single Sign On</h2>
			<div class="divRow">
				<div class="divCell">
	                <input type="checkbox" id="enable_saml" name="enable_saml" onclick="enableSAMLClicked()" <%= account.enableSAML != AdminSSOLogin.DISABLED ? "checked":"" %>>
	                <label>Enable SSO Authentication</label>
				</div>
            </div>
            <div id="divsamloptions" class="divRow" style="display: none;">
                <div class="divCell">
	                <span style="margin-left:24px;">Allow login using:</span>
			        <select id="samloptions" name="samloptions">
                        <option value="<%=AdminSSOLogin.ENABLED.dbValue()%>"><%=AdminSSOLogin.ENABLED.displayName()%></option>
					    <option value="<%=AdminSSOLogin.BLOCK.dbValue()%>"><%=AdminSSOLogin.BLOCK.displayName()%></option>
					    <option value="<%=AdminSSOLogin.REDIRECT.dbValue()%>"><%=AdminSSOLogin.REDIRECT.displayName()%></option>
				    </select>
				</div>
		    </div>
            <div class="clear"></div>
         </div>
        <% } %>

        <div class="divRow clear"><br></div>
		<div class="divRow"><br></div>
		</div>
		<div class="divRow centerThis">
				<% if (!isSelfManageAccount || isLicenseTeamManagerEditingLicenseAccount) { %>
						<a class="buttonSmall" href="<%=StringEscapeUtils.escapeHtml4(sForwardURL)%>"><%=StringEscapeUtils.escapeHtml4(sCancelButtonText)%></a>
				<% } %>
				<% if (admin.can(Perms.User.MODIFYEXISTINGUSERACCOUNTS) || isLicenseTeamManagerEditingLicenseAccount) { %>
					<input class="buttonLarge buttonSave" id= "saveChanges" name="saveChanges" type="button" value="Save Changes"/>
				<% } %>
					<input type="hidden" id="<%=Constants.RQUSERID%>" name="<%=Constants.RQUSERID%>" value="<%=admin.sUserID%>"/>
					<input type="hidden" id="<%=Constants.RQACCOUNTID%>" name="<%=Constants.RQACCOUNTID%>" value="<%=account.sUserID%>"/>
					<input type="hidden" id="childPassword" name="childPassword" value=""/>
					<% if (!isSelfManageAccount) { %>
						<input type="hidden" id="<%=Constants.RQFOLDERID%>" name="<%=Constants.RQFOLDERID%>" value="<%=account.sHomeFolder%>"/>
					<% } %>
					<input type="hidden" id="<%=Constants.RQLICENSEID%>" name="<%=Constants.RQLICENSEID%>" value="<%=sLicenseId%>"/>
			</div>
			
		</form>
        <div class="divRow"></div>
        </div>

<jsp:include page="/admin/footertop.jsp">
	<jsp:param name="pfi" value="<%=pfo.sCacheID%>"/>
	<jsp:param name="ufi" value="<%=ufo.sCacheID%>"/>
</jsp:include>
<script type="text/javascript" src="/js/analytics.js"></script>

	<script type="text/javascript">
	    var uid = '<%=userId%>';
	    //analyticsExclude(["param_eventCostCenter"]);
	    analyticsInit(uid, null);
		var licenseIdToLicenseInfo = <%=licenseIdToLicenseInfoJSON.toString()%>;
	
		$(document).ready(function() {

			//programatically disable automplete for form fields
			$("#pageWrapper").find("input[name], select[name]").prop("autocomplete","new-password");
			
<%			if (account.requiresDeviceVerification()) { %>
				$('#twoFactorStatusSpn').text('<%=account.isTokenBasedTwoFactorAuthEnabled() ? "Token" : "Email"%>  Enabled');
				$('#twoFactorStatusSpn').addClass('enabledTwoStep');
<%			} else { %>
				$('#twoFactorStatusSpn').text('Disabled');
				$('#twoFactorStatusSpn').addClass('disabledTwoStep');
<%			} %>

			$("#folderChooser").fancybox({
				beforeLoad     :   function() {
					var rootFolderParam =  '&rootfolder=' + licenseIdToLicenseInfo[$('#<%=Constants.RQLICENSEID%>').val()].folderid; 
					this.href= '/admin/foldertree.jsp?<%=sQueryString%>&action=createuser&findfolder=' + $("#<%=Constants.RQFOLDERID%>").val() + rootFolderParam;
 			    },
				'width'				: '35%',
				'height'			: '75%',
		        'autoScale'     	: false,
		        'transitionIn'		: 'none',
				'transitionOut'		: 'none',
				'type'				: 'iframe',
				"hideOnOverlayClick": false,
		        'autoSize'			: false,
				'openSpeed'			: 0,
				'closeSpeed'        : 'fast',
				'closeClick'  		: false,
				helpers    : { 
					        'overlay' : {'closeClick': false}
				},
			    beforeShow : function() {
			        	$('.fancybox-overlay').css({
			        		'background-color' :'rgba(119, 119, 119, 0.7)'
			        	});
			        },
			    iframe: { preload: false }
			});

			// Show the US, Canada or text state selections with the default selected
			if ($("#countryid").val() == '<%=Constants.COUNTRY_ID_USA%>') {
	            $("#state").show();
				$("#ca_state").hide();
				$("#text_state").hide();
			} else if ($("#countryid").val() == '<%=Constants.COUNTRY_ID_CANADA%>') {
				$("#ca_state").show();
		        $("#state").hide();
				$("#text_state").hide();
			} else {
				$("#text_state").val("<%=account.sState%>").show();
		        $("#state").val("").hide();
				$("#ca_state").val("").hide();
			}

			$.initdialog();
			$("#saveChanges").on('click', function(){
				checkPassword("u");
			});

			$("#savePassword").on('click', function() {
				checkPassword("p");
			});
			
			$(".deleteDevice").on('click',function(){
			    $(this).closest("tr").addClass('selectedDevice');
			    checkPassword("del_device");
			});
			
			$('#licenseSlct').on('change', function() {
				$('#<%=Constants.RQLICENSEID%>').val($(this).val());
				if ($(this).val() != '') {
					$('#folderNameSpn').html(licenseIdToLicenseInfo[$(this).val()].foldername);
					$('#<%=Constants.RQFOLDERID%>').val(licenseIdToLicenseInfo[$(this).val()].folderid);
				}
				$('#pgiClientIdSpn').html(licenseIdToLicenseInfo[$(this).val()].pgiclientid);
			});
			
			getMailingListStatus('<%=StringEscapeUtils.escapeEcmaScript(account.sEmailAddress)%>');
			
			$("#subscribe_system_updates").on('click',function(){
			   var text = $(this).val();
			   //subscribe
			   if(text.toLowerCase().indexOf('notify') != -1){
				    var params = {
					    action : 'subscribe',
					    email : '<%=StringEscapeUtils.escapeEcmaScript(account.sEmailAddress)%>',
					    fname : '<%=StringEscapeUtils.escapeEcmaScript(account.sFirstName)%>',
					    lname : '<%=StringEscapeUtils.escapeEcmaScript(account.sLastName)%>'
				    }
			       subscribeUser(params);
			   } else {
					toggleSystemUpdateSubscriptionStatus({action:'unsubscribe',email:'<%=StringEscapeUtils.escapeEcmaScript(account.sEmailAddress)%>'});
			   }
			});
			
			// Show the US, Canada or text state selections when country selection changes
			$("#countryid").change(function() {
				var optionSelected = $(this).val();
				if (optionSelected == '<%=Constants.COUNTRY_ID_USA%>' || optionSelected == '') {
		            $("#state").val("").show();
		            $("#ca_state").hide();
		            $("#text_state").hide();
				} else if (optionSelected == '<%=Constants.COUNTRY_ID_CANADA%>') {
					$("#ca_state").val("").show();
			        $("#state").hide();
					$("#text_state").hide();
				} else {
					$("#text_state").val("").show();
			        $("#state").hide();
					$("#ca_state").hide();
				}
			});
 
			// Select the US country if not selected and US state changed.
			$("#state").change(function() {
				if ($("#countryid").val() == '') {
		            $("#countryid").val('<%=Constants.COUNTRY_ID_USA%>');
				}
			});

			// Show the SSO login option selection if SAML enabled.
			if ($("#enable_saml").length && $("#enable_saml")[0].checked) {
			    $("#samloptions").val("<%=account.enableSAML.dbValue()%>");
			    $("#divsamloptions").show();
			}
		});

		function enableSAMLClicked() {
			if ($("#enable_saml")[0].checked) {
				$("#divsamloptions").show();
			} else {
				$("#divsamloptions").hide();
			}
		};

		function getMailingListStatus(emailAddr, hostname) {
			var params = {
				    action: 'status',
				    email: emailAddr
			    };
			$.extend(params, <%=ufo.json()%>);
			$.ajax({
				type: 'GET',
		        url: "/admin/management/proc_mailinglist_actions.jsp",
				data: params,
				dataType: 'json',
				success: function(jsonResult){
				    if (jsonResult.success) {
				    	$("#subscribe_system_updates").show();
						toggleSubscriptionText(jsonResult.status);
				    } else {
				    	$("#subscribe_system_updates").hide();
				    }
				},
				error: function(xmlHttpRequest, status, errorThrown) {
					$("#subscribe_system_updates").hide();
		        }
		    });
		}
		
		function subscribeUser(params){
			$.extend(params, <%=ufo.json()%>);
			$.ajax({
				type: 'GET',
		        url: "/admin/management/proc_mailinglist_actions.jsp",
				data: params,
				dataType: 'json',
				success: function(jsonResult){
				    if(jsonResult.success){
						toggleSubscriptionText(true);
				    }else{
						errorHandler(jsonResult);
				    }
				},
				error: function(xmlHttpRequest, status, errorThrown) {
					$.alert('Oops! Something went wrong.', 'error:' + errorThrown, 'icon_error.png');
		        }
		    });
		}
		
		function toggleSystemUpdateSubscriptionStatus(params) {
			$.extend(params,<%=ufo.json()%>);
		    $.ajax({ 
			    type: "POST",			
                url: "/admin/management/proc_mailinglist_actions.jsp",
                data: params,
                dataType: "json",
                success: function(jsonResult) {
                    if (jsonResult.success) {
						toggleSubscriptionText(jsonResult.status);
					} else {
						errorHandler(jsonResult.errors);
					}
                }
            });
		}
		
		function toggleSubscriptionText(subscribed) {
			$("#subscribe_system_updates").val(subscribed ? "Unsubscribe from System Updates" : "Notify Me of System Updates");  
		}
		
		function folderTreeCallback(selectedFolder, folderName) {
			$("#folderNameSpn").html(folderName);
			$("#<%=Constants.RQFOLDERID%>").val(selectedFolder);
		}

		function formSubmit(){
			// set the name attrib for the us, canada or text state selection
			if ($("#state").is(":visible")) {
				$("#state").attr("name", "state");
				$("#ca_state").removeAttr("name");
				$("#text_state").removeAttr("name");
			} else if ($("#ca_state").is(":visible")) {
				$("#ca_state").attr("name", "state");
				$("#state").removeAttr("name");
				$("#text_state").removeAttr("name");
			} else if ($("#text_state").is(":visible")) {
				$("#text_state").attr("name", "state");
				$("#state").removeAttr("name");
				$("#ca_state").removeAttr("name");
			}

			var dataString = $("#frm_userinfo").serialize();

			$.ajax({ type: "POST",
                url: "/admin/management/proc_userinfo.jsp",
                data: dataString,
                dataType: "json",
                success: function(jsonResult) {
					jsonResult = jsonResult[0];
                    $("span.small-error-text").remove();
                    $(".error").removeClass("error");
                    if (jsonResult.success) {
						$.alert("Admin information saved successfully!","","icon_check.png");
						return false;
					} else {
						errorHandler(jsonResult.errors);
					}
                }
            });

            return false;
		}

		function formSubmit_password(){
			var dataString = $("#frm_changepassword").serialize();
			$.ajax({ type: "POST",
                url: "/admin/management/proc_changepassword.jsp",
                data: dataString,
                dataType: "json",
                success: function(jsonResult) {
					jsonResult = jsonResult[0];
				    $("span.small-error-text").remove();
                    $(".error").removeClass("error");
                    if (jsonResult.success) {
						$.alert("Password changed successfully!","","icon_check.png");
						return false;
					} else {
						errorHandler(jsonResult.errors);
					}
                }
            });
            return false;
		}
		
		function deleteAdminDevice(){
		    var deviceID = $(".selectedDevice").attr("id");
		    var dataString = $("#frm_changepassword").serialize()+"&action=<%=Constants.DEL_DEVICE%>&deviceid="+deviceID+"&childPassword="+$("#password").val();
			$.ajax({ type: "POST",
		                url: "/admin/proc_adminverificationtools.jsp",
		                data: dataString,
		                dataType: "json",
		                success: function(jsonResult) {
							jsonResult = jsonResult[0];
						    $("span.small-error-text").remove();
		                    $(".error").removeClass("error");
		                    if (jsonResult.success) {
					   			$(".selectedDevice").remove();
								$.alert("Device verification deleted successfully!","","icon_check.png");
							} else {
							    errorHandler(jsonResult.errors);
							}
		                }
		            });
		}
		
		function errorHandler(errors){
			var frmError = "";
			var frmName = "messageBar";
			var curError="";
			var curElement = "";
			var c = false;
			for (i=0; i<errors.length; i++) {
			  	curError = errors[i];
			  	curElement = curError.element[0];
			  	if(curElement!=frmName && curElement!="__ERROR__"){
					if (curError.element == "chuck") {
							c = true;
					}
			  		$("#" + curElement).addClass("error").before("<span class=\"small-error-text\">" + curError.message + "<br></span>");
			  		if (curElement == "state") {
              			$("#ca_state").addClass("error");
              			$("#text_state").addClass("error");
              		}
			    }else{
			  		frmError = frmError + curError.message + "<br>";
			  	}
			}
			if(frmError!=""){
				$.alert("Hmm. Something isn't right. ",frmError,"icon_alert.png");
			}
			return false;
		}
		
		
		function authenticate(whichform){
			var password = $("#password").val();
			
			if(whichform=="u"){
				$("#childPassword").val(password);
				formSubmit();
			}else if(whichform=="del_device"){
			    deleteAdminDevice();
			}
			else{
				$("#<%=Constants.RQCURRENTPASSWORD%>").val(password);
				formSubmit_password();
			}
			
		}
		function checkPassword(whichform){
			$("#password").val("");
			$("#name").val("");
			var objButton = {"Cancel": function(){$("#authForm").dialog("close");},"Authenticate":function(){authenticate(whichform);$("#authForm").dialog("close");}};
			$.confirmPassword("Please enter your current password for authentication."," ",objButton,"");
		}
	</script>
<%}catch(Exception e){
	//e.printStackTrace();
		response.sendRedirect(ErrorHandler.handle(e, request));
	}%>
<jsp:include page="/admin/footerbottom.jsp">
	<jsp:param name="pfi" value="<%=pfo.sCacheID%>"/>
	<jsp:param name="ufi" value="<%=ufo.sCacheID%>"/>
</jsp:include>
