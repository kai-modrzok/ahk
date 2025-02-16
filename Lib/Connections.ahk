﻿#Include <Login>
#Include <DateConv>
#Include <uriDecode>
#Include <PowerTools>
#Include <FindText>
; Calls ButtonBox
;global PowerTools_ConnectionsRootUrl
;PowerTools_ConnectionsRootUrl := Connections_GetRootUrl()
; ----------------------------------------------------------------------
CNAuth() {
sPassword := Login_SetPassword()
If (sPassword="")
    return 
PowerTools_ConnectionsRootUrl := PowerTools_RegRead("ConnectionsRootUrl")

WebRequest := ComObjCreate("WinHttp.WinHttpRequest.5.1")
sUrl = https://%PowerTools_ConnectionsRootUrl%/profiles/atom/profile.do?email=xx ; TODO
WebRequest.Open("GET", sUrl, false) ; Async=false	
WebRequest.SetCredentials(A_UserName, sPassword, 0)
WebRequest.SetCredentials(A_UserName, sPassword, 1)
WebRequest.Send()

If (WebRequest.Status=200)
    TrayTipAutoHide("Connections Auth", "Authentification was successful!")
Else {
    sText := "Authentification failed! " . WebRequest.StatusText
    TrayTip Connections Auth, %sText%
}
} ; eof

; ----------------------------------------------------------------------
CNGetOld(sUrl, showError := true) {
; Syntax: sResponse := CNGet(sUrl)
; Run HttpGet request on a ConNext page using provided Password authentification
; Output is ResponseText. in case of error it starts with "Error 
; If (sResponse ~= "Error.*")

sPassword := Login_GetPassword() 

If (sPassword="")
    sResponse := "Error: No password"
Else {
    WebRequest := ComObjCreate("WinHttp.WinHttpRequest.5.1")
    WebRequest.Open("GET", sUrl, false) ; Async=false	
    WebRequest.SetCredentials(A_UserName, sPassword, 0)
    WebRequest.SetCredentials(A_UserName, sPassword, 1)
    If (Login_IsVPN()) {
        WebRequest.SetProxy(1) ; direct connection
    }

    WebRequest.Send()
    ; Debug
    ;sText := WebRequest.Status . WebRequest.ResponseText

    If (WebRequest.Status=200)
        sResponse := WebRequest.ResponseText
    Else
        sResponse := "Error on HttpRequest: " .  WebRequest.StatusText
    ;sResponse := (WebRequest.Status=200?WebRequest.ResponseText:"Error on HttpRequest: " .  WebRequest.StatusText)
}

If (showError) and (sResponse ~= "Error.*") {
    ; MsgBox 0x10, Error, %sResponse%
    TrayTip ConNext Get Error!, %sResponse%
}
return sResponse

}


; ----------------------------------------------------------------------
Connections_Profile2Email(sUrl){
; Requires Password - DownloadToString(sUrl) ; does not work/ returns empty
PowerTools_ConnectionsRootUrl := PowerTools_RegRead("ConnectionsRootUrl")
If RegExMatch(sUrl,"\?userid=([^#\?]*)",sMatch)
	sUrl = https://%PowerTools_ConnectionsRootUrl%/profiles/atom/profile.do?userid=%sMatch1%
Else If RegExMatch(sUrl,"\?key=(.*)",sMatch)
	sUrl = https://%PowerTools_ConnectionsRootUrl%/profiles/atom/profile.do?key=%sMatch1%

sSource := CNGet(sUrl)
If (sSource ~= "Error.*") 
	return

If RegExMatch(sSource,"<email>(.*?)</email>",sEmail) 
	return sEmail1
}

; ----------------------------------------------------------------------
Connections_Uid2Email(sUid){
; Requires Password - DownloadToString(sUrl) ; does not work/ returns empty
; With VPN does not work via HttpGet
PowerTools_ConnectionsRootUrl := PowerTools_RegRead("ConnectionsRootUrl")
sUrl = https://%PowerTools_ConnectionsRootUrl%/profiles/atom/profile.do?userid=%sUid%
sSource := CNGet(sUrl)
If (sSource ~= "Error.*") 
	return
If RegExMatch(sSource,"<email>(.*?)</email>",sEmail) 
		return sEmail1
}
; ----------------------------------------------------------------------
CNEmail2Uid(sEmail){
; Requires Password - DownloadToString(sUrl) ; does not work/ returns empty
PowerTools_ConnectionsRootUrl := PowerTools_RegRead("ConnectionsRootUrl")
sUrl = https://%PowerTools_ConnectionsRootUrl%/profiles/atom/profile.do?email=%sEmail%
	
sSource := CNGet(sUrl)
If (sSource ~= "Error.*") 
	return
sPat = <div class="x-profile-uid">(.*?)</div>
If RegExMatch(sSource,sPat,sUid) 
		return sUid1
}
; ----------------------------------------------------------------------
Connections_Email2Key(sEmail){
; Requires Password - DownloadToString(sUrl) ; does not work/ returns empty
PowerTools_ConnectionsRootUrl := PowerTools_RegRead("ConnectionsRootUrl")
sUrl = https://%PowerTools_ConnectionsRootUrl%/profiles/atom/profile.do?email=%sEmail%
	
sSource := CNGet(sUrl)
If (sSource ~= "Error.*") 
	return
sPat= U)https?://%PowerTools_ConnectionsRootUrl%/profiles/atom/profileTags.do\?targetKey=(.*)&
If RegExMatch(sSource,sPat,sKey) 
		return sKey1
}
; ----------------------------------------------------------------------
Connections_Emails2Mentions(sEmailList){
OnMessage(0x44, "OnMentionMsgBox")
MsgBox 0x24, Emails To Mentions, Select your Mention Display Name Format:
OnMessage(0x44, "")
sNameStyle = first ; Default
IfMsgBox, Yes
    sNameStyle = first	
IfMsgBox, No
    sNameStyle = full

Loop, parse, sEmailList, ";"
{
    sMention := CNEmail2Mention(A_LoopField, sNameStyle)
    sHtmlMentions = %sHtmlMentions%, %sMention%
}	
return SubStr(sHtmlMentions,3) ; remove trailing ;
} ; eofun


; ----------------------------------------------------------------------
Connections_SendMentions(sEmailList){
Loop, parse, sEmailList, ";"
{
    sInput := RegExReplace(A_LoopField,"@.*","")
	SendInput {@}
	Sleep 300
	SendInput %sInput%
	Sleep 500 ; time for autocompletion
	SendInput {Enter}{space} ; only Enter works in Status update
}	

} ;eofun


; ----------------------------------------------------------------------
CNEmail2Mention(sEmail,sNameStyle := "first"){
PowerTools_ConnectionsRootUrl := PowerTools_RegRead("ConnectionsRootUrl")
sUid := CNEmail2Uid(sEmail)
If (!sUid)
    return

If (sNameStyle = "first")
    sName := RegExReplace(sEmail,"\..*" ,"")
Else {
    sName := RegExReplace(sEmail,"@.*" ,"")
    sName := StrReplace(sName,"." ," ")
	sName := RegExReplace(sName," \(.*\)","") ; Remove (uid) in firstname
}
StringUpper, sName, sName , T
sMention := "<a class='vcard' data-userid='" . sUid . "' href='https://" . PowerTools_ConnectionsRootUrl . "/profiles/html/profileView.do?userid=" . sUid . "'>@" . sName . "</a>"
return sMention
}
; ----------------------------------------------------------------------
Connections_Mentions2Mentions(sHtml){
; Extract list of Mentions in Html source
; Syntax:
;   sHtmlMentions := Connections_Mentions2Mentions(sHtml)
PowerTools_ConnectionsRootUrl := PowerTools_RegRead("ConnectionsRootUrl")
sPat = U)\?userid=(.*)".*>(.*)<
Pos = 1 
While Pos := RegExMatch(sHtml,sPat,sMatch,Pos+StrLen(sMatch)) {
    If InStr(sUidList,sMatch1 . ";"){	
		continue
	}
	sMention := "<a class='vcard' data-userid='" . sMatch1 . "' href='https://" . PowerTools_ConnectionsRootUrl . "/profiles/html/profileView.do?userid=" . sMatch1 . "'>" . sMatch2 . "</a>"
    sHtmlMentions = %sHtmlMentions% %sMention%
    sUidList := sMatch1 . ";" sUidList
}
return sHtmlMentions
} ; eof
; ----------------------------------------------------------------------
Connections_Mentions2Emails(sHtml){
; Extract list of Email from Mentions in Html source
; Syntax:
;   sEmailList := Connections_Mentions2Emails(sHtml)
; Calls: Connections_Uid2Email
sPat = \?userid=([0-9A-Z]*?)"
Pos = 1 
While Pos := RegExMatch(sHtml,sPat,sUid,Pos+StrLen(sUid)){
    If InStr(sUidList,sUid1 . ";") ; skip duplicates
        continue
    
    sEmail := Connections_Uid2Email(sUid1)
    If (sEmail = "") ; Inactive user
        continue
    sEmailList := sEmailList . ";" . sEmail
    sUidList := sUid1 . ";" . sUidList
}
return SubStr(sEmailList,2) ; remove trailing ;

} ; eof

