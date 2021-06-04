; pb-httprequest-manager rev.1
; written by deseven
;
; https://github.com/deseven/pb-httprequest-manager

DeclareModule HTTPRequestManager
  
  EnableExplicit
  
  Structure request
    type.b
    url.s
    textData.s
    flags.i
    Map headers.s()
    finishEvent.i
    timeout.i
    comment.s
  EndStructure
  
  Structure response
    result.b
    statusCode.l
    response.s
    headers.s
    error.s
  EndStructure
  
  Enumeration HTTPRequestManagerStatus 1
    #Queued
    #InProgress
    #TimedOutAborting
    #TimedOut
    #Failed
    #Success
  EndEnumeration
  
  Declare init(MaxConcurrentRequests.b=3,DefaultRequestTimeout.i=30000,DefaultUserAgent.s="",DefaultFinishEvent=0,TreatAbortingAsActive.b=#False)
  Declare process()
  Declare request(*request.request)
  Declare easyRequest(Type,URL$,Data$="",Flags=0)
  Declare free(id.i)
  Declare getNumActive()
  Declare getNumTotal()
  Declare getResponse(id.i)
  Declare getStatus(id.i)
  Declare.s getComment(id.i)
  
EndDeclareModule

Module HTTPRequestManager
  
  Structure requestInternal
    id.i
    httpRequestID.i
    status.b
    started.i
    finished.i
    remove.b
    request.request
    response.response
  EndStructure
  
  Global init.b
  Global concurrentRequests.b
  Global defaultTimeout.l
  Global defaultEvent.i
  Global abortingIsActive.b
  Global userAgent.s
  Global NewList requests.requestInternal()
  
  Procedure init(MaxConcurrentRequests.b = 3,DefaultRequestTimeout.i = 30000,DefaultUserAgent.s = "",DefaultFinishEvent = 0,TreatAbortingAsActive.b = #False)
    userAgent          = DefaultUserAgent
    concurrentRequests = MaxConcurrentRequests
    defaultTimeout     = DefaultRequestTimeout
    defaultEvent       = DefaultFinishEvent
    abortingIsActive   = TreatAbortingAsActive
    init               = #True
    ProcedureReturn #True
  EndProcedure
  
  Procedure getNumTotal()
    If init
      ProcedureReturn ListSize(requests())
    EndIf
  EndProcedure
  
  Procedure getNumActive()
    Protected numRequests.i
    If init
      ForEach requests()
        If requests()\status = #InProgress
          numRequests + 1
        EndIf
        If abortingIsActive And requests()\status = #TimedOutAborting
          numRequests + 1
        EndIf
      Next
      ProcedureReturn numRequests
    EndIf
  EndProcedure
  
  Procedure getResponse(id.i)
    If init
      ForEach requests()
        If requests()\id = id
          If requests()\status >= #TimedOut
            ProcedureReturn @requests()\response
          Else
            Break
          EndIf
        EndIf
      Next
    EndIf
  EndProcedure
  
  Procedure getStatus(id.i)
    If init
      ForEach requests()
        If requests()\id = id
          ProcedureReturn requests()\status
        EndIf
      Next
    EndIf
  EndProcedure
  
  Procedure.s getComment(id.i)
    If init
      ForEach requests()
        If requests()\id = id
          ProcedureReturn requests()\request\comment
        EndIf
      Next
    EndIf
  EndProcedure
  
  Procedure free(id.i)
    If init
      ForEach requests()
        If requests()\id = id Or id = #PB_All
          If requests()\status >= #TimedOut Or requests()\status = #Queued
            DeleteElement(requests())
            If id <> #PB_All
              ProcedureReturn #True
            EndIf
          EndIf
        EndIf
      Next
    EndIf
  EndProcedure
  
  Procedure abort(id.i)
    If init
      ForEach requests()
        If requests()\id = id
          If requests()\status = #InProgress
            AbortHTTP(requests()\httpRequestID)
            ProcedureReturn #True
          EndIf
        EndIf
      Next
    EndIf
  EndProcedure
  
  Procedure nextID()
    Protected maxID.i
    ForEach requests()
      If requests()\id > maxID
        maxID = requests()\id
      EndIf
    Next
    ProcedureReturn maxID + 1
  EndProcedure
  
  Procedure requestStart(*request.requestInternal)
    *request\started = ElapsedMilliseconds()
    *request\status = #InProgress
    ProcedureReturn HTTPRequest(*request\request\type,*request\request\url,*request\request\textData,*request\request\flags,*request\request\headers())
  EndProcedure
  
  Procedure easyRequest(Type,URL$,Data$ = "",Flags = 0)
    If init
      Protected request.request
      request\url = URL$
      request\textData = Data$
      request\flags = Flags
      request\type = Type
      ProcedureReturn request(@request)
    EndIf
  EndProcedure
  
  Procedure request(*request.request)
    If init
      Protected addUserAgent = #True
      Protected nextID.i = nextID()
      AddElement(requests())
      requests()\id = nextID
      If *request\timeout = 0
        *request\timeout = defaultTimeout
      EndIf
      If *request\finishEvent = 0
        *request\finishEvent = defaultEvent
      EndIf
      ForEach *request\headers()
        If LCase(MapKey(*request\headers())) = "user-agent"
          addUserAgent = #False
        EndIf
      Next
      If addUserAgent And userAgent
        *request\headers("User-Agent") = userAgent
      EndIf
      *request\flags = *request\flags|#PB_HTTP_Asynchronous
      CopyStructure(*request,@requests()\request,request)
      requests()\status = #Queued
      If getNumActive() < concurrentRequests
        requests()\httpRequestID = requestStart(@requests())
      EndIf
    EndIf
    ProcedureReturn requests()\id
  EndProcedure
  
  Procedure process()
    If ListSize(requests())
      ForEach requests()
        Select requests()\status
          Case #TimedOutAborting,#InProgress
            Protected progress.i = HTTPProgress(requests()\httpRequestID)
            Select progress
              Case #PB_HTTP_Success,#PB_HTTP_Failed,#PB_HTTP_Aborted
                Select progress
                  Case #PB_HTTP_Success
                    requests()\status = #Success
                  Case #PB_HTTP_Failed
                    requests()\status = #Failed
                  Case #PB_HTTP_Aborted
                    requests()\status = #TimedOut
                EndSelect
                requests()\finished = ElapsedMilliseconds()
                requests()\response\response = HTTPInfo(requests()\httpRequestID,#PB_HTTP_Response)
                requests()\response\statusCode = Val(HTTPInfo(requests()\httpRequestID,#PB_HTTP_StatusCode))
                requests()\response\headers = HTTPInfo(requests()\httpRequestID,#PB_HTTP_Headers)
                requests()\response\error = HTTPInfo(requests()\httpRequestID,#PB_HTTP_ErrorMessage)
                FinishHTTP(requests()\httpRequestID)
                requests()\httpRequestID = 0
                If requests()\request\finishEvent > 0
                    PostEvent(requests()\request\finishEvent,-1,-1,-1,requests()\id)
                EndIf
              Default
                If requests()\request\timeout > 0
                  If requests()\started + requests()\request\timeout < ElapsedMilliseconds()
                    requests()\status = #TimedOutAborting
                    AbortHTTP(requests()\httpRequestID)
                  EndIf
                EndIf
            EndSelect
        EndSelect
      Next
      
      If getNumActive() < concurrentRequests
        ForEach requests()
          If requests()\status = #Queued
            requests()\httpRequestID = requestStart(@requests())
            Break
          EndIf
        Next
      EndIf
      
    EndIf
  EndProcedure
  
EndModule