#------------------------------------------------------------------------------------------------------------------------------------------
:local ddnsDomain "DOMAIN_NAME" #ex: example.com
:local ddnsHostname "HOSTNAME"  #ex: @ www app
:local ddnsInterface "PPPOE_INTERFACE_NAME"
:local cfToken "CLOUDFLARE_TOKEN"
#------------------------------------------------------------------------------------------------------------------------------------------
:global dynamicRecode
:local cache $dynamicRecode
#------------------------------------------------------------------------------------------------------------------------------------------

#------------------------------------------------------------------------------------------------------------------------------------------
if (([:len $cache] = 0) || ([:typeof $cache] = "nothing")) do= {
  :set cache {now, last, cfZoneID, cfDnsRecodeId, cfTTL, cfProxied}
}

#------------------------------------------------------------------------------------------------------------------------------------------
:set ($cache->"now") [/ip address get [/ip address find actual-interface=$ddnsInterface ] address ]

#------------------------------------------------------------------------------------------------------------------------------------------
if ([:typeof [($cache->"now")]] = nil ) do={
  :log info ("[DDNS] No ip address present on " . $ddnsInterface . ", please check.")

} else={
  :local ipFormat [:pick ($cache->"now") 0 [:find ($cache->"now") "/"]]
  
  #----------------------------------------------------------------------------------------------------------------------------------------
  :if (($cache->"now") != ($cache->"last")) do={
    :log info ("[DDNS] Try to Update use $ddnsInterface IP : $ipFormat")
    
    :local ddnsURL ""
    :local ddnsJSON ""
    :local result ""
    :local resultJSON ""
    :local cfZoneID ($cache->"cfZoneID")
    :local cfDnsRecodeId ($cache->"cfDnsRecodeId")
    :local cfTTL ($cache->"cfTTL")
    :local cfProxied ($cache->"cfProxied")
    
    #--------------------------------------------------------------------------------------------------------------------------------------
    if ([:len $cfZoneID] = 0) do= {
      :log info ("[DDNS] try to found Zone ID")
      :set ddnsURL "https://api.cloudflare.com/client/v4/zones?name=$ddnsDomain"
      :set result [:tool fetch url=$ddnsURL http-method=get mode=https \
      http-header-field="Authorization: Bearer $cfToken,content-type:application/json"\
      as-value output=user]
      
      :set resultJSON [:deserialize from=json value=($result->"data")]
      :set cfZoneID ([:pick ($resultJSON->"result") 0]->"id")
      :set ($cache->"cfZoneID") $cfZoneID
	  :log info ("[DDNS] Zone ID is: $cfZoneID")
    }
    
    #--------------------------------------------------------------------------------------------------------------------------------------
    if ([:len $cfZoneID] > 0) do= {
      #------------------------------------------------------------------------------------------------------------------------------------
      if ([:len $cfDnsRecodeId] = 0) do= {
        :log info ("[DDNS] try to found DNS Recode ID")
        :set ddnsURL "https://api.cloudflare.com/client/v4/zones/$cfZoneID/dns_records?type=A&name=$ddnsHostname.$ddnsDomain"
        :set result [:tool fetch url=$ddnsURL http-method=get mode=https \
        http-header-field="Authorization: Bearer $cfToken,content-type:application/json" as-value output=user]
        
        :set resultJSON [:deserialize from=json value=($result->"data")]
        :set cfDnsRecodeId  ([:pick ($resultJSON->"result") 0]->"id")
        :set cfTTL ([:pick ($resultJSON->"result") 0]->"ttl")
        :set cfProxied ([:pick ($resultJSON->"result") 0]->"proxied")
        :set ($cache->"cfDnsRecodeId") cfDnsRecodeId
        :set ($cache->"cfTTL") cfTTL
        :set ($cache->"cfProxied") cfProxied
		:log info ("[DDNS] DNS Recode ID is: $cfZoneID  ttl: $cfTTL  proxied: $cfProxied")
      }
      
      #------------------------------------------------------------------------------------------------------------------------------------
      if ([:len $cfDnsRecodeId] > 0) do= {
        #update dns
        :set ddnsURL "https://api.cloudflare.com/client/v4/zones/$cfZoneID/dns_records/$cfDnsRecodeId"
        :set ddnsJSON "{\"type\":\"A\",\"name\":\"$ddnsHostname\",\"content\":\"$ipFormat\",\"ttl\":$cfTTL,\"proxied\":$cfProxied}"
        :set result [:tool fetch url="$ddnsURL" http-method=put http-data=$ddnsJSON mode=https \
        http-header-field="Authorization: Bearer $cfToken,content-type:application/json" as-value output=user]
        
        :set resultJSON [:deserialize from=json value=($result->"data")]
        
        #----------------------------------------------------------------------------------------------------------------------------------
        if ($resultJSON->"success" = true) do= {
          :set ($cache->"last") ($cache->"now")
          :log info ("[DDNS] Update Successful.")
          
        } else {
          :log info ("[DDNS] Update Failed.")
        }
        
      } else {
          :log info ("[DDNS] Can't found DNS Recode ID")
        
        }
    } else {
      :log info ("[DDNS] Can't found Zone ID")
    }

    
  } else={
    :log info ("[DDNS] $ddnsInterface $ddnsHostname.$ddnsDomain $ipFormat is already up to date.")
  }
}

#------------------------------------------------------------------------------------------------------------------------------------------
:set $dynamicRecode $cache