; ----------------------------------------------------------------------
CNLikers2Emails(sUrl){
; Only for Blog entries
; Syntax:
;    sEmailList := CNLikers2Emails(sUrl)
; Calls DownloadToString

sUrl := RegExReplace(sUrl,"\?.*","") ; clean-up url: remove section and lang tag
sSource := DownloadToString(sUrl)
; Parse response for string between <title> </title> for atom <title type="html">
sPat = <input type="hidden" name="entryId" value="([^/]*)"/>
If RegExMatch(sSource, sPat, sEntryId)
	sEntryId := sEntryId1

; Get BlogId
Array := StrSplit(sUrl,"/")
sBlogId := Array[5]
sApiUrl = https://connectionsroot/blogs/%sBlogId%/api/recommend/entries/%sEntryId%

sSource := DownloadToString(sApiUrl)

Pos = 1 
While Pos := RegExMatch(sSource,"<contributor>.*?<email>(.*?)</email>.*?</contributor>",sEmail,Pos+StrLen(sEmail))
    sEmailList = %sEmailList%;%sEmail1%
; Create Email
return SubStr(sEmailList,2) ;
} ; eof

; ----------------------------------------------------------------------
OnMentionMsgBox() {
    DetectHiddenWindows, On
    Process, Exist
    If (WinExist("ahk_class #32770 ahk_pid " . ErrorLevel)) {
        ControlSetText Button1, First Name
		ControlSetText Button2, Full Name
    }
}

CNEvent2Emails(sUrl){
; Syntax : 
; sEmailList := CNAttendees2Emails(sUrl) or CNAttendees2Emails(sEvenUid)
; Input sUrl or sEventUuid
	; Test https://connectionsroot/communities/service/html/communityview?communityUuid=1f40ae3f-215e-48b2-86f5-7b43b7229d2c#fullpageWidgetId=W2a25ef83ef5c_4f39_b65b_578387091606&eventInstUuid=ed9fccde-6c68-4705-aa05-104f5dda28ee 
	; more than 100
	; MsgBox 0x10, ConNext Enhancer: Error, You need to be in Edit mode!	
	If (InStr(sUrl, "http")) {
        sPat = &eventInstUuid=(.*)
        If (!RegExMatch(sUrl,sPat,sEventUuid)) {
            MsgBox 0x10, Connections Enhancer: Error, Provided Url does not match an event!
            return
        }
        sEventUuid := sEventUuid1
    } Else
        sEventUuid := sUrl
		
	sUrl = https://connectionsroot/communities/calendar/atom/calendar/event/attendees?eventInstUuid=%sEventUuid%&type=attend
    
	sXml := CNGetAtomPages(sUrl)
	If (sXml ~= "Error.*") {
		MsgBox 0x10, Connections Enhancer: Error, Could not download page!
		return
	}
	
	
	sPat = U)<email .*>(.*)</email>
	Pos = 1 
	While Pos := RegExMatch(sHtml,sPat,sEmail,Pos+StrLen(sEmail)){
    	sEmailList = %sEmailList%;%sEmail1%
	}
	return SubStr(sEmailList,2)
}
; ----------------------------------------------------------------------

CNEvent2Email(sEventUrl){
; Calls: CNGet, CNEvent2Emails
; Create Outlook Email from Event Url  

sPat = &eventInstUuid=(.*)
If !(RegExMatch(sEventUrl,sPat,sEventUuid)) {
	TrayTipAutoHide("Connections Enhancer","Provided Url does not match an event!",3000,3) ; error
	return
}
PowerTools_ConnectionsRootUrl := PowerTools_RegRead("ConnectionsRootUrl")
sUrl = https://%PowerTools_ConnectionsRootUrl%/communities/calendar/atom/calendar/event?eventInstUuid=%sEventUuid1%
sHtml := CNGet(sUrl)
Try
	oEmail := ComObjActive("Outlook.Application").CreateItem(0)
Catch
	oEmail := ComObjCreate("Outlook.Application").CreateItem(0)


; title between <title xmlns:atom="http://www.w3.org/2005/Atom" type="text">[Waiting for more Attendees:30] Learning Bite: Python Use Case : Spotify Download</title>
RegExMatch(sHtml,"<title [^>]*>([^<]*)</title>",sSubject)
oEmail.Subject := "RE: " . html_decode(sSubject1)

; Copy Body from temporary Email
; Body
RegExMatch(sHtml,"<content [^>]*>([^<]*)</content>",sBody)

oEmail.BodyFormat := 2 ;olFormatHTML 
sBody := html_decode(sBody1)
; Add link to event
EventLink = <a href="%sEventUrl%">Link to ConNext Event</a><br>
sBody := EventLink . sBody
html := "<html><body>" . sBody . "</body></html>"
oEmail.HTMLBody := html


sEmailList := CNEvent2Emails(sEventUuid1)
; Add Attendees
oEmail.To := sEMailList	
oEmail.Display 
}
; ----------------------------------------------------------------------

CNEvent2Meeting(sEventUrl,isMeeting := True){
; Calls: CNGet, CNEvent2Emails  
sPat = &eventInstUuid=(.*)
If !(RegExMatch(sEventUrl,sPat,sEventUuid)) {
	TrayTipAutoHide("Connections Enhancer","Provided Url does not match an event!",3000,3) ; error
	return
}
PowerTools_ConnectionsRootUrl := PowerTools_RegRead("ConnectionsRootUrl")
sUrl = https://%PowerTools_ConnectionsRootUrl%/communities/calendar/atom/calendar/event?eventInstUuid=%sEventUuid1%
sHtml := CNGet(sUrl)
Try
	oAppointment := ComObjActive("Outlook.Application").CreateItem(1)
Catch
	oAppointment := ComObjCreate("Outlook.Application").CreateItem(1)

WinActivate ahk_exe OUTLOOK.exe ; needs to authorize
; title between <title xmlns:atom="http://www.w3.org/2005/Atom" type="text">[Waiting for more Attendees:30] Learning Bite: Python Use Case : Spotify Download</title>
RegExMatch(sHtml,"<title [^>]*>([^<]*)</title>",sSubject)
oAppointment.Subject := html_decode(sSubject1)

; content between  <content .*>  </content>
; start time: <snx:startDate .*></snx:startDate> 2020-01-31T23:30:00.000Z
RegExMatch(sHtml,"<snx:startDate [^>]*>([^<]*)</snx:startDate>",sStart)

sStart := DateConvZ(sStart1)
oAppointment.Start := sStart

; end date: <snx:endDate .*>2020-01-31T23:30:00.000Z</snx:endDate>
RegExMatch(sHtml,"<snx:endDate [^>]*>([^<]*)</snx:endDate>",sEnd)
oAppointment.End := DateConvZ(sEnd1)
; end date: <snx:endDate .*>2020-01-31T23:30:00.000Z</snx:endDate>
RegExMatch(sHtml,"<snx:location [^>]*>([^<]*)</snx:location>",sLocation)
oAppointment.Location := sLocation1


; Copy Body from temporary Email
; Body
RegExMatch(sHtml,"<content [^>]*>([^<]*)</content>",sBody)


oEmail := ComObjActive("Outlook.Application").CreateItem(0) 

oEmail.BodyFormat := 2 ;olFormatHTML 
sBody := html_decode(sBody1)
EventLink = <a href="%sEventUrl%">Link to ConNext Event</a><br>
sBody := EventLink . sBody

html := "<html><body>" . sBody . "</body></html>"
oEmail.HTMLBody := html
EmailInspector := oEmail.GetInspector
wdDocEmail := EmailInspector.WordEditor
ApptInspector := oAppointment.GetInspector
wdDocAppt := ApptInspector.WordEditor
wdDocAppt.Range.FormattedText := wdDocEmail.Range.FormattedText
oEmail.Close(1) ; Close and discard

If (isMeeting) {
    sEmailList := CNEvent2Emails(sEventUuid1)
    ; Add Attendees
    oAppointment.MeetingStatus := 1
    Loop, parse, sEmailList, ";"
    {
        oAppointment.Recipients.Add(A_LoopField) 
    }
}	
oAppointment.Display 
}
; ----------------------------------------------------------------------

