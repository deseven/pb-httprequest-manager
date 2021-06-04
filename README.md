# pb-httprequest-manager
A queue manager for [PureBasic](http://purebasic.com)'s HTTPRequest(), supports timeouts, parallel requests and completion events. Originally created to mitigate a couple of PB bugs, but can also be used if you need to make a ton of requests with little effort.  

## usage
```
IncludeFile "httprequest-manager.pbi"

InitNetwork()
HTTPRequestManager::init()

For i = 1 To 10
  HTTPRequestManager::easyRequest(#PB_HTTP_Get,"https://google.com/")
Next

While HTTPRequestManager::getNumActive()
  HTTPRequestManager::process()
  Delay(50)
Wend

HTTPRequestManager::free(#PB_All)
```
For advanced usage check out the included `example.pb`.