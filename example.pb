EnableExplicit

IncludeFile "httprequest-manager.pbi"

Enumeration #PB_Event_FirstCustomValue
  #ev_HTTP
  #ev_HTTP_Special
EndEnumeration

Macro AddRequests()
  
  ; a simple GET request, syntax pretty much mimics the original HTTPRequest()
  HTTPRequestManager::easyRequest(#PB_HTTP_Get,"https://httpbin.org/get?var=value")
  
  ; a simple POST request with additional flags
  HTTPRequestManager::easyRequest(#PB_HTTP_Post,"https://httpbin.org/post","var=value",#PB_HTTP_NoRedirect)
  
  ; a simple request which will become stalled after the timeout defined in init()
  HTTPRequestManager::easyRequest(#PB_HTTP_Get,"http://httpstat.us/200?sleep=10000")
  
  ; a simple request which will never answer
  HTTPRequestManager::easyRequest(#PB_HTTP_Get,"http://www.google.com:81/")
  
  ; a simple request which will return 404
  HTTPRequestManager::easyRequest(#PB_HTTP_Get,"https://httpbin.org/404")
  
  ; a simple request which will redirect 3 times
  HTTPRequestManager::easyRequest(#PB_HTTP_Get,"https://httpbin.org/redirect/3")
  
  ; a simple request to a non-existing domain
  HTTPRequestManager::easyRequest(#PB_HTTP_Get,"http://nodomain.d7.wtf")
  
  ; a more advanced request requires using a pre-defined structure
  Define Request.HTTPRequestManager::request
  Request\type = #PB_HTTP_Get
  Request\url = "https://httpbin.org/headers"
  Request\headers("My-Cool-Header") = "My cool value"
  Request\headers("Another-Cool-Header") = "Another cool value"
  Request\comment = "This request is special!" ;can be used to store text data related to the request
  Request\finishEvent = #ev_HTTP_Special
  Request\timeout = 10000
  HTTPRequestManager::request(@Request)
  
  ; each request returns a unique id that can be used later
  ; this id will be also returned in the finish event (if you defined one), use EventData() to get it
  
EndMacro

OpenWindow(0,0,0,400,300,"HTTPRequestManager Example",#PB_Window_ScreenCentered|#PB_Window_SystemMenu)
EditorGadget(0,0,0,400,270,#PB_Editor_WordWrap|#PB_Editor_ReadOnly)
ButtonGadget(1,0,270,200,30,"Add requests")
TextGadget(2,200,276,195,30,"Active/Total",#PB_Text_Right)

; 3 concurrent requests, 3 sec timeout, set user agent, send #ev_HTTP event on completion
HTTPRequestManager::init(3,3000,"HTTPRequestManager/1.0",#ev_HTTP)

Define ev.i,active.i,activeNew.i,id.i
Define *response.HTTPRequestManager::response
Define log.s

Repeat
  
  ev = WaitWindowEvent(50)
  
  ; needs to be called from time to time
  HTTPRequestManager::process()
  
  SetGadgetText(2,"Active/Stalled/Total (" + Str(HTTPRequestManager::getNumActive()) + "/" + Str(HTTPRequestManager::getNumStalled()) + "/" + Str(HTTPRequestManager::getNumTotal()) + ")")
  
  Select ev
      
    Case #PB_Event_Gadget
      If EventGadget() = 1
        AddRequests()
      EndIf
      
    Case #ev_HTTP,#ev_HTTP_Special
      
      ; getting response for our request
      *response = HTTPRequestManager::getResponse(EventData())
      
      If *response
        log = "[" + FormatDate("%hh:%ii:%ss",Date()) + "] Finished #" + Str(EventData()) + " ("
        Select HTTPRequestManager::getStatus(EventData())
          Case HTTPRequestManager::#TimedOut
            log + "timed out"
          Case HTTPRequestManager::#Failed
            log + "failed, " + *response\error
          Case HTTPRequestManager::#Success
            log + "success, "
            log + "code " + Str(*response\statusCode)
            log + ", " + Str(HTTPRequestManager::getDownloadedBytes(EventData())) + " bytes"
        EndSelect
        log + "), took " + Str(HTTPRequestManager::getTimeTook(EventData())) + "ms"
        AddGadgetItem(0,0,log)
        
        ; actual server answer
        If *response\text
          Debug "response for " + Str(EventData()) + ":"
          Debug *response\text
          Debug "====="
        EndIf
        
        ; we previously set a comment for our "special" request
        If ev = #ev_HTTP_Special
          Debug HTTPRequestManager::getComment(EventData())
        EndIf
        
        ; it's always a good idea to free the used resources
        HTTPRequestManager::free(EventData())
      EndIf
      
  EndSelect
  
Until ev = #PB_Event_CloseWindow