String2UTF8(sInput){
	
vSize := StrPut(sInput, "UTF-8")
VarSetCapacity(vUtf8, vSize)
vSize := StrPut(sInput, &vUtf8, vSize, "UTF-8")
sOutput .= StrGet(&vUtf8, "CP0") ;cafÃƒÂ©
}

; ----------------------------------------------------------------------
CNGetAtomPages(sUrl,pagesize:=150){
; Syntax: sXml := CNGetAtom
; Called by CNAttendees2Emails
; Calls: CNGet


sUrl := RegExReplace(sUrl, "&ps=.*", "")
;pagesize := 100
pagecnt := 1
TotalCount := 0
   
LoopPage:
sPageUrl = %sUrl%&ps=%pagesize%&page=%pagecnt%

;sXml_page := BrowserGetPage(sPageUrl) ; will flash a browser window
sXml_page := CNGet(sPageUrl)


If (sXml_page ~= "Error.*") {
	return sXml_page
}
   
If (pagecnt = 1) {
    sXml := sXml_page
}
Else { ; merge pages
    sXml := StrReplace(sXml, "</feed>", "") ; remove ending <feed>
    sXml_page := RegExReplace(sXml_page, "^(.*?)<entry", "<entry")
    sXml := sXml . sXml_page
	
}

; Get number of entry found
NewStr := RegExReplace(sXml_page, "sU)<entry[^>]*>(.*)</entry>", "", EntryCount)

TotalCount := TotalCount + EntryCount

If (EntryCount = pagesize) {
	pagecnt ++
    GoTo, LoopPage    
}
TrayTipAutoHide("Connections Enhancer", TotalCount . " entries were extracted from response.")
;MsgBox 0x40, ConNext Enhancer, %TotalCount%  were extracted.  

return sXml
}
; ----------------------------------------------------------------------
; Called by NWS: Ctrl+E in browser
Connections_Edit(sUrl){
PowerTools_ConnectionsRootUrl := PowerTools_RegRead("ConnectionsRootUrl")
If InStr(sUrl,"://" . PowerTools_ConnectionsRootUrl . "/blogs") { ; ConNext Blog
	If InStr(sUrl,"method=edit") 
		return
	
	sUrl := StrReplace(sUrl,"/blogs/","/blogs/roller-ui/authoring/weblog.do?method=edit&weblog=")
	sUrl := StrReplace(sUrl,"/entry/","&entry=")
	
} Else If InStr(sUrl,"://" . PowerTools_ConnectionsRootUrl . "/wikis") { ; ConNext Wiki - not in edit mode	
	If InStr(sUrl,"/edit") 
		return
	; Remove link to section part
	sUrl := RegExReplace(sUrl, "\?section=.*", "")		
	sUrl = %sUrl%/edit	
} Else ; not possible
	return
; Overwrite current window but stays in same browser profile
Send ^l
Clip_Paste(sUrl)
SendInput {Enter}
} ; eofun
; ----------------------------------------------------------------------
; Called by Connections Enhancer: Ctrl+S in browser - does not work-> CRX or native hotkey in TinyCE Editor
Connections_Save(sUrl){
PowerTools_ConnectionsRootUrl := PowerTools_RegRead("ConnectionsRootUrl")
ReCNRoot := StrReplace(PowerTools_ConnectionsRootUrl, ".","\.")
If RegExMatch(sUrl,"://" . ReCNRoot . "/blogs/.*weblog\.do\?method=edit") { ; ConNext Blog in edit mode
	SendInput ^+J ; or F12
    SendInput {Tab}document.getElementById('postEntryID').click(){Enter}
	return
    SendInput ^+J
} Else If RegExMatch(sUrl,"://" . ReCNRoot . "/wikis/.*/edit") { ; ConNext Wiki - in edit mode	
	SendInput ^+J{Tab}
	Sleep 3000
    SendInput document.getElementById('edit_saveclose').click(){Enter}
	return
	SendInput ^+J
}
} ; eofun

; ----------------------------------------------------------------------
CNGetTitle(sUrl){
; Syntax:
;   sTitle := CNGetTitle(sUrl)
; Called by IntelliPaste-> Link2Text
PowerTools_ConnectionsRootUrl := PowerTools_RegRead("ConnectionsRootUrl")
If InStr(sUrl,"://" . PowerTools_ConnectionsRootUrl . "/forums/")
    return CNGetForumTitle(sUrl)
Else If InStr(sUrl,"://" . PowerTools_ConnectionsRootUrl . "/blogs/")
    return CNGetBlogTitle(sUrl)
Else If InStr(sUrl,"://" . PowerTools_ConnectionsRootUrl . "/wikis/")
    return CNGetWikiTitle(sUrl)
Else If InStr(sUrl,"communityUuid=") 
    return CNGetCommunityTitle(sUrl)
} ; eofun
; ----------------------------------------------------------------------

CNGetWikiTitle(sUrl){
; Shall support link by pageid
PowerTools_ConnectionsRootUrl := PowerTools_RegRead("ConnectionsRootUrl")
If Instr(sUrl,"/search?query") {
; https://connectionsroot/wikis/home#!/search?query=%20ms_teams%20meeting%20virtual&mode=this&wikiLabel=W354104eee9d6_4a63_9c48_32eb87112262
	If RegExMatch(sUrl, "search\?.*&wikiLabel=([^&]*)", sWikiLabel)
		sUrl := "https://" . PowerTools_ConnectionsRootUrl . "/wikis/basic/anonymous/api/wiki/" . sWikiLabel1 . "/entry"
} Else {
	; Remove section part https://connectionsroot/wikis/home/wiki/W1d0f7e400e73_4328_9930_7e375562b15c/page/Test%20Case%20Review?lang=en-us&section=checklist
	sUrl := RegExReplace(sUrl,"\?.*","")
	; Remove comment part https://connectionsroot/wikis/home/wiki/Wc4f94c47297c_42c8_878f_525fd907cb68/page/Teams%20PowerShell%20Setup/comment/afe506be-f5a5-490b-9f50-7a9c0c16a1fa 

	; Convert Url to API GET request
	sUrl := RegExReplace(sUrl, "/wikis/.*/wiki/","/wikis/basic/anonymous/api/wiki/")

	; https://connectionsroot/wikis/home/wiki/W354104eee9d6_4a63_9c48_32eb87112262/index?sort=mostpopular&tag=sync
	; -> https://connectionsroot/wikis/basic/anonymous/api/wiki/W354104eee9d6_4a63_9c48_32eb87112262/entry
	If InStr(sUrl,"/page/") { ; Get Page name
		sUrl := RegExReplace(sUrl,"/comment/.*","")
		sUrl := StrReplace(sUrl,"/page/","/navigation/")
		sUrl := sUrl . "/entry" ; append for API call
	} Else If Instr(sUrl,"/index") { ; Get Wiki Name
		; https://connectionsroot/wikis/home?lang=en#!/wiki/W354104eee9d6_4a63_9c48_32eb87112262/index?sort=mostpopular&tag=ms_power_automate
		sUrl := RegExReplace(sUrl,"/index.*","/entry")
	}
}

sResponse := CNGet(sUrl,True)
sPat = <title type="text">(.*?)</title>
If (RegExMatch(sResponse, sPat, sTitle)) {
    return sTitle1
}
MsgBox, 16, Error, Can not get wiki title.
} ; eofun

; ----------------------------------------------------------------------

CNGetWikiName(sWikiLabel){
PowerTools_ConnectionsRootUrl := PowerTools_RegRead("ConnectionsRootUrl")
sUrl := "https://" . PowerTools_ConnectionsRootUrl . "/wikis/basic/anonymous/api/wiki/" . sWikiLabel . "/entry"	
sResponse := CNGet(sUrl,True)
sPat = <title type="text">(.*?)</title>
If (RegExMatch(sResponse, sPat, sTitle)) {
    return sTitle1
}
MsgBox, 16, Error, Can not get wiki name.
}



; ----------------------------------------------------------------------

; Calls: HttpGet (does not work via VPN connection, requires Password, faster)
;        DownloadToString (if with VPN, does not require password)
CNGetBlogTitle(sUrl){
; Remove link to section or comment permalink.
; Example: https://connectionsroot/blogs/tdalon/entry/teams_chat_link#outlook_vba_create_group_chat_from_email
; Example: https://connectionsroot/blogs/5e459baf-5ca3-4490-848c-4a39ff5488d8/entry/Pop_out_chat?lang=en#threadid=9d904fd6-c550-4722-9f65-f2a40807aef1
; Example: https://connectionsroot/blogs/tdalon/search?t=entry&q=meeting+ms_teams&maxresults=150&lang=en

sUrl := RegExReplace(sUrl,"#.*$","")


; If no VPN
If (Login_IsVPN()) ; VPN 
	sSource := DownloadToString(sUrl)
Else {
	sPassword := Login_GetPassword()
	If !sPassword { ; empty | no password provided
		sSource := DownloadToString(sUrl)
	} Else {
		; Transform Url to Atom - Comments feed
		; https://connectionsroot/blogs/tdalon/entry/Win10_1809_Evergreening_Update?lang=en
		; https://connectionsroot/blogs/roller-ui/rendering/feed/tdalon/entrycomments/Win10_1809_Evergreening_Update/atom?contentFormat=html&lang=en
		PowerTools_ConnectionsRootUrl := PowerTools_RegRead("ConnectionsRootUrl")
		sUrl := StrReplace(sUrl,"https://" . PowerTools_ConnectionsRootUrl . "/blogs/","")
		sUrl = https://%PowerTools_ConnectionsRootUrl%/blogs/roller-ui/rendering/feed/%sUrl%/atom?contentFormat=html
		sUrl := StrReplace(sUrl,"/entry/","/entrycomments/") 
		sSource := CNGet(sUrl)
	}
}

sPat = <title[^>]*>\s*(.*?)\s*</title>

If (RegExMatch(sSource, sPat, sTitle)) {
	;sTitle := StrReplace(sTitle, "`r`n") ; remove line breaks
	;sTitle := RegExReplace(sTitle, "['n\s't]*") ; remove line breaks
	sTitle := sTitle1
	
	sTitle := StrReplace(sTitle,"&amp;","&")
	sTitle := StrReplace(sTitle,"#39","'")
	sTitle := StrReplace(sTitle,"&';","'")

	; Remove trailing - containing Blog Name
	;StringGetPos,pos,sTitle,%A_space%-,R
	;if (pos != -1)
    ;    sTitle := SubStr(sTitle,1,pos)
	sTitle := StrReplace(sTitle,"Blog Blog","Blog")
	return sTitle
} Else {
	MsgBox, 16, Error, Can not get blog title.
}
} ; eofun

; ----------------------------------------------------------------------

CNGetForumTitle(sUrl){
; Calls: DownloadToString 
; https://connectionsroot/forums/html/topic?id=1d84a56a-de8f-4798-8b57-9cc296ff5b40&ps=500#repliesPg=0
sUrl := RegExReplace(sUrl,"&.*$","")
sUrl := RegExReplace(sUrl,"#.*$","")

sSource := DownloadToString(sUrl)
; sSource := CNGet(sUrl) ; Does not work without VPN - auth error

; Parse response for string between <title> </title> for atom <title type="html">
sPat = <title[^>]*>\s*(.*?)\s*</title>
If (RegExMatch(sSource, sPat, sTitle)) {
	sTitle := StrReplace(sTitle1,"&amp;","&")
	sTitle := StrReplace(sTitle,"#39","'")
	return sTitle
}
MsgBox, 16, Error, Can not get forum title.
}


CNGetCommunityTitle(sUrl){
If !RegExMatch(sUrl,"\?communityUuid=(.*)$",sUuid){
    MsgBox, 16, Error, Can not get Community Uuid from url.
    return
}

sUrl = https://connectionsroot//communities/service/atom/community/instance?communityUuid=%sUuid1%
sResponse := CNGet(sUrl)
sPat = <title.*?>(.*?)</title>
If !(RegExMatch(sResponse, sPat, sTitle)) {
    MsgBox, 16, Error, Can not extract title from Response Text.
    return
}
sTitle := StrReplace(sTitle1,"&amp;","&")
sTitle := StrReplace(sTitle,"#39","'")
return sTitle
} ; eofun

; ----------------------------------------------------------------------
Connections_CleanLink(sUrl){
; Link := Connections_CleanLink(sUrl)
ReConnectionsRootUrl := StrReplace(PowerTools_ConnectionsRootUrl,".","\.")
	
; Switch to https
sUrl := StrReplace(sUrl,"http://","https://")

; Link to Blog entries: https://connectionsroot/blogs/tdalon?tags=chrome&lang=en
; Wiki page: https://connectionsroot/wikis/home?lang=en#!/wiki/Wa8a86fe4ac2b_4e9d_8e98_17d4671c70f8 
; => remove ?lang=en#!
; Comment permalink https://connectionsroot/blogs/tdalon/entry/connext_link_format?lang=en#threadid=356630b7-2c83-4d94-b033-d8ca24f456d7
; => https://connectionsroot/blogs/tdalon/entry/connext_link_format#threadid=356630b7-2c83-4d94-b033-d8ca24f456d7

; Language might be en-us => add - to the word		; de_de


; Wiki section
;		https://connectionsroot/wikis/home?lang=en#!/wiki/W10f67125ddc8_42e1_a6da_0a8e6a1cd541/page/Help%20on%20NWS%20Search%20Tool&section=overview
sUrl := RegExReplace(sUrl, "[&|\?]lang=[\w-_]+(#!)?" , "")
sUrl := StrReplace(sUrl,"&section=","?section=")
	
; wiki pages filtered by tag example https://connectionsroot/wikis/home/wiki/W354104eee9d6_4a63_9c48_32eb87112262/index?lang=en&tag=nws_workflow
sUrl := StrReplace(sUrl,"index&tag=","index?tag=")

; Remove ?logDownload=true&downloadType=view&versionNum=1 (when copying image from Files)
; Ex. https://connectionsroot/files/form/anonymous/api/library/9d7cc0b6-434a-4f44-9091-6f13fbac8a4e/document/f091ded1-da5d-45fb-8910-927439348a90/media/idea_orange_trans.png?versionNum=1
; Ex. https://connectionsroot/files/form/anonymous/api/library/ffd279a0-2764-46bb-a8ec-b1aa3c713072/document/87249fa7-87f8-4977-b511-6c49a1597e31/media/wikis_32.jpg?logDownload=true&downloadType=view&versionNum=1

;sUrl := RegExReplace(sUrl, "\?versionNum=\d+" , "")
sUrl := RegExReplace(sUrl, "://" . ReConnectionsRootUrl . "/files/form/anonymous/api/library/([^?]*)\?.*", "://" . PowerTools_ConnectionsRootUrl . "/files/form/anonymous/api/library/$1")

; Remove lastMod (when copying profile picture)
; Ex. https://connectionsroot/profiles/photo.do?key=7df0fd93-6999-426d-869c-d36d434d11fa&lastMod=1500531017000
sUrl := RegExReplace(sUrl, "&lastMod=\d+" , "")

; Remove ?preventCache=1500037805880 if copied from wiki/blogs
sUrl := RegExReplace(sUrl, "\?preventCache=\d+" , "")

; Remove ?logDownload=true&downloadType=view from copy video address from context menu
sUrl := StrReplace(sUrl, "?logDownload=true&downloadType=view","")


sUrl := StrReplace(sUrl,"'","%27")

sText := Connections_Link2Text(sUrl)

return [sUrl, sText]

}
; ----------------------------------------------------------------------

Connections_Link2Text(sLink){
; sText := Connections_Link2Text(sLink)
; Called by IntelliPaste->Link2Text
PowerTools_ConnectionsRootUrl := PowerTools_RegRead("ConnectionsRootUrl")
ReConnectionsRootUrl := StrReplace(PowerTools_ConnectionsRootUrl,".","\.")
If Connections_IsUrl(sLink,"wiki") {
	linktext := CNGetWikiTitle(sLink)
	
	If !linktext ; empty
		linktext = Link Text 
	Else {
		If RegExMatch(sLink,"://" . ReConnectionsRootUrl . "/wikis/.*/wiki/([^/]*)/page/",sWikiLabel) {
			sMatch = ://%ReConnectionsRootUrl%/wikis/.*/page/.*\?section=(.*)
			If RegExMatch(sLink,sMatch,sSection) {
				sSection1 := StrReplace(sSection1,"_"," ")
				linktext = %linktext% : %sSection1%
			}
			WikiName := CNGetWikiName(sWikiLabel1)
			linktext = %linktext% | %WikiName% Wiki
		} Else If RegExMatch(sLink,"/comment/.*") { ; comment
			linktext = %linktext% (Wiki Comment)
		} Else If RegExMatch(sLink,"/search\?.*query=([^&]*)",sMatch) {
		; https://connectionsroot/wikis/home#!/search?query=%20ms_teams%20meeting%20virtual&mode=this&wikiLabel=W354104eee9d6_4a63_9c48_32eb87112262
			sQuery := Trim(StrReplace(sMatch1,"%20"," "))
			linktext := linktext . " - Pages matching '" . sQuery . "'"
		} Else If RegExMatch(sLink,"/index\?([^&]*)(.*)",sMatch) {
		; https://connectionsroot/wikis/home/wiki/W354104eee9d6_4a63_9c48_32eb87112262/index?sort=mostpopular&tag=ms_teams&tag=meeting
			sQuery := StrReplace(sMatch2,"&tag="," #")
			linktext := linktext . " (Wiki) - Pages matching" . sQuery 
		} Else
			linktext = %linktext% (Wiki Page)
		; Prepend CoachNet
		If InStr(sLink,"/wiki/W354104eee9d6_4a63_9c48_32eb87112262/") {
			If !InStr(linktext,"CoachNet")
				linktext = CoachNet: %linktext% 
		}	
	}
	linktext := uriDecode(linktext) ; Bug with Quotes &quot;
	linktext := StrReplace(linktext,"&amp;","&")
	
}
Else If Connections_IsUrl(sLink,"blog") {
	linktext := CNGetBlogTitle(sLink)
	; For community blog does not end with Blog but with - Community name
	If RegExMatch(linktext,".*Blog$") { ; personal blog
		If RegExMatch(linktext," - (.*)",BlogName)
			BlogName := BlogName1
	} Else { ; Community Blog
		If RegExMatch(linktext," - ([^-]*) - ([^-]*)$",BlogName)
			BlogName := BlogName1 " - " BlogName2	
	}
	linktext := RegExReplace(linktext," - (.*)","")
	If !linktext
		linktext = Link Text 
	Else {	
		; Check for section link or comment permalink
		; Example: https://connectionsroot/blogs/tdalon/entry/teams_chat_link#outlook_vba_create_group_chat_from_email
		; Example: https://connectionsroot/blogs/5e459baf-5ca3-4490-848c-4a39ff5488d8/entry/Pop_out_chat?lang=en#threadid=9d904fd6-c550-4722-9f65-f2a40807aef1
		If RegExMatch(sLink,"://" . ReConnectionsRootUrl . "/blogs/.*#threadid=.*$") {
			linktext = %linktext% (Comment)
		} Else If RegExMatch(sLink,ReConnectionsRootUrl . "/blogs/.*#(.*$)",sSection) {			
			sSection1 := StrReplace(sSection1,"_"," ")
			sSection1 := uriDecode(sSection1)
			linktext = %linktext% : %sSection1%
		} Else If RegExMatch(sLink,"/search\?.*&q=([^&]*)",sMatch) {
			; https://connectionsroot/blogs/tdalon/search?t=entry&q=meeting+ms_teams&maxresults=150&lang=en
			sQuery := StrReplace(sMatch1,"%20"," ")
			linktext := linktext . " - Entries matching '" . sQuery . "'"
		} Else If RegExMatch(sLink,"\?tags=([^&]*)",sMatch) {
			; https://connectionsroot/blogs/tdalon?tags=ms_teams%20meeting&maxresults=150&lang=en
			sTags := StrReplace(sMatch1,"%20"," #")
			linktext := linktext . " - Entries matching '#" . sTags . "'"
		}
		;linktext = %linktext% (Blog Post)
		if (BlogName!="") {
			linktext := StrReplace(linktext,"|","`|")
			longtitle = %linktext% (%BlogName%)
			linktext := ListBox("Link text display", "Select your link text display", linktext . "|" . longtitle, Select := 1)
		}
	}

	
} Else If Connections_IsUrl(sLink,"forum") {
	linktext := CNGetForumTitle(sLink)
	sQuery =
	; https://connectionsroot/forums/html/forum?id=755c8bb9-52a5-4db8-9ac9-933777b4322d&ps=500&tags=meeting%20virtual&query=participant%20limit
	If RegExMatch(sLink,"[\?&]query=([^&]*)",sMatch) {
		sQuery := StrReplace(sMatch1,"%20"," ")
		linktext := linktext . " - Topics matching '" . sQuery 
	}
	If RegExMatch(sLink,"[\?&]tags=([^&]*)",sMatch) {
		sTags := StrReplace(sMatch1,"%20"," #")
		If (sQuery="")
			linktext := linktext . " - Topics matching '#" . sTags . "'"
		Else
			linktext := linktext . " #" . sTags . "'"
	} Else If Not (sQuery="")
		linktext := linktext . "'"

} Else If InStr(sLink,"?communityUuid=") {
	linktext := CNGetCommunityTitle(sLink)
	If !linktext
		linktext = Link Text (Community)
	Else
		linktext := linktext . " (Community)"
	
}
; Event Search #TODO
; https://connectionsroot/communities/service/html/communityview?communityUuid=1f40ae3f-215e-48b2-86f5-7b43b7229d2c#fullpageWidgetId=W2a25ef83ef5c_4f39_b65b_578387091606&tags=ms_teams 

/*
InputBox, linktext , Display Link Text, Enter Link display text:,,640,125,,,,, %linktext%
if ErrorLevel ; Cancel
	return
*/
return linktext  
} ; eofun
 
; -------------------------------------------------------------------------------------------------------------------
CNGet(sUrl,showError := False){
; Syntax:
;    sXml := CNGet(sUrl)
; Called by: CNGetAtomPages->CNEvent2Emails
;            			   ->CNEvent2Meeting

sPassword := Login_GetPassword() 
If (sPassword="")
    sResponse := "Error: No password"
Else {
    WebRequest := ComObjCreate("Msxml2.XMLHTTP")
    WebRequest.Open("GET", sUrl, false,A_UserName,sPassword) ; Async=false
    WebRequest.Send()

    ; Debug
    ;sText := WebRequest.Status . WebRequest.ResponseText

    If (WebRequest.Status=200)
        sResponse := WebRequest.ResponseText
    Else
        sResponse := "Error on XmlHttpRequest: " .  WebRequest.StatusText
    ;sResponse := (WebRequest.Status=200?WebRequest.ResponseText:"Error on HttpRequest: " .  WebRequest.StatusText)
}

If (showError) and (sResponse ~= "Error.*") {
    ; MsgBox 0x10, Error, %sResponse%
    TrayTip Connections Get Error!, %sResponse%
}
return sResponse
}

; ----------------------------------------------------------------------

; Called by ConnectionsSearch and ConnectionsEnhancer-> CreateNew
CNGetForumId(sUrl){
; Trim part after & e.g. permalink https://connectionsroot/forums/html/threadTopic?id=18503bfc-8d76-4861-9f03-524a7a18d6bd&permalinkReplyUuid=b4fe66c6-1aa2-4d0b-89be-0cdf2719512d
; Trim after # example https://connectionsroot/forums/html/topic?id=5c1dbf73-844d-43d7-b5b7-77a6c0e49383#repliesPg=0


If RegExMatch(sUrl, "/forums/html/forum\?id=([^&]*)", sForumUuid)
	Return sForumUuid1

sUrl :=RegExReplace(sUrl,"&.*","")
sUrl :=RegExReplace(sUrl,"#.*","")
sSource := DownloadToString(sUrl) ; HttpGet does not work without VPN
;sSource := CNGet(sUrl)

; look-out forumUuid
sPat = '/forums/html/forum\?id=([^']*)'
If RegExMatch(sSource, sPat, sForumUuid)
	Return sForumUuid1

MsgBox,48,Warning!,Forum Id not found!
return
} ; eofun

; ----------------------------------------------------------------------

Connections_FormatImg(sHtml){
; CLICK TO ENLARGE
; Blogs or other sources / Neither Forum nor Wiki nor Files nor Resources (CE Lotus Msg)
; Format img as centered 95% width with click to enlarge 
PowerTools_ConnectionsRootUrl := PowerTools_RegRead("ConnectionsRootUrl")

sPat= U)(?!<a href=[^>]*>)<img [^>]*src="((?!https?://%PowerTools_ConnectionsRootUrl%/forums/)(?!/wikis/form/api/wiki/)(?!https?://%PowerTools_ConnectionsRootUrl%/files/form/anonymous/api/library/)(?!https?://%PowerTools_ConnectionsRootUrl%/files/basic/anonymous/api/library/)(?!https?://%PowerTools_ConnectionsRootUrl%/connections/resources/)(?!https://statics.teams.cdn.office.net/)[^"]*)"([^>]*)>

sRep = <a href="$1">$0</a> 
sHtml := RegExReplace(sHtml,sPat,sRep)

sHtmlNew := sHtml
sPat = s)<img [^>]*>
Pos=1
While Pos :=    RegExMatch(sHtml, sPat, sSearch,Pos+StrLen(sSearch)) {
	If InStr(sSearch,"https://statics.teams.cdn.office.net/") ; Win10 emoji
		Continue
	If InStr(sSearch,"width") ; Width already preset
		Continue

	; Resize to 95%
	sPat= <img [^>]*src="([^"]*)"
	sRep = <img src="$1" style="width: 95_percent;margin: 0px auto; display: block;"
	sRep := StrReplace(sRep,"_percent","%")
	sSearchRep := RegExReplace(sSearch,sPat,sRep)

	sHtmlNew := StrReplace(sHtmlNew,sSearch,sSearchRep)
} ; End While


return sHtmlNew
}

; ----------------------------------------------------------------------
; TODO Not used
CNFormatImg(sHTMLCode,mode:=0){
; Format images <img> as centered with 95% width
; Support click to enlarge if no resources and possible (no wiki)
; Syntax:
;    sHtmlCode := FormatImg(sHtmlCode,mode)
; mode = 0 (default): auto-fit width to 95% and Click to enlarge
; mode = 1: auto-fit to 95%
; mode = 3: click-to enlarge

PowerTools_ConnectionsRootUrl := PowerTools_RegRead("ConnectionsRootUrl")
; CLICK TO ENLARGE
if (mode=0) or (mode=3){
	; Blogs or other sources / Neither Forum nor Wiki nor Files nor Resources (CE Lotus Msg)
	; Format img as centered 95% width with click to enlarge 

    sPat= U)(?!<a href=[^>]*>)<img [^>]*src="((?!https?://%PowerTools_ConnectionsRootUrl%/forums/)(?!form/api/wiki/)(?!https?://%PowerTools_ConnectionsRootUrl%/files/form/anonymous/api/library/)(?!https?://%PowerTools_ConnectionsRootUrl%/files/basic/anonymous/api/library/)(?!https?://%PowerTools_ConnectionsRootUrl%/connections/resources/)[^"]*)"([^>]*)>
    
	sRep = <a href="$1">$0</a> 
    sHTMLCode := RegExReplace(sHTMLCode,sPat,sRep)
	
}

; AUTO-FIT to 95% width
if (mode=0) or (mode=1){

	; Resize to 95%
	sPat= <img [^>]*src="([^"]*)"
	sRep = <img width="95_percent" src="$1" style="margin: 0px auto; display: block;"
	sRep := StrReplace(sRep,"_percent","%")
	sHTMLCode := RegExReplace(sHTMLCode,sPat,sRep)

; TODO exclude win10 emoticons: https://statics.teams.cdn.office.net/*
	
} ; end if

return sHTMLCode
; TODO ignore file located here https://connectionsroot/files/form/anonymous/api/library/ffd279a0-2764-46bb-a8ec-b1aa3c713072/document/ or ending with _32.png
; Ignore https://connectionsroot/connections/resources/web/com.ibm.lconn.core.styles.oneui3/images/blank.gif
}

; ----------------------------------------------------------------------

Connections_SettingSetTocStyle() {
Choice := ButtonBox("ConnectionsEnhancer:Setting:TocStyle","Choose your TOC Style:","?|bullet-white|none-yellow|num-white")
If ( Choice = "ButtonBox_Cancel") or ( Choice = "Timeout")
    return
PowerTools_RegWrite("CNTocStyle",Choice)
TrayTipAutoHide("ConNextEnhancer Setting", "TOC Style was set to " . Choice)
}

; ----------------------------------------------------------------------

 html_decode(html) {	
   ; original name: ComUnHTML() by 'Guest' from
   ; https://autohotkey.com/board/topic/47356-unhtm-remove-html-formatting-from-a-string-updated/page-2 
   html := RegExReplace(html, "\r?\n|\r", "<br>") ; added this because original strips line breaks
   oHTML := ComObjCreate("HtmlFile") 
   oHTML.write(html)
   return % oHTML.documentElement.innerText 
}


; -------------------------------------------------------------------------------------------------------------------
Connections_ExpandMentionsWithProfilePicture(sHtml,sUid:=""){
; Prepend profile picture with link to the profile page before @mentions
;  

PowerTools_ConnectionsRootUrl := PowerTools_RegRead("ConnectionsRootUrl")
; Comment if you don't want to be asked
sPicSize = 100
sSep = <br>
;CNExpandMentionsWithProfilePicture_InputDlg(sPicSize,sSep)
;If !sPicSize ; Cancel
;	return

sHtmlNew := sHtml
If !sUid 
	sPat = U)<[^<]*class="vcard".*\?userid=([^"]*)".*</a> 
Else
	sPat = U)<[^<]*class="vcard".*\?userid=%sUid%".*</a> 
; sPat = <span[^<]*class="vcard".*?\?userid=([^"]*)".*?</a>   does not work because Code View is different from HTML Source

Pos=1
While Pos :=    RegExMatch(sHtml, sPat, sSearch,Pos+StrLen(sSearch)) {
	sUid := sSearch1
	sPicUrl = https://%PowerTools_ConnectionsRootUrl%/profiles/photo.do?userid=%sUid%
	If InStr(sHtmlNew,sPicUrl) ; Picture already inserted (by uid) ->skip
		Continue
	sEMail := Connections_Uid2Email(sUid)
	sPicUrl = https://%PowerTools_ConnectionsRootUrl%/profiles/photo.do?email=%sEmail%
	If InStr(sHtmlNew,sPicUrl) ; Picture already inserted (by email)->skip
		Continue
	sRep = <a href="https://%PowerTools_ConnectionsRootUrl%/profiles/html/profileView.do?userid=%sUid%"><img width=%sPicSize% src="%sPicUrl%"/></a>%sSep% %sSearch%
	sHtmlNew := StrReplace(sHtmlNew,sSearch,sRep)
}
return sHtmlNew
}
; -------------------------------------------------------------------------------------------------------------------

CNExpandMentionsWithProfilePicture_InputDlg(ByRef ExpandMentionsWithProfilePicture_PicSize, ByRef ExpandMentionsWithProfilePicture_Sep){

; Default Values
If !ExpandMentionsWithProfilePicture_PicSize
	ExpandMentionsWithProfilePicture_PicSize = 100
If !ExpandMentionsWithProfilePicture_Sep
	ExpandMentionsWithProfilePicture_Sep = <br>	

Gui, CNExpandMentions:New,,Expand Mentions
Gui, +LastFound 
gui_hwnd := WinExist()
	
Gui, Add, Text, x17 y8 w120 h20, Picture size: 
Gui, Add, Text, x17 yp+30 wp hp, Separator (html): 
Gui, Add, Edit, xp+140 y8 w100 hp vExpandMentionsWithProfilePicture_PicSize, %ExpandMentionsWithProfilePicture_PicSize%
Gui, Add, Edit, xp yp+30 wp hp vExpandMentionsWithProfilePicture_Sep, %ExpandMentionsWithProfilePicture_Sep% 
Gui, Add, Button, x27 y68 w70 hp gOK, OK 
Gui, Add, Button, xp+150 yp wp hp gCancel, Cancel 
Gui, Show, x279 y217 h98 w277 

WinWaitClose, AHK_ID %gui_hwnd%

Return

Cancel: 
CNExpandMentionsGuiClose: 
CNExpandMentionsGuiEscape:
Gui, Destroy
Return

OK: 
Gui, Submit
Gui, Destroy

Return
} ; eofun

; -------------------------------------------------------------------------------------------------------------------
Connections_PersonalizeMentions(sHtml,sUid:=""){
; Prepend profile picture with link to the profile page before @mentions
;  

; Comment if you don't want to be asked
sPicSize = 100
sSep = <br>
;CNExpandMentionsWithProfilePicture_InputDlg(sPicSize,sSep)
;If !sPicSize ; Cancel
;	return

sHtmlNew := sHtml
If !sUid  
	sPat = U)<[^<]*class="vcard".*\?userid=([^"]*)".*</a> 
Else {
	sPat = U)<[^<]*class="vcard".*\?userid=%sUid%".*</a> 
	sName := CNUid2FirstName(sUid)
}
; sPat = <span[^<]*class="vcard".*?\?userid=([^"]*)".*?</a>   does not work because Code View is different from HTML Source

Pos=1
While Pos :=    RegExMatch(sHtml, sPat, sSearch,Pos+StrLen(sSearch)) {
	If !sUid {
		sLoopUid := sSearch1
		sName := CNUid2FirstName(sLoopUid)
	} Else
		sLoopUid := sUid	
	sMention := "<a class='vcard' data-userid='" . sUid . "' href='https://" . PowerTools_ConnectionsRootUrl . "/profiles/html/profileView.do?userid=" . sLoopUid . "'>@" . sName . "</a>"	
	
	sHtmlNew := StrReplace(sHtmlNew,sSearch,sMention)
}
return sHtmlNew
}

; -------------------------------------------------------------------------------------------------------------------
CNUid2FirstName(sUid){
If (sUid = "0687B1B0935023B9852577B70002F94D")
	sName := "Edson"
Else {
	sEMail := Connections_Uid2Email(sUid)
	sName := RegExReplace(sEmail,"\..*" ,"")
	StringUpper, sName, sName , T
}
return sName
}

; -------------------------------------------------------------------------------------------------------------------

Connections_DownloadHtml(sUrl){
; https://connectionsroot/wikis/basic/api/wiki/628f3b85-5674-439d-8f24-8ccea25bde54/page/4426b27e-fadf-4887-9955-67dc70dba7be/media?convertTo=html

If !RegExMatch(sUrl,"/wikis/.*/wiki/(.*?)/page/([^/]*)",sMatch) {
	MsgBox 0x10, Connections Enhancer: Error, You shall have a Wiki page opened!
	return
}
PowerTools_ConnectionsRootUrl := PowerTools_RegRead("ConnectionsRootUrl")
sWikiLabel := sMatch1
sPageLabel := sMatch2
sApiUrl = https://%PowerTools_ConnectionsRootUrl%/wikis/basic/anonymous/api/wiki/%sWikiLabel%/page/%sPageLabel%/media?convertTo=html
Run, %sApiUrl%
}


; -------------------------------------------------------------------------------------------------------------------
Connections_GetRootUrl(){
PowerTools_ConnectionsRootUrl := PowerTools_RegRead("ConnectionsRootUrl")
If (PowerTools_ConnectionsRootUrl)
	return PowerTools_ConnectionsRootUrl

If (PowerTools_ConnectionsRootUrl="") {
	If FileExist("PowerTools.ini") {
		IniRead, ConnectionsRootUrl, PowerTools.ini, Connections, ConnectionsRootUrl
		If !(ConnectionsRootUrl="ERROR")
			PowerTools_ConnectionsRootUrl = ConnectionsRootUrl
	}
}

PowerTools_ConnectionsRootUrl := Connections_SetRootUrl()
return PowerTools_ConnectionsRootUrl
} ; eofun
; -------------------------------------------------------------------------------------------------------------------

Connections_SetRootUrl(){
; Prompt user to input Connections Root Url
; Output is without http(s)//
DefConnectionsRootUrl := PowerTools_RegRead("ConnectionsRootUrl")
If (DefConnectionsRootUrl="") {
	If FileExist("PowerTools.ini") {
		IniRead, DefConnectionsRootUrl, PowerTools.ini, Connections, ConnectionsRootUrl
		If (DefConnectionsRootUrl="ERROR")
			DefConnectionsRootUrl = xx ; TODO
	}
}
InputBox, PowerTools_ConnectionsRootUrl, Connections Url, Enter Connections Root Url: ,, 200, 125,,, , , %DefConnectionsRootUrl%
If ErrorLevel
   	return
PowerTools_ConnectionsRootUrl := StrReplace(PowerTools_ConnectionsRootUrl,"https://","")
PowerTools_ConnectionsRootUrl := StrReplace(PowerTools_ConnectionsRootUrl,"http://","")
PowerTools_RegWrite("ConnectionsRootUrl",PowerTools_ConnectionsRootUrl)
return PowerTools_ConnectionsRootUrl
} ; eofun
; -------------------------------------------------------------------------------------------------------------------

Connections_ProfileSearch2Emails(sUrl) {
; Syntax: sEmailList := Connections_ProfileSearch2Emails(sUrl)
PowerTools_ConnectionsRootUrl := PowerTools_RegRead("ConnectionsRootUrl")
ReConnectionsRootUrl := StrReplace(PowerTools_ConnectionsRootUrl,".","\.")
sPat := "^https?://" . ReConnectionsRootUrl  . "/profiles/html/.*"

If !RegExMatch(sUrl,sPat) {
	TrayTip, ProfileSearch2Emails, Url does not match a profile search '<connectionsroot>/profiles/html/'!,,0x3
	return
}

sUrl := RegExReplace(sUrl, "pageSize=[^&]*&","") ; remove pageSize 
sAtomUrl := RegExReplace(sUrl, "/html/[^/]*[sS]earch.do", "/atom/search.do")


sXml := CNGetAtomPages(sAtomUrl)

If (sXml ~= "Error.*") {
	;MsgBox 0x10, Connections Enhancer: Error, Could not download page!
	return
}

sPat = U)<email>(.*)</email>
Pos = 1 
While Pos := RegExMatch(sXml,sPat,sEmail,Pos+StrLen(sEmail)){
	sEmailList = %sEmailList%;%sEmail1%
}
return SubStr(sEmailList,2) ; remove starting ;
} ; eofun
; -------------------------------------------------------------------------------------------------------------------


; -------------------------------------------------------------------------------------------------------------------
; Returns true if current window can be an opened connext editor
Connections_IsWinEdit(sUrl := "") {
If !sUrl ; empty
	sUrl := Browser_GetUrl()
PowerTools_ConnectionsRootUrl := PowerTools_RegRead("ConnectionsRootUrl")
ReConnectionsRootUrl := StrReplace(PowerTools_ConnectionsRootUrl,".","\.")
If InStr(sUrl,PowerTools_ConnectionsRootUrl . "/wikis/")
	return RegExMatch(sURL, ReConnectionsRootUrl . "/wikis/.*/edit") || RegExMatch(sURL, ReConnectionsRootUrl . "/wikis/.*/create")
Else If InStr(sUrl, PowerTools_ConnectionsRootUrl . "/blogs/")
	return InStr(sUrl, PowerTools_ConnectionsRootUrl . "/blogs/roller-ui/authoring/weblog.do") ; method edit or create
Else If InStr(sUrl, PowerTools_ConnectionsRootUrl . "forums/html/topic?") or InStr(sUrl, PowerTools_ConnectionsRootUrl . "/forums/html/threadTopic?") or  RegExMatch(sURL, ReConnectionsRootUrl . "/forums/html/forum\?id=.*showForm=true")
	return True ;(A_Cursor = "IBeam")
}
; -------------------------------------------------------------------------------------------------------------------

Connections_IsWinActive() {
If Not Browser_WinActive()
    return False
sUrl := Browser_GetUrl()
return Connections_IsUrl(sUrl)
} ; eofun
; -------------------------------------------------------------------------------------------------------------------

Connections_IsUrl(sUrl,sType:="") {
PowerTools_ConnectionsRootUrl := PowerTools_RegRead("ConnectionsRootUrl")
If (sType = "")
	return InStr(sUrl,"://" . PowerTools_ConnectionsRootUrl)
	
Switch sType
{
Case "blog":
	return InStr(sUrl,"://" . PowerTools_ConnectionsRootUrl . "/blogs/")
Case "forum":
	return InStr(sUrl,"://" . PowerTools_ConnectionsRootUrl . "/forums/")
Case "wiki":
	return InStr(sUrl,"://" . PowerTools_ConnectionsRootUrl . "/wikis/")
Case "wiki-edit":
	ReConnectionsRootUrl := StrReplace(PowerTools_ConnectionsRootUrl,".","\.")
	return RegExMatch(sUrl, ReConnectionsRootUrl  . "/wikis/.*/edit")
Default:
 return InStr(sUrl,"://" . PowerTools_ConnectionsRootUrl)
} ; end switch
} ; end function

; ----------------------------------------------------------------------

Connections_CloseCodeView(){
; Close code view iff opened
Text:="|<>*176$113.00000000000000000000000000000000000M00TU0000000007s000k01r0000000000xk001U0600000000003U000300A000000000060000600M0DUUliDVs0M03s7g7UM0tl1XUt6Q0k0AsQsNkQ31W3630MM100kNUlVUC6146A40kE2030n1X106838AMM1zk6061a37z04E6EMkk300A0A3A6A00Ak8UlUU600M0M6MAM00FUlVX1UA00M0MAkMk1vVn3b61WCM0SstkvktVw1w3qA1wDU0DkT0xUy00000000000000000000000000000000000000U"

If (ok:=FindText(,,,, 0, 0, Text,,0))
	SendInput {Tab 2}{Enter}
} ;eofun

; ----------------------------------------------------------------------
Connections_GetHtmlEditor(){
; Get Html from Connections Editor using Hotkey Ctrl+Shift+U
; only works with textbox.io and TinyMCE in RichText Mode - Else user must already be in HTML Source view
Send ^+u ; Open code view via Ctrl+Shift+U Hotkey
; Copy all source code to clipboard
	
Send ^a
sleep, 300
sHtml := Clip_GetSelection()
return sHtml
} ; eofun
; ----------------------------------------------------------------------

; -------------------------------------------------------------------------------------------------------------------
Connections_CleanCode(sHtml){
; Clean table style
sPat = rel="noopener noreferrer.*?"
sHtml := RegExReplace(sHtml,sPat,"")
;sHtml := StrReplace(sHtml,"&nbsp;"," ")
sHtml := StrReplace(sHtml,"&amp;","&")

sHtml := StrReplace(sHtml,"white-space:pre","") ; copy from Visual Studio VS Code

; Remove black font formatting
sPat = Us)<span style="color:rgb\( 0 , 0 , 0 \)">(.*)</span>
sHtml := RegExReplace(sHtml,sPat,"$1")

; Remove id="wikiLink.*"
sPat = U)id="wikiLink.*"
sHtml := RegExReplace(sHtml,sPat,"")

return sHtml
}
; -------------------------------------------------------------------------------------------------------------------
; ----------------------------------------------------------------------
Connections_CleanLinks(sHtml){
; Clean ConNext Url from lang tags
sHtml := StrReplace(sHtml,"http://" . PowerTools_ConnectionsRootUrl . "/","https://" . PowerTools_ConnectionsRootUrl . "/")
sHtml  := RegExReplace(sHtml , "[&|\?]lang=[\w-_]+(#!)?" , "")	
; Remove lastMod part from links
sHtml := RegExReplace(sHtml, "&lastMod=\d+" , "")

return sHtml
}
; ----------------------------------------------------------------------
Connections_CleanTable(sHtml){
; Clean table style

;sPat = <td style="[^"]*?
;sRep = <td style="text-align:center; 
;sHtml := RegExReplace(sHtml,sPat,sRep)

;<td style="width:288px;border-color:#696969">

sHtml := RegExReplace(sHtml,"<td style=""width:[^;]*","<td style=""")
;sHtml := RegExReplace(sHtml,"<td style=""height:.*?;""","<td ")
sPat = <tr style="width:.*?;"
sHtml := RegExReplace(sHtml,sPat,"<tr ")
sPat = <tr style="height:.*?;"
sHtml := RegExReplace(sHtml,sPat,"<tr ")
;sHtml := RegExReplace(sHtml,"height:.*?;","")
;sHtml := RegExReplace(sHtml,"style=""\s*?""","") ; remove empty style

;Full Width: https://connectionsroot/blogs/tdalon/entry/nice_html_tables
sPat =  <table (.*?) style="[^"]*
;table border="1" style="border-collapse: collapse; width: 100%;"
sRep = <table $1 style="table-layout: fixed; width: 95_percent;
sRep := StrReplace(sRep,"_percent","%")
sHtml := RegExReplace(sHtml,sPat,sRep)

return sHtml
}
; ----------------------------------------------------------------